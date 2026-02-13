import gleam/list
import gleam/option.{None}
import gleeunit/should
import philstubs/core/government_level.{County, Federal, Municipal, State}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/data/browse_repo
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/test_helpers
import sqlight

fn sample_federal_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("browse-fed-001"),
    title: "Federal Test Bill",
    summary: "A federal test bill.",
    body: "SECTION 1. Federal test.",
    level: Federal,
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-01-01",
    source_url: None,
    source_identifier: "H.R. 1",
    sponsors: [],
    topics: ["environment", "energy"],
  )
}

fn sample_ca_state_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("browse-ca-001"),
    title: "California Housing Bill",
    summary: "A CA state bill.",
    body: "SECTION 1. Housing in California.",
    level: State(state_code: "CA"),
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-02-01",
    source_url: None,
    source_identifier: "AB 100",
    sponsors: [],
    topics: ["housing", "zoning"],
  )
}

fn sample_tx_state_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("browse-tx-001"),
    title: "Texas Energy Bill",
    summary: "A TX state bill.",
    body: "SECTION 1. Energy in Texas.",
    level: State(state_code: "TX"),
    legislation_type: legislation_type.Bill,
    status: legislation_status.Enacted,
    introduced_date: "2024-03-01",
    source_url: None,
    source_identifier: "HB 200",
    sponsors: [],
    topics: ["energy", "infrastructure"],
  )
}

fn sample_ca_county_ordinance() -> Legislation {
  Legislation(
    id: legislation.legislation_id("browse-ca-county-001"),
    title: "Los Angeles County Zoning Ordinance",
    summary: "A county ordinance.",
    body: "SECTION 1. Zoning in LA County.",
    level: County(state_code: "CA", county_name: "Los Angeles"),
    legislation_type: legislation_type.Ordinance,
    status: legislation_status.Enacted,
    introduced_date: "2024-04-01",
    source_url: None,
    source_identifier: "ORD-001",
    sponsors: [],
    topics: ["zoning", "land use"],
  )
}

fn sample_ca_municipal_ordinance() -> Legislation {
  Legislation(
    id: legislation.legislation_id("browse-ca-muni-001"),
    title: "San Francisco Rent Control",
    summary: "A municipal ordinance.",
    body: "SECTION 1. Rent control in SF.",
    level: Municipal(state_code: "CA", municipality_name: "San Francisco"),
    legislation_type: legislation_type.Ordinance,
    status: legislation_status.Introduced,
    introduced_date: "2024-05-01",
    source_url: None,
    source_identifier: "ORD-SF-001",
    sponsors: [],
    topics: ["housing", "rent control"],
  )
}

fn sample_wa_municipal_ordinance() -> Legislation {
  Legislation(
    id: legislation.legislation_id("browse-wa-muni-001"),
    title: "Seattle Transit Ordinance",
    summary: "A Seattle ordinance.",
    body: "SECTION 1. Transit in Seattle.",
    level: Municipal(state_code: "WA", municipality_name: "Seattle"),
    legislation_type: legislation_type.Ordinance,
    status: legislation_status.Introduced,
    introduced_date: "2024-06-01",
    source_url: None,
    source_identifier: "ORD-SEA-001",
    sponsors: [],
    topics: ["transit", "infrastructure"],
  )
}

fn insert_all_samples(connection: sqlight.Connection) -> Nil {
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_ca_state_bill())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_tx_state_bill())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_ca_county_ordinance())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_ca_municipal_ordinance())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_wa_municipal_ordinance())
  Nil
}

// --- count_by_government_level tests ---

pub fn count_by_government_level_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  let assert Ok(counts) = browse_repo.count_by_government_level(connection)

  // 1 federal, 2 state, 1 county, 2 municipal
  counts |> list.key_find("federal") |> should.equal(Ok(1))
  counts |> list.key_find("state") |> should.equal(Ok(2))
  counts |> list.key_find("county") |> should.equal(Ok(1))
  counts |> list.key_find("municipal") |> should.equal(Ok(2))
}

