import gleam/http/request
import gleam/http/response.{type Response, Response}
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit/should
import philstubs/core/government_level
import philstubs/core/legislation
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/test_helpers
import philstubs/ingestion/congress_api_client
import philstubs/ingestion/ingestion_state_repo
import philstubs/ingestion/openstates_types
import philstubs/ingestion/state_ingestion

/// Mock Open States API response with 2 bills and no more pages.
const mock_openstates_response = "
{
  \"results\": [
    {
      \"id\": \"ocd-bill/test1\",
      \"session\": \"20252026\",
      \"jurisdiction\": {
        \"id\": \"ocd-jurisdiction/country:us/state:ca/government\",
        \"name\": \"California\",
        \"classification\": \"state\"
      },
      \"identifier\": \"SB 100\",
      \"title\": \"California Education Reform Act\",
      \"classification\": [\"bill\"],
      \"subject\": [\"Education\"],
      \"openstates_url\": \"https://openstates.org/ca/bills/20252026/SB100/\",
      \"first_action_date\": \"2025-01-15\",
      \"latest_action_date\": \"2025-02-01\",
      \"latest_action_description\": \"Referred to Committee on Education\",
      \"abstracts\": [
        {\"abstract\": \"An act to reform education funding.\", \"note\": \"As introduced\"}
      ],
      \"sponsorships\": [
        {
          \"name\": \"Sen. Smith\",
          \"primary\": true,
          \"classification\": \"primary\",
          \"person\": {\"name\": \"Jane Smith\", \"party\": \"Democratic\"}
        }
      ],
      \"actions\": [
        {\"description\": \"Introduced\", \"date\": \"2025-01-15\", \"classification\": [\"introduction\"]},
        {\"description\": \"Referred to Committee on Education\", \"date\": \"2025-02-01\", \"classification\": [\"committee-referral\"]}
      ]
    },
    {
      \"id\": \"ocd-bill/test2\",
      \"session\": \"20252026\",
      \"jurisdiction\": {
        \"id\": \"ocd-jurisdiction/country:us/state:ca/government\",
        \"name\": \"California\",
        \"classification\": \"state\"
      },
      \"identifier\": \"AB 200\",
      \"title\": \"Clean Energy Jobs Act\",
      \"classification\": [\"bill\"],
      \"subject\": [\"Energy\", \"Environment\"],
      \"openstates_url\": \"https://openstates.org/ca/bills/20252026/AB200/\",
      \"first_action_date\": \"2025-01-20\",
      \"latest_action_date\": \"2025-03-01\",
      \"latest_action_description\": \"Passed Assembly\",
      \"abstracts\": [],
      \"sponsorships\": [
        {
          \"name\": \"Asm. Johnson\",
          \"primary\": true,
          \"classification\": \"primary\",
          \"person\": {\"name\": \"Bob Johnson\"}
        }
      ],
      \"actions\": [
        {\"description\": \"Introduced\", \"date\": \"2025-01-20\", \"classification\": [\"introduction\"]},
        {\"description\": \"Passed Assembly\", \"date\": \"2025-03-01\", \"classification\": [\"passage\"]}
      ]
    }
  ],
  \"pagination\": {
    \"per_page\": 20,
    \"page\": 1,
    \"max_page\": 1,
    \"total_items\": 2
  }
}
"

fn mock_dispatcher() -> congress_api_client.HttpDispatcher {
  fn(_req: request.Request(String)) -> Result(Response(String), String) {
    Ok(Response(status: 200, headers: [], body: mock_openstates_response))
  }
}

fn mock_error_dispatcher() -> congress_api_client.HttpDispatcher {
  fn(_req: request.Request(String)) -> Result(Response(String), String) {
    Ok(Response(status: 500, headers: [], body: "Internal Server Error"))
  }
}

