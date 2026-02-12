import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import philstubs/core/government_level
import philstubs/core/legislation
import philstubs/data/legislation_repo
import philstubs/ingestion/congress_api_client.{type HttpDispatcher}
import philstubs/ingestion/congress_types.{type ApiError}
import philstubs/ingestion/ingestion_adapter.{
  type AdapterError, type AdapterResult, AdapterApiError, AdapterDatabaseError,
  AdapterResult,
}
import philstubs/ingestion/ingestion_state_repo
import philstubs/ingestion/jurisdiction_registry
import philstubs/ingestion/legistar_api_client
import philstubs/ingestion/legistar_mapper
import philstubs/ingestion/legistar_types.{
  type LegistarConfig, type LegistarMatter,
}
import philstubs/ingestion/rate_limiter.{type RateLimiterState}
import sqlight

/// Default page size for Legistar OData requests.
const default_page_size = 100

/// Minimum milliseconds between Legistar API requests.
/// Conservative 500ms interval since no documented rate limit.
const legistar_rate_limit_ms = 500

/// Run ingestion for a list of Legistar client IDs.
/// Looks up each client_id in the jurisdiction registry and ingests
/// with default config (no token, default base URL).
pub fn run(
  connection: sqlight.Connection,
  client_ids: List(String),
) -> List(Result(AdapterResult, AdapterError)) {
  let dispatcher = legistar_api_client.default_dispatcher()
  ingest_clients(connection, client_ids, None, dispatcher)
}

/// Ingest multiple Legistar clients. Continues on per-client failure,
/// collecting results for each client independently.
pub fn ingest_clients(
  connection: sqlight.Connection,
  client_ids: List(String),
  token: Option(String),
  dispatcher: HttpDispatcher,
) -> List(Result(AdapterResult, AdapterError)) {
  ingest_clients_loop(connection, client_ids, token, dispatcher, [])
}

fn ingest_clients_loop(
  connection: sqlight.Connection,
  remaining_clients: List(String),
  token: Option(String),
  dispatcher: HttpDispatcher,
  accumulated_results: List(Result(AdapterResult, AdapterError)),
) -> List(Result(AdapterResult, AdapterError)) {
  case remaining_clients {
    [] -> list.reverse(accumulated_results)
    [client_id, ..rest] -> {
      let config = legistar_types.default_config(client_id, token)
      let client_result = ingest_client(connection, config, dispatcher)
      ingest_clients_loop(connection, rest, token, dispatcher, [
        client_result,
        ..accumulated_results
      ])
    }
  }
}

/// Ingest matters from a single Legistar client.
/// Looks up the client_id in the jurisdiction registry for government level.
/// Resumes from last offset if previous ingestion state exists.
pub fn ingest_client(
  connection: sqlight.Connection,
  config: LegistarConfig,
  dispatcher: HttpDispatcher,
) -> Result(AdapterResult, AdapterError) {
  let jurisdiction_entry =
    jurisdiction_registry.get_by_client_id(config.client_id)

  let level = case jurisdiction_entry {
    Some(entry) -> entry.government_level
    None ->
      // Default to Municipal with unknown location for unregistered clients
      government_level.Municipal("", config.client_id)
  }

  ingest_client_with_level(connection, config, level, dispatcher)
}

/// Ingest matters from a single Legistar client with an explicit government level.
pub fn ingest_client_with_level(
  connection: sqlight.Connection,
  config: LegistarConfig,
  government_level: government_level.GovernmentLevel,
  dispatcher: HttpDispatcher,
) -> Result(AdapterResult, AdapterError) {
  let ingestion_id =
    ingestion_state_repo.build_local_ingestion_id("legistar", config.client_id)

  // Load existing ingestion state for resumption
  use existing_state <- result.try(
    ingestion_state_repo.get_by_jurisdiction_and_session(
      connection,
      config.client_id,
      "current",
    )
    |> result.map_error(AdapterDatabaseError),
  )

  let initial_offset = case existing_state {
    Some(state) -> state.last_offset
    None -> 0
  }

  // Create/update ingestion state to "in_progress"
  let initial_state =
    ingestion_state_repo.IngestionState(
      id: ingestion_id,
      source: "legistar",
      congress_number: None,
      bill_type: None,
      jurisdiction: Some(config.client_id),
      session: Some("current"),
      last_offset: initial_offset,
      last_page: 0,
      last_update_date: None,
      total_bills_fetched: case existing_state {
        Some(state) -> state.total_bills_fetched
        None -> 0
      },
      status: "in_progress",
      started_at: None,
      completed_at: None,
      error_message: None,
    )

  use _ <- result.try(
    ingestion_state_repo.upsert(connection, initial_state)
    |> result.map_error(AdapterDatabaseError),
  )

  let rate_limiter_state =
    rate_limiter.new_with_interval(legistar_rate_limit_ms)

  // Start paginated fetch loop
  case
    fetch_and_store_loop(
      connection,
      config,
      government_level,
      dispatcher,
      initial_offset,
      ingestion_id,
      0,
      rate_limiter_state,
    )
  {
    Ok(total_stored) -> {
      let _ = ingestion_state_repo.mark_completed(connection, ingestion_id)
      Ok(AdapterResult(
        source_name: "legistar",
        client_id: config.client_id,
        bills_fetched: total_stored,
        bills_stored: total_stored,
      ))
    }
    Error(ingestion_error) -> {
      let error_message = adapter_error_to_string(ingestion_error)
      let _ =
        ingestion_state_repo.mark_failed(
          connection,
          ingestion_id,
          error_message,
        )
      Error(ingestion_error)
    }
  }
}

