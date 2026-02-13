import gleam/http
import gleam/list
import gleam/option.{None}
import gleam/string
import gleeunit/should
import philstubs/core/government_level.{County, Federal, Municipal, State}
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
  Context(static_directory: "", db_connection:)
}

fn sample_federal_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("api-test-fed-001"),
    title: "Federal Climate Act",
    summary: "Federal climate legislation.",
    body: "SECTION 1. Climate.",
    level: Federal,
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-01-15",
    source_url: None,
    source_identifier: "H.R. 42",
    sponsors: ["Rep. Smith"],
    topics: ["climate", "environment"],
  )
}

fn sample_state_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("api-test-ca-001"),
    title: "California Water Bill",
    summary: "CA water legislation.",
    body: "SECTION 1. Water.",
    level: State(state_code: "CA"),
    legislation_type: legislation_type.Resolution,
    status: legislation_status.Enacted,
    introduced_date: "2024-02-15",
    source_url: None,
    source_identifier: "AB 55",
    sponsors: [],
    topics: ["water", "environment"],
  )
}

fn sample_county_ordinance() -> Legislation {
  Legislation(
    id: legislation.legislation_id("api-test-county-001"),
    title: "LA County Zoning Ordinance",
    summary: "LA county zoning.",
    body: "SECTION 1. Zoning.",
    level: County(state_code: "CA", county_name: "Los Angeles"),
    legislation_type: legislation_type.Ordinance,
    status: legislation_status.Enacted,
    introduced_date: "2024-03-15",
    source_url: None,
    source_identifier: "ORD-LA-1",
    sponsors: [],
    topics: ["zoning"],
  )
}

fn sample_municipal_ordinance() -> Legislation {
  Legislation(
    id: legislation.legislation_id("api-test-muni-001"),
    title: "Seattle Transit Ordinance",
    summary: "Seattle transit.",
    body: "SECTION 1. Transit.",
    level: Municipal(state_code: "WA", municipality_name: "Seattle"),
    legislation_type: legislation_type.Ordinance,
    status: legislation_status.Introduced,
    introduced_date: "2024-04-15",
    source_url: None,
    source_identifier: "ORD-SEA-1",
    sponsors: [],
    topics: ["transit"],
  )
}

fn sample_housing_template() -> LegislationTemplate {
  LegislationTemplate(
    id: legislation_template.template_id("api-test-tmpl-001"),
    title: "Model Housing Ordinance",
    description: "A template for housing legislation.",
    body: "SECTION 1. Housing requirements.",
    suggested_level: Municipal("", ""),
    suggested_type: legislation_type.Ordinance,
    author: "Housing Policy Institute",
    topics: ["housing", "zoning"],
    created_at: "2024-06-01T12:00:00Z",
    download_count: 10,
  )
}

fn insert_all_legislation(connection: sqlight.Connection) -> Nil {
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())
  let assert Ok(Nil) = legislation_repo.insert(connection, sample_state_bill())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_county_ordinance())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_municipal_ordinance())
  Nil
}

// --- GET /api/legislation tests ---

pub fn api_legislation_list_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_legislation(connection)

  let response =
    simulate.request(http.Get, "/api/legislation")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("total_count") |> should.be_true
  body |> string.contains("items") |> should.be_true
  body |> string.contains("page") |> should.be_true
  body |> string.contains("Federal Climate Act") |> should.be_true
}

pub fn api_legislation_list_with_level_filter_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_legislation(connection)

  let response =
    simulate.request(http.Get, "/api/legislation?level=federal")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("Federal Climate Act") |> should.be_true
  // Should not contain state-level items in filtered results
  body |> string.contains("California Water Bill") |> should.be_false
}

pub fn api_legislation_list_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/legislation")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"total_count\":0") |> should.be_true
}

pub fn api_legislation_list_has_cors_headers_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/legislation")
    |> router.handle_request(context)

  let cors_header =
    list.key_find(response.headers, "access-control-allow-origin")
  cors_header |> should.equal(Ok("*"))
}

// --- GET /api/legislation/stats tests ---

