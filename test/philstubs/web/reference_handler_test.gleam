import gleam/http
import gleam/option.{None}
import gleam/string
import gleeunit/should
import philstubs/core/government_level
import philstubs/core/legislation.{Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/core/reference
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/reference_repo
import philstubs/data/test_helpers
import philstubs/web/context.{Context}
import philstubs/web/router
import sqlight
import wisp/simulate

fn test_context(db_connection: sqlight.Connection) -> context.Context {
  Context(
    static_directory: "",
    db_connection:,
    current_user: None,
    github_client_id: "",
    github_client_secret: "",
    scheduler: None,
  )
}

fn insert_test_legislation(
  connection: sqlight.Connection,
  legislation_id: String,
  title: String,
) -> Nil {
  let test_legislation =
    Legislation(
      id: legislation.legislation_id(legislation_id),
      title:,
      summary: "Test summary",
      body: "Test body referencing 42 U.S.C. 1983",
      level: government_level.Federal,
      legislation_type: legislation_type.Bill,
      status: legislation_status.Introduced,
      introduced_date: "2024-01-15",
      source_url: None,
      source_identifier: "TEST-001",
      sponsors: [],
      topics: [],
    )
  let assert Ok(_) = legislation_repo.insert(connection, test_legislation)
  Nil
}

// --- GET /api/legislation/:id/references ---

pub fn api_references_from_returns_200_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "ref-001", "Test Bill")

  let ref =
    reference.CrossReference(
      id: reference.reference_id("ref-001:42 u.s.c. 1983"),
      source_legislation_id: "ref-001",
      target_legislation_id: None,
      citation_text: "42 u.s.c. 1983",
      reference_type: reference.References,
      confidence: 0.9,
      extractor: reference.GleamNative,
      extracted_at: "2026-01-01T00:00:00",
    )
  let assert Ok(_) = reference_repo.insert_reference(connection, ref)

  let response =
    simulate.request(http.Get, "/api/legislation/ref-001/references")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("legislation_id") |> should.be_true
  body |> string.contains("ref-001") |> should.be_true
  body |> string.contains("references") |> should.be_true
  body |> string.contains("42 u.s.c. 1983") |> should.be_true
}

pub fn api_references_from_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/legislation/nonexistent/references")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"references\":[]") |> should.be_true
}

// --- GET /api/legislation/:id/referenced-by ---

pub fn api_referenced_by_returns_200_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "ref-src", "Source Bill")
  insert_test_legislation(connection, "ref-tgt", "Target Bill")

  let ref =
    reference.CrossReference(
      id: reference.reference_id("ref-src:some citation"),
      source_legislation_id: "ref-src",
      target_legislation_id: option.Some("ref-tgt"),
      citation_text: "some citation",
      reference_type: reference.Amends,
      confidence: 0.95,
      extractor: reference.GleamNative,
      extracted_at: "2026-01-01T00:00:00",
    )
  let assert Ok(_) = reference_repo.insert_reference(connection, ref)

  let response =
    simulate.request(http.Get, "/api/legislation/ref-tgt/referenced-by")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("referenced_by") |> should.be_true
  body |> string.contains("ref-src") |> should.be_true
}

// --- GET /api/query-maps ---

pub fn api_list_query_maps_returns_200_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/query-maps")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("query_maps") |> should.be_true
  body |> string.contains("count") |> should.be_true
}

// --- POST /api/query-maps ---

pub fn api_create_query_map_returns_201_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let json_body =
    "{\"name\": \"Find amendments\", \"query_template\": \"SELECT * FROM legislation_references WHERE reference_type = 'amends'\"}"

  let response =
    simulate.request(http.Post, "/api/query-maps")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(201)
  let body = simulate.read_body(response)
  body |> string.contains("Find amendments") |> should.be_true
  body |> string.contains("query_template") |> should.be_true
}

pub fn api_create_query_map_missing_name_returns_400_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let json_body = "{\"query_template\": \"SELECT 1\"}"

  let response =
    simulate.request(http.Post, "/api/query-maps")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(400)
}

// --- GET /api/query-maps/:id ---

pub fn api_query_map_detail_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let query_map =
    reference.QueryMap(
      id: reference.query_map_id("test-qm"),
      name: "Test Query",
      description: "A test query map",
      query_template: "SELECT 1",
      parameters: "{}",
      created_at: "2026-01-01T00:00:00",
    )
  let assert Ok(_) = reference_repo.insert_query_map(connection, query_map)

  let response =
    simulate.request(http.Get, "/api/query-maps/test-qm")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("Test Query") |> should.be_true
}

pub fn api_query_map_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/query-maps/nonexistent")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

// --- POST /api/references/extract ---

pub fn api_extract_citations_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let json_body =
    "{\"text\": \"This bill amends 42 U.S.C. 1983 and references Pub. L. 117-169.\"}"

  let response =
    simulate.request(http.Post, "/api/references/extract")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("citations") |> should.be_true
  body |> string.contains("count") |> should.be_true
  body |> string.contains("citation_text") |> should.be_true
}

pub fn api_extract_citations_empty_text_returns_400_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let json_body = "{\"text\": \"\"}"

  let response =
    simulate.request(http.Post, "/api/references/extract")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(400)
}
