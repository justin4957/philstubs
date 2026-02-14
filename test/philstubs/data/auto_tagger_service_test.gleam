import gleam/list
import gleam/option.{None}
import gleeunit/should
import philstubs/core/government_level.{Federal}
import philstubs/core/legislation.{Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/data/auto_tagger_service
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/test_helpers
import philstubs/data/topic_repo
import philstubs/data/topic_seed

fn setup_with_taxonomy(callback: fn(sqlight.Connection) -> Nil) -> Nil {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let assert Ok(_) = topic_seed.seed_topic_taxonomy(connection)
  callback(connection)
}

import sqlight

pub fn auto_tag_legislation_single_test() {
  setup_with_taxonomy(fn(connection) {
    let housing_bill =
      Legislation(
        id: legislation.legislation_id("autotag-001"),
        title: "Affordable Housing Act",
        summary: "A bill about housing and rent affordability",
        body: "SECTION 1.",
        level: Federal,
        legislation_type: legislation_type.Bill,
        status: legislation_status.Introduced,
        introduced_date: "2024-01-15",
        source_url: None,
        source_identifier: "H.R. 500",
        sponsors: [],
        topics: [],
      )
    let assert Ok(Nil) = legislation_repo.insert(connection, housing_bill)

    let assert Ok(assigned_ids) =
      auto_tagger_service.auto_tag_legislation(
        connection,
        "autotag-001",
        "Affordable Housing Act",
        "A bill about housing and rent affordability",
      )

    // Should match housing-related topics
    assigned_ids |> list.length |> should.not_equal(0)
    assigned_ids |> list.contains("housing") |> should.be_true
  })
}

pub fn auto_tag_legislation_no_match_test() {
  setup_with_taxonomy(fn(connection) {
    let unrelated_bill =
      Legislation(
        id: legislation.legislation_id("autotag-002"),
        title: "Naming of Post Office Act",
        summary: "Designates a post office in Springfield",
        body: "SECTION 1.",
        level: Federal,
        legislation_type: legislation_type.Bill,
        status: legislation_status.Introduced,
        introduced_date: "2024-01-15",
        source_url: None,
        source_identifier: "H.R. 501",
        sponsors: [],
        topics: [],
      )
    let assert Ok(Nil) = legislation_repo.insert(connection, unrelated_bill)

    let assert Ok(assigned_ids) =
      auto_tagger_service.auto_tag_legislation(
        connection,
        "autotag-002",
        "Naming of Post Office Act",
        "Designates a post office in Springfield",
      )

    assigned_ids |> list.length |> should.equal(0)
  })
}

pub fn auto_tag_all_untagged_test() {
  setup_with_taxonomy(fn(connection) {
    // Insert two legislation records without topic assignments
    let housing_bill =
      Legislation(
        id: legislation.legislation_id("bulk-001"),
        title: "Climate Emissions Control Act",
        summary: "Reducing greenhouse emissions",
        body: "SECTION 1.",
        level: Federal,
        legislation_type: legislation_type.Bill,
        status: legislation_status.Introduced,
        introduced_date: "2024-01-15",
        source_url: None,
        source_identifier: "H.R. 600",
        sponsors: [],
        topics: [],
      )
    let assert Ok(Nil) = legislation_repo.insert(connection, housing_bill)

    let assert Ok(tagged_count) =
      auto_tagger_service.auto_tag_all_untagged(connection)

    // Should tag at least one record
    tagged_count |> should.equal(1)

    // Verify topics were assigned
    let assert Ok(assigned_topics) =
      topic_repo.get_legislation_topics(connection, "bulk-001")
    assigned_topics |> list.length |> should.not_equal(0)
  })
}

pub fn backfill_from_json_topics_test() {
  setup_with_taxonomy(fn(connection) {
    // Insert legislation with JSON topics that match taxonomy
    let legislation_record =
      Legislation(
        id: legislation.legislation_id("backfill-001"),
        title: "Test Bill",
        summary: "Test",
        body: "SECTION 1.",
        level: Federal,
        legislation_type: legislation_type.Bill,
        status: legislation_status.Introduced,
        introduced_date: "2024-01-15",
        source_url: None,
        source_identifier: "H.R. 700",
        sponsors: [],
        topics: ["Housing", "Education"],
      )
    let assert Ok(Nil) = legislation_repo.insert(connection, legislation_record)

    let assert Ok(backfill_count) =
      auto_tagger_service.backfill_from_json_topics(connection)

    // Should match "Housing" and "Education" from taxonomy
    backfill_count |> should.equal(2)
  })
}