pub fn api_legislation_stats_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_legislation(connection)

  let response =
    simulate.request(http.Get, "/api/legislation/stats")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"total\":4") |> should.be_true
  body |> string.contains("by_level") |> should.be_true
  body |> string.contains("by_type") |> should.be_true
  body |> string.contains("by_status") |> should.be_true
}

pub fn api_legislation_stats_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/legislation/stats")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"total\":0") |> should.be_true
}

// --- GET /api/legislation/:id error format tests ---

pub fn api_legislation_not_found_error_format_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/legislation/nonexistent")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

// --- POST /api/templates tests ---

pub fn api_template_create_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let json_body =
    "{\"title\":\"Test Template\",\"description\":\"A test\",\"body\":\"SECTION 1.\",\"suggested_level\":{\"kind\":\"federal\"},\"suggested_type\":\"bill\",\"author\":\"Test Author\",\"topics\":[\"test\"]}"

  let response =
    simulate.request(http.Post, "/api/templates")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(201)
  let body = simulate.read_body(response)
  body |> string.contains("Test Template") |> should.be_true
  body |> string.contains("Test Author") |> should.be_true

  let content_type = list.key_find(response.headers, "content-type")
  content_type
  |> should.equal(Ok("application/json; charset=utf-8"))
}

pub fn api_template_create_missing_title_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let json_body =
    "{\"title\":\"\",\"description\":\"A test\",\"body\":\"SECTION 1.\",\"suggested_level\":{\"kind\":\"federal\"},\"suggested_type\":\"bill\",\"author\":\"Test Author\",\"topics\":[\"test\"]}"

  let response =
    simulate.request(http.Post, "/api/templates")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(400)
  let body = simulate.read_body(response)
  body |> string.contains("VALIDATION_ERROR") |> should.be_true
  body |> string.contains("title") |> should.be_true
}

pub fn api_template_create_invalid_json_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Post, "/api/templates")
    |> simulate.string_body("{invalid json}")
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(400)
}

// --- PUT /api/templates/:id tests ---

pub fn api_template_update_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())

  let json_body =
    "{\"title\":\"Updated Housing Ordinance\",\"description\":\"Updated desc\",\"body\":\"SECTION 1. Updated.\",\"suggested_level\":{\"kind\":\"federal\"},\"suggested_type\":\"bill\",\"author\":\"New Author\",\"topics\":[\"housing\",\"updated\"]}"

  let response =
    simulate.request(http.Put, "/api/templates/api-test-tmpl-001")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("Updated Housing Ordinance") |> should.be_true
  body |> string.contains("New Author") |> should.be_true
}

pub fn api_template_update_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let json_body =
    "{\"title\":\"Test\",\"description\":\"Test\",\"body\":\"Body\",\"suggested_level\":{\"kind\":\"federal\"},\"suggested_type\":\"bill\",\"author\":\"Author\",\"topics\":[]}"

  let response =
    simulate.request(http.Put, "/api/templates/nonexistent")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(404)
  let body = simulate.read_body(response)
  body |> string.contains("NOT_FOUND") |> should.be_true
}

// --- DELETE /api/templates/:id tests ---

pub fn api_template_delete_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())

  let response =
    simulate.request(http.Delete, "/api/templates/api-test-tmpl-001")
    |> router.handle_request(context)

  response.status |> should.equal(204)

  // Verify template is actually deleted
  let assert Ok(None) = template_repo.get_by_id(connection, "api-test-tmpl-001")
}

pub fn api_template_delete_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Delete, "/api/templates/nonexistent")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

// --- GET /api/templates/:id/download tests ---

pub fn api_template_download_text_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())

  let response =
    simulate.request(
      http.Get,
      "/api/templates/api-test-tmpl-001/download?format=text",
    )
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("Model Housing Ordinance") |> should.be_true

  let content_type = list.key_find(response.headers, "content-type")
  content_type |> should.equal(Ok("text/plain; charset=utf-8"))
}

pub fn api_template_download_markdown_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())

  let response =
    simulate.request(
      http.Get,
      "/api/templates/api-test-tmpl-001/download?format=markdown",
    )
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("# Model Housing Ordinance") |> should.be_true

  let content_type = list.key_find(response.headers, "content-type")
  content_type |> should.equal(Ok("text/markdown; charset=utf-8"))
}

