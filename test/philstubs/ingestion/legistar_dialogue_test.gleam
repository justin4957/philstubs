/// Dialogue tests for Legistar ingestion.
///
/// These tests document the complete request/response interaction flow
/// between the application and the Legistar API. The key distinguishing
/// feature of Legistar ingestion is the multi-endpoint interaction:
/// the app first fetches a matters list, then makes a separate sponsor
/// request for each matter, resulting in N+1 total HTTP requests.
///
/// Interaction pattern:
///   App → Legistar matters list endpoint → parse matters →
///   for each matter: App → Legistar sponsors endpoint → parse sponsors →
///   map matter + sponsors to domain types → store in DB →
///   update ingestion state
import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/http/response.{type Response, Response}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import philstubs/core/government_level
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/test_helpers
import philstubs/ingestion/congress_api_client
import philstubs/ingestion/ingestion_state_repo
import philstubs/ingestion/legistar_ingestion
import philstubs/ingestion/legistar_types

/// Mock Legistar matters response with 2 matters (Ordinance + Resolution).
const dialogue_matters_response = "
[
  {
    \"MatterId\": 2001,
    \"MatterGuid\": \"guid-2001\",
    \"MatterFile\": \"CB 120000\",
    \"MatterName\": \"Transit Infrastructure\",
    \"MatterTitle\": \"An ordinance relating to public transit improvements\",
    \"MatterTypeName\": \"Ordinance\",
    \"MatterStatusName\": \"Adopted\",
    \"MatterBodyName\": \"City Council\",
    \"MatterIntroDate\": \"2024-03-01T00:00:00\",
    \"MatterAgendaDate\": \"2024-04-15T00:00:00\",
    \"MatterPassedDate\": \"2024-05-01T00:00:00\",
    \"MatterEnactmentDate\": null,
    \"MatterEnactmentNumber\": null,
    \"MatterNotes\": \"Expanding light rail service\",
    \"MatterLastModifiedUtc\": \"2024-05-05T10:00:00\"
  },
  {
    \"MatterId\": 2002,
    \"MatterGuid\": \"guid-2002\",
    \"MatterFile\": \"Res 33000\",
    \"MatterName\": null,
    \"MatterTitle\": \"A resolution honoring local educators\",
    \"MatterTypeName\": \"Resolution\",
    \"MatterStatusName\": \"Filed\",
    \"MatterBodyName\": \"City Council\",
    \"MatterIntroDate\": \"2024-06-01T00:00:00\",
    \"MatterAgendaDate\": null,
    \"MatterPassedDate\": null,
    \"MatterEnactmentDate\": null,
    \"MatterEnactmentNumber\": null,
    \"MatterNotes\": null,
    \"MatterLastModifiedUtc\": \"2024-06-02T08:30:00\"
  }
]
"

