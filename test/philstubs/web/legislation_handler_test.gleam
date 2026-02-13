import gleam/http
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import philstubs/core/government_level.{Federal, State}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/data/database
import philstubs/data/legislation_repo
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
    id: legislation.legislation_id("test-leg-001"),
    title: "Clean Air Restoration Act",
    summary: "A bill to restore clean air standards across the nation and establish new emission limits for industrial facilities.",
    body: "SECTION 1. SHORT TITLE.\nThis Act may be cited as the \"Clean Air Restoration Act\".\n\nSECTION 2. EMISSION STANDARDS.\n(a) The Administrator of the Environmental Protection Agency shall revise emission standards...",
    level: Federal,
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-03-15",
    source_url: Some("https://congress.gov/bill/118th-congress/hr-1234"),
    source_identifier: "H.R. 1234",
    sponsors: ["Rep. Smith, Jane", "Rep. Johnson, Robert"],
    topics: ["environment", "air quality", "emissions"],
  )
}

fn sample_state_resolution() -> Legislation {
  Legislation(
    id: legislation.legislation_id("test-leg-002"),
    title: "California Water Conservation Resolution",
    summary: "A resolution declaring the importance of water conservation in the state of California.",
    body: "RESOLVED, That the Legislature of the State of California declares the importance of water conservation measures...",
    level: State(state_code: "CA"),
    legislation_type: legislation_type.Resolution,
    status: legislation_status.Enacted,
    introduced_date: "2024-01-10",
    source_url: None,
    source_identifier: "SCR 42",
    sponsors: ["Sen. Garcia, Maria"],
    topics: ["water", "environment", "conservation"],
  )
}

fn sample_bill_no_summary() -> Legislation {
  Legislation(
    id: legislation.legislation_id("test-leg-003"),
    title: "Data Privacy Enhancement Act",
    summary: "",
    body: "SECTION 1. Any entity collecting personal data shall comply with the following requirements...",
    level: Federal,
    legislation_type: legislation_type.Bill,
    status: legislation_status.InCommittee,
    introduced_date: "2024-06-01",
    source_url: None,
    source_identifier: "S. 567",
    sponsors: [],
    topics: ["privacy", "data", "technology"],
  )
}

// --- GET /legislation/:id tests ---

pub fn legislation_detail_renders_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-001")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("Clean Air Restoration Act") |> should.be_true
  body |> string.contains("H.R. 1234") |> should.be_true
  body |> string.contains("Introduced") |> should.be_true
  body |> string.contains("2024-03-15") |> should.be_true
}

pub fn legislation_detail_shows_summary_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-001")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("Summary") |> should.be_true
  body
  |> string.contains("restore clean air standards")
  |> should.be_true
}

pub fn legislation_detail_shows_body_text_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-001")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("Full Text") |> should.be_true
  body
  |> string.contains("Clean Air Restoration Act")
  |> should.be_true
}

pub fn legislation_detail_shows_sponsors_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-001")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("Sponsors") |> should.be_true
  body |> string.contains("Rep. Smith, Jane") |> should.be_true
  body |> string.contains("Rep. Johnson, Robert") |> should.be_true
}

pub fn legislation_detail_shows_topics_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-001")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("environment") |> should.be_true
  body |> string.contains("air quality") |> should.be_true
  body |> string.contains("emissions") |> should.be_true
}

pub fn legislation_detail_shows_source_link_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-001")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("View original") |> should.be_true
  body
  |> string.contains("https://congress.gov/bill/118th-congress/hr-1234")
  |> should.be_true
}

pub fn legislation_detail_hides_source_link_when_none_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_state_resolution())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-002")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("View original") |> should.be_false
}

pub fn legislation_detail_shows_download_buttons_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-001")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("Download as Text") |> should.be_true
  body |> string.contains("Download as Markdown") |> should.be_true
  body
  |> string.contains("/legislation/test-leg-001/download?format=text")
  |> should.be_true
  body
  |> string.contains("/legislation/test-leg-001/download?format=markdown")
  |> should.be_true
}

pub fn legislation_detail_shows_find_similar_link_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-001")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("Find similar legislation") |> should.be_true
}

