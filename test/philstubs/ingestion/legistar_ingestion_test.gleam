import gleam/http/request
import gleam/http/response.{type Response, Response}
import gleam/list
import gleam/option.{None, Some}
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
import philstubs/ingestion/legistar_ingestion
import philstubs/ingestion/legistar_types

/// Mock Legistar API response with 2 matters as a plain JSON array.
const mock_matters_response = "
[
  {
    \"MatterId\": 1001,
    \"MatterGuid\": \"guid-1001\",
    \"MatterFile\": \"CB 119000\",
    \"MatterName\": \"Bicycle Infrastructure\",
    \"MatterTitle\": \"An ordinance relating to bicycle lane construction\",
    \"MatterTypeName\": \"Ordinance\",
    \"MatterStatusName\": \"Adopted\",
    \"MatterBodyName\": \"City Council\",
    \"MatterIntroDate\": \"2024-06-01T00:00:00\",
    \"MatterAgendaDate\": \"2024-07-15T00:00:00\",
    \"MatterPassedDate\": \"2024-08-01T00:00:00\",
    \"MatterEnactmentDate\": null,
    \"MatterEnactmentNumber\": null,
    \"MatterNotes\": \"Expanding protected bike lanes\",
    \"MatterLastModifiedUtc\": \"2024-08-05T10:00:00\"
  },
  {
    \"MatterId\": 1002,
    \"MatterGuid\": \"guid-1002\",
    \"MatterFile\": \"Res 32000\",
    \"MatterName\": null,
    \"MatterTitle\": \"A resolution recognizing community volunteers\",
    \"MatterTypeName\": \"Resolution\",
    \"MatterStatusName\": \"Filed\",
    \"MatterBodyName\": \"City Council\",
    \"MatterIntroDate\": \"2024-09-01T00:00:00\",
    \"MatterAgendaDate\": null,
    \"MatterPassedDate\": null,
    \"MatterEnactmentDate\": null,
    \"MatterEnactmentNumber\": null,
    \"MatterNotes\": null,
    \"MatterLastModifiedUtc\": \"2024-09-02T08:30:00\"
  }
]
"

/// Mock sponsors response for matter 1001.
const mock_sponsors_1001 = "
[
  {\"MatterSponsorName\": \"Council Member Garcia\"},
  {\"MatterSponsorName\": \"Council Member Patel\"}
]
"

/// Mock sponsors response for matter 1002.
const mock_sponsors_1002 = "
[
  {\"MatterSponsorName\": \"Council Member Lee\"}
]
"

/// Build a mock dispatcher that returns matters for the main endpoint
/// and sponsors for individual matter endpoints.
fn mock_dispatcher() -> congress_api_client.HttpDispatcher {
  fn(req: request.Request(String)) -> Result(Response(String), String) {
    let path = req.path
    case string.contains(path, "/Sponsors") {
      True ->
        case string.contains(path, "/1001/") {
          True ->
            Ok(Response(status: 200, headers: [], body: mock_sponsors_1001))
          False ->
            Ok(Response(status: 200, headers: [], body: mock_sponsors_1002))
        }
      False ->
        Ok(Response(status: 200, headers: [], body: mock_matters_response))
    }
  }
}

fn mock_error_dispatcher() -> congress_api_client.HttpDispatcher {
  fn(_req: request.Request(String)) -> Result(Response(String), String) {
    Ok(Response(status: 500, headers: [], body: "Internal Server Error"))
  }
}

pub fn ingest_client_with_mock_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let config = legistar_types.default_config("seattle", None)
  let dispatcher = mock_dispatcher()
  let level = government_level.Municipal("WA", "Seattle")

  let result =
    legistar_ingestion.ingest_client_with_level(
      connection,
      config,
      level,
      dispatcher,
    )

  let assert Ok(ingestion_result) = result
  ingestion_result.source_name |> should.equal("legistar")
  ingestion_result.client_id |> should.equal("seattle")
  ingestion_result.bills_stored |> should.equal(2)

  // Verify bills were stored in the database
  let assert Ok(all_records) = legislation_repo.list_all(connection)
  list.length(all_records) |> should.equal(2)

  // Verify first matter (CB 119000 - ordinance, adopted)
  let assert Ok(Some(matter_1001)) =
    legislation_repo.get_by_id(connection, "legistar-seattle-1001")
  matter_1001.title
  |> should.equal("An ordinance relating to bicycle lane construction")
  matter_1001.legislation_type |> should.equal(legislation_type.Ordinance)
  matter_1001.status |> should.equal(legislation_status.Enacted)
  matter_1001.level
  |> should.equal(government_level.Municipal("WA", "Seattle"))
  matter_1001.source_identifier |> should.equal("CB 119000")
  matter_1001.summary |> should.equal("Expanding protected bike lanes")
  matter_1001.sponsors
  |> should.equal(["Council Member Garcia", "Council Member Patel"])
  matter_1001.introduced_date |> should.equal("2024-06-01")

  // Verify second matter (Res 32000 - resolution, filed/introduced)
  let assert Ok(Some(matter_1002)) =
    legislation_repo.get_by_id(connection, "legistar-seattle-1002")
  matter_1002.title
  |> should.equal("A resolution recognizing community volunteers")
  matter_1002.legislation_type |> should.equal(legislation_type.Resolution)
  matter_1002.status |> should.equal(legislation_status.Introduced)
  matter_1002.sponsors |> should.equal(["Council Member Lee"])
  matter_1002.introduced_date |> should.equal("2024-09-01")
}

pub fn ingest_client_updates_ingestion_state_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let config = legistar_types.default_config("seattle", None)
  let dispatcher = mock_dispatcher()
  let level = government_level.Municipal("WA", "Seattle")

  let assert Ok(_) =
    legistar_ingestion.ingest_client_with_level(
      connection,
      config,
      level,
      dispatcher,
    )

  // Verify ingestion state was updated
  let assert Ok(Some(state)) =
    ingestion_state_repo.get_by_jurisdiction_and_session(
      connection,
      "seattle",
      "current",
    )
  state.status |> should.equal("completed")
  state.total_bills_fetched |> should.equal(2)
  state.source |> should.equal("legistar")
  state.jurisdiction |> should.equal(Some("seattle"))
  state.session |> should.equal(Some("current"))
}

pub fn ingest_client_idempotent_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let config = legistar_types.default_config("seattle", None)
  let dispatcher = mock_dispatcher()
  let level = government_level.Municipal("WA", "Seattle")

  // Run ingestion twice
  let assert Ok(_) =
    legistar_ingestion.ingest_client_with_level(
      connection,
      config,
      level,
      dispatcher,
    )
  let assert Ok(_) =
    legistar_ingestion.ingest_client_with_level(
      connection,
      config,
      level,
      dispatcher,
    )

  // Should still have exactly 2 records (updated, not duplicated)
  let assert Ok(all_records) = legislation_repo.list_all(connection)
  list.length(all_records) |> should.equal(2)
}

