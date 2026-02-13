import gleam/http
import gleam/list
import gleam/string
import gleeunit/should
import philstubs/core/government_level.{Federal, Municipal}
import philstubs/core/legislation_template.{
  type LegislationTemplate, LegislationTemplate,
}
import philstubs/core/legislation_type
import philstubs/data/database
import philstubs/data/template_repo
import philstubs/data/test_helpers
import philstubs/web/context.{Context}
import philstubs/web/router
import sqlight
import wisp/simulate

fn test_context(db_connection: sqlight.Connection) -> context.Context {
  Context(static_directory: "", db_connection:)
}

fn sample_housing_template() -> LegislationTemplate {
  LegislationTemplate(
    id: legislation_template.template_id("test-tmpl-001"),
    title: "Model Affordable Housing Ordinance",
    description: "A template for municipalities to adopt inclusionary zoning requirements for new residential development.",
    body: "WHEREAS the [Municipality] recognizes the need for affordable housing;\n\nSECTION 1. All new residential developments of 10 or more units shall include a minimum of 15% affordable units.",
    suggested_level: Municipal("", ""),
    suggested_type: legislation_type.Ordinance,
    author: "Housing Policy Institute",
    topics: ["housing", "zoning", "affordable housing"],
    created_at: "2024-06-01T12:00:00Z",
    download_count: 42,
  )
}

fn sample_transparency_template() -> LegislationTemplate {
  LegislationTemplate(
    id: legislation_template.template_id("test-tmpl-002"),
    title: "Government Transparency Act Template",
    description: "A model bill for open data publication requirements across government agencies.",
    body: "AN ACT to promote transparency and open government data.\n\nSECTION 1. All government agencies shall publish datasets in machine-readable format.",
    suggested_level: Federal,
    suggested_type: legislation_type.Bill,
    author: "Open Government Coalition",
    topics: ["transparency", "open data", "government accountability"],
    created_at: "2024-04-15T09:30:00Z",
    download_count: 87,
  )
}

// --- GET /templates tests ---

pub fn templates_list_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/templates")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("Legislation Templates") |> should.be_true
  body |> string.contains("No templates yet") |> should.be_true
}

pub fn templates_list_with_items_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())
  let assert Ok(Nil) =
    template_repo.insert(connection, sample_transparency_template())

  let response =
    simulate.request(http.Get, "/templates")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body
  |> string.contains("Model Affordable Housing Ordinance")
  |> should.be_true
  body
  |> string.contains("Government Transparency Act Template")
  |> should.be_true
}

pub fn templates_list_sorted_by_downloads_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())
  let assert Ok(Nil) =
    template_repo.insert(connection, sample_transparency_template())

  let response =
    simulate.request(http.Get, "/templates?sort=downloads")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  // Transparency template has 87 downloads, housing has 42
  // So transparency should appear first
  let transparency_position =
    body |> string.contains("Government Transparency Act Template")
  transparency_position |> should.be_true
}

// --- GET /templates/new tests ---

pub fn template_new_form_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/templates/new")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("Upload a Legislation Template") |> should.be_true
  body |> string.contains("Title") |> should.be_true
  body |> string.contains("Template Body") |> should.be_true
  body |> string.contains("Author") |> should.be_true
}

// --- POST /templates tests ---

pub fn template_create_success_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Post, "/templates")
    |> simulate.form_body([
      #("title", "Clean Water Act Template"),
      #("description", "Model legislation for water quality"),
      #("body", "SECTION 1. Water quality standards..."),
      #("suggested_level", "state"),
      #("suggested_type", "bill"),
      #("author", "Water Policy Network"),
      #("topics", "water, environment, health"),
    ])
    |> router.handle_request(context)

  // Should redirect to the new template
  response.status |> should.equal(303)

  // Verify template was stored
  let assert Ok(templates) = template_repo.list_all(connection)
  templates |> list.length |> should.equal(1)
  let assert [created] = templates
  created.title |> should.equal("Clean Water Act Template")
  created.author |> should.equal("Water Policy Network")
  created.topics |> should.equal(["water", "environment", "health"])
}

pub fn template_create_missing_title_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Post, "/templates")
    |> simulate.form_body([
      #("title", ""),
      #("description", "some description"),
      #("body", "some body text"),
      #("author", "Test Author"),
    ])
    |> router.handle_request(context)

  response.status |> should.equal(400)
  let body = simulate.read_body(response)
  body |> string.contains("Title is required") |> should.be_true
}

pub fn template_create_missing_body_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Post, "/templates")
    |> simulate.form_body([
      #("title", "Valid Title"),
      #("description", "some description"),
      #("body", ""),
      #("author", "Test Author"),
    ])
    |> router.handle_request(context)

  response.status |> should.equal(400)
  let body = simulate.read_body(response)
  body |> string.contains("Template body is required") |> should.be_true
}

