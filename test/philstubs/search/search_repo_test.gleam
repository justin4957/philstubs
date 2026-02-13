import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import philstubs/core/government_level.{Federal, Municipal, State}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/test_helpers
import philstubs/search/search_query.{SearchQuery}
import philstubs/search/search_repo

fn sample_federal_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("search-fed-001"),
    title: "Clean Energy Innovation Act",
    summary: "Promotes renewable energy research and development",
    body: "Section 1. This Act promotes clean energy and solar power...",
    level: Federal,
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-03-15",
    source_url: Some("https://example.gov/bill/001"),
    source_identifier: "H.R. 1001",
    sponsors: ["Rep. Smith", "Rep. Jones"],
    topics: ["energy", "climate"],
  )
}

fn sample_state_housing_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("search-state-001"),
    title: "Affordable Housing Tax Credit Act",
    summary: "Provides tax credits for affordable housing construction",
    body: "THE PEOPLE OF CALIFORNIA ENACT: Section 1. Housing credits...",
    level: State("CA"),
    legislation_type: legislation_type.Bill,
    status: legislation_status.PassedChamber,
    introduced_date: "2024-01-20",
    source_url: None,
    source_identifier: "SB 456",
    sponsors: ["Sen. Garcia"],
    topics: ["housing", "tax credits"],
  )
}

fn sample_municipal_ordinance() -> Legislation {
  Legislation(
    id: legislation.legislation_id("search-muni-001"),
    title: "Seattle Noise Restriction Ordinance",
    summary: "Restricts noise levels in residential areas",
    body: "BE IT ORDAINED by the City of Seattle...",
    level: Municipal(state_code: "WA", municipality_name: "Seattle"),
    legislation_type: legislation_type.Ordinance,
    status: legislation_status.Enacted,
    introduced_date: "2024-06-01",
    source_url: Some("https://legistar.seattle.gov/ord/100"),
    source_identifier: "Ord. 2024-100",
    sponsors: ["Councilmember Davis"],
    topics: ["noise", "zoning"],
  )
}

fn sample_enacted_resolution() -> Legislation {
  Legislation(
    id: legislation.legislation_id("search-fed-002"),
    title: "National Parks Preservation Resolution",
    summary: "Resolution supporting national park preservation efforts",
    body: "Resolved, that the Congress supports preservation...",
    level: Federal,
    legislation_type: legislation_type.Resolution,
    status: legislation_status.Enacted,
    introduced_date: "2024-02-10",
    source_url: Some("https://example.gov/res/002"),
    source_identifier: "H.Res. 50",
    sponsors: ["Rep. Wilson"],
    topics: ["parks", "conservation"],
  )
}

fn seed_all_records(connection) -> Nil {
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_state_housing_bill())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_municipal_ordinance())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_enacted_resolution())
  Nil
}

pub fn search_by_text_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  seed_all_records(connection)

  let query =
    SearchQuery(..search_query.default(), text: Some("clean energy solar"))

  let assert Ok(results) = search_repo.search(connection, query)
  results.total_count |> should.equal(1)

  let assert [first_result] = results.items
  legislation.legislation_id_to_string(first_result.legislation.id)
  |> should.equal("search-fed-001")
}

pub fn search_by_text_with_ranking_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  seed_all_records(connection)

  // "housing" appears in state bill title, summary, and body
  let query = SearchQuery(..search_query.default(), text: Some("housing"))

  let assert Ok(results) = search_repo.search(connection, query)
  results.total_count |> should.equal(1)

  let assert [first_result] = results.items
  legislation.legislation_id_to_string(first_result.legislation.id)
  |> should.equal("search-state-001")
}

pub fn search_with_level_filter_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  seed_all_records(connection)

  // Filter by federal only — should get 2 (bill + resolution)
  let query =
    SearchQuery(..search_query.default(), government_level: Some("federal"))

  let assert Ok(results) = search_repo.search(connection, query)
  results.total_count |> should.equal(2)

  // All results should be federal
  list.each(results.items, fn(search_result) {
    search_result.legislation.level |> should.equal(Federal)
  })
}

