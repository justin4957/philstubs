import gleam/dict
import gleam/list
import gleam/option.{None}
import gleeunit/should
import philstubs/core/government_level
import philstubs/core/legislation.{Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/core/reference
import philstubs/data/database
import philstubs/data/impact_repo
import philstubs/data/legislation_repo
import philstubs/data/reference_repo
import philstubs/data/test_helpers
import sqlight

fn insert_test_legislation(
  connection: sqlight.Connection,
  legislation_id: String,
  title: String,
  level: government_level.GovernmentLevel,
  legislation_type: legislation_type.LegislationType,
) -> Nil {
  let record =
    Legislation(
      id: legislation.legislation_id(legislation_id),
      title:,
      summary: "",
      body: "Test body",
      level:,
      legislation_type:,
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
  reference_type: reference.ReferenceType,
) -> Nil {
  let ref =
    reference.CrossReference(
      id: reference.reference_id(source_id <> ":" <> target_id),
      source_legislation_id: source_id,
      target_legislation_id: option.Some(target_id),
      citation_text: source_id <> " cites " <> target_id,
      reference_type:,
      confidence: 0.95,
      extractor: reference.GleamNative,
      extracted_at: "2026-01-01T00:00:00",
    )
  let assert Ok(_) = reference_repo.insert_reference(connection, ref)
  Nil
}

// --- load_dependency_graph ---

pub fn empty_graph_from_empty_db_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(graph) = impact_repo.load_dependency_graph(connection)

  graph.outgoing |> dict.size |> should.equal(0)
  graph.incoming |> dict.size |> should.equal(0)
}

pub fn resolved_references_appear_in_graph_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  insert_test_legislation(
    connection,
    "leg-A",
    "Bill A",
    government_level.Federal,
    legislation_type.Bill,
  )
  insert_test_legislation(
    connection,
    "leg-B",
    "Bill B",
    government_level.Federal,
    legislation_type.Bill,
  )
  insert_resolved_reference(connection, "leg-A", "leg-B", reference.Implements)

  let assert Ok(graph) = impact_repo.load_dependency_graph(connection)

  // Outgoing: A -> B
  let assert Ok(outgoing_edges) = dict.get(graph.outgoing, "leg-A")
  outgoing_edges |> list.length |> should.equal(1)
  let assert Ok(first_outgoing) = list.first(outgoing_edges)
  first_outgoing.target_id |> should.equal("leg-B")

  // Incoming: B -> A (reversed)
  let assert Ok(incoming_edges) = dict.get(graph.incoming, "leg-B")
  incoming_edges |> list.length |> should.equal(1)
  let assert Ok(first_incoming) = list.first(incoming_edges)
  first_incoming.target_id |> should.equal("leg-A")
}

pub fn unresolved_references_excluded_from_graph_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  insert_test_legislation(
    connection,
    "leg-A",
    "Bill A",
    government_level.Federal,
    legislation_type.Bill,
  )

  // Insert unresolved reference (target_legislation_id is NULL)
  let ref =
    reference.CrossReference(
      id: reference.reference_id("unresolved-ref"),
      source_legislation_id: "leg-A",
      target_legislation_id: None,
      citation_text: "some citation",
      reference_type: reference.References,
      confidence: 0.5,
      extractor: reference.GleamNative,
      extracted_at: "2026-01-01T00:00:00",
    )
  let assert Ok(_) = reference_repo.insert_reference(connection, ref)

  let assert Ok(graph) = impact_repo.load_dependency_graph(connection)
  graph.outgoing |> dict.size |> should.equal(0)
  graph.incoming |> dict.size |> should.equal(0)
}

// --- load_legislation_metadata ---

pub fn metadata_loading_with_government_levels_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  insert_test_legislation(
    connection,
    "fed-1",
    "Federal Act",
    government_level.Federal,
    legislation_type.Bill,
  )
  insert_test_legislation(
    connection,
    "state-1",
    "State Bill",
    government_level.State("NY"),
    legislation_type.Resolution,
  )
  insert_test_legislation(
    connection,
    "county-1",
    "County Ordinance",
    government_level.County("IL", "Cook"),
    legislation_type.Ordinance,
  )
  insert_test_legislation(
    connection,
    "muni-1",
    "City Bylaw",
    government_level.Municipal("TX", "Austin"),
    legislation_type.Bylaw,
  )

  let assert Ok(metadata) = impact_repo.load_legislation_metadata(connection)

  metadata |> dict.size |> should.equal(4)

  let assert Ok(federal_summary) = dict.get(metadata, "fed-1")
  federal_summary.title |> should.equal("Federal Act")
  federal_summary.level |> should.equal(government_level.Federal)
  federal_summary.legislation_type |> should.equal(legislation_type.Bill)

  let assert Ok(state_summary) = dict.get(metadata, "state-1")
  state_summary.level |> should.equal(government_level.State("NY"))
  state_summary.legislation_type |> should.equal(legislation_type.Resolution)

  let assert Ok(county_summary) = dict.get(metadata, "county-1")
  county_summary.level |> should.equal(government_level.County("IL", "Cook"))

  let assert Ok(municipal_summary) = dict.get(metadata, "muni-1")
  municipal_summary.level
  |> should.equal(government_level.Municipal("TX", "Austin"))
}

pub fn empty_metadata_from_empty_db_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(metadata) = impact_repo.load_legislation_metadata(connection)

  metadata |> dict.size |> should.equal(0)
}
