/// Dialogue tests for Open States ingestion.
///
/// These tests document the complete request/response interaction flow
/// between the application and the Open States / Plural Policy API.
/// They focus on the interaction sequence and field mapping chain,
/// including nested object extraction (jurisdiction, sponsors, abstracts).
///
/// Interaction pattern:
///   App → Open States bill list endpoint → parse response → extract
///   nested fields (jurisdiction, sponsors, abstracts) → map to domain types →
///   store in DB → update ingestion state
import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/http/response.{type Response, Response}
import gleam/list
import gleam/option.{Some}
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
import philstubs/ingestion/openstates_types
import philstubs/ingestion/state_ingestion

/// Mock Open States API response with 2 California bills.
/// Includes nested jurisdiction, sponsors with person objects,
/// abstracts, actions with classifications, and topics.
const dialogue_openstates_response = "
{
  \"results\": [
    {
      \"id\": \"ocd-bill/dialogue-1\",
      \"session\": \"20252026\",
      \"jurisdiction\": {
        \"id\": \"ocd-jurisdiction/country:us/state:ca/government\",
        \"name\": \"California\",
        \"classification\": \"state\"
      },
      \"identifier\": \"SB 500\",
      \"title\": \"Affordable Housing Expansion Act\",
      \"classification\": [\"bill\"],
      \"subject\": [\"Housing\", \"Urban Development\"],
      \"openstates_url\": \"https://openstates.org/ca/bills/20252026/SB500/\",
      \"first_action_date\": \"2025-01-10\",
      \"latest_action_date\": \"2025-03-15\",
      \"latest_action_description\": \"Referred to Committee on Housing and Community Development\",
      \"abstracts\": [
        {\"abstract\": \"An act to expand affordable housing programs statewide.\", \"note\": \"As introduced\"}
      ],
      \"sponsorships\": [
        {
          \"name\": \"Sen. Martinez\",
          \"primary\": true,
          \"classification\": \"primary\",
          \"person\": {\"name\": \"Ana Martinez\", \"party\": \"Democratic\"}
        }
      ],
      \"actions\": [
        {\"description\": \"Introduced\", \"date\": \"2025-01-10\", \"classification\": [\"introduction\"]},
        {\"description\": \"Referred to Committee on Housing\", \"date\": \"2025-03-15\", \"classification\": [\"committee-referral\"]}
      ]
    },
    {
      \"id\": \"ocd-bill/dialogue-2\",
      \"session\": \"20252026\",
      \"jurisdiction\": {
        \"id\": \"ocd-jurisdiction/country:us/state:ca/government\",
        \"name\": \"California\",
        \"classification\": \"state\"
      },
      \"identifier\": \"AB 750\",
      \"title\": \"Clean Water Standards Act\",
      \"classification\": [\"bill\"],
      \"subject\": [\"Environment\"],
      \"openstates_url\": \"https://openstates.org/ca/bills/20252026/AB750/\",
      \"first_action_date\": \"2025-02-01\",
      \"latest_action_date\": \"2025-04-10\",
      \"latest_action_description\": \"Signed by Governor\",
      \"abstracts\": [],
      \"sponsorships\": [
        {
          \"name\": \"Asm. Chen\",
          \"primary\": true,
          \"classification\": \"primary\",
          \"person\": {\"name\": \"David Chen\"}
        }
      ],
      \"actions\": [
        {\"description\": \"Introduced\", \"date\": \"2025-02-01\", \"classification\": [\"introduction\"]},
        {\"description\": \"Passed Assembly\", \"date\": \"2025-03-20\", \"classification\": [\"passage\"]},
        {\"description\": \"Signed by Governor\", \"date\": \"2025-04-10\", \"classification\": [\"became-law\"]}
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

/// Build a request-logging dispatcher that records each request URL
/// via the provided Subject, then returns the canned response.
fn logging_success_dispatcher(
  request_log: Subject(String),
) -> congress_api_client.HttpDispatcher {
  fn(req: request.Request(String)) -> Result(Response(String), String) {
    process.send(request_log, req.path)
    Ok(Response(status: 200, headers: [], body: dialogue_openstates_response))
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
///   1. App sends GET to /bills?jurisdiction=California&page=1&per_page=20
///   2. API returns 200 with 2 bills including nested jurisdiction, sponsors, abstracts
///   3. App parses JSON → extracts state code from OCD jurisdiction ID →
///      extracts sponsor names from person.name → extracts summary from first abstract →
///      maps to domain types → stores in DB
///   4. App marks ingestion state as "completed"
///
/// Key nested extractions:
///   - jurisdiction.id "ocd-jurisdiction/.../state:ca/..." → State("CA")
///   - sponsorships[0].person.name "Ana Martinez" → sponsors: ["Ana Martinez"]
///   - abstracts[0].abstract → summary text
pub fn openstates_success_dialogue_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let request_log = process.new_subject()
  let config = openstates_types.default_config("test-key")
  let dispatcher = logging_success_dispatcher(request_log)

  // --- Dialogue Step 1: App initiates jurisdiction ingestion ---
  let result =
    state_ingestion.ingest_jurisdiction(
      connection,
      config,
      "California",
      dispatcher,
    )

  // --- Verify interaction sequence ---
  let logged_requests = collect_logged_requests(request_log)

  // Exactly 1 API request (single page, max_page=1)
  list.length(logged_requests) |> should.equal(1)

  // Request path contains the bill listing endpoint
  let assert [first_request_path] = logged_requests
  first_request_path
  |> string.contains("/bills")
  |> should.be_true

  // --- Verify pipeline output ---
  let assert Ok(ingestion_result) = result
  ingestion_result.jurisdiction |> should.equal("California")
  ingestion_result.bills_stored |> should.equal(2)

  // --- Verify stored records ---
  let assert Ok(all_records) = legislation_repo.list_all(connection)
  list.length(all_records) |> should.equal(2)

  // Verify State level correctly extracted from OCD jurisdiction ID
  let assert Ok(Some(bill_sb500)) =
    legislation_repo.get_by_id(connection, "openstates-ca-20252026-SB500")
  bill_sb500.level |> should.equal(government_level.State("CA"))

  // Verify sponsors extracted from nested person.name
  bill_sb500.sponsors |> should.equal(["Ana Martinez"])

  // Verify summary extracted from first abstract
  bill_sb500.summary
  |> should.equal("An act to expand affordable housing programs statewide.")

  // Verify topics from subject array
  bill_sb500.topics |> should.equal(["Housing", "Urban Development"])

  // --- Verify ingestion state ---
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

/// --- Dialogue Test: Error Flow ---
///
/// Documents the error interaction sequence:
///   1. App sends GET to bill list endpoint for California
///   2. API returns 500 Internal Server Error
///   3. App returns error result
///   4. App marks ingestion state as "failed" with jurisdiction/session fields
///   5. No bills are stored
pub fn openstates_error_dialogue_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let request_log = process.new_subject()
  let config = openstates_types.default_config("test-key")
  let dispatcher = logging_error_dispatcher(request_log)

  // --- Dialogue Step 1: App attempts jurisdiction ingestion ---
  let result =
    state_ingestion.ingest_jurisdiction(
      connection,
      config,
      "California",
      dispatcher,
    )

  // --- Verify request was attempted ---
  let logged_requests = collect_logged_requests(request_log)
  list.length(logged_requests) |> should.equal(1)

  // --- Verify error result ---
  should.be_error(result)

  // --- Verify no bills stored ---
  let assert Ok(all_records) = legislation_repo.list_all(connection)
  list.length(all_records) |> should.equal(0)

  // --- Verify ingestion state marked failed with jurisdiction context ---
  let assert Ok(Some(state)) =
    ingestion_state_repo.get_by_jurisdiction_and_session(
      connection,
      "California",
      "2025",
    )
  state.status |> should.equal("failed")
  state.jurisdiction |> should.equal(Some("California"))
}

/// --- Dialogue Test: Field Mapping Chain ---
///
/// Documents the precise field transformations from Open States API to domain types:
///   - OCD jurisdiction ID "ocd-jurisdiction/.../state:ca/..." → state code "CA"
///   - classification: ["bill"] → legislation_type: Bill
///   - action classification ["became-law"] → status: Enacted
///   - action classification ["committee-referral"] → status: InCommittee
///   - sponsorships[].person.name → sponsors list (uses person.name, not sponsorship.name)
///   - first abstract text → summary (empty abstracts → empty summary)
///   - first_action_date → introduced_date
///   - subject array → topics list
pub fn openstates_field_mapping_dialogue_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let request_log = process.new_subject()
  let config = openstates_types.default_config("test-key")
  let dispatcher = logging_success_dispatcher(request_log)

  let assert Ok(_) =
    state_ingestion.ingest_jurisdiction(
      connection,
      config,
      "California",
      dispatcher,
    )

  // --- Verify classification mapping: ["bill"] → Bill ---
  let assert Ok(Some(bill_sb500)) =
    legislation_repo.get_by_id(connection, "openstates-ca-20252026-SB500")
  bill_sb500.legislation_type |> should.equal(legislation_type.Bill)

  let assert Ok(Some(bill_ab750)) =
    legislation_repo.get_by_id(connection, "openstates-ca-20252026-AB750")
  bill_ab750.legislation_type |> should.equal(legislation_type.Bill)

  // --- Verify status inference from last action classification ---
  // Last action ["committee-referral"] → InCommittee
  bill_sb500.status |> should.equal(legislation_status.InCommittee)

  // Last action ["became-law"] → Enacted
  bill_ab750.status |> should.equal(legislation_status.Enacted)

  // --- Verify State level from OCD jurisdiction ID ---
  bill_sb500.level |> should.equal(government_level.State("CA"))
  bill_ab750.level |> should.equal(government_level.State("CA"))

  // --- Verify sponsor extraction from person.name ---
  // Sponsorship name "Sen. Martinez" vs person.name "Ana Martinez" → uses person.name
  bill_sb500.sponsors |> should.equal(["Ana Martinez"])
  // Person without party field still extracted correctly
  bill_ab750.sponsors |> should.equal(["David Chen"])

  // --- Verify summary from first abstract (or empty when none) ---
  bill_sb500.summary
  |> should.equal("An act to expand affordable housing programs statewide.")
  // Empty abstracts array → empty summary
  bill_ab750.summary |> should.equal("")

  // --- Verify source identifier preserved ---
  bill_sb500.source_identifier |> should.equal("SB 500")
  bill_ab750.source_identifier |> should.equal("AB 750")

  // --- Verify introduced_date from first_action_date ---
  bill_sb500.introduced_date |> should.equal("2025-01-10")
  bill_ab750.introduced_date |> should.equal("2025-02-01")

  // --- Verify topics from subject array ---
  bill_sb500.topics |> should.equal(["Housing", "Urban Development"])
  bill_ab750.topics |> should.equal(["Environment"])
}
