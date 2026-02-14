import gleam/http
import gleam/option.{None, Some}
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

// --- GET /api/legislation/:id/impact ---

pub fn impact_endpoint_returns_200_with_empty_graph_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "leg-001", "Test Bill")

  let response =
    simulate.request(http.Get, "/api/legislation/leg-001/impact")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("root_legislation_id") |> should.be_true
  body |> string.contains("leg-001") |> should.be_true
  body |> string.contains("\"nodes\":[]") |> should.be_true
  body |> string.contains("\"total_nodes\":0") |> should.be_true
}

pub fn impact_endpoint_returns_direct_impacts_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "leg-A", "Bill A")
  insert_test_legislation(connection, "leg-B", "Bill B")
  insert_resolved_reference(connection, "leg-A", "leg-B")

  let response =
    simulate.request(http.Get, "/api/legislation/leg-A/impact")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("leg-B") |> should.be_true
  body |> string.contains("Bill B") |> should.be_true
  body |> string.contains("direct") |> should.be_true
}

pub fn impact_endpoint_respects_direction_param_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "leg-A", "Bill A")
  insert_test_legislation(connection, "leg-B", "Bill B")
  insert_resolved_reference(connection, "leg-A", "leg-B")

  // Outgoing from A should find B
  let outgoing_response =
    simulate.request(
      http.Get,
      "/api/legislation/leg-A/impact?direction=outgoing",
    )
    |> router.handle_request(context)

  outgoing_response.status |> should.equal(200)
  let outgoing_body = simulate.read_body(outgoing_response)
  outgoing_body |> string.contains("leg-B") |> should.be_true
  outgoing_body
  |> string.contains("\"direction\":\"outgoing\"")
  |> should.be_true

  // Incoming to A should not find B (B is a target, not a source pointing to A)
  let incoming_response =
    simulate.request(
      http.Get,
      "/api/legislation/leg-A/impact?direction=incoming",
    )
    |> router.handle_request(context)

  incoming_response.status |> should.equal(200)
  let incoming_body = simulate.read_body(incoming_response)
  incoming_body |> string.contains("\"nodes\":[]") |> should.be_true
}

pub fn impact_endpoint_respects_max_depth_param_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "leg-A", "Bill A")
  insert_test_legislation(connection, "leg-B", "Bill B")
  insert_test_legislation(connection, "leg-C", "Bill C")
  insert_resolved_reference(connection, "leg-A", "leg-B")
  insert_resolved_reference(connection, "leg-B", "leg-C")

  // max_depth=1 should only find B, not C
  let response =
    simulate.request(
      http.Get,
      "/api/legislation/leg-A/impact?direction=outgoing&max_depth=1",
    )
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("leg-B") |> should.be_true
  body |> string.contains("leg-C") |> should.be_false
  body |> string.contains("\"max_depth\":1") |> should.be_true
}

pub fn impact_endpoint_defaults_to_both_and_depth_3_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "leg-001", "Test Bill")

  let response =
    simulate.request(http.Get, "/api/legislation/leg-001/impact")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"direction\":\"both\"") |> should.be_true
  body |> string.contains("\"max_depth\":3") |> should.be_true
}

pub fn impact_endpoint_invalid_direction_defaults_to_both_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  insert_test_legislation(connection, "leg-001", "Test Bill")

  let response =
    simulate.request(
      http.Get,
      "/api/legislation/leg-001/impact?direction=invalid",
    )
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"direction\":\"both\"") |> should.be_true
}