pub fn ingest_client_handles_server_error_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let config = legistar_types.default_config("seattle", None)
  let dispatcher = mock_error_dispatcher()
  let level = government_level.Municipal("WA", "Seattle")

  let result =
    legistar_ingestion.ingest_client_with_level(
      connection,
      config,
      level,
      dispatcher,
    )

  // Should return an error
  should.be_error(result)

  // Ingestion state should be marked as failed
  let assert Ok(Some(state)) =
    ingestion_state_repo.get_by_jurisdiction_and_session(
      connection,
      "seattle",
      "current",
    )
  state.status |> should.equal("failed")
}

pub fn ingest_clients_continues_on_failure_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  // Use error dispatcher — both clients will fail,
  // but the function should continue to the second one
  let dispatcher = mock_error_dispatcher()

  let results =
    legistar_ingestion.ingest_clients(
      connection,
      ["seattle", "chicago"],
      None,
      dispatcher,
    )

  // Both should be errors, but we should have results for both
  list.length(results) |> should.equal(2)
}

/// Live smoke test: fetches real data from the Legistar API.
/// Seattle is public/open and requires no API token.
/// Only runs when the Legistar API is reachable.
pub fn live_api_smoke_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let config = legistar_types.default_config("seattle", None)
  let dispatcher = legistar_ingestion.default_dispatcher_for_test()
  let level = government_level.Municipal("WA", "Seattle")

  // Fetch just a few matters to keep the test fast
  let result =
    legistar_ingestion.fetch_single_page_for_test(
      connection,
      config,
      level,
      0,
      3,
      dispatcher,
    )

  case result {
    Ok(bills_stored) -> {
      // Should have stored some matters
      should.be_true(bills_stored > 0)

      // Verify at least one record is in the database
      let assert Ok(all_records) = legislation_repo.list_all(connection)
      should.be_true(all_records != [])

      // Verify the record has expected structure (Municipal level)
      let assert [first_record, ..] = all_records
      legislation.legislation_id_to_string(first_record.id)
      |> string.starts_with("legistar-")
      |> should.be_true

      // Verify it's a Municipal-level record
      case first_record.level {
        government_level.Municipal(state_code, municipality_name) -> {
          state_code |> should.equal("WA")
          municipality_name |> should.equal("Seattle")
        }
        _ -> should.be_true(False)
      }
    }
    Error(_) -> {
      // API might be temporarily unavailable; don't fail hard
      Nil
    }
  }
}
