import gleam/http/request
import gleam/http/response.{type Response, Response}
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit/should
import philstubs/core/legislation
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/test_helpers
import philstubs/ingestion/congress_api_client
import philstubs/ingestion/congress_ingestion
import philstubs/ingestion/congress_types
import philstubs/ingestion/ingestion_state_repo

/// Mock HTTP response for a bill list with 2 bills and no next page.
const mock_bill_list_response = "
{
  \"bills\": [
    {
      \"congress\": 118,
      \"latestAction\": {
        \"actionDate\": \"2024-01-15\",
        \"text\": \"Referred to the Committee on Energy and Commerce.\"
      },
      \"number\": \"100\",
      \"originChamber\": \"House\",
      \"originChamberCode\": \"H\",
      \"title\": \"Test Bill Alpha\",
      \"type\": \"HR\",
      \"updateDate\": \"2024-01-16T00:00:00Z\",
      \"url\": \"https://api.congress.gov/v3/bill/118/hr/100\"
    },
    {
      \"congress\": 118,
      \"latestAction\": {
        \"actionDate\": \"2024-02-01\",
        \"text\": \"Became Public Law No: 118-5.\"
      },
      \"number\": \"200\",
      \"originChamber\": \"House\",
      \"originChamberCode\": \"H\",
      \"title\": \"Test Bill Beta\",
      \"type\": \"HR\",
      \"updateDate\": \"2024-02-02T00:00:00Z\",
      \"url\": \"https://api.congress.gov/v3/bill/118/hr/200\"
    }
  ],
  \"pagination\": {
    \"count\": 2
  }
}
"

fn mock_dispatcher() -> congress_api_client.HttpDispatcher {
  fn(_req: request.Request(String)) -> Result(Response(String), String) {
    Ok(Response(status: 200, headers: [], body: mock_bill_list_response))
  }
}

fn mock_error_dispatcher() -> congress_api_client.HttpDispatcher {
  fn(_req: request.Request(String)) -> Result(Response(String), String) {
    Ok(Response(status: 500, headers: [], body: "Internal Server Error"))
  }
}

pub fn ingest_bills_with_mock_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let config = congress_types.default_config("test-key", 118)
  let dispatcher = mock_dispatcher()

  let result =
    congress_ingestion.ingest_bills(
      connection,
      config,
      congress_types.Hr,
      dispatcher,
    )

  let assert Ok(ingestion_result) = result
  ingestion_result.bill_type |> should.equal("hr")
  ingestion_result.bills_stored |> should.equal(2)

  // Verify bills were stored in the database
  let assert Ok(all_records) = legislation_repo.list_all(connection)
  list.length(all_records) |> should.equal(2)

  // Verify first bill
  let assert Ok(Some(bill_alpha)) =
    legislation_repo.get_by_id(connection, "congress_gov-118-hr-100")
  bill_alpha.title |> should.equal("Test Bill Alpha")
  bill_alpha.legislation_type |> should.equal(legislation_type.Bill)
  bill_alpha.status |> should.equal(legislation_status.InCommittee)
  bill_alpha.source_identifier |> should.equal("H.R. 100")

  // Verify second bill (enacted)
  let assert Ok(Some(bill_beta)) =
    legislation_repo.get_by_id(connection, "congress_gov-118-hr-200")
  bill_beta.title |> should.equal("Test Bill Beta")
  bill_beta.status |> should.equal(legislation_status.Enacted)
}

pub fn ingest_bills_updates_ingestion_state_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let config = congress_types.default_config("test-key", 118)
  let dispatcher = mock_dispatcher()

  let assert Ok(_) =
    congress_ingestion.ingest_bills(
      connection,
      config,
      congress_types.Hr,
      dispatcher,
    )

  // Verify ingestion state was updated
  let assert Ok(Some(state)) =
    ingestion_state_repo.get_by_congress_and_type(connection, 118, "hr")
  state.status |> should.equal("completed")
  state.total_bills_fetched |> should.equal(2)
}

pub fn ingest_bills_idempotent_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let config = congress_types.default_config("test-key", 118)
  let dispatcher = mock_dispatcher()

  // Run ingestion twice
  let assert Ok(_) =
    congress_ingestion.ingest_bills(
      connection,
      config,
      congress_types.Hr,
      dispatcher,
    )
  let assert Ok(_) =
    congress_ingestion.ingest_bills(
      connection,
      config,
      congress_types.Hr,
      dispatcher,
    )

  // Should still have exactly 2 records (updated, not duplicated)
  let assert Ok(all_records) = legislation_repo.list_all(connection)
  list.length(all_records) |> should.equal(2)
}

pub fn ingest_bills_handles_server_error_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let config = congress_types.default_config("test-key", 118)
  let dispatcher = mock_error_dispatcher()

  let result =
    congress_ingestion.ingest_bills(
      connection,
      config,
      congress_types.Hr,
      dispatcher,
    )

  // Should return an error
  should.be_error(result)

  // Ingestion state should be marked as failed
  let assert Ok(Some(state)) =
    ingestion_state_repo.get_by_congress_and_type(connection, 118, "hr")
  state.status |> should.equal("failed")
}

/// Live smoke test: fetches real data from Congress.gov API.
/// Only runs when CONGRESS_API_KEY is set in the environment.
pub fn live_api_smoke_test() {
  case congress_ingestion.load_api_key_for_test() {
    Error(_) -> {
      // Skip test if API key not available
      Nil
    }
    Ok(api_key) -> {
      use connection <- database.with_named_connection(":memory:")
      let assert Ok(_) = test_helpers.setup_test_db(connection)

      let config = congress_types.default_config(api_key, 118)
      let dispatcher = congress_ingestion.default_dispatcher_for_test()

      // Fetch just one page of House bills
      let result =
        congress_ingestion.fetch_single_page_for_test(
          connection,
          config,
          congress_types.Hr,
          0,
          5,
          dispatcher,
        )

      case result {
        Ok(bills_stored) -> {
          // Should have stored some bills
          should.be_true(bills_stored > 0)

          // Verify at least one bill is in the database
          let assert Ok(all_records) = legislation_repo.list_all(connection)
          should.be_true(all_records != [])

          // Verify the bill has expected structure
          let assert [first_record, ..] = all_records
          legislation.legislation_id_to_string(first_record.id)
          |> string.starts_with("congress_gov-118-hr-")
          |> should.be_true
        }
        Error(_) -> {
          // API might be temporarily unavailable; don't fail hard
          Nil
        }
      }
    }
  }
}
