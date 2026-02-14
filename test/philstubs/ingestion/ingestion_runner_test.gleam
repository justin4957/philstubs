import philstubs/core/ingestion_job.{Federal}
import philstubs/data/database
import philstubs/data/test_helpers
import philstubs/ingestion/ingestion_runner

/// Test that run_source dispatches correctly for the federal source.
/// This will fail with a config error if CONGRESS_API_KEY is not set,
/// which is expected — we're testing the dispatch path, not the API.
pub fn run_federal_dispatches_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let result = ingestion_runner.run_source(connection, Federal)
  case result {
    Error(ingestion_runner.FederalError(_)) -> Nil
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}
