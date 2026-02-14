import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import philstubs/core/reference
import philstubs/data/reference_repo
import sqlight

fn with_test_db(test_fn: fn(sqlight.Connection) -> Nil) -> Nil {
  let assert Ok(connection) = sqlight.open(":memory:")
  let assert Ok(_) = philstubs_test_helpers.setup_test_db(connection)
  test_fn(connection)
}

import philstubs/data/test_helpers as philstubs_test_helpers

fn sample_reference(
  source_id: String,
  citation: String,
) -> reference.CrossReference {
  reference.CrossReference(
    id: reference.reference_id(source_id <> ":" <> citation),
    source_legislation_id: source_id,
    target_legislation_id: None,
    citation_text: citation,
    reference_type: reference.References,
    confidence: 0.9,
    extractor: reference.GleamNative,
    extracted_at: "2026-01-01T00:00:00",
  )
}

fn sample_reference_with_target(
  source_id: String,
  target_id: String,
  citation: String,
) -> reference.CrossReference {
  reference.CrossReference(
    id: reference.reference_id(source_id <> ":" <> citation),
    source_legislation_id: source_id,
    target_legislation_id: Some(target_id),
    citation_text: citation,
    reference_type: reference.Amends,
    confidence: 0.95,
    extractor: reference.GleamNative,
    extracted_at: "2026-01-01T00:00:00",
  )
}

fn insert_test_legislation(
  connection: sqlight.Connection,
  legislation_id: String,
) -> Nil {
  let assert Ok(_) =
    sqlight.query(
      "INSERT INTO legislation (id, title, body, government_level, legislation_type, status, source_identifier)
       VALUES (?, 'Test Bill', 'Test body', 'federal', 'bill', 'introduced', 'TEST-001')",
      on: connection,
      with: [sqlight.text(legislation_id)],
      expecting: decode.success(Nil),
    )
  Nil
}

pub fn insert_and_find_references_from_test() {
  with_test_db(fn(connection) {
    insert_test_legislation(connection, "leg-001")
    let ref = sample_reference("leg-001", "42 u.s.c. 1983")
    let assert Ok(_) = reference_repo.insert_reference(connection, ref)

    let assert Ok(refs) =
      reference_repo.find_references_from(connection, "leg-001", 10)
    refs |> list.length |> should.equal(1)

    let assert Ok(first) = list.first(refs)
    first.citation_text |> should.equal("42 u.s.c. 1983")
    first.source_legislation_id |> should.equal("leg-001")
  })
}

pub fn insert_and_find_references_to_test() {
  with_test_db(fn(connection) {
    insert_test_legislation(connection, "leg-001")
    insert_test_legislation(connection, "leg-002")
    let ref =
      sample_reference_with_target("leg-001", "leg-002", "42 u.s.c. 1983")
    let assert Ok(_) = reference_repo.insert_reference(connection, ref)

    let assert Ok(incoming_refs) =
      reference_repo.find_references_to(connection, "leg-002", 10)
    incoming_refs |> list.length |> should.equal(1)

    let assert Ok(first) = list.first(incoming_refs)
    first.source_legislation_id |> should.equal("leg-001")
  })
}

pub fn unresolved_citation_has_null_target_test() {
  with_test_db(fn(connection) {
    insert_test_legislation(connection, "leg-001")
    let ref = sample_reference("leg-001", "Pub. L. 117-169")
    let assert Ok(_) = reference_repo.insert_reference(connection, ref)

    let assert Ok(refs) =
      reference_repo.find_references_from(connection, "leg-001", 10)
    let assert Ok(first) = list.first(refs)
    first.target_legislation_id |> should.equal(None)
  })
}

pub fn idempotent_insert_test() {
  with_test_db(fn(connection) {
    insert_test_legislation(connection, "leg-001")
    let ref = sample_reference("leg-001", "42 u.s.c. 1983")
    let assert Ok(_) = reference_repo.insert_reference(connection, ref)
    let assert Ok(_) = reference_repo.insert_reference(connection, ref)

    let assert Ok(count) = reference_repo.count_references(connection)
    count |> should.equal(1)
  })
}

