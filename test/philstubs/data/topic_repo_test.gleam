import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import philstubs/core/government_level.{Federal, Municipal, State}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/core/topic
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

// --- Insert and retrieval tests ---

pub fn insert_and_get_by_id_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let test_topic =
    topic.Topic(
      id: topic.topic_id("test-topic"),
      name: "Test Topic",
      slug: "test-topic",
      description: "A test topic",
      parent_id: None,
      display_order: 1,
    )

  let assert Ok(Nil) = topic_repo.insert(connection, test_topic)

  let assert Ok(Some(retrieved)) =
    topic_repo.get_by_id(connection, topic.topic_id("test-topic"))
  retrieved.name |> should.equal("Test Topic")
  retrieved.slug |> should.equal("test-topic")
}

pub fn get_by_id_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(result) =
    topic_repo.get_by_id(connection, topic.topic_id("nonexistent"))
  result |> should.equal(None)
}

pub fn get_by_slug_test() {
  setup_with_taxonomy(fn(connection) {
    let assert Ok(Some(housing)) = topic_repo.get_by_slug(connection, "housing")
    housing.name |> should.equal("Housing")
  })
}

// --- Hierarchy tests ---

pub fn list_parent_topics_test() {
  setup_with_taxonomy(fn(connection) {
    let assert Ok(parents) = topic_repo.list_parent_topics(connection)
    parents |> list.length |> should.equal(9)

    // Verify ordering
    let first_parent = list.first(parents)
    let assert Ok(first) = first_parent
    first.name |> should.equal("Civil Rights")
  })
}

pub fn list_children_test() {
  setup_with_taxonomy(fn(connection) {
    let assert Ok(Some(housing)) = topic_repo.get_by_slug(connection, "housing")
    let assert Ok(children) = topic_repo.list_children(connection, housing.id)
    children |> list.length |> should.equal(3)

    let child_names = list.map(children, fn(child) { child.name })
    child_names |> list.contains("Zoning") |> should.be_true
    child_names |> list.contains("Affordable Housing") |> should.be_true
    child_names |> list.contains("Tenant Rights") |> should.be_true
  })
}

pub fn list_topic_tree_test() {
  setup_with_taxonomy(fn(connection) {
    let assert Ok(tree) = topic_repo.list_topic_tree(connection)
    tree |> list.length |> should.equal(9)

    // Each parent should have 3 children
    list.each(tree, fn(node) { node.children |> list.length |> should.equal(3) })
  })
}

// --- Assignment tests ---

pub fn assign_and_get_legislation_topics_test() {
  setup_with_taxonomy(fn(connection) {
    // Insert a legislation record
    let legislation_record = sample_federal_bill()
    let assert Ok(Nil) = legislation_repo.insert(connection, legislation_record)

    // Assign topics
    let assert Ok(Nil) =
      topic_repo.assign_legislation_topic(
        connection,
        "topic-test-fed-001",
        topic.topic_id("housing"),
        topic.Manual,
      )
    let assert Ok(Nil) =
      topic_repo.assign_legislation_topic(
        connection,
        "topic-test-fed-001",
        topic.topic_id("zoning"),
        topic.AutoKeyword,
      )

    let assert Ok(assigned_topics) =
      topic_repo.get_legislation_topics(connection, "topic-test-fed-001")
    assigned_topics |> list.length |> should.equal(2)
  })
}

pub fn assign_legislation_topic_idempotent_test() {
  setup_with_taxonomy(fn(connection) {
    let assert Ok(Nil) =
      legislation_repo.insert(connection, sample_federal_bill())

    // Assign same topic twice — should not error
    let assert Ok(Nil) =
      topic_repo.assign_legislation_topic(
        connection,
        "topic-test-fed-001",
        topic.topic_id("housing"),
        topic.Manual,
      )
    let assert Ok(Nil) =
      topic_repo.assign_legislation_topic(
        connection,
        "topic-test-fed-001",
        topic.topic_id("housing"),
        topic.AutoKeyword,
      )

    let assert Ok(topics) =
      topic_repo.get_legislation_topics(connection, "topic-test-fed-001")
    topics |> list.length |> should.equal(1)
  })
}

pub fn remove_legislation_topic_test() {
  setup_with_taxonomy(fn(connection) {
    let assert Ok(Nil) =
      legislation_repo.insert(connection, sample_federal_bill())

    let assert Ok(Nil) =
      topic_repo.assign_legislation_topic(
        connection,
        "topic-test-fed-001",
        topic.topic_id("housing"),
        topic.Manual,
      )
    let assert Ok(Nil) =
      topic_repo.remove_legislation_topic(
        connection,
        "topic-test-fed-001",
        topic.topic_id("housing"),
      )

    let assert Ok(topics) =
      topic_repo.get_legislation_topics(connection, "topic-test-fed-001")
    topics |> list.length |> should.equal(0)
  })
}

pub fn assign_and_get_template_topics_test() {
  setup_with_taxonomy(fn(connection) {
    // Insert a template
    let assert Ok(Nil) =
      sqlight.query(
        "INSERT INTO legislation_templates (id, title, body, author) VALUES (?, ?, ?, ?)",
        on: connection,
        with: [
          sqlight.text("tmpl-test-001"),
          sqlight.text("Test Template"),
          sqlight.text("Body text"),
          sqlight.text("Author"),
        ],
        expecting: decode.success(Nil),
      )
      |> result.replace(Nil)

    let assert Ok(Nil) =
      topic_repo.assign_template_topic(
        connection,
        "tmpl-test-001",
        topic.topic_id("education"),
        topic.Manual,
      )

    let assert Ok(template_topics) =
      topic_repo.get_template_topics(connection, "tmpl-test-001")
    template_topics |> list.length |> should.equal(1)

    let assert Ok(first) = list.first(template_topics)
    first.name |> should.equal("Education")
  })
}

