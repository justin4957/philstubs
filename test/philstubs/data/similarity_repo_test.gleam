import gleam/list
import gleam/option.{None}
import gleeunit/should
import philstubs/core/government_level.{Federal, State}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_template.{
  type LegislationTemplate, LegislationTemplate,
}
import philstubs/core/legislation_type
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/similarity_repo
import philstubs/data/template_repo
import philstubs/data/test_helpers

fn sample_legislation_a() -> Legislation {
  Legislation(
    id: legislation.legislation_id("leg-fed-001"),
    title: "AN ACT to establish standards for environmental protection and regulate emissions from industrial facilities",
    summary: "Establishes environmental standards",
    body: "AN ACT to establish standards for environmental protection and regulate emissions from industrial facilities",
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

fn sample_legislation_b() -> Legislation {
  Legislation(
    id: legislation.legislation_id("leg-state-001"),
    title: "AN ACT to establish standards for environmental protection and regulate emissions from industrial facilities in California",
    summary: "California environmental standards",
    body: "AN ACT to establish standards for environmental protection and regulate emissions from industrial facilities in California",
    level: State("CA"),
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-03-20",
    source_url: None,
    source_identifier: "SB 200",
    sponsors: [],
    topics: ["environment", "emissions", "california"],
  )
}

fn sample_legislation_c() -> Legislation {
  Legislation(
    id: legislation.legislation_id("leg-state-002"),
    title: "AN ACT concerning water rights and agricultural irrigation",
    summary: "Water rights",
    body: "AN ACT concerning water rights and agricultural irrigation",
    level: State("TX"),
    legislation_type: legislation_type.Bill,
    status: legislation_status.Enacted,
    introduced_date: "2024-06-01",
    source_url: None,
    source_identifier: "SB 300",
    sponsors: [],
    topics: ["water", "agriculture"],
  )
}

fn sample_template() -> LegislationTemplate {
  LegislationTemplate(
    id: legislation_template.template_id("tmpl-env-001"),
    title: "Environmental Protection Standards Template",
    description: "Model legislation for environmental standards",
    body: "AN ACT to establish standards for environmental protection and regulate emissions from industrial facilities",
    suggested_level: Federal,
    suggested_type: legislation_type.Bill,
    author: "Policy Group",
    topics: ["environment", "emissions"],
    created_at: "2024-01-01",
    download_count: 0,
    owner_user_id: None,
  )
}

pub fn store_and_find_similar_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_a())
  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_b())

  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-fed-001",
      "leg-state-001",
      0.87,
      0.92,
      0.85,
      0.9,
    )

  let assert Ok(results) =
    similarity_repo.find_similar(connection, "leg-fed-001", 0.0, 10)
  results |> list.length |> should.equal(1)

  let assert [similar_record] = results
  similar_record.similarity_score |> should.equal(0.87)
  similar_record.title_score |> should.equal(0.92)
  similar_record.body_score |> should.equal(0.85)
  similar_record.topic_score |> should.equal(0.9)
  similar_record.legislation.title
  |> should.equal(
    "AN ACT to establish standards for environmental protection and regulate emissions from industrial facilities in California",
  )
}

pub fn find_similar_respects_min_score_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_a())
  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_b())
  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_c())

  // Store high similarity for A-B and low for A-C
  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-fed-001",
      "leg-state-001",
      0.87,
      0.9,
      0.85,
      0.9,
    )
  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-fed-001",
      "leg-state-002",
      0.15,
      0.1,
      0.12,
      0.0,
    )

  // Query with min_score 0.5 — should only return B
  let assert Ok(results) =
    similarity_repo.find_similar(connection, "leg-fed-001", 0.5, 10)
  results |> list.length |> should.equal(1)
}

pub fn find_similar_orders_by_score_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_a())
  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_b())
  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_c())

  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-fed-001",
      "leg-state-001",
      0.6,
      0.7,
      0.5,
      0.6,
    )
  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-fed-001",
      "leg-state-002",
      0.8,
      0.8,
      0.8,
      0.8,
    )

  let assert Ok(results) =
    similarity_repo.find_similar(connection, "leg-fed-001", 0.0, 10)
  results |> list.length |> should.equal(2)

  let assert [first, second] = results
  // Higher score should come first
  let assert True = first.similarity_score >=. second.similarity_score
}

