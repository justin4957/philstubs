import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import philstubs/core/legislation
import philstubs/data/legislation_repo
import philstubs/ingestion/bill_mapper
import philstubs/ingestion/congress_api_client.{type HttpDispatcher}
import philstubs/ingestion/congress_types.{
  type ApiError, type CongressApiConfig, type CongressBillType, ApiKeyMissing,
}
import philstubs/ingestion/ingestion_state_repo
import philstubs/ingestion/rate_limiter.{type RateLimiterState}
import sqlight

/// Default page size for bill list requests.
const default_page_size = 20

/// Result of ingesting bills for a single bill type.
pub type IngestionResult {
  IngestionResult(bill_type: String, bills_fetched: Int, bills_stored: Int)
}

/// Errors that can occur during ingestion.
pub type IngestionError {
  ApiClientError(ApiError)
  DatabaseError(sqlight.Error)
}

/// Run ingestion using the production dispatcher and env API key.
pub fn run(
  connection: sqlight.Connection,
  congress_number: Int,
) -> Result(List(IngestionResult), IngestionError) {
  case congress_api_client.load_api_key() {
    Error(ApiKeyMissing) -> Error(ApiClientError(ApiKeyMissing))
    Error(other) -> Error(ApiClientError(other))
    Ok(api_key) -> {
      let config = congress_types.default_config(api_key, congress_number)
      let dispatcher = congress_api_client.default_dispatcher()
      ingest_all_bill_types(connection, config, dispatcher)
    }
  }
}

/// Ingest all bill types for a given congress.
pub fn ingest_all_bill_types(
  connection: sqlight.Connection,
  config: CongressApiConfig,
  dispatcher: HttpDispatcher,
) -> Result(List(IngestionResult), IngestionError) {
  let bill_types = congress_types.all_bill_types()
  ingest_bill_types_loop(connection, config, dispatcher, bill_types, [])
}

fn ingest_bill_types_loop(
  connection: sqlight.Connection,
  config: CongressApiConfig,
  dispatcher: HttpDispatcher,
  remaining_types: List(CongressBillType),
  accumulated_results: List(IngestionResult),
) -> Result(List(IngestionResult), IngestionError) {
  case remaining_types {
    [] -> Ok(list.reverse(accumulated_results))
    [bill_type, ..rest] -> {
      case ingest_bills(connection, config, bill_type, dispatcher) {
        Ok(ingestion_result) ->
          ingest_bill_types_loop(connection, config, dispatcher, rest, [
            ingestion_result,
            ..accumulated_results
          ])
        Error(ingestion_error) -> Error(ingestion_error)
      }
    }
  }
}

