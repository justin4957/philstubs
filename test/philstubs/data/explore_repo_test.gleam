import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import philstubs/core/government_level
import philstubs/core/legislation.{Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/core/reference
import philstubs/core/topic
import philstubs/data/database
import philstubs/data/explore_repo
import philstubs/data/legislation_repo
import philstubs/data/reference_repo
import philstubs/data/similarity_repo
import philstubs/data/test_helpers
import philstubs/data/topic_repo
import sqlight

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

// --- load_node tests ---

pub fn load_node_with_topics_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  insert_test_legislation(connection, "leg-001", "Test Bill")
  insert_test_topic(connection, "topic-1", "Healthcare", "healthcare")
  let assert Ok(_) =
    topic_repo.assign_legislation_topic(
      connection,
      "leg-001",
      topic.topic_id("topic-1"),
      topic.AutoKeyword,
    )

  let assert Ok(Some(#(legislation, topics))) =
    explore_repo.load_node(connection, "leg-001")

  legislation.title |> should.equal("Test Bill")
  list.length(topics) |> should.equal(1)
  let assert [first_topic] = topics
  first_topic.name |> should.equal("Healthcare")
}

pub fn load_node_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(None) = explore_repo.load_node(connection, "nonexistent")
}

// --- load_node_edges tests ---

pub fn load_node_edges_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  insert_test_legislation(connection, "leg-A", "Bill A")
  insert_test_legislation(connection, "leg-B", "Bill B")
  insert_resolved_reference(connection, "leg-A", "leg-B")

  let assert Ok(#(outgoing, _incoming, _similarities)) =
    explore_repo.load_node_edges(connection, "leg-A")

  list.length(outgoing) |> should.equal(1)
}

// --- inter-references tests ---

pub fn load_inter_references_filtered_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  insert_test_legislation(connection, "leg-A", "Bill A")
  insert_test_legislation(connection, "leg-B", "Bill B")
  insert_test_legislation(connection, "leg-C", "Bill C")
  insert_resolved_reference(connection, "leg-A", "leg-B")
  insert_resolved_reference(connection, "leg-A", "leg-C")

  // Only ask for inter-references within {A, B} — should exclude A->C
  let assert Ok(refs) =
    explore_repo.load_inter_references(connection, ["leg-A", "leg-B"])

  list.length(refs) |> should.equal(1)
}

// --- inter-similarities tests ---

pub fn load_inter_similarities_filtered_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  insert_test_legislation(connection, "leg-A", "Bill A")
  insert_test_legislation(connection, "leg-B", "Bill B")
  insert_test_legislation(connection, "leg-C", "Bill C")

  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-A",
      "leg-B",
      0.8,
      0.7,
      0.85,
      0.6,
    )
  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-A",
      "leg-C",
      0.5,
      0.4,
      0.55,
      0.3,
    )

  // Only ask for inter-similarities within {A, B} — should exclude A<->C
  let assert Ok(sims) =
    explore_repo.load_inter_similarities(connection, ["leg-A", "leg-B"], 0.1)

  // Both forward (A->B) and reverse (B->A) stored, but query finds those
  // where source IN set AND target IN set
  list.length(sims) |> should.not_equal(0)
}

// --- similarity adjacency test ---

pub fn load_similarity_adjacency_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  insert_test_legislation(connection, "leg-A", "Bill A")
  insert_test_legislation(connection, "leg-B", "Bill B")

  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-A",
      "leg-B",
      0.8,
      0.7,
      0.85,
      0.6,
    )

  let assert Ok(adjacency) =
    explore_repo.load_similarity_adjacency(connection, 0.1)

  // Should have entries for both directions since store_similarity stores both
  dict.size(adjacency) |> should.not_equal(0)
}
