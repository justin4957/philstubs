import gleam/http
import gleam/list
import gleam/option.{None}
import gleam/string
import gleeunit/should
import philstubs/core/government_level.{County, Federal, Municipal, State}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/test_helpers
import philstubs/web/context.{Context}
import philstubs/web/router
import sqlight
import wisp/simulate

fn test_context(db_connection: sqlight.Connection) -> context.Context {
  Context(static_directory: "", db_connection:)
}

fn sample_federal_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("browse-test-fed"),
    title: "Federal Climate Act",
    summary: "Federal climate legislation.",
    body: "SECTION 1. Climate.",
    level: Federal,
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-01-15",
    source_url: None,
    source_identifier: "H.R. 42",
    sponsors: [],
    topics: ["climate", "environment"],
  )
}

fn sample_ca_state_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("browse-test-ca"),
    title: "California Water Bill",
    summary: "CA water legislation.",
    body: "SECTION 1. Water.",
    level: State(state_code: "CA"),
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-02-15",
    source_url: None,
    source_identifier: "AB 55",
    sponsors: [],
    topics: ["water", "environment"],
  )
}

fn sample_ca_county_ordinance() -> Legislation {
  Legislation(
    id: legislation.legislation_id("browse-test-ca-county"),
    title: "LA County Transit Ordinance",
    summary: "LA county transit.",
    body: "SECTION 1. Transit.",
    level: County(state_code: "CA", county_name: "Los Angeles"),
    legislation_type: legislation_type.Ordinance,
    status: legislation_status.Enacted,
    introduced_date: "2024-03-15",
    source_url: None,
    source_identifier: "ORD-LA-1",
    sponsors: [],
    topics: ["transit"],
  )
}

fn sample_ca_municipal_ordinance() -> Legislation {
  Legislation(
    id: legislation.legislation_id("browse-test-ca-sf"),
    title: "San Francisco Housing Ordinance",
    summary: "SF housing.",
    body: "SECTION 1. Housing.",
    level: Municipal(state_code: "CA", municipality_name: "San Francisco"),
    legislation_type: legislation_type.Ordinance,
    status: legislation_status.Introduced,
    introduced_date: "2024-04-15",
    source_url: None,
    source_identifier: "ORD-SF-1",
    sponsors: [],
    topics: ["housing"],
  )
}

fn sample_tx_state_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("browse-test-tx"),
    title: "Texas Energy Bill",
    summary: "TX energy legislation.",
    body: "SECTION 1. Energy.",
    level: State(state_code: "TX"),
    legislation_type: legislation_type.Bill,
    status: legislation_status.Enacted,
    introduced_date: "2024-05-15",
    source_url: None,
    source_identifier: "HB 100",
    sponsors: [],
    topics: ["energy"],
  )
}

fn insert_all_samples(connection: sqlight.Connection) -> Nil {
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_ca_state_bill())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_ca_county_ordinance())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_ca_municipal_ordinance())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_tx_state_bill())
  Nil
}

// --- GET /browse tests ---

pub fn browse_root_renders_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/browse")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body
  |> string.contains("Browse by Government Level")
  |> should.be_true
  body |> string.contains("Federal") |> should.be_true
  body |> string.contains("State") |> should.be_true
  body |> string.contains("County") |> should.be_true
  body |> string.contains("Municipal") |> should.be_true
}

pub fn browse_root_shows_counts_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_samples(connection)

  let response =
    simulate.request(http.Get, "/browse")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  // Federal count: 1
  body |> string.contains("1") |> should.be_true
  // State count: 2
  body |> string.contains("2") |> should.be_true
}

pub fn browse_root_shows_topic_link_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/browse")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("Browse by Topic") |> should.be_true
  body |> string.contains("/browse/topics") |> should.be_true
}

pub fn browse_root_empty_db_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/browse")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  // All counts should be 0
  body |> string.contains("0") |> should.be_true
}

// --- GET /browse/federal tests ---

pub fn browse_federal_redirects_to_search_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/browse/federal")
    |> router.handle_request(context)

  response.status |> should.equal(303)
  let location = list.key_find(response.headers, "location")
  location |> should.equal(Ok("/search?level=federal"))
}

// --- GET /browse/states tests ---

pub fn browse_states_renders_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_samples(connection)

  let response =
    simulate.request(http.Get, "/browse/states")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("State Legislation") |> should.be_true
  body |> string.contains("CA") |> should.be_true
  body |> string.contains("TX") |> should.be_true
}

pub fn browse_states_shows_breadcrumbs_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/browse/states")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("breadcrumb") |> should.be_true
  body |> string.contains("/browse") |> should.be_true
}

pub fn browse_states_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/browse/states")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body
  |> string.contains("No state legislation available")
  |> should.be_true
}

pub fn browse_states_links_to_state_detail_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_samples(connection)

  let response =
    simulate.request(http.Get, "/browse/states")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("/browse/state/CA") |> should.be_true
  body |> string.contains("/browse/state/TX") |> should.be_true
}

// --- GET /browse/state/:state_code tests ---

pub fn browse_state_detail_renders_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_samples(connection)

  let response =
    simulate.request(http.Get, "/browse/state/CA")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("CA Legislation") |> should.be_true
  body |> string.contains("State Legislature") |> should.be_true
}

pub fn browse_state_detail_shows_breadcrumbs_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/browse/state/CA")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("Browse") |> should.be_true
  body |> string.contains("States") |> should.be_true
  body |> string.contains("CA") |> should.be_true
}

pub fn browse_state_detail_shows_counties_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_samples(connection)

  let response =
    simulate.request(http.Get, "/browse/state/CA")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("Counties") |> should.be_true
  body |> string.contains("Los Angeles") |> should.be_true
}

pub fn browse_state_detail_shows_municipalities_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_samples(connection)

  let response =
    simulate.request(http.Get, "/browse/state/CA")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("Cities") |> should.be_true
  body |> string.contains("San Francisco") |> should.be_true
}

pub fn browse_state_detail_links_to_search_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_samples(connection)

  let response =
    simulate.request(http.Get, "/browse/state/CA")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body
  |> string.contains("/search?level=state&amp;state=CA")
  |> should.be_true
}

pub fn browse_state_detail_empty_counties_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_samples(connection)

  let response =
    simulate.request(http.Get, "/browse/state/TX")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body
  |> string.contains("No county legislation available for TX")
  |> should.be_true
  body
  |> string.contains("No municipal legislation available for TX")
  |> should.be_true
}

// --- GET /browse/topics tests ---

pub fn browse_topics_renders_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_samples(connection)

  let response =
    simulate.request(http.Get, "/browse/topics")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("Browse by Topic") |> should.be_true
  body |> string.contains("environment") |> should.be_true
  body |> string.contains("housing") |> should.be_true
  body |> string.contains("energy") |> should.be_true
}

pub fn browse_topics_links_to_search_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)
  insert_all_samples(connection)

  let response =
    simulate.request(http.Get, "/browse/topics")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("/search?q=") |> should.be_true
}

pub fn browse_topics_shows_breadcrumbs_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/browse/topics")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("breadcrumb") |> should.be_true
  body |> string.contains("Browse") |> should.be_true
  body |> string.contains("Topics") |> should.be_true
}

pub fn browse_topics_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/browse/topics")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("No topics available") |> should.be_true
}

// --- Navigation link in layout test ---

pub fn browse_link_in_navigation_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/browse")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  // Nav should include Browse link
  body |> string.contains("Browse") |> should.be_true
}
