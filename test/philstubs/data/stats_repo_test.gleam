import gleam/list
import gleam/option.{None}
import gleeunit/should
import philstubs/core/government_level.{County, Federal, Municipal, State}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/stats_repo
import philstubs/data/test_helpers
import sqlight

fn sample_federal_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("stats-fed-001"),
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
    topics: ["environment"],
  )
}

fn sample_state_resolution() -> Legislation {
  Legislation(
    id: legislation.legislation_id("stats-state-001"),
    title: "State Resolution",
    summary: "A state resolution.",
    body: "SECTION 1. State test.",
    level: State(state_code: "CA"),
    legislation_type: legislation_type.Resolution,
    status: legislation_status.Enacted,
    introduced_date: "2024-02-01",
    source_url: None,
    source_identifier: "SR 1",
    sponsors: [],
    topics: ["housing"],
  )
}

fn sample_county_ordinance() -> Legislation {
  Legislation(
    id: legislation.legislation_id("stats-county-001"),
    title: "County Ordinance",
    summary: "A county ordinance.",
    body: "SECTION 1. County test.",
    level: County(state_code: "CA", county_name: "Los Angeles"),
    legislation_type: legislation_type.Ordinance,
    status: legislation_status.Introduced,
    introduced_date: "2024-03-01",
    source_url: None,
    source_identifier: "ORD-001",
    sponsors: [],
    topics: ["zoning"],
  )
}

fn sample_municipal_bill() -> Legislation {
  Legislation(
    id: legislation.legislation_id("stats-muni-001"),
    title: "Municipal Bill",
    summary: "A municipal bill.",
    body: "SECTION 1. Municipal test.",
    level: Municipal(state_code: "CA", municipality_name: "San Francisco"),
    legislation_type: legislation_type.Bill,
    status: legislation_status.InCommittee,
    introduced_date: "2024-04-01",
    source_url: None,
    source_identifier: "ORD-SF-001",
    sponsors: [],
    topics: ["transit"],
  )
}

fn insert_all_samples(connection: sqlight.Connection) -> Nil {
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_federal_bill())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_state_resolution())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_county_ordinance())
  let assert Ok(Nil) =
    legislation_repo.insert(connection, sample_municipal_bill())
  Nil
}

pub fn get_legislation_stats_total_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  let assert Ok(stats) = stats_repo.get_legislation_stats(connection)
  stats.total |> should.equal(4)
}

pub fn get_legislation_stats_by_level_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  let assert Ok(stats) = stats_repo.get_legislation_stats(connection)
  stats.by_level |> list.key_find("federal") |> should.equal(Ok(1))
  stats.by_level |> list.key_find("state") |> should.equal(Ok(1))
  stats.by_level |> list.key_find("county") |> should.equal(Ok(1))
  stats.by_level |> list.key_find("municipal") |> should.equal(Ok(1))
}

pub fn get_legislation_stats_by_type_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  let assert Ok(stats) = stats_repo.get_legislation_stats(connection)
  // 2 bills (federal + municipal), 1 resolution, 1 ordinance
  stats.by_type |> list.key_find("bill") |> should.equal(Ok(2))
  stats.by_type |> list.key_find("resolution") |> should.equal(Ok(1))
  stats.by_type |> list.key_find("ordinance") |> should.equal(Ok(1))
}

pub fn get_legislation_stats_by_status_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  insert_all_samples(connection)

  let assert Ok(stats) = stats_repo.get_legislation_stats(connection)
  // 2 introduced, 1 enacted, 1 in_committee
  stats.by_status |> list.key_find("introduced") |> should.equal(Ok(2))
  stats.by_status |> list.key_find("enacted") |> should.equal(Ok(1))
  stats.by_status |> list.key_find("in_committee") |> should.equal(Ok(1))
}

pub fn get_legislation_stats_empty_db_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(stats) = stats_repo.get_legislation_stats(connection)
  stats.total |> should.equal(0)
  stats.by_level |> list.length |> should.equal(0)
  stats.by_type |> list.length |> should.equal(0)
  stats.by_status |> list.length |> should.equal(0)
}