/// Mock sponsors for matter 2001.
const dialogue_sponsors_2001 = "
[
  {\"MatterSponsorName\": \"Council Member Rivera\"},
  {\"MatterSponsorName\": \"Council Member Nguyen\"}
]
"

/// Mock sponsors for matter 2002.
const dialogue_sponsors_2002 = "
[
  {\"MatterSponsorName\": \"Council Member Thompson\"}
]
"

/// Build a request-logging dispatcher that records each request URL,
/// routes by URL path to return different responses for matters vs sponsors,
/// and returns canned responses.
fn logging_success_dispatcher(
  request_log: Subject(String),
) -> congress_api_client.HttpDispatcher {
  fn(req: request.Request(String)) -> Result(Response(String), String) {
    let path = req.path
    // Log every request for interaction sequence verification
    process.send(request_log, path)

    case string.contains(path, "/Sponsors") {
      True ->
        case string.contains(path, "/2001/") {
          True ->
            Ok(Response(status: 200, headers: [], body: dialogue_sponsors_2001))
          False ->
            Ok(Response(status: 200, headers: [], body: dialogue_sponsors_2002))
        }
      False ->
        Ok(Response(status: 200, headers: [], body: dialogue_matters_response))
    }
  }
}

/// Build a request-logging dispatcher that records requests, then returns 500.
fn logging_error_dispatcher(
  request_log: Subject(String),
) -> congress_api_client.HttpDispatcher {
  fn(req: request.Request(String)) -> Result(Response(String), String) {
    process.send(request_log, req.path)
    Ok(Response(status: 500, headers: [], body: "Internal Server Error"))
  }
}

/// Collect all logged request URLs from the subject (non-blocking).
fn collect_logged_requests(request_log: Subject(String)) -> List(String) {
  collect_logged_requests_loop(request_log, [])
}

fn collect_logged_requests_loop(
  request_log: Subject(String),
  accumulated_requests: List(String),
) -> List(String) {
  case process.receive(request_log, 0) {
    Ok(request_url) ->
      collect_logged_requests_loop(request_log, [
        request_url,
        ..accumulated_requests
      ])
    Error(_) -> list.reverse(accumulated_requests)
  }
}

/// --- Dialogue Test: Success Flow ---
///
/// Documents the complete interaction sequence:
///   1. App sends GET to /v2/seattle/Matters?$skip=0&$top=100
///   2. API returns 200 with 2 matters (Ordinance: Adopted, Resolution: Filed)
///   3. App sends GET to /v2/seattle/Matters/2001/Sponsors (for matter 1)
///   4. API returns 200 with 2 sponsors
///   5. App sends GET to /v2/seattle/Matters/2002/Sponsors (for matter 2)
///   6. API returns 200 with 1 sponsor
///   7. App maps matters + sponsors → domain types → stores in DB
///   8. App marks ingestion state as "completed"
pub fn legistar_success_dialogue_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let request_log = process.new_subject()
  let config = legistar_types.default_config("seattle", None)
  let dispatcher = logging_success_dispatcher(request_log)
  let level = government_level.Municipal("WA", "Seattle")

  // --- Dialogue Step 1: App initiates client ingestion ---
  let result =
    legistar_ingestion.ingest_client_with_level(
      connection,
      config,
      level,
      dispatcher,
    )

  // --- Verify pipeline output ---
  let assert Ok(ingestion_result) = result
  ingestion_result.source_name |> should.equal("legistar")
  ingestion_result.client_id |> should.equal("seattle")
  ingestion_result.bills_stored |> should.equal(2)

  // --- Verify stored records ---
  let assert Ok(all_records) = legislation_repo.list_all(connection)
  list.length(all_records) |> should.equal(2)

  // Verify Municipal level on stored records
  let assert Ok(Some(matter_2001)) =
    legislation_repo.get_by_id(connection, "legistar-seattle-2001")
  matter_2001.level
  |> should.equal(government_level.Municipal("WA", "Seattle"))

  // Verify sponsors attached from separate endpoint
  matter_2001.sponsors
  |> should.equal(["Council Member Rivera", "Council Member Nguyen"])

  let assert Ok(Some(matter_2002)) =
    legislation_repo.get_by_id(connection, "legistar-seattle-2002")
  matter_2002.sponsors |> should.equal(["Council Member Thompson"])

  // --- Verify ingestion state ---
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
}

/// --- Dialogue Test: Multi-Request Interaction ---
///
/// Documents the N+1 request pattern unique to Legistar:
///   1 matters list request + 1 sponsor request per matter = 3 total requests.
/// Verifies the exact request count and URL patterns for each endpoint.
pub fn legistar_multi_request_dialogue_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let request_log = process.new_subject()
  let config = legistar_types.default_config("seattle", None)
  let dispatcher = logging_success_dispatcher(request_log)
  let level = government_level.Municipal("WA", "Seattle")

  let assert Ok(_) =
    legistar_ingestion.ingest_client_with_level(
      connection,
      config,
      level,
      dispatcher,
    )

  // --- Verify exact request count: 1 matters + 2 sponsors = 3 ---
  let logged_requests = collect_logged_requests(request_log)
  list.length(logged_requests) |> should.equal(3)

  // --- Verify request URL patterns ---
  let assert [matters_request, sponsor_request_1, sponsor_request_2] =
    logged_requests

  // First request: matters list endpoint
  matters_request |> string.contains("Matters") |> should.be_true
  matters_request |> string.contains("Sponsors") |> should.be_false

  // Second request: sponsors for matter 2001
  sponsor_request_1 |> string.contains("Sponsors") |> should.be_true
  sponsor_request_1 |> string.contains("2001") |> should.be_true

  // Third request: sponsors for matter 2002
  sponsor_request_2 |> string.contains("Sponsors") |> should.be_true
  sponsor_request_2 |> string.contains("2002") |> should.be_true
}

/// --- Dialogue Test: Error Flow ---
///
/// Documents the error interaction sequence:
///   1. App sends GET to matters list endpoint
///   2. API returns 500 Internal Server Error
///   3. App returns error result (no sponsor requests attempted)
///   4. App marks ingestion state as "failed"
///   5. No matters are stored
pub fn legistar_error_dialogue_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let request_log = process.new_subject()
  let config = legistar_types.default_config("seattle", None)
  let dispatcher = logging_error_dispatcher(request_log)
  let level = government_level.Municipal("WA", "Seattle")

  // --- Dialogue Step 1: App attempts matters fetch ---
  let result =
    legistar_ingestion.ingest_client_with_level(
      connection,
      config,
      level,
      dispatcher,
    )

  // --- Verify only 1 request made (matters list failed, no sponsor requests) ---
  let logged_requests = collect_logged_requests(request_log)
  list.length(logged_requests) |> should.equal(1)

  // --- Verify error result ---
  should.be_error(result)

  // --- Verify no matters stored ---
  let assert Ok(all_records) = legislation_repo.list_all(connection)
  list.length(all_records) |> should.equal(0)

  // --- Verify ingestion state marked failed ---
  let assert Ok(Some(state)) =
    ingestion_state_repo.get_by_jurisdiction_and_session(
      connection,
      "seattle",
      "current",
    )
  state.status |> should.equal("failed")
}

