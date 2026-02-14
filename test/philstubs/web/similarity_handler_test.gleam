import gleam/http
import gleam/option.{None}
import gleam/string
import gleeunit/should
import philstubs/core/government_level.{Federal, State}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/similarity_repo
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

fn sample_federal_legislation() -> Legislation {
  Legislation(
    id: legislation.legislation_id("sim-fed-001"),
    title: "Clean Air Standards Act",
    summary: "Establishes new air quality standards",
    body: "AN ACT to establish standards for environmental protection and regulate emissions from industrial facilities throughout the nation",
    level: Federal,
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-01-15",
    source_url: None,
    source_identifier: "H.R. 100",
    sponsors: [],
    topics: ["environment", "emissions"],
  )
}

fn sample_state_legislation() -> Legislation {
  Legislation(
    id: legislation.legislation_id("sim-state-001"),
    title: "California Clean Air Standards Act",
    summary: "California environmental standards",
    body: "AN ACT to establish standards for environmental protection and regulate emissions from industrial facilities in the state of California",
    level: State("CA"),
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-03-20",
    source_url: None,
    source_identifier: "SB 200",
    sponsors: [],
    topics: ["environment", "emissions"],
  )
}

fn setup_with_similarity(connection: sqlight.Connection) -> Nil {
  let assert Ok(_) =
    legislation_repo.insert(connection, sample_federal_legislation())
  let assert Ok(_) =
    legislation_repo.insert(connection, sample_state_legislation())
  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "sim-fed-001",
      "sim-state-001",
      0.87,
      0.92,
      0.85,
      0.9,
    )
  Nil
}

// --- GET /api/legislation/:id/similar ---

pub fn api_similar_legislation_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  setup_with_similarity(connection)

  let response =
    simulate.request(http.Get, "/api/legislation/sim-fed-001/similar")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("legislation_id") |> should.be_true
  body |> string.contains("sim-fed-001") |> should.be_true
  body |> string.contains("similar") |> should.be_true
  body |> string.contains("similarity_score") |> should.be_true
  body |> string.contains("0.87") |> should.be_true
  body
  |> string.contains("California Clean Air Standards Act")
  |> should.be_true
}

pub fn api_similar_legislation_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(_) =
    legislation_repo.insert(connection, sample_federal_legislation())

  let response =
    simulate.request(http.Get, "/api/legislation/sim-fed-001/similar")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"similar\":[]") |> should.be_true
}

// --- GET /api/legislation/:id/adoption-timeline ---

pub fn api_adoption_timeline_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  setup_with_similarity(connection)

  let response =
    simulate.request(http.Get, "/api/legislation/sim-fed-001/adoption-timeline")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("timeline") |> should.be_true
  body |> string.contains("introduced_date") |> should.be_true
  body |> string.contains("2024-03-20") |> should.be_true
}

pub fn api_adoption_timeline_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/legislation/nonexistent/adoption-timeline")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"timeline\":[]") |> should.be_true
}

// --- GET /legislation/:id/diff/:comparison_id ---

pub fn diff_page_renders_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(_) =
    legislation_repo.insert(connection, sample_federal_legislation())
  let assert Ok(_) =
    legislation_repo.insert(connection, sample_state_legislation())

  let response =
    simulate.request(http.Get, "/legislation/sim-fed-001/diff/sim-state-001")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("Legislation Comparison") |> should.be_true
  body |> string.contains("Clean Air Standards Act") |> should.be_true
  body
  |> string.contains("California Clean Air Standards Act")
  |> should.be_true
  body |> string.contains("diff-view") |> should.be_true
  body |> string.contains("diff-content") |> should.be_true
}

pub fn diff_page_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(_) =
    legislation_repo.insert(connection, sample_federal_legislation())

  let response =
    simulate.request(http.Get, "/legislation/sim-fed-001/diff/nonexistent")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

pub fn diff_page_both_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/legislation/nonexistent-a/diff/nonexistent-b")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

// --- POST /api/similarity/compute ---

pub fn api_compute_similarities_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(_) =
    legislation_repo.insert(connection, sample_federal_legislation())
  let assert Ok(_) =
    legislation_repo.insert(connection, sample_state_legislation())

  let response =
    simulate.request(http.Post, "/api/similarity/compute")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("legislation_pairs_stored") |> should.be_true
  body |> string.contains("template_matches_stored") |> should.be_true
}

pub fn api_compute_similarities_get_not_allowed_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/similarity/compute")
    |> router.handle_request(context)

  response.status |> should.equal(405)
}
