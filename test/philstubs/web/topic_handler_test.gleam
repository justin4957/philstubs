import gleam/http
import gleam/list
import gleam/option.{None}
import gleam/string
import gleeunit/should
import philstubs/core/government_level.{Federal}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/core/topic
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/test_helpers
import philstubs/data/topic_repo
import philstubs/data/topic_seed
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

fn setup_with_taxonomy(callback: fn(sqlight.Connection) -> Nil) -> Nil {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let assert Ok(_) = topic_seed.seed_topic_taxonomy(connection)
  callback(connection)
}

// --- GET /api/topics/taxonomy ---

pub fn api_topics_taxonomy_test() {
  setup_with_taxonomy(fn(connection) {
    let context = test_context(connection)

    let response =
      simulate.request(http.Get, "/api/topics/taxonomy")
      |> router.handle_request(context)

    response.status |> should.equal(200)
    let body = simulate.read_body(response)
    body |> string.contains("taxonomy") |> should.be_true
    body |> string.contains("Housing") |> should.be_true
    body |> string.contains("children") |> should.be_true
  })
}

// --- GET /api/topics/:slug ---

pub fn api_topic_detail_test() {
  setup_with_taxonomy(fn(connection) {
    let context = test_context(connection)

    // Insert and assign legislation
    let assert Ok(Nil) =
      legislation_repo.insert(connection, sample_federal_bill())
    let assert Ok(Nil) =
      topic_repo.assign_legislation_topic(
        connection,
        "handler-test-001",
        topic.topic_id("housing"),
        topic.Manual,
      )

    let response =
      simulate.request(http.Get, "/api/topics/housing")
      |> router.handle_request(context)

    response.status |> should.equal(200)
    let body = simulate.read_body(response)
    body |> string.contains("Housing") |> should.be_true
    body |> string.contains("federal_count") |> should.be_true
    body |> string.contains("state_count") |> should.be_true
  })
}

pub fn api_topic_detail_not_found_test() {
  setup_with_taxonomy(fn(connection) {
    let context = test_context(connection)

    let response =
      simulate.request(http.Get, "/api/topics/nonexistent-topic")
      |> router.handle_request(context)

    response.status |> should.equal(404)
    let body = simulate.read_body(response)
    body |> string.contains("NOT_FOUND") |> should.be_true
  })
}

// --- GET /api/topics/:slug/legislation ---

pub fn api_topic_legislation_test() {
  setup_with_taxonomy(fn(connection) {
    let context = test_context(connection)

    let assert Ok(Nil) =
      legislation_repo.insert(connection, sample_federal_bill())
    let assert Ok(Nil) =
      topic_repo.assign_legislation_topic(
        connection,
        "handler-test-001",
        topic.topic_id("housing"),
        topic.Manual,
      )

    let response =
      simulate.request(http.Get, "/api/topics/housing/legislation")
      |> router.handle_request(context)

    response.status |> should.equal(200)
    let body = simulate.read_body(response)
    body |> string.contains("items") |> should.be_true
    body |> string.contains("Housing Reform Act") |> should.be_true
  })
}

// --- GET /api/topics/search ---

pub fn api_topic_search_test() {
  setup_with_taxonomy(fn(connection) {
    let context = test_context(connection)

    let response =
      simulate.request(http.Get, "/api/topics/search?q=Hou")
      |> router.handle_request(context)

    response.status |> should.equal(200)
    let body = simulate.read_body(response)
    body |> string.contains("Housing") |> should.be_true
    body |> string.contains("topics") |> should.be_true
  })
}

// --- POST /api/topics/auto-tag ---

pub fn api_auto_tag_test() {
  setup_with_taxonomy(fn(connection) {
    let context = test_context(connection)

    // Insert legislation that should be auto-tagged
    let assert Ok(Nil) =
      legislation_repo.insert(connection, sample_federal_bill())

    let response =
      simulate.request(http.Post, "/api/topics/auto-tag")
      |> router.handle_request(context)

    response.status |> should.equal(200)
    let body = simulate.read_body(response)
    body |> string.contains("tagged_count") |> should.be_true
  })
}

// --- GET /browse/topics (HTML) ---

pub fn browse_topics_page_test() {
  setup_with_taxonomy(fn(connection) {
    let context = test_context(connection)

    let response =
      simulate.request(http.Get, "/browse/topics")
      |> router.handle_request(context)

    response.status |> should.equal(200)
    let body = simulate.read_body(response)
    body |> string.contains("Browse by Topic") |> should.be_true
    body |> string.contains("Housing") |> should.be_true
  })
}

// --- GET /browse/topics/:slug (HTML) ---

pub fn browse_topic_detail_page_test() {
  setup_with_taxonomy(fn(connection) {
    let context = test_context(connection)

    let response =
      simulate.request(http.Get, "/browse/topics/housing")
      |> router.handle_request(context)

    response.status |> should.equal(200)
    let body = simulate.read_body(response)
    body |> string.contains("Housing") |> should.be_true
    body |> string.contains("Federal") |> should.be_true
  })
}

// --- CORS on topic API ---

pub fn api_topics_taxonomy_has_cors_test() {
  setup_with_taxonomy(fn(connection) {
    let context = test_context(connection)

    let response =
      simulate.request(http.Get, "/api/topics/taxonomy")
      |> router.handle_request(context)

    let cors_header =
      list.key_find(response.headers, "access-control-allow-origin")
    cors_header |> should.equal(Ok("*"))
  })
}

// --- Sample data ---

fn sample_federal_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("handler-test-001"),
    title: "Housing Reform Act",
    summary: "Federal housing legislation.",
    body: "SECTION 1. Housing.",
    level: Federal,
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-01-15",
    source_url: None,
    source_identifier: "H.R. 999",
    sponsors: [],
    topics: ["housing"],
  )
}