/// --- Dialogue Test: Field Mapping Chain ---
///
/// Documents the precise field transformations from Legistar API to domain types:
///   - MatterTypeName "Ordinance" → legislation_type: Ordinance
///   - MatterTypeName "Resolution" → legislation_type: Resolution
///   - MatterStatusName "Adopted" → status: Enacted
///   - MatterStatusName "Filed" → status: Introduced
///   - Title fallback chain: MatterTitle > MatterName > MatterFile > "Untitled"
///   - Date format stripping: "2024-03-01T00:00:00" → "2024-03-01"
///   - Summary from MatterNotes (or empty when null)
///   - Source identifier from MatterFile
pub fn legistar_field_mapping_dialogue_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let request_log = process.new_subject()
  let config = legistar_types.default_config("seattle", None)
  let dispatcher = logging_success_dispatcher(request_log)
  let level = government_level.Municipal("WA", "Seattle")

  let assert Ok(_) =
    legistar_ingestion.ingest_client_with_level(
      connection,
      config,
      level,
      dispatcher,
    )

  // --- Verify type mapping ---
  let assert Ok(Some(matter_2001)) =
    legislation_repo.get_by_id(connection, "legistar-seattle-2001")
  // MatterTypeName "Ordinance" → Ordinance
  matter_2001.legislation_type |> should.equal(legislation_type.Ordinance)

  let assert Ok(Some(matter_2002)) =
    legislation_repo.get_by_id(connection, "legistar-seattle-2002")
  // MatterTypeName "Resolution" → Resolution
  matter_2002.legislation_type |> should.equal(legislation_type.Resolution)

  // --- Verify status mapping ---
  // MatterStatusName "Adopted" → Enacted
  matter_2001.status |> should.equal(legislation_status.Enacted)
  // MatterStatusName "Filed" → Introduced
  matter_2002.status |> should.equal(legislation_status.Introduced)

  // --- Verify title uses MatterTitle (first in fallback chain) ---
  matter_2001.title
  |> should.equal("An ordinance relating to public transit improvements")
  // MatterTitle present, so MatterName "null" is not used
  matter_2002.title
  |> should.equal("A resolution honoring local educators")

  // --- Verify date format stripping ---
  // "2024-03-01T00:00:00" → "2024-03-01"
  matter_2001.introduced_date |> should.equal("2024-03-01")
  matter_2002.introduced_date |> should.equal("2024-06-01")

  // --- Verify summary from MatterNotes ---
  matter_2001.summary |> should.equal("Expanding light rail service")
  // Null MatterNotes → empty summary
  matter_2002.summary |> should.equal("")

  // --- Verify source identifier from MatterFile ---
  matter_2001.source_identifier |> should.equal("CB 120000")
  matter_2002.source_identifier |> should.equal("Res 33000")
}
