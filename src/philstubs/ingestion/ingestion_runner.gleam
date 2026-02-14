import gleam/list
import gleam/string
import philstubs/core/ingestion_job.{type IngestionSource, Federal, Local, State}
import philstubs/ingestion/congress_ingestion
import philstubs/ingestion/jurisdiction_registry
import philstubs/ingestion/legistar_ingestion
import philstubs/ingestion/state_ingestion
import sqlight

/// Aggregated result of running an ingestion source.
pub type RunResult {
  RunResult(records_fetched: Int, records_stored: Int)
}

/// Errors from running an ingestion source.
pub type RunError {
  FederalError(String)
  StateError(String)
  LocalError(String)
  ConfigError(String)
}

/// Run an ingestion source against the database, dispatching to the
/// appropriate pipeline.
pub fn run_source(
  connection: sqlight.Connection,
  source: IngestionSource,
) -> Result(RunResult, RunError) {
  case source {
    Federal -> run_federal(connection)
    State -> run_state(connection)
    Local -> run_local(connection)
  }
}

/// Run the federal (Congress.gov) ingestion pipeline.
fn run_federal(connection: sqlight.Connection) -> Result(RunResult, RunError) {
  case congress_ingestion.run(connection, 119) {
    Ok(ingestion_results) -> {
      let total_fetched =
        list.fold(ingestion_results, 0, fn(accumulator, ingestion_result) {
          accumulator + ingestion_result.bills_fetched
        })
      let total_stored =
        list.fold(ingestion_results, 0, fn(accumulator, ingestion_result) {
          accumulator + ingestion_result.bills_stored
        })
      Ok(RunResult(records_fetched: total_fetched, records_stored: total_stored))
    }
    Error(ingestion_error) ->
      Error(FederalError(congress_error_to_string(ingestion_error)))
  }
}

/// Run the state (Open States) ingestion pipeline.
fn run_state(connection: sqlight.Connection) -> Result(RunResult, RunError) {
  let jurisdictions = default_state_jurisdictions()
  case state_ingestion.run(connection, jurisdictions) {
    Ok(jurisdiction_results) -> {
      let #(total_fetched, total_stored) =
        list.fold(
          jurisdiction_results,
          #(0, 0),
          fn(accumulator, jurisdiction_result) {
            case jurisdiction_result {
              Ok(state_result) -> #(
                accumulator.0 + state_result.bills_fetched,
                accumulator.1 + state_result.bills_stored,
              )
              Error(_) -> accumulator
            }
          },
        )
      Ok(RunResult(records_fetched: total_fetched, records_stored: total_stored))
    }
    Error(state_error) -> Error(StateError(state_error_to_string(state_error)))
  }
}

/// Run the local (Legistar) ingestion pipeline.
fn run_local(connection: sqlight.Connection) -> Result(RunResult, RunError) {
  let client_ids =
    jurisdiction_registry.all_jurisdictions()
    |> list.map(fn(jurisdiction_entry) { jurisdiction_entry.client_id })

  let adapter_results = legistar_ingestion.run(connection, client_ids)
  let #(total_fetched, total_stored) =
    list.fold(adapter_results, #(0, 0), fn(accumulator, adapter_result) {
      case adapter_result {
        Ok(legistar_result) -> #(
          accumulator.0 + legistar_result.bills_fetched,
          accumulator.1 + legistar_result.bills_stored,
        )
        Error(_) -> accumulator
      }
    })
  Ok(RunResult(records_fetched: total_fetched, records_stored: total_stored))
}

/// Default state jurisdictions for ingestion.
fn default_state_jurisdictions() -> List(String) {
  ["California", "New York", "Texas", "Washington", "Illinois"]
}

fn congress_error_to_string(error: congress_ingestion.IngestionError) -> String {
  case error {
    congress_ingestion.ApiClientError(api_error) ->
      "Federal API error: " <> string.inspect(api_error)
    congress_ingestion.DatabaseError(db_error) ->
      "Federal DB error: " <> sqlight_error_to_string(db_error)
  }
}

fn state_error_to_string(error: state_ingestion.StateIngestionError) -> String {
  case error {
    state_ingestion.StateApiClientError(api_error) ->
      "State API error: " <> string.inspect(api_error)
    state_ingestion.StateDatabaseError(db_error) ->
      "State DB error: " <> sqlight_error_to_string(db_error)
  }
}

fn sqlight_error_to_string(error: sqlight.Error) -> String {
  case error {
    sqlight.SqlightError(_, message, _) -> message
  }
}
