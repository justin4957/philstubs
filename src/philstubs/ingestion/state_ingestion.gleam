import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import philstubs/core/legislation
import philstubs/data/legislation_repo
import philstubs/ingestion/congress_api_client.{type HttpDispatcher}
import philstubs/ingestion/congress_types.{type ApiError, ApiKeyMissing}
import philstubs/ingestion/ingestion_state_repo
import philstubs/ingestion/openstates_api_client
import philstubs/ingestion/openstates_types.{type OpenStatesConfig}
import philstubs/ingestion/rate_limiter.{type RateLimiterState}
import philstubs/ingestion/state_bill_mapper
import sqlight

/// Default page size for Open States bill list requests.
const default_page_size = 20

/// Minimum milliseconds between Open States API requests.
/// Open States allows 10 req/min = 6000ms between requests.
const openstates_rate_limit_ms = 6000

/// Result of ingesting bills for a single jurisdiction.
pub type StateIngestionResult {
  StateIngestionResult(
    jurisdiction: String,
    bills_fetched: Int,
    bills_stored: Int,
  )
}

/// Errors that can occur during state ingestion.
pub type StateIngestionError {
  StateApiClientError(ApiError)
  StateDatabaseError(sqlight.Error)
}

/// Run state ingestion using the production dispatcher and env API key.
pub fn run(
  connection: sqlight.Connection,
  jurisdictions: List(String),
) -> Result(
  List(Result(StateIngestionResult, StateIngestionError)),
  StateIngestionError,
) {
  case openstates_api_client.load_api_key() {
    Error(ApiKeyMissing) -> Error(StateApiClientError(ApiKeyMissing))
    Error(other) -> Error(StateApiClientError(other))
    Ok(api_key) -> {
      let config = openstates_api_client.default_config(api_key)
      let dispatcher = openstates_api_client.default_dispatcher()
      Ok(ingest_jurisdictions(connection, config, jurisdictions, dispatcher))
    }
  }
}

/// Ingest bills for multiple jurisdictions. Continues on per-jurisdiction
/// failure, collecting results for each jurisdiction independently.
pub fn ingest_jurisdictions(
  connection: sqlight.Connection,
  config: OpenStatesConfig,
  jurisdictions: List(String),
  dispatcher: HttpDispatcher,
) -> List(Result(StateIngestionResult, StateIngestionError)) {
  ingest_jurisdictions_loop(connection, config, jurisdictions, dispatcher, [])
}

fn ingest_jurisdictions_loop(
  connection: sqlight.Connection,
  config: OpenStatesConfig,
  remaining_jurisdictions: List(String),
  dispatcher: HttpDispatcher,
  accumulated_results: List(Result(StateIngestionResult, StateIngestionError)),
) -> List(Result(StateIngestionResult, StateIngestionError)) {
  case remaining_jurisdictions {
    [] -> list.reverse(accumulated_results)
    [jurisdiction, ..rest] -> {
      let jurisdiction_result =
        ingest_jurisdiction(connection, config, jurisdiction, dispatcher)
      ingest_jurisdictions_loop(connection, config, rest, dispatcher, [
        jurisdiction_result,
        ..accumulated_results
      ])
    }
  }
}