pub fn ingest_jurisdiction_with_mock_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let config = openstates_types.default_config("test-key")
  let dispatcher = mock_dispatcher()

  let result =
    state_ingestion.ingest_jurisdiction(
      connection,
      config,
      "California",
      dispatcher,
    )

  let assert Ok(ingestion_result) = result
  ingestion_result.jurisdiction |> should.equal("California")
  ingestion_result.bills_stored |> should.equal(2)

  // Verify bills were stored in the database
  let assert Ok(all_records) = legislation_repo.list_all(connection)
  list.length(all_records) |> should.equal(2)

  // Verify first bill (SB 100 - in committee)
  let assert Ok(Some(bill_sb100)) =
    legislation_repo.get_by_id(connection, "openstates-ca-20252026-SB100")
  bill_sb100.title |> should.equal("California Education Reform Act")
  bill_sb100.legislation_type |> should.equal(legislation_type.Bill)
  bill_sb100.status |> should.equal(legislation_status.InCommittee)
  bill_sb100.level |> should.equal(government_level.State("CA"))
  bill_sb100.source_identifier |> should.equal("SB 100")
  bill_sb100.summary
  |> should.equal("An act to reform education funding.")
  bill_sb100.sponsors |> should.equal(["Jane Smith"])
  bill_sb100.topics |> should.equal(["Education"])
  bill_sb100.introduced_date |> should.equal("2025-01-15")

  // Verify second bill (AB 200 - passed chamber)
  let assert Ok(Some(bill_ab200)) =
    legislation_repo.get_by_id(connection, "openstates-ca-20252026-AB200")
  bill_ab200.title |> should.equal("Clean Energy Jobs Act")
  bill_ab200.status |> should.equal(legislation_status.PassedChamber)
  bill_ab200.sponsors |> should.equal(["Bob Johnson"])
  bill_ab200.topics |> should.equal(["Energy", "Environment"])
}

pub fn ingest_jurisdiction_updates_ingestion_state_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let config = openstates_types.default_config("test-key")
  let dispatcher = mock_dispatcher()

  let assert Ok(_) =
    state_ingestion.ingest_jurisdiction(
      connection,
      config,
      "California",
      dispatcher,
    )

  // Verify ingestion state was updated
  let assert Ok(Some(state)) =
    ingestion_state_repo.get_by_jurisdiction_and_session(
      connection,
      "California",
      "2025",
    )
  state.status |> should.equal("completed")
  state.total_bills_fetched |> should.equal(2)
  state.source |> should.equal("openstates")
  state.jurisdiction |> should.equal(Some("California"))
}

pub fn ingest_jurisdiction_idempotent_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let config = openstates_types.default_config("test-key")
  let dispatcher = mock_dispatcher()

  // Run ingestion twice
  let assert Ok(_) =
    state_ingestion.ingest_jurisdiction(
      connection,
      config,
      "California",
      dispatcher,
    )
  let assert Ok(_) =
    state_ingestion.ingest_jurisdiction(
      connection,
      config,
      "California",
      dispatcher,
    )

  // Should still have exactly 2 records (updated, not duplicated)
  let assert Ok(all_records) = legislation_repo.list_all(connection)
  list.length(all_records) |> should.equal(2)
}

pub fn ingest_jurisdiction_handles_server_error_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let config = openstates_types.default_config("test-key")
  let dispatcher = mock_error_dispatcher()

  let result =
    state_ingestion.ingest_jurisdiction(
      connection,
      config,
      "California",
      dispatcher,
    )

  // Should return an error
  should.be_error(result)

  // Ingestion state should be marked as failed
  let assert Ok(Some(state)) =
    ingestion_state_repo.get_by_jurisdiction_and_session(
      connection,
      "California",
      "2025",
    )
  state.status |> should.equal("failed")
}

pub fn ingest_jurisdictions_continues_on_failure_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let config = openstates_types.default_config("test-key")

  // Use error dispatcher — both jurisdictions will fail,
  // but the function should continue to the second one
  let dispatcher = mock_error_dispatcher()

  let results =
    state_ingestion.ingest_jurisdictions(
      connection,
      config,
      ["California", "Texas"],
      dispatcher,
    )

  // Both should be errors, but we should have results for both
  list.length(results) |> should.equal(2)
}

/// Live smoke test: fetches real data from Open States API.
/// Only runs when PLURAL_POLICY_KEY is set in the environment.
pub fn live_api_smoke_test() {
  case state_ingestion.load_api_key_for_test() {
    Error(_) -> {
      // Skip test if API key not available
      Nil
    }
    Ok(api_key) -> {
      use connection <- database.with_named_connection(":memory:")
      let assert Ok(_) = test_helpers.setup_test_db(connection)

      let config = openstates_types.default_config(api_key)
      let dispatcher = state_ingestion.default_dispatcher_for_test()

      // Fetch just one page of California bills
      let result =
        state_ingestion.fetch_single_page_for_test(
          connection,
          config,
          "California",
          1,
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

          // Verify the bill has expected structure (State level)
          let assert [first_record, ..] = all_records
          legislation.legislation_id_to_string(first_record.id)
          |> string.starts_with("openstates-")
          |> should.be_true

          // Verify it's a State-level record
          case first_record.level {
            government_level.State(_) -> should.be_true(True)
            _ -> should.be_true(False)
          }
        }
        Error(_) -> {
          // API might be temporarily unavailable; don't fail hard
          Nil
        }
      }
    }
  }
}