pub fn delete_references_for_test() {
  with_test_db(fn(connection) {
    insert_test_legislation(connection, "leg-001")
    let ref1 = sample_reference("leg-001", "42 u.s.c. 1983")
    let ref2 = sample_reference("leg-001", "26 u.s.c. 501")
    let assert Ok(_) = reference_repo.insert_reference(connection, ref1)
    let assert Ok(_) = reference_repo.insert_reference(connection, ref2)

    let assert Ok(count_before) = reference_repo.count_references(connection)
    count_before |> should.equal(2)

    let assert Ok(_) =
      reference_repo.delete_references_for(connection, "leg-001")

    let assert Ok(count_after) = reference_repo.count_references(connection)
    count_after |> should.equal(0)
  })
}

pub fn count_references_empty_test() {
  with_test_db(fn(connection) {
    let assert Ok(count) = reference_repo.count_references(connection)
    count |> should.equal(0)
  })
}

pub fn insert_and_get_query_map_test() {
  with_test_db(fn(connection) {
    let query_map =
      reference.QueryMap(
        id: reference.query_map_id("qm-001"),
        name: "Find amendments",
        description: "Find all legislation that amends a given statute",
        query_template: "SELECT * FROM legislation_references WHERE reference_type = 'amends' AND source_legislation_id = :id",
        parameters: "{\"id\": \"string\"}",
        created_at: "2026-01-01T00:00:00",
      )
    let assert Ok(_) = reference_repo.insert_query_map(connection, query_map)

    let assert Ok(Some(retrieved)) =
      reference_repo.get_query_map_by_id(connection, "qm-001")
    retrieved.name |> should.equal("Find amendments")
    retrieved.description
    |> should.equal("Find all legislation that amends a given statute")
  })
}

pub fn get_nonexistent_query_map_returns_none_test() {
  with_test_db(fn(connection) {
    let assert Ok(result) =
      reference_repo.get_query_map_by_id(connection, "nonexistent")
    result |> should.equal(None)
  })
}

pub fn list_query_maps_test() {
  with_test_db(fn(connection) {
    let qm1 =
      reference.QueryMap(
        id: reference.query_map_id("qm-001"),
        name: "Alpha query",
        description: "",
        query_template: "SELECT 1",
        parameters: "{}",
        created_at: "2026-01-01T00:00:00",
      )
    let qm2 =
      reference.QueryMap(
        id: reference.query_map_id("qm-002"),
        name: "Beta query",
        description: "",
        query_template: "SELECT 2",
        parameters: "{}",
        created_at: "2026-01-01T00:00:00",
      )
    let assert Ok(_) = reference_repo.insert_query_map(connection, qm1)
    let assert Ok(_) = reference_repo.insert_query_map(connection, qm2)

    let assert Ok(query_maps) = reference_repo.list_query_maps(connection)
    query_maps |> list.length |> should.equal(2)

    // Should be ordered by name ASC
    let assert Ok(first) = list.first(query_maps)
    first.name |> should.equal("Alpha query")
  })
}

pub fn delete_query_map_test() {
  with_test_db(fn(connection) {
    let query_map =
      reference.QueryMap(
        id: reference.query_map_id("qm-001"),
        name: "To be deleted",
        description: "",
        query_template: "SELECT 1",
        parameters: "{}",
        created_at: "2026-01-01T00:00:00",
      )
    let assert Ok(_) = reference_repo.insert_query_map(connection, query_map)
    let assert Ok(_) = reference_repo.delete_query_map(connection, "qm-001")

    let assert Ok(result) =
      reference_repo.get_query_map_by_id(connection, "qm-001")
    result |> should.equal(None)
  })
}
