import gleam/http
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import philstubs/core/government_level.{Federal, State}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_template.{
  type LegislationTemplate, LegislationTemplate,
}
import philstubs/core/legislation_type
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/template_repo
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

fn sample_federal_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("export-test-fed"),
    title: "Federal Climate Act",
    summary: "Federal climate legislation.",
    body: "SECTION 1. Climate.",
    level: Federal,
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-01-15",
    source_url: Some("https://congress.gov/bill/118/hr42"),
    source_identifier: "H.R. 42",
    sponsors: ["Rep. Smith"],
    topics: ["climate", "environment"],
  )
}

fn sample_state_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("export-test-ca"),
    title: "California Water Bill",
    summary: "CA water legislation.",
    body: "SECTION 1. Water.",
    level: State(state_code: "CA"),
    legislation_type: legislation_type.Bill,
    status: legislation_status.Enacted,
    introduced_date: "2024-02-15",
    source_url: None,
    source_identifier: "AB 55",
    sponsors: [],
    topics: ["water"],
  )
}

fn sample_template() -> LegislationTemplate {
  LegislationTemplate(
    id: legislation_template.template_id("export-tmpl-1"),
    title: "Model Housing Ordinance",
    description: "A template for housing.",
    body: "SECTION 1. Housing.",
    suggested_level: Federal,
    suggested_type: legislation_type.Ordinance,
    author: "Policy Institute",
    topics: ["housing"],
    created_at: "2024-06-01",
    download_count: 10,
    owner_user_id: None,
  )
}

fn insert_sample_data(connection: sqlight.Connection) -> Nil {
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())
  let assert Ok(Nil) = legislation_repo.insert(connection, sample_state_bill())
  let assert Ok(Nil) = template_repo.insert(connection, sample_template())
  Nil
}

// --- Legislation export tests ---

pub fn export_legislation_json_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_sample_data(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/export/legislation")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("export_format") |> should.be_true
  body |> string.contains("\"json\"") |> should.be_true
  body |> string.contains("total_count") |> should.be_true
  body |> string.contains("Federal Climate Act") |> should.be_true
  body |> string.contains("California Water Bill") |> should.be_true
}

pub fn export_legislation_csv_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_sample_data(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/export/legislation?format=csv")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  // Header row
  body
  |> string.contains("id,title,summary,level")
  |> should.be_true
  // Data
  body |> string.contains("export-test-fed") |> should.be_true
  body |> string.contains("export-test-ca") |> should.be_true
}

pub fn export_legislation_csv_content_type_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/export/legislation?format=csv")
    |> router.handle_request(context)

  let content_type = list.key_find(response.headers, "content-type")
  content_type
  |> should.equal(Ok("text/csv; charset=utf-8"))
}

pub fn export_legislation_csv_content_disposition_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/export/legislation?format=csv")
    |> router.handle_request(context)

  let disposition = list.key_find(response.headers, "content-disposition")
  disposition
  |> should.equal(Ok("attachment; filename=\"legislation-export.csv\""))
}

pub fn export_legislation_default_format_is_json_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/export/legislation")
    |> router.handle_request(context)

  let content_type = list.key_find(response.headers, "content-type")
  content_type
  |> should.equal(Ok("application/json; charset=utf-8"))
}

pub fn export_legislation_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/export/legislation?format=csv")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  // Should have only the header row
  body
  |> string.contains("id,title,summary,level")
  |> should.be_true
}

pub fn export_legislation_cors_headers_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/export/legislation")
    |> router.handle_request(context)

  let cors_header =
    list.key_find(response.headers, "access-control-allow-origin")
  cors_header |> should.equal(Ok("*"))
}

// --- Template export tests ---

pub fn export_templates_json_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_sample_data(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/export/templates")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("export_format") |> should.be_true
  body |> string.contains("Model Housing Ordinance") |> should.be_true
}

pub fn export_templates_csv_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_sample_data(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/export/templates?format=csv")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body
  |> string.contains("id,title,description,suggested_level")
  |> should.be_true
  body |> string.contains("export-tmpl-1") |> should.be_true
}

pub fn export_templates_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/export/templates?format=csv")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  // Only header row
  body
  |> string.contains("id,title,description")
  |> should.be_true
}

// --- Search export tests ---

pub fn export_search_json_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_sample_data(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/export/search?q=climate")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("export_format") |> should.be_true
  body |> string.contains("Federal Climate Act") |> should.be_true
}

pub fn export_search_csv_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_sample_data(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/export/search?q=climate&format=csv")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("export-test-fed") |> should.be_true
}

// --- API docs page tests ---

pub fn api_docs_page_renders_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/docs/api")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("API Documentation") |> should.be_true
}

pub fn api_docs_page_contains_export_docs_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/docs/api")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("Bulk Data Export") |> should.be_true
  body |> string.contains("/api/export/legislation") |> should.be_true
  body |> string.contains("/api/export/templates") |> should.be_true
}

pub fn api_docs_page_contains_openapi_link_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/docs/api")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("openapi.json") |> should.be_true
}

pub fn api_docs_page_nav_link_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/docs/api")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("/docs/api") |> should.be_true
  body |> string.contains("API") |> should.be_true
}

pub fn export_legislation_json_content_disposition_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/export/legislation?format=json")
    |> router.handle_request(context)

  let disposition = list.key_find(response.headers, "content-disposition")
  disposition
  |> should.equal(Ok("attachment; filename=\"legislation-export.json\""))
}