pub fn count_by_government_level_empty_db_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(counts) = browse_repo.count_by_government_level(connection)

  counts |> list.length |> should.equal(0)
}

// --- count_by_state tests ---

pub fn count_by_state_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  let assert Ok(state_counts) = browse_repo.count_by_state(connection)

  // CA: 1 state + 1 county + 1 municipal = 3
  // TX: 1 state = 1
  // WA: 1 municipal = 1
  state_counts |> list.key_find("CA") |> should.equal(Ok(3))
  state_counts |> list.key_find("TX") |> should.equal(Ok(1))
  state_counts |> list.key_find("WA") |> should.equal(Ok(1))
}

pub fn count_by_state_alphabetical_order_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  let assert Ok(state_counts) = browse_repo.count_by_state(connection)

  let state_codes = list.map(state_counts, fn(item) { item.0 })
  // Should be alphabetically ordered: CA, TX, WA
  state_codes |> should.equal(["CA", "TX", "WA"])
}

// --- count_counties_in_state tests ---

pub fn count_counties_in_state_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  let assert Ok(county_counts) =
    browse_repo.count_counties_in_state(connection, "CA")

  county_counts |> list.length |> should.equal(1)
  county_counts
  |> list.key_find("Los Angeles")
  |> should.equal(Ok(1))
}

pub fn count_counties_in_state_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  let assert Ok(county_counts) =
    browse_repo.count_counties_in_state(connection, "TX")

  county_counts |> list.length |> should.equal(0)
}

// --- count_municipalities_in_state tests ---

pub fn count_municipalities_in_state_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  let assert Ok(municipal_counts) =
    browse_repo.count_municipalities_in_state(connection, "CA")

  municipal_counts |> list.length |> should.equal(1)
  municipal_counts
  |> list.key_find("San Francisco")
  |> should.equal(Ok(1))
}

pub fn count_municipalities_in_state_different_state_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  let assert Ok(municipal_counts) =
    browse_repo.count_municipalities_in_state(connection, "WA")

  municipal_counts |> list.length |> should.equal(1)
  municipal_counts
  |> list.key_find("Seattle")
  |> should.equal(Ok(1))
}

// --- count_state_legislation tests ---

pub fn count_state_legislation_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  let assert Ok(count) = browse_repo.count_state_legislation(connection, "CA")
  count |> should.equal(1)
}

pub fn count_state_legislation_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  // WA has no state-level legislation (only municipal)
  let assert Ok(count) = browse_repo.count_state_legislation(connection, "WA")
  count |> should.equal(0)
}

// --- count_topics tests ---

pub fn count_topics_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  let assert Ok(topic_counts) = browse_repo.count_topics(connection)

  // Topics across all records:
  // environment: 1 (federal)
  // energy: 2 (federal, TX)
  // housing: 2 (CA state, SF municipal)
  // zoning: 2 (CA state, LA county)
  // infrastructure: 2 (TX, Seattle)
  // land use: 1 (LA county)
  // rent control: 1 (SF municipal)
  // transit: 1 (Seattle)
  topic_counts |> list.length |> should.not_equal(0)

  // energy and housing and zoning and infrastructure should have count 2
  topic_counts |> list.key_find("energy") |> should.equal(Ok(2))
  topic_counts |> list.key_find("housing") |> should.equal(Ok(2))
}

pub fn count_topics_ordered_by_count_descending_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  let assert Ok(topic_counts) = browse_repo.count_topics(connection)

  // First topic should have highest count
  let assert [first, ..] = topic_counts
  let #(_, first_count) = first
  first_count |> should.equal(2)
}

pub fn count_topics_empty_db_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(topic_counts) = browse_repo.count_topics(connection)
  topic_counts |> list.length |> should.equal(0)
}