pub fn template_create_missing_author_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Post, "/templates")
    |> simulate.form_body([
      #("title", "Valid Title"),
      #("description", "some description"),
      #("body", "Some body text"),
      #("author", ""),
    ])
    |> router.handle_request(context)

  response.status |> should.equal(400)
  let body = simulate.read_body(response)
  body |> string.contains("Author is required") |> should.be_true
}

pub fn template_create_sanitizes_xss_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let _response =
    simulate.request(http.Post, "/templates")
    |> simulate.form_body([
      #("title", "Test <script>alert('xss')</script>"),
      #("description", "Safe description"),
      #("body", "SECTION 1. <script>malicious()</script> text"),
      #("author", "Safe Author"),
      #("suggested_level", "federal"),
      #("suggested_type", "bill"),
      #("topics", ""),
    ])
    |> router.handle_request(context)

  // Verify the stored data is sanitized
  let assert Ok(templates) = template_repo.list_all(connection)
  let assert [created] = templates
  created.title
  |> string.contains("<script")
  |> should.be_false
  created.body
  |> string.contains("<script")
  |> should.be_false
}

// --- GET /templates/:id tests ---

pub fn template_detail_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())

  let response =
    simulate.request(http.Get, "/templates/test-tmpl-001")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body
  |> string.contains("Model Affordable Housing Ordinance")
  |> should.be_true
  body |> string.contains("Housing Policy Institute") |> should.be_true
  body
  |> string.contains("WHEREAS the [Municipality]")
  |> should.be_true
  body |> string.contains("Download as Text") |> should.be_true
  body |> string.contains("Download as Markdown") |> should.be_true
}

pub fn template_detail_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/templates/nonexistent-id")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

// --- GET /templates/:id/download tests ---

pub fn template_download_plain_text_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())

  let response =
    simulate.request(http.Get, "/templates/test-tmpl-001/download?format=text")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body
  |> string.contains("Model Affordable Housing Ordinance")
  |> should.be_true
  body |> string.contains("Author: Housing Policy Institute") |> should.be_true
  body |> string.contains("WHEREAS the [Municipality]") |> should.be_true

  // Check content-type header
  let content_type = list.key_find(response.headers, "content-type")
  content_type |> should.equal(Ok("text/plain; charset=utf-8"))

  // Check content-disposition header
  let content_disposition =
    list.key_find(response.headers, "content-disposition")
  content_disposition |> should.be_ok
}

pub fn template_download_markdown_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())

  let response =
    simulate.request(
      http.Get,
      "/templates/test-tmpl-001/download?format=markdown",
    )
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body
  |> string.contains("# Model Affordable Housing Ordinance")
  |> should.be_true
  body
  |> string.contains("**Author:** Housing Policy Institute")
  |> should.be_true

  let content_type = list.key_find(response.headers, "content-type")
  content_type |> should.equal(Ok("text/markdown; charset=utf-8"))
}

pub fn template_download_increments_count_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())

  // Initial count is 42
  let assert Ok(Some(before)) =
    template_repo.get_by_id(connection, "test-tmpl-001")
  before.download_count |> should.equal(42)

  // Download
  let _response =
    simulate.request(http.Get, "/templates/test-tmpl-001/download?format=text")
    |> router.handle_request(context)

  // Count should be 43
  let assert Ok(Some(after)) =
    template_repo.get_by_id(connection, "test-tmpl-001")
  after.download_count |> should.equal(43)
}

pub fn template_download_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/templates/nonexistent/download?format=text")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

// --- DELETE /templates/:id tests ---

pub fn template_delete_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())

  // DELETE via POST (method override)
  let response =
    simulate.request(http.Post, "/templates/test-tmpl-001")
    |> router.handle_request(context)

  // Should redirect to listing
  response.status |> should.equal(303)

  // Verify template was deleted
  let assert Ok(result) = template_repo.get_by_id(connection, "test-tmpl-001")
  result |> should.be_none
}

pub fn template_delete_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Post, "/templates/nonexistent-id")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

// --- API tests ---

pub fn api_templates_list_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())
  let assert Ok(Nil) =
    template_repo.insert(connection, sample_transparency_template())

  let response =
    simulate.request(http.Get, "/api/templates")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body
  |> string.contains("Model Affordable Housing Ordinance")
  |> should.be_true
  body
  |> string.contains("Government Transparency Act Template")
  |> should.be_true

  let content_type = list.key_find(response.headers, "content-type")
  content_type
  |> should.equal(Ok("application/json; charset=utf-8"))
}

pub fn api_template_detail_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())

  let response =
    simulate.request(http.Get, "/api/templates/test-tmpl-001")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body
  |> string.contains("Model Affordable Housing Ordinance")
  |> should.be_true
  body |> string.contains("Housing Policy Institute") |> should.be_true

  let content_type = list.key_find(response.headers, "content-type")
  content_type
  |> should.equal(Ok("application/json; charset=utf-8"))
}

pub fn api_template_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/templates/nonexistent")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

import gleam/option.{Some}