pub fn api_template_download_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/templates/nonexistent/download")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

// --- GET /api/levels tests ---

pub fn api_levels_list_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_legislation(connection)

  let response =
    simulate.request(http.Get, "/api/levels")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("levels") |> should.be_true
  body |> string.contains("federal") |> should.be_true
  body |> string.contains("state") |> should.be_true
  body |> string.contains("\"label\"") |> should.be_true
  body |> string.contains("\"count\"") |> should.be_true
}

pub fn api_levels_list_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/levels")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"levels\":[]") |> should.be_true
}

// --- GET /api/levels/:level/jurisdictions tests ---

pub fn api_level_state_jurisdictions_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_legislation(connection)

  let response =
    simulate.request(http.Get, "/api/levels/state/jurisdictions")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"level\":\"state\"") |> should.be_true
  body |> string.contains("jurisdictions") |> should.be_true
  body |> string.contains("CA") |> should.be_true
  body |> string.contains("WA") |> should.be_true
}

pub fn api_level_county_jurisdictions_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_legislation(connection)

  let response =
    simulate.request(http.Get, "/api/levels/county/jurisdictions?state=CA")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"level\":\"county\"") |> should.be_true
  body |> string.contains("Los Angeles") |> should.be_true
}

pub fn api_level_county_requires_state_param_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/levels/county/jurisdictions")
    |> router.handle_request(context)

  response.status |> should.equal(400)
  let body = simulate.read_body(response)
  body |> string.contains("VALIDATION_ERROR") |> should.be_true
  body |> string.contains("state") |> should.be_true
}

pub fn api_level_municipal_jurisdictions_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_legislation(connection)

  let response =
    simulate.request(http.Get, "/api/levels/municipal/jurisdictions?state=WA")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("Seattle") |> should.be_true
}

pub fn api_level_unknown_returns_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/levels/unknown/jurisdictions")
    |> router.handle_request(context)

  response.status |> should.equal(404)
  let body = simulate.read_body(response)
  body |> string.contains("NOT_FOUND") |> should.be_true
}

// --- GET /api/topics tests ---

pub fn api_topics_list_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_legislation(connection)

  let response =
    simulate.request(http.Get, "/api/topics")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("topics") |> should.be_true
  body |> string.contains("environment") |> should.be_true
  body |> string.contains("climate") |> should.be_true
  body |> string.contains("\"count\"") |> should.be_true
}

pub fn api_topics_list_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/topics")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"topics\":[]") |> should.be_true
}

// --- CORS tests ---

pub fn api_cors_headers_on_get_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/topics")
    |> router.handle_request(context)

  let cors_origin =
    list.key_find(response.headers, "access-control-allow-origin")
  cors_origin |> should.equal(Ok("*"))

  let cors_methods =
    list.key_find(response.headers, "access-control-allow-methods")
  cors_methods |> should.be_ok
}

pub fn api_cors_preflight_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Options, "/api/legislation")
    |> router.handle_request(context)

  response.status |> should.equal(204)
  let cors_origin =
    list.key_find(response.headers, "access-control-allow-origin")
  cors_origin |> should.equal(Ok("*"))
}

// --- Method not allowed tests ---

pub fn api_templates_method_not_allowed_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Patch, "/api/templates")
    |> router.handle_request(context)

  response.status |> should.equal(405)
  let body = simulate.read_body(response)
  body |> string.contains("METHOD_NOT_ALLOWED") |> should.be_true
}

// --- Unknown API endpoint test ---

pub fn api_unknown_endpoint_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/nonexistent")
    |> router.handle_request(context)

  response.status |> should.equal(404)
  let body = simulate.read_body(response)
  body |> string.contains("NOT_FOUND") |> should.be_true
}

// --- Content-Type validation ---

pub fn api_json_content_type_on_responses_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/legislation/stats")
    |> router.handle_request(context)

  let content_type = list.key_find(response.headers, "content-type")
  content_type
  |> should.equal(Ok("application/json; charset=utf-8"))
}
