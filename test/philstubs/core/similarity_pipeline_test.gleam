import gleam/option.{None}
import gleeunit/should
import philstubs/core/government_level.{Federal, State}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_template.{
  type LegislationTemplate, LegislationTemplate,
}
import philstubs/core/legislation_type
import philstubs/core/similarity_pipeline
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/similarity_repo
import philstubs/data/template_repo
import philstubs/data/test_helpers

fn similar_legislation_a() -> Legislation {
  Legislation(
    id: legislation.legislation_id("pipeline-fed-001"),
    title: "AN ACT to establish standards for environmental protection and regulate emissions from industrial facilities",
    summary: "Environmental standards",
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

fn similar_legislation_b() -> Legislation {
  Legislation(
    id: legislation.legislation_id("pipeline-state-001"),
    title: "AN ACT to establish standards for environmental protection and regulate emissions from industrial facilities in California",
    summary: "California environmental standards",
    body: "AN ACT to establish standards for environmental protection and regulate emissions from industrial facilities in the state of California",
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

fn different_legislation_c() -> Legislation {
  Legislation(
    id: legislation.legislation_id("pipeline-state-002"),
    title: "AN ACT concerning water rights and agricultural irrigation requirements",
    summary: "Water rights",
    body: "AN ACT concerning water rights and agricultural irrigation requirements for farms and ranches across the state",
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

fn matching_template() -> LegislationTemplate {
  LegislationTemplate(
    id: legislation_template.template_id("tmpl-pipeline-001"),
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

pub fn compute_similarities_for_stores_results_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) =
    legislation_repo.insert(connection, similar_legislation_a())
  let assert Ok(_) =
    legislation_repo.insert(connection, similar_legislation_b())
  let assert Ok(_) =
    legislation_repo.insert(connection, different_legislation_c())

  let assert Ok(stored_count) =
    similarity_pipeline.compute_similarities_for(
      connection,
      "pipeline-fed-001",
      0.3,
    )

  // A and B are very similar so should be stored; A and C are different
  let assert True = stored_count >= 1
}

pub fn compute_similarities_skips_low_scores_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) =
    legislation_repo.insert(connection, similar_legislation_a())
  let assert Ok(_) =
    legislation_repo.insert(connection, different_legislation_c())

  let assert Ok(stored_count) =
    similarity_pipeline.compute_similarities_for(
      connection,
      "pipeline-fed-001",
      0.8,
    )

  // A and C are very different, with high threshold nothing should be stored
  stored_count |> should.equal(0)
}

pub fn compute_all_similarities_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) =
    legislation_repo.insert(connection, similar_legislation_a())
  let assert Ok(_) =
    legislation_repo.insert(connection, similar_legislation_b())
  let assert Ok(_) =
    legislation_repo.insert(connection, different_legislation_c())

  let assert Ok(stored_count) =
    similarity_pipeline.compute_all_similarities(connection, 0.3)

  // At least the A-B pair should be stored
  let assert True = stored_count >= 1

  // Verify results can be queried
  let assert Ok(similar_to_a) =
    similarity_repo.find_similar(connection, "pipeline-fed-001", 0.3, 10)
  let assert True = similar_to_a != []
}

pub fn compute_template_matches_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) =
    legislation_repo.insert(connection, similar_legislation_a())
  let assert Ok(_) =
    legislation_repo.insert(connection, different_legislation_c())
  let assert Ok(_) = template_repo.insert(connection, matching_template())

  let assert Ok(stored_count) =
    similarity_pipeline.compute_template_matches(connection, 0.3)

  // Template matches A (very similar) and possibly not C (very different)
  let assert True = stored_count >= 1

  let assert Ok(matches) =
    similarity_repo.find_template_matches(
      connection,
      "tmpl-pipeline-001",
      0.3,
      10,
    )
  let assert True = matches != []
}

pub fn compute_similarities_for_nonexistent_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(stored_count) =
    similarity_pipeline.compute_similarities_for(
      connection,
      "nonexistent-id",
      0.3,
    )

  stored_count |> should.equal(0)
}