// --- Aggregation and search tests ---

pub fn count_legislation_by_topic_test() {
  setup_with_taxonomy(fn(connection) {
    // Insert legislation and assign topics
    let assert Ok(Nil) =
      legislation_repo.insert(connection, sample_federal_bill())
    let assert Ok(Nil) =
      topic_repo.assign_legislation_topic(
        connection,
        "topic-test-fed-001",
        topic.topic_id("zoning"),
        topic.AutoKeyword,
      )

    let assert Ok(counts) = topic_repo.count_legislation_by_topic(connection)

    // Housing parent should have count >= 1 (from zoning child)
    let housing_count =
      list.find(counts, fn(twc) { twc.topic.slug == "housing" })
    let assert Ok(found) = housing_count
    found.legislation_count |> should.equal(1)
  })
}

pub fn cross_level_summary_test() {
  setup_with_taxonomy(fn(connection) {
    let assert Ok(Nil) =
      legislation_repo.insert(connection, sample_federal_bill())
    let assert Ok(Nil) =
      legislation_repo.insert(connection, sample_state_bill())
    let assert Ok(Nil) =
      legislation_repo.insert(connection, sample_municipal_ordinance())

    let assert Ok(Nil) =
      topic_repo.assign_legislation_topic(
        connection,
        "topic-test-fed-001",
        topic.topic_id("housing"),
        topic.Manual,
      )
    let assert Ok(Nil) =
      topic_repo.assign_legislation_topic(
        connection,
        "topic-test-state-001",
        topic.topic_id("housing"),
        topic.Manual,
      )
    let assert Ok(Nil) =
      topic_repo.assign_legislation_topic(
        connection,
        "topic-test-muni-001",
        topic.topic_id("zoning"),
        topic.Manual,
      )

    let assert Ok(Some(summary)) =
      topic_repo.get_cross_level_summary(connection, "housing")
    summary.federal_count |> should.equal(1)
    summary.state_count |> should.equal(1)
    summary.municipal_count |> should.equal(1)
  })
}

pub fn cross_level_summary_not_found_test() {
  setup_with_taxonomy(fn(connection) {
    let assert Ok(None) =
      topic_repo.get_cross_level_summary(connection, "nonexistent")
    Nil
  })
}

pub fn search_topics_test() {
  setup_with_taxonomy(fn(connection) {
    let assert Ok(results) = topic_repo.search_topics(connection, "Hou", 10)
    results |> list.length |> should.equal(1)

    let assert Ok(first) = list.first(results)
    first.name |> should.equal("Housing")
  })
}

pub fn search_topics_returns_multiple_test() {
  setup_with_taxonomy(fn(connection) {
    let assert Ok(results) = topic_repo.search_topics(connection, "Public", 10)
    // "Public Health", "Public Safety", "Public Transit"
    results |> list.length |> should.equal(3)
  })
}

pub fn get_topic_keywords_test() {
  setup_with_taxonomy(fn(connection) {
    let assert Ok(keywords) =
      topic_repo.get_topic_keywords(connection, topic.topic_id("housing"))
    keywords |> list.contains("housing") |> should.be_true
    keywords |> list.contains("rent") |> should.be_true
  })
}

pub fn list_all_topics_with_keywords_test() {
  setup_with_taxonomy(fn(connection) {
    let assert Ok(topic_keywords) =
      topic_repo.list_all_topics_with_keywords(connection)
    // Should have entries for all topics that have keywords
    topic_keywords |> list.length |> should.not_equal(0)
  })
}

pub fn list_legislation_for_topic_test() {
  setup_with_taxonomy(fn(connection) {
    let assert Ok(Nil) =
      legislation_repo.insert(connection, sample_federal_bill())
    let assert Ok(Nil) =
      topic_repo.assign_legislation_topic(
        connection,
        "topic-test-fed-001",
        topic.topic_id("housing"),
        topic.Manual,
      )

    let assert Ok(legislation_list) =
      topic_repo.list_legislation_for_topic(connection, "housing", 20, 0)
    legislation_list |> list.length |> should.equal(1)

    let assert Ok(first) = list.first(legislation_list)
    first.title |> should.equal("Housing Reform Act")
  })
}

// --- Sample data helpers ---

import gleam/dynamic/decode
import gleam/result

fn sample_federal_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("topic-test-fed-001"),
    title: "Housing Reform Act",
    summary: "Federal housing legislation.",
    body: "SECTION 1. Housing.",
    level: Federal,
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-01-15",
    source_url: None,
    source_identifier: "H.R. 100",
    sponsors: [],
    topics: ["housing"],
  )
}

fn sample_state_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("topic-test-state-001"),
    title: "CA Zoning Reform",
    summary: "State zoning legislation.",
    body: "SECTION 1. Zoning.",
    level: State(state_code: "CA"),
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-02-15",
    source_url: None,
    source_identifier: "AB 200",
    sponsors: [],
    topics: ["zoning"],
  )
}

fn sample_municipal_ordinance() -> Legislation {
  Legislation(
    id: legislation.legislation_id("topic-test-muni-001"),
    title: "Seattle Affordable Housing Ordinance",
    summary: "Municipal housing ordinance.",
    body: "SECTION 1. Affordable housing.",
    level: Municipal(state_code: "WA", municipality_name: "Seattle"),
    legislation_type: legislation_type.Ordinance,
    status: legislation_status.Enacted,
    introduced_date: "2024-03-15",
    source_url: None,
    source_identifier: "ORD-SEA-100",
    sponsors: [],
    topics: ["housing", "zoning"],
  )
}