pub fn legislation_detail_shows_related_legislation_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  // Insert two records with overlapping topics
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_state_resolution())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-001")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  // The state resolution shares "environment" topic with the federal bill
  body |> string.contains("Related Legislation") |> should.be_true
  body
  |> string.contains("California Water Conservation Resolution")
  |> should.be_true
}

pub fn legislation_detail_enacted_status_badge_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_state_resolution())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-002")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("status-enacted") |> should.be_true
  body |> string.contains("Enacted") |> should.be_true
}

pub fn legislation_detail_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/legislation/nonexistent-id")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

pub fn legislation_detail_open_graph_meta_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-001")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("og:title") |> should.be_true
  body |> string.contains("og:description") |> should.be_true
  body |> string.contains("og:type") |> should.be_true
}

// --- GET /legislation/:id/download tests ---

pub fn legislation_download_plain_text_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-001/download?format=text")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("Clean Air Restoration Act") |> should.be_true
  body |> string.contains("Identifier: H.R. 1234") |> should.be_true
  body |> string.contains("Sponsors:") |> should.be_true

  let content_type = list.key_find(response.headers, "content-type")
  content_type |> should.equal(Ok("text/plain; charset=utf-8"))

  let content_disposition =
    list.key_find(response.headers, "content-disposition")
  content_disposition |> should.be_ok
}

pub fn legislation_download_markdown_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let response =
    simulate.request(
      http.Get,
      "/legislation/test-leg-001/download?format=markdown",
    )
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body
  |> string.contains("# Clean Air Restoration Act")
  |> should.be_true
  body |> string.contains("**Identifier:**") |> should.be_true
  body |> string.contains("## Full Text") |> should.be_true

  let content_type = list.key_find(response.headers, "content-type")
  content_type |> should.equal(Ok("text/markdown; charset=utf-8"))
}

pub fn legislation_download_default_format_is_text_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-001/download")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let content_type = list.key_find(response.headers, "content-type")
  content_type |> should.equal(Ok("text/plain; charset=utf-8"))
}

pub fn legislation_download_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/legislation/nonexistent/download?format=text")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

pub fn legislation_download_includes_summary_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-001/download?format=text")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("Summary:") |> should.be_true
  body
  |> string.contains("restore clean air standards")
  |> should.be_true
}

pub fn legislation_download_omits_summary_when_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_bill_no_summary())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-003/download?format=text")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("Summary:") |> should.be_false
}

// --- GET /api/legislation/:id tests ---

pub fn api_legislation_detail_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let response =
    simulate.request(http.Get, "/api/legislation/test-leg-001")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("Clean Air Restoration Act") |> should.be_true
  body |> string.contains("H.R. 1234") |> should.be_true
  body |> string.contains("environment") |> should.be_true

  let content_type = list.key_find(response.headers, "content-type")
  content_type
  |> should.equal(Ok("application/json; charset=utf-8"))
}

pub fn api_legislation_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/legislation/nonexistent")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

// --- Related legislation tests ---

pub fn related_legislation_query_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_state_resolution())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_bill_no_summary())

  // Find related to the federal bill by its topics
  let assert Ok(related) =
    legislation_repo.find_related(
      connection,
      "test-leg-001",
      ["environment", "air quality", "emissions"],
      5,
    )

  // Should find the state resolution (shares "environment" topic) but not the federal bill itself
  related |> list.length |> should.not_equal(0)
  let related_ids =
    list.map(related, fn(record) {
      legislation.legislation_id_to_string(record.id)
    })
  related_ids
  |> list.contains("test-leg-001")
  |> should.be_false
}

pub fn related_legislation_empty_topics_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())

  let assert Ok(related) =
    legislation_repo.find_related(connection, "test-leg-001", [], 5)

  related |> list.length |> should.equal(0)
}

pub fn legislation_detail_no_summary_section_when_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_bill_no_summary())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-003")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  // Should have Full Text but not the Summary section
  body |> string.contains("Full Text") |> should.be_true
  body
  |> string.contains("legislation-summary-section")
  |> should.be_false
}

pub fn legislation_detail_no_sponsors_section_when_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_bill_no_summary())

  let response =
    simulate.request(http.Get, "/legislation/test-leg-003")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("sponsors-list") |> should.be_false
}