/// Ingest bills for a single jurisdiction from Open States.
/// Resumes from last page if previous ingestion state exists.
pub fn ingest_jurisdiction(
  connection: sqlight.Connection,
  config: OpenStatesConfig,
  jurisdiction: String,
  dispatcher: HttpDispatcher,
) -> Result(StateIngestionResult, StateIngestionError) {
  let session = current_session_identifier()
  let ingestion_id =
    ingestion_state_repo.build_state_ingestion_id(jurisdiction, session)

  // Load or create ingestion state
  use existing_state <- result.try(
    ingestion_state_repo.get_by_jurisdiction_and_session(
      connection,
      jurisdiction,
      session,
    )
    |> result.map_error(StateDatabaseError),
  )

  let initial_page = case existing_state {
    Some(state) ->
      case state.last_page > 0 {
        True -> state.last_page
        False -> 1
      }
    None -> 1
  }

  // Create/update ingestion state to "in_progress"
  let initial_state =
    ingestion_state_repo.IngestionState(
      id: ingestion_id,
      source: "openstates",
      congress_number: None,
      bill_type: None,
      jurisdiction: Some(jurisdiction),
      session: Some(session),
      last_offset: 0,
      last_page: initial_page,
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
    |> result.map_error(StateDatabaseError),
  )

  let rate_limiter_state =
    rate_limiter.new_with_interval(openstates_rate_limit_ms)

  // Start paginated fetch loop
  case
    fetch_and_store_page_loop(
      connection,
      config,
      jurisdiction,
      dispatcher,
      initial_page,
      ingestion_id,
      0,
      rate_limiter_state,
      None,
    )
  {
    Ok(total_stored) -> {
      let _ = ingestion_state_repo.mark_completed(connection, ingestion_id)
      Ok(StateIngestionResult(
        jurisdiction: jurisdiction,
        bills_fetched: total_stored,
        bills_stored: total_stored,
      ))
    }
    Error(ingestion_error) -> {
      let error_message = state_ingestion_error_to_string(ingestion_error)
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

fn fetch_and_store_page_loop(
  connection: sqlight.Connection,
  config: OpenStatesConfig,
  jurisdiction: String,
  dispatcher: HttpDispatcher,
  page: Int,
  ingestion_id: String,
  total_stored: Int,
  rate_limiter_state: RateLimiterState,
  updated_since: Option(String),
) -> Result(Int, StateIngestionError) {
  // Rate limit
  let rate_limiter_state = rate_limiter.wait_for_capacity(rate_limiter_state)

  // Fetch page
  let fetch_result =
    openstates_api_client.fetch_bills(
      config,
      jurisdiction,
      page,
      default_page_size,
      updated_since,
      dispatcher,
    )

  case fetch_result {
    Error(api_error) -> Error(StateApiClientError(api_error))
    Ok(bill_list_response) -> {
      let bills = bill_list_response.results
      let bills_count = list.length(bills)

      // Store each bill
      use stored_count <- result.try(store_bills_loop(connection, bills, 0))

      let new_total = total_stored + stored_count

      // Update page progress
      let _ =
        ingestion_state_repo.update_page_progress(
          connection,
          ingestion_id,
          page,
          stored_count,
        )

      // Check if more pages available
      case page < bill_list_response.pagination.max_page && bills_count > 0 {
        True ->
          fetch_and_store_page_loop(
            connection,
            config,
            jurisdiction,
            dispatcher,
            page + 1,
            ingestion_id,
            new_total,
            rate_limiter_state,
            updated_since,
          )
        False -> Ok(new_total)
      }
    }
  }
}

fn store_bills_loop(
  connection: sqlight.Connection,
  bills: List(openstates_types.OpenStatesBill),
  stored_count: Int,
) -> Result(Int, StateIngestionError) {
  case bills {
    [] -> Ok(stored_count)
    [bill, ..rest] -> {
      let legislation_record = state_bill_mapper.map_bill_to_legislation(bill)
      let legislation_id_string =
        legislation.legislation_id_to_string(legislation_record.id)

      // Check if already exists
      case legislation_repo.get_by_id(connection, legislation_id_string) {
        Error(db_error) -> Error(StateDatabaseError(db_error))
        Ok(Some(_existing)) -> {
          // Update existing record
          case legislation_repo.update(connection, legislation_record) {
            Error(db_error) -> Error(StateDatabaseError(db_error))
            Ok(Nil) -> store_bills_loop(connection, rest, stored_count + 1)
          }
        }
        Ok(None) -> {
          // Insert new record
          case legislation_repo.insert(connection, legislation_record) {
            Error(db_error) -> Error(StateDatabaseError(db_error))
            Ok(Nil) -> store_bills_loop(connection, rest, stored_count + 1)
          }
        }
      }
    }
  }
}

/// Determine the current legislative session identifier.
/// Most states use 2-year sessions aligned with odd-year starts.
fn current_session_identifier() -> String {
  "2025"
}

/// Re-export load_api_key for test use.
pub fn load_api_key_for_test() -> Result(String, ApiError) {
  openstates_api_client.load_api_key()
}

/// Re-export default_dispatcher for test use.
pub fn default_dispatcher_for_test() -> HttpDispatcher {
  openstates_api_client.default_dispatcher()
}

/// Fetch and store a single page of state bills. Used by live smoke tests
/// to avoid paginating through the entire bill list.
pub fn fetch_single_page_for_test(
  connection: sqlight.Connection,
  config: OpenStatesConfig,
  jurisdiction: String,
  page: Int,
  per_page: Int,
  dispatcher: HttpDispatcher,
) -> Result(Int, StateIngestionError) {
  let fetch_result =
    openstates_api_client.fetch_bills(
      config,
      jurisdiction,
      page,
      per_page,
      None,
      dispatcher,
    )

  case fetch_result {
    Error(api_error) -> Error(StateApiClientError(api_error))
    Ok(bill_list_response) -> {
      store_bills_loop(connection, bill_list_response.results, 0)
    }
  }
}

fn state_ingestion_error_to_string(error: StateIngestionError) -> String {
  case error {
    StateApiClientError(api_error) ->
      "API error: " <> api_error_to_string(api_error)
    StateDatabaseError(db_error) ->
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