pub fn search_with_type_filter_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  seed_all_records(connection)

  // Filter by ordinance type
  let query =
    SearchQuery(..search_query.default(), legislation_type: Some("ordinance"))

  let assert Ok(results) = search_repo.search(connection, query)
  results.total_count |> should.equal(1)

  let assert [first_result] = results.items
  first_result.legislation.legislation_type
  |> should.equal(legislation_type.Ordinance)
}

pub fn search_with_status_filter_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  seed_all_records(connection)

  // Filter by enacted status
  let query = SearchQuery(..search_query.default(), status: Some("enacted"))

  let assert Ok(results) = search_repo.search(connection, query)
  results.total_count |> should.equal(2)

  list.each(results.items, fn(search_result) {
    search_result.legislation.status
    |> should.equal(legislation_status.Enacted)
  })
}

pub fn search_with_date_range_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  seed_all_records(connection)

  // Filter to only legislation introduced in Q1 2024
  let query =
    SearchQuery(
      ..search_query.default(),
      date_from: Some("2024-01-01"),
      date_to: Some("2024-03-31"),
    )

  let assert Ok(results) = search_repo.search(connection, query)
  // Fed bill (Mar 15), State bill (Jan 20), Fed resolution (Feb 10) — not municipal (Jun 1)
  results.total_count |> should.equal(3)
}

pub fn search_with_combined_filters_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  seed_all_records(connection)

  // Federal + enacted = only the resolution
  let query =
    SearchQuery(
      ..search_query.default(),
      government_level: Some("federal"),
      status: Some("enacted"),
    )

  let assert Ok(results) = search_repo.search(connection, query)
  results.total_count |> should.equal(1)

  let assert [first_result] = results.items
  legislation.legislation_id_to_string(first_result.legislation.id)
  |> should.equal("search-fed-002")
}

pub fn search_pagination_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  seed_all_records(connection)

  // Page 1 with 2 per page
  let query = SearchQuery(..search_query.default(), per_page: 2, page: 1)

  let assert Ok(page_one_results) = search_repo.search(connection, query)
  page_one_results.total_count |> should.equal(4)
  page_one_results.total_pages |> should.equal(2)
  page_one_results.page |> should.equal(1)
  list.length(page_one_results.items) |> should.equal(2)

  // Page 2
  let query_page_two =
    SearchQuery(..search_query.default(), per_page: 2, page: 2)

  let assert Ok(page_two_results) =
    search_repo.search(connection, query_page_two)
  page_two_results.total_count |> should.equal(4)
  page_two_results.page |> should.equal(2)
  list.length(page_two_results.items) |> should.equal(2)
}

pub fn search_no_text_browse_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  seed_all_records(connection)

  // No text, no filters — returns all legislation
  let query = search_query.default()

  let assert Ok(results) = search_repo.search(connection, query)
  results.total_count |> should.equal(4)
}

pub fn search_empty_results_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  // No records seeded

  let query = SearchQuery(..search_query.default(), text: Some("nonexistent"))

  let assert Ok(results) = search_repo.search(connection, query)
  results.total_count |> should.equal(0)
  results.total_pages |> should.equal(0)
  results.items |> should.equal([])
}

pub fn search_text_with_filter_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  seed_all_records(connection)

  // Text search for "preservation" + federal filter
  let query =
    SearchQuery(
      ..search_query.default(),
      text: Some("preservation"),
      government_level: Some("federal"),
    )

  let assert Ok(results) = search_repo.search(connection, query)
  results.total_count |> should.equal(1)

  let assert [first_result] = results.items
  first_result.legislation.level |> should.equal(Federal)
  legislation.legislation_id_to_string(first_result.legislation.id)
  |> should.equal("search-fed-002")
}

pub fn search_snippet_contains_text_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  seed_all_records(connection)

  // FTS search should produce snippet with <mark> tags
  let query = SearchQuery(..search_query.default(), text: Some("noise"))

  let assert Ok(results) = search_repo.search(connection, query)
  results.total_count |> should.equal(1)

  let assert [first_result] = results.items
  // Snippet should contain mark tags around the matched term
  string.contains(first_result.snippet, "<mark>")
  |> should.equal(True)
}