pub fn find_similar_limits_results_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_a())
  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_b())
  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_c())

  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-fed-001",
      "leg-state-001",
      0.87,
      0.9,
      0.85,
      0.9,
    )
  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-fed-001",
      "leg-state-002",
      0.6,
      0.6,
      0.6,
      0.6,
    )

  // Limit to 1 result
  let assert Ok(results) =
    similarity_repo.find_similar(connection, "leg-fed-001", 0.0, 1)
  results |> list.length |> should.equal(1)
}

pub fn find_similar_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(results) =
    similarity_repo.find_similar(connection, "nonexistent", 0.0, 10)
  results |> should.equal([])
}

pub fn store_template_match_and_find_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_a())
  let assert Ok(_) = template_repo.insert(connection, sample_template())

  let assert Ok(_) =
    similarity_repo.store_template_match(
      connection,
      "tmpl-env-001",
      "leg-fed-001",
      0.92,
      0.95,
      0.9,
      0.88,
    )

  let assert Ok(results) =
    similarity_repo.find_template_matches(connection, "tmpl-env-001", 0.0, 10)
  results |> list.length |> should.equal(1)

  let assert [template_match] = results
  template_match.similarity_score |> should.equal(0.92)
  template_match.legislation.title
  |> should.equal(
    "AN ACT to establish standards for environmental protection and regulate emissions from industrial facilities",
  )
}

pub fn adoption_timeline_ordered_by_date_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_a())
  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_b())
  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_c())

  // Store similarities from A to B and C
  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-fed-001",
      "leg-state-001",
      0.87,
      0.9,
      0.85,
      0.9,
    )
  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-fed-001",
      "leg-state-002",
      0.6,
      0.6,
      0.6,
      0.6,
    )

  let assert Ok(timeline) =
    similarity_repo.adoption_timeline(connection, "leg-fed-001", 0.0)
  timeline |> list.length |> should.equal(2)

  // Should be ordered by introduced_date ascending
  let assert [first_event, second_event] = timeline
  // B is 2024-03-20, C is 2024-06-01
  first_event.introduced_date |> should.equal("2024-03-20")
  second_event.introduced_date |> should.equal("2024-06-01")
}

pub fn delete_similarities_for_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_a())
  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_b())

  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-fed-001",
      "leg-state-001",
      0.87,
      0.9,
      0.85,
      0.9,
    )

  // Verify similarity exists
  let assert Ok(before_results) =
    similarity_repo.find_similar(connection, "leg-fed-001", 0.0, 10)
  before_results |> list.length |> should.equal(1)

  // Delete similarities for the legislation
  let assert Ok(_) =
    similarity_repo.delete_similarities_for(connection, "leg-fed-001")

  // Verify no similarities remain
  let assert Ok(after_results) =
    similarity_repo.find_similar(connection, "leg-fed-001", 0.0, 10)
  after_results |> should.equal([])
}

pub fn store_similarity_idempotent_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_a())
  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_b())

  // Store same pair twice with different scores
  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-fed-001",
      "leg-state-001",
      0.5,
      0.5,
      0.5,
      0.5,
    )
  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-fed-001",
      "leg-state-001",
      0.9,
      0.9,
      0.9,
      0.9,
    )

  // Should only have one result with the updated score
  let assert Ok(results) =
    similarity_repo.find_similar(connection, "leg-fed-001", 0.0, 10)
  results |> list.length |> should.equal(1)

  let assert [similar_record] = results
  similar_record.similarity_score |> should.equal(0.9)
}

pub fn count_similarities_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_a())
  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_b())

  let assert Ok(count_before) = similarity_repo.count_similarities(connection)
  count_before |> should.equal(0)

  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-fed-001",
      "leg-state-001",
      0.87,
      0.9,
      0.85,
      0.9,
    )

  let assert Ok(count_after) = similarity_repo.count_similarities(connection)
  // store_similarity stores both directions
  count_after |> should.equal(2)
}

pub fn find_similar_bidirectional_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_a())
  let assert Ok(_) = legislation_repo.insert(connection, sample_legislation_b())

  let assert Ok(_) =
    similarity_repo.store_similarity(
      connection,
      "leg-fed-001",
      "leg-state-001",
      0.87,
      0.9,
      0.85,
      0.9,
    )

  // Should be queryable from either direction
  let assert Ok(forward_results) =
    similarity_repo.find_similar(connection, "leg-fed-001", 0.0, 10)
  forward_results |> list.length |> should.equal(1)

  let assert Ok(reverse_results) =
    similarity_repo.find_similar(connection, "leg-state-001", 0.0, 10)
  reverse_results |> list.length |> should.equal(1)
}
