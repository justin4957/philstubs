import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import philstubs/core/government_level.{County, Federal, State}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/test_helpers

fn sample_federal_legislation() -> Legislation {
  Legislation(
    id: legislation.legislation_id("test-fed-001"),
    title: "Clean Air Standards Act",
    summary: "Establishes new air quality standards",
    body: "Section 1. This Act establishes comprehensive standards...",
    level: Federal,
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-03-15",
    source_url: Some("https://example.gov/bill/1234"),
    source_identifier: "H.R. 1234",
    sponsors: ["Rep. Smith", "Rep. Jones"],
    topics: ["environment", "air quality"],
  )
}

fn sample_state_legislation() -> Legislation {
  Legislation(
    id: legislation.legislation_id("test-state-001"),
    title: "California Housing Incentive Act",
    summary: "Provides tax incentives for affordable housing",
    body: "THE PEOPLE OF CALIFORNIA ENACT: Section 1...",
    level: State("CA"),
    legislation_type: legislation_type.Bill,
    status: legislation_status.PassedChamber,
    introduced_date: "2024-01-20",
    source_url: None,
    source_identifier: "SB 456",
    sponsors: ["Sen. Garcia"],
    topics: ["housing", "tax incentives"],
  )
}

pub fn insert_and_get_by_id_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let record = sample_federal_legislation()
  let assert Ok(Nil) = legislation_repo.insert(connection, record)

  let assert Ok(Some(retrieved)) =
    legislation_repo.get_by_id(connection, "test-fed-001")

  legislation.legislation_id_to_string(retrieved.id)
  |> should.equal("test-fed-001")
  retrieved.title |> should.equal("Clean Air Standards Act")
  retrieved.summary |> should.equal("Establishes new air quality standards")
  retrieved.body
  |> should.equal("Section 1. This Act establishes comprehensive standards...")
  retrieved.level |> should.equal(Federal)
  retrieved.legislation_type |> should.equal(legislation_type.Bill)
  retrieved.status |> should.equal(legislation_status.Introduced)
  retrieved.introduced_date |> should.equal("2024-03-15")
  retrieved.source_url
  |> should.equal(Some("https://example.gov/bill/1234"))
  retrieved.source_identifier |> should.equal("H.R. 1234")
  retrieved.sponsors |> should.equal(["Rep. Smith", "Rep. Jones"])
  retrieved.topics |> should.equal(["environment", "air quality"])
}

pub fn get_by_id_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let result = legislation_repo.get_by_id(connection, "nonexistent-id")
  result |> should.equal(Ok(None))
}

pub fn list_all_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_legislation())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_state_legislation())

  let assert Ok(records) = legislation_repo.list_all(connection)
  records |> list.length |> should.equal(2)
}

pub fn update_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let record = sample_federal_legislation()
  let assert Ok(Nil) = legislation_repo.insert(connection, record)

  let updated_record =
    Legislation(
      ..record,
      title: "Updated Clean Air Act",
      status: legislation_status.Enacted,
      topics: ["environment", "air quality", "climate"],
    )
  let assert Ok(Nil) = legislation_repo.update(connection, updated_record)

  let assert Ok(Some(retrieved)) =
    legislation_repo.get_by_id(connection, "test-fed-001")
  retrieved.title |> should.equal("Updated Clean Air Act")
  retrieved.status |> should.equal(legislation_status.Enacted)
  retrieved.topics
  |> should.equal(["environment", "air quality", "climate"])
}

pub fn delete_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_legislation())
  let assert Ok(Some(_)) =
    legislation_repo.get_by_id(connection, "test-fed-001")

  let assert Ok(Nil) = legislation_repo.delete(connection, "test-fed-001")
  let result = legislation_repo.get_by_id(connection, "test-fed-001")
  result |> should.equal(Ok(None))
}

pub fn search_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_legislation())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_state_legislation())

  // Search for "air quality" — should match only the federal legislation
  let assert Ok(results) = legislation_repo.search(connection, "air quality")
  results |> list.length |> should.equal(1)
  let assert [matched_record] = results
  legislation.legislation_id_to_string(matched_record.id)
  |> should.equal("test-fed-001")

  // Search for "housing" — should match only the state legislation
  let assert Ok(housing_results) =
    legislation_repo.search(connection, "housing")
  housing_results |> list.length |> should.equal(1)
  let assert [housing_match] = housing_results
  legislation.legislation_id_to_string(housing_match.id)
  |> should.equal("test-state-001")
}

pub fn insert_with_none_source_url_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let record = sample_state_legislation()
  let assert Ok(Nil) = legislation_repo.insert(connection, record)

  let assert Ok(Some(retrieved)) =
    legislation_repo.get_by_id(connection, "test-state-001")
  retrieved.source_url |> should.equal(None)
}

pub fn insert_with_county_level_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let county_record =
    Legislation(
      id: legislation.legislation_id("test-county-001"),
      title: "Cook County Noise Ordinance",
      summary: "Noise restrictions for residential zones",
      body: "BE IT ORDAINED...",
      level: County("IL", "Cook"),
      legislation_type: legislation_type.Ordinance,
      status: legislation_status.Enacted,
      introduced_date: "2024-06-01",
      source_url: None,
      source_identifier: "Ord. 2024-15",
      sponsors: ["Commissioner Davis"],
      topics: ["noise", "zoning"],
    )

  let assert Ok(Nil) = legislation_repo.insert(connection, county_record)
  let assert Ok(Some(retrieved)) =
    legislation_repo.get_by_id(connection, "test-county-001")

  retrieved.level |> should.equal(County("IL", "Cook"))
  retrieved.legislation_type |> should.equal(legislation_type.Ordinance)
  retrieved.status |> should.equal(legislation_status.Enacted)
}
