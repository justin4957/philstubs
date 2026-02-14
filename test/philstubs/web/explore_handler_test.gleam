import gleam/http
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import philstubs/core/government_level
import philstubs/core/legislation.{Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/core/reference
import philstubs/core/topic
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/reference_repo
import philstubs/data/test_helpers
import philstubs/data/topic_repo
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
  let record =
    Legislation(
      id: legislation.legislation_id(legislation_id),
      title:,
      summary: "",
      body: "Test body",
      level: government_level.Federal,
      legislation_type: legislation_type.Bill,
      status: legislation_status.Introduced,
      introduced_date: "2024-01-01",
      source_url: None,
      source_identifier: "TEST",
      sponsors: [],
      topics: [],
    )
  let assert Ok(_) = legislation_repo.insert(connection, record)
  Nil
}

fn insert_resolved_reference(
  connection: sqlight.Connection,
  source_id: String,
  target_id: String,
) -> Nil {
  let ref =
    reference.CrossReference(
      id: reference.reference_id(source_id <> ":" <> target_id),
      source_legislation_id: source_id,
      target_legislation_id: Some(target_id),
      citation_text: source_id <> " references " <> target_id,
      reference_type: reference.References,
      confidence: 0.9,
      extractor: reference.GleamNative,
      extracted_at: "2026-01-01T00:00:00",
    )
  let assert Ok(_) = reference_repo.insert_reference(connection, ref)
  Nil
}

fn insert_test_topic(
  connection: sqlight.Connection,
  topic_id: String,
  name: String,
  slug: String,
) -> Nil {
  let record =
    topic.Topic(
      id: topic.topic_id(topic_id),
      name:,
      slug:,
      description: "",
      parent_id: None,
      display_order: 0,
    )
  let assert Ok(_) = topic_repo.insert(connection, record)
  Nil
}

// --- GET /api/explore/node/:id ---

pub fn explore_node_200_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "leg-001", "Clean Water Act")

  let response =
    simulate.request(http.Get, "/api/explore/node/leg-001")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"node\"") |> should.be_true
  body |> string.contains("Clean Water Act") |> should.be_true
  body |> string.contains("\"edges\"") |> should.be_true
  body |> string.contains("\"neighbors\"") |> should.be_true
}

pub fn explore_node_404_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/explore/node/nonexistent")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

pub fn explore_node_with_edges_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "leg-A", "Bill A")
  insert_test_legislation(connection, "leg-B", "Bill B")
  insert_resolved_reference(connection, "leg-A", "leg-B")

  let response =
    simulate.request(http.Get, "/api/explore/node/leg-A")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("leg-B") |> should.be_true
  body |> string.contains("\"references\"") |> should.be_true
}

// --- GET /api/explore/expand/:id ---

pub fn explore_expand_defaults_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "leg-001", "Test Bill")

  let response =
    simulate.request(http.Get, "/api/explore/expand/leg-001")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"root_id\":\"leg-001\"") |> should.be_true
  body |> string.contains("\"depth\":1") |> should.be_true
}

pub fn explore_expand_filtered_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "leg-A", "Bill A")
  insert_test_legislation(connection, "leg-B", "Bill B")
  insert_resolved_reference(connection, "leg-A", "leg-B")

  let response =
    simulate.request(
      http.Get,
      "/api/explore/expand/leg-A?edge_types=references&depth=1",
    )
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("leg-B") |> should.be_true
}

pub fn explore_expand_depth_clamped_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "leg-001", "Test Bill")

  // depth=10 should be clamped to 3
  let response =
    simulate.request(http.Get, "/api/explore/expand/leg-001?depth=10")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"depth\":3") |> should.be_true
}

// --- GET /api/explore/path/:from/:to ---

pub fn explore_path_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "leg-A", "Bill A")
  insert_test_legislation(connection, "leg-B", "Bill B")
  insert_resolved_reference(connection, "leg-A", "leg-B")

  let response =
    simulate.request(http.Get, "/api/explore/path/leg-A/leg-B")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"from_id\":\"leg-A\"") |> should.be_true
  body |> string.contains("\"to_id\":\"leg-B\"") |> should.be_true
  body |> string.contains("\"distance\":1") |> should.be_true
}

pub fn explore_path_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "leg-A", "Bill A")
  insert_test_legislation(connection, "leg-B", "Bill B")

  let response =
    simulate.request(http.Get, "/api/explore/path/leg-A/leg-B")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"distance\":-1") |> should.be_true
}

// --- GET /api/explore/cluster/:topic_slug ---

pub fn explore_cluster_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "leg-A", "Bill A")
  insert_test_legislation(connection, "leg-B", "Bill B")
  insert_test_topic(connection, "topic-1", "Healthcare", "healthcare")
  let assert Ok(_) =
    topic_repo.assign_legislation_topic(
      connection,
      "leg-A",
      topic.topic_id("topic-1"),
      topic.AutoKeyword,
    )
  let assert Ok(_) =
    topic_repo.assign_legislation_topic(
      connection,
      "leg-B",
      topic.topic_id("topic-1"),
      topic.AutoKeyword,
    )

  let response =
    simulate.request(http.Get, "/api/explore/cluster/healthcare")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"topic_slug\":\"healthcare\"") |> should.be_true
  body |> string.contains("\"topic_name\":\"Healthcare\"") |> should.be_true
}

pub fn explore_cluster_404_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/explore/cluster/nonexistent")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}
