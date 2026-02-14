/// Dialogue tests for Congress.gov ingestion.
///
/// These tests document the complete request/response interaction flow
/// between the application and the Congress.gov API. Unlike the existing
/// mock tests (which verify correctness of individual operations), dialogue
/// tests focus on the full interaction sequence and field mapping chain.
///
/// Interaction pattern:
///   App → Congress.gov bill list endpoint → parse response → map fields →
///   store in DB → update ingestion state
import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/http/response.{type Response, Response}
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit/should
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/test_helpers
import philstubs/ingestion/congress_api_client
import philstubs/ingestion/congress_ingestion
import philstubs/ingestion/congress_types
import philstubs/ingestion/ingestion_state_repo

/// Mock bill list JSON with 2 bills covering different status mappings.
const dialogue_bill_list_response = "
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

/// Build a request-logging dispatcher that records each request URL
/// via the provided Subject, then returns the canned response.
fn logging_success_dispatcher(
  request_log: Subject(String),
) -> congress_api_client.HttpDispatcher {
  fn(req: request.Request(String)) -> Result(Response(String), String) {
    // Log the request URL for interaction sequence verification
    process.send(request_log, req.path)
    Ok(Response(status: 200, headers: [], body: dialogue_bill_list_response))
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
///   1. App sends GET to /v3/bill/118/hr?offset=0&limit=20&format=json&api_key=...
///   2. API returns 200 with 2 bills (HR 100: "Referred to Committee", HR 200: "Became Public Law")
///   3. App parses JSON → maps to domain types → stores in DB
///   4. App marks ingestion state as "completed" with total_bills_fetched: 2
pub fn congress_success_dialogue_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let request_log = process.new_subject()
  let config = congress_types.default_config("test-key", 118)
  let dispatcher = logging_success_dispatcher(request_log)

  // --- Dialogue Step 1: App initiates bill list request ---
  let result =
    congress_ingestion.ingest_bills(
      connection,
      config,
      congress_types.Hr,
      dispatcher,
    )

  // --- Verify interaction sequence ---
  let logged_requests = collect_logged_requests(request_log)

  // Exactly 1 API request was made (single page, no pagination next link)
  list.length(logged_requests) |> should.equal(1)

  // Request URL contains the expected bill list path pattern
  let assert [first_request_path] = logged_requests
  first_request_path
  |> string.contains("/v3/bill/118/hr")
  |> should.be_true

  // --- Verify pipeline output ---
  let assert Ok(ingestion_result) = result
  ingestion_result.bills_stored |> should.equal(2)

  // --- Verify stored records (end-to-end from API response to DB) ---
  let assert Ok(all_records) = legislation_repo.list_all(connection)
  list.length(all_records) |> should.equal(2)

  // Verify both bills stored with correct IDs
  let assert Ok(Some(bill_alpha)) =
    legislation_repo.get_by_id(connection, "congress_gov-118-hr-100")
  bill_alpha.title |> should.equal("Test Bill Alpha")

  let assert Ok(Some(bill_beta)) =
    legislation_repo.get_by_id(connection, "congress_gov-118-hr-200")
  bill_beta.title |> should.equal("Test Bill Beta")

  // --- Verify ingestion state tracking ---
  let assert Ok(Some(state)) =
    ingestion_state_repo.get_by_congress_and_type(connection, 118, "hr")
  state.status |> should.equal("completed")
  state.total_bills_fetched |> should.equal(2)
}

/// --- Dialogue Test: Error Flow ---
///
/// Documents the error interaction sequence:
///   1. App sends GET to bill list endpoint
///   2. API returns 500 Internal Server Error
///   3. App returns error result
///   4. App marks ingestion state as "failed"
///   5. No bills are stored in the database
pub fn congress_error_dialogue_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let request_log = process.new_subject()
  let config = congress_types.default_config("test-key", 118)
  let dispatcher = logging_error_dispatcher(request_log)

  // --- Dialogue Step 1: App attempts bill list request ---
  let result =
    congress_ingestion.ingest_bills(
      connection,
      config,
      congress_types.Hr,
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

  // --- Verify ingestion state marked failed ---
  let assert Ok(Some(state)) =
    ingestion_state_repo.get_by_congress_and_type(connection, 118, "hr")
  state.status |> should.equal("failed")
}

/// --- Dialogue Test: Field Mapping Chain ---
///
/// Documents the precise field transformations from Congress.gov API to domain types:
///   - API "type": "HR" → legislation_type: Bill
///   - API latestAction.text "Became Public Law" → status: Enacted
///   - API latestAction.text "Referred to...Committee" → status: InCommittee
///   - API "number": "100" with type "HR" → source_identifier: "H.R. 100"
///   - Legislation ID format: "congress_gov-{congress}-{type}-{number}"
///   - Source URL format: "https://www.congress.gov/bill/{congress}th-congress/house-bill/{number}"
pub fn congress_field_mapping_dialogue_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let request_log = process.new_subject()
  let config = congress_types.default_config("test-key", 118)
  let dispatcher = logging_success_dispatcher(request_log)

  let assert Ok(_) =
    congress_ingestion.ingest_bills(
      connection,
      config,
      congress_types.Hr,
      dispatcher,
    )

  // --- Verify HR type mapping → Bill ---
  let assert Ok(Some(bill_alpha)) =
    legislation_repo.get_by_id(connection, "congress_gov-118-hr-100")
  bill_alpha.legislation_type |> should.equal(legislation_type.Bill)

  let assert Ok(Some(bill_beta)) =
    legislation_repo.get_by_id(connection, "congress_gov-118-hr-200")
  bill_beta.legislation_type |> should.equal(legislation_type.Bill)

  // --- Verify status inference from latestAction.text ---
  // "Referred to the Committee on Energy and Commerce." → InCommittee
  bill_alpha.status |> should.equal(legislation_status.InCommittee)

  // "Became Public Law No: 118-5." → Enacted
  bill_beta.status |> should.equal(legislation_status.Enacted)

  // --- Verify source identifier format: "H.R. {number}" ---
  bill_alpha.source_identifier |> should.equal("H.R. 100")
  bill_beta.source_identifier |> should.equal("H.R. 200")

  // --- Verify source URL construction ---
  case bill_alpha.source_url {
    Some(url) -> {
      url |> string.contains("congress.gov/bill/118") |> should.be_true
      url |> string.contains("house-bill/100") |> should.be_true
    }
    _ -> Nil
  }
}