/// Ingest bills of a specific type from Congress.gov.
/// Resumes from last offset if previous ingestion state exists.
pub fn ingest_bills(
  connection: sqlight.Connection,
  config: CongressApiConfig,
  bill_type: CongressBillType,
  dispatcher: HttpDispatcher,
) -> Result(IngestionResult, IngestionError) {
  let bill_type_string = congress_types.bill_type_to_string(bill_type)
  let ingestion_id =
    ingestion_state_repo.build_ingestion_id(
      config.congress_number,
      bill_type_string,
    )

  // Load or create ingestion state
  use existing_state <- result.try(
    ingestion_state_repo.get_by_congress_and_type(
      connection,
      config.congress_number,
      bill_type_string,
    )
    |> result.map_error(DatabaseError),
  )

  let initial_offset = case existing_state {
    Some(state) -> state.last_offset
    None -> 0
  }

  // Create/update ingestion state to "in_progress"
  let initial_state =
    ingestion_state_repo.IngestionState(
      id: ingestion_id,
      source: "congress_gov",
      congress_number: Some(config.congress_number),
      bill_type: Some(bill_type_string),
      jurisdiction: None,
      session: None,
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
    |> result.map_error(DatabaseError),
  )

  let rate_limiter_state = rate_limiter.new()

  // Start paginated fetch loop
  case
    fetch_and_store_loop(
      connection,
      config,
      bill_type,
      dispatcher,
      initial_offset,
      ingestion_id,
      0,
      rate_limiter_state,
    )
  {
    Ok(total_stored) -> {
      // Mark completed
      let _ = ingestion_state_repo.mark_completed(connection, ingestion_id)
      Ok(IngestionResult(
        bill_type: bill_type_string,
        bills_fetched: total_stored,
        bills_stored: total_stored,
      ))
    }
    Error(ingestion_error) -> {
      // Mark failed
      let error_message = ingestion_error_to_string(ingestion_error)
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
  config: CongressApiConfig,
  bill_type: CongressBillType,
  dispatcher: HttpDispatcher,
  offset: Int,
  ingestion_id: String,
  total_stored: Int,
  rate_limiter_state: RateLimiterState,
) -> Result(Int, IngestionError) {
  // Rate limit
  let rate_limiter_state = rate_limiter.wait_for_capacity(rate_limiter_state)

  // Fetch page
  let fetch_result =
    congress_api_client.fetch_bill_list(
      config,
      bill_type,
      offset,
      default_page_size,
      dispatcher,
    )

  case fetch_result {
    Error(api_error) -> Error(ApiClientError(api_error))
    Ok(bill_list_response) -> {
      let bills = bill_list_response.bills
      let bills_count = list.length(bills)

      // Store each bill
      use stored_count <- result.try(store_bills_loop(connection, bills, 0))

      let new_total = total_stored + stored_count
      let new_offset = offset + bills_count

      // Update progress
      let _ =
        ingestion_state_repo.update_progress(
          connection,
          ingestion_id,
          new_offset,
          stored_count,
        )

      // Check if more pages available
      case bill_list_response.pagination.next {
        Some(_) if bills_count > 0 ->
          fetch_and_store_loop(
            connection,
            config,
            bill_type,
            dispatcher,
            new_offset,
            ingestion_id,
            new_total,
            rate_limiter_state,
          )
        _ -> Ok(new_total)
      }
    }
  }
}

fn store_bills_loop(
  connection: sqlight.Connection,
  bills: List(congress_types.CongressBillListItem),
  stored_count: Int,
) -> Result(Int, IngestionError) {
  case bills {
    [] -> Ok(stored_count)
    [bill_item, ..rest] -> {
      let legislation_record =
        bill_mapper.map_list_item_to_legislation(bill_item)
      let legislation_id_string =
        legislation.legislation_id_to_string(legislation_record.id)

      // Check if already exists
      case legislation_repo.get_by_id(connection, legislation_id_string) {
        Error(db_error) -> Error(DatabaseError(db_error))
        Ok(Some(_existing)) -> {
          // Update existing record
          case legislation_repo.update(connection, legislation_record) {
            Error(db_error) -> Error(DatabaseError(db_error))
            Ok(Nil) -> store_bills_loop(connection, rest, stored_count + 1)
          }
        }
        Ok(None) -> {
          // Insert new record
          case legislation_repo.insert(connection, legislation_record) {
            Error(db_error) -> Error(DatabaseError(db_error))
            Ok(Nil) -> store_bills_loop(connection, rest, stored_count + 1)
          }
        }
      }
    }
  }
}

/// Re-export load_api_key for test use.
pub fn load_api_key_for_test() -> Result(String, ApiError) {
  congress_api_client.load_api_key()
}

/// Re-export default_dispatcher for test use.
pub fn default_dispatcher_for_test() -> HttpDispatcher {
  congress_api_client.default_dispatcher()
}

/// Fetch and store a single page of bills. Used by live smoke tests
/// to avoid paginating through the entire bill list.
pub fn fetch_single_page_for_test(
  connection: sqlight.Connection,
  config: CongressApiConfig,
  bill_type: CongressBillType,
  offset: Int,
  limit: Int,
  dispatcher: HttpDispatcher,
) -> Result(Int, IngestionError) {
  let fetch_result =
    congress_api_client.fetch_bill_list(
      config,
      bill_type,
      offset,
      limit,
      dispatcher,
    )

  case fetch_result {
    Error(api_error) -> Error(ApiClientError(api_error))
    Ok(bill_list_response) -> {
      store_bills_loop(connection, bill_list_response.bills, 0)
    }
  }
}

fn ingestion_error_to_string(error: IngestionError) -> String {
  case error {
    ApiClientError(api_error) -> "API error: " <> api_error_to_string(api_error)
    DatabaseError(db_error) ->
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