fn fetch_and_store_loop(
  connection: sqlight.Connection,
  config: LegistarConfig,
  government_level: government_level.GovernmentLevel,
  dispatcher: HttpDispatcher,
  offset: Int,
  ingestion_id: String,
  total_stored: Int,
  rate_limiter_state: RateLimiterState,
) -> Result(Int, AdapterError) {
  // Rate limit
  let rate_limiter_state = rate_limiter.wait_for_capacity(rate_limiter_state)

  // Fetch page of matters
  let fetch_result =
    legistar_api_client.fetch_matters(
      config,
      offset,
      default_page_size,
      dispatcher,
    )

  case fetch_result {
    Error(api_error) -> Error(AdapterApiError(api_error))
    Ok(matters) -> {
      let matters_count = list.length(matters)

      // Store each matter (with sponsor fetching)
      use stored_count <- result.try(store_matters_loop(
        connection,
        config,
        government_level,
        dispatcher,
        matters,
        0,
        rate_limiter_state,
      ))

      let new_total = total_stored + stored_count
      let new_offset = offset + matters_count

      // Update progress
      let _ =
        ingestion_state_repo.update_progress(
          connection,
          ingestion_id,
          new_offset,
          stored_count,
        )

      // Check if more pages available (empty array = end of data)
      case matters_count >= default_page_size && matters_count > 0 {
        True ->
          fetch_and_store_loop(
            connection,
            config,
            government_level,
            dispatcher,
            new_offset,
            ingestion_id,
            new_total,
            rate_limiter_state,
          )
        False -> Ok(new_total)
      }
    }
  }
}

fn store_matters_loop(
  connection: sqlight.Connection,
  config: LegistarConfig,
  government_level: government_level.GovernmentLevel,
  dispatcher: HttpDispatcher,
  matters: List(LegistarMatter),
  stored_count: Int,
  rate_limiter_state: RateLimiterState,
) -> Result(Int, AdapterError) {
  case matters {
    [] -> Ok(stored_count)
    [matter, ..rest] -> {
      // Rate limit for sponsor fetch
      let rate_limiter_state =
        rate_limiter.wait_for_capacity(rate_limiter_state)

      // Fetch sponsors for this matter
      let sponsors = case
        legistar_api_client.fetch_sponsors(config, matter.matter_id, dispatcher)
      {
        Ok(sponsor_list) -> sponsor_list
        Error(_) -> []
      }

      let legislation_record =
        legistar_mapper.map_matter_to_legislation(
          matter,
          config.client_id,
          government_level,
          sponsors,
        )
      let legislation_id_string =
        legislation.legislation_id_to_string(legislation_record.id)

      // Check if already exists (upsert pattern)
      case legislation_repo.get_by_id(connection, legislation_id_string) {
        Error(db_error) -> Error(AdapterDatabaseError(db_error))
        Ok(Some(_existing)) -> {
          case legislation_repo.update(connection, legislation_record) {
            Error(db_error) -> Error(AdapterDatabaseError(db_error))
            Ok(Nil) ->
              store_matters_loop(
                connection,
                config,
                government_level,
                dispatcher,
                rest,
                stored_count + 1,
                rate_limiter_state,
              )
          }
        }
        Ok(None) -> {
          case legislation_repo.insert(connection, legislation_record) {
            Error(db_error) -> Error(AdapterDatabaseError(db_error))
            Ok(Nil) ->
              store_matters_loop(
                connection,
                config,
                government_level,
                dispatcher,
                rest,
                stored_count + 1,
                rate_limiter_state,
              )
          }
        }
      }
    }
  }
}

/// Re-export default_dispatcher for test use.
pub fn default_dispatcher_for_test() -> HttpDispatcher {
  legistar_api_client.default_dispatcher()
}

/// Fetch and store a single page of matters. Used by live smoke tests
/// to avoid paginating through the entire matters list.
pub fn fetch_single_page_for_test(
  connection: sqlight.Connection,
  config: LegistarConfig,
  government_level: government_level.GovernmentLevel,
  skip: Int,
  top: Int,
  dispatcher: HttpDispatcher,
) -> Result(Int, AdapterError) {
  let fetch_result =
    legistar_api_client.fetch_matters(config, skip, top, dispatcher)

  case fetch_result {
    Error(api_error) -> Error(AdapterApiError(api_error))
    Ok(matters) -> {
      let rate_limiter_state =
        rate_limiter.new_with_interval(legistar_rate_limit_ms)
      store_matters_loop(
        connection,
        config,
        government_level,
        dispatcher,
        matters,
        0,
        rate_limiter_state,
      )
    }
  }
}

fn adapter_error_to_string(error: AdapterError) -> String {
  case error {
    AdapterApiError(api_error) ->
      "API error: " <> api_error_to_string(api_error)
    AdapterDatabaseError(db_error) ->
      "Database error: " <> sqlight_error_to_string(db_error)
  }
}

fn api_error_to_string(error: ApiError) -> String {
  case error {
    congress_types.HttpError(message) -> "HTTP error: " <> message
    congress_types.JsonDecodeError(message) -> "JSON decode error: " <> message
    congress_types.ApiKeyMissing -> "API key missing"
    congress_types.RateLimitExceeded -> "Rate limit exceeded"
    congress_types.NotFound -> "Not found"
    congress_types.ServerError(status) ->
      "Server error: " <> int.to_string(status)
  }
}

fn sqlight_error_to_string(error: sqlight.Error) -> String {
  case error {
    sqlight.SqlightError(_, message, _) -> message
  }
}
