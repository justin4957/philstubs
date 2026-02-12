import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import philstubs/core/government_level
import philstubs/ingestion/jurisdiction_registry

pub fn get_by_client_id_found_test() {
  let result = jurisdiction_registry.get_by_client_id("seattle")
  case result {
    Some(entry) -> {
      entry.client_id |> should.equal("seattle")
      entry.display_name |> should.equal("Seattle")
      entry.government_level
      |> should.equal(government_level.Municipal("WA", "Seattle"))
      entry.requires_token |> should.equal(False)
    }
    None -> should.fail()
  }
}

pub fn get_by_client_id_not_found_test() {
  jurisdiction_registry.get_by_client_id("nonexistent")
  |> should.equal(None)
}

pub fn get_by_client_id_county_test() {
  let result = jurisdiction_registry.get_by_client_id("kingcounty")
  case result {
    Some(entry) -> {
      entry.client_id |> should.equal("kingcounty")
      entry.display_name |> should.equal("King County")
      entry.government_level
      |> should.equal(government_level.County("WA", "King County"))
    }
    None -> should.fail()
  }
}

pub fn all_jurisdictions_returns_expected_entries_test() {
  let entries = jurisdiction_registry.all_jurisdictions()
  list.length(entries) |> should.equal(6)

  // Verify municipal entries
  let municipal_count =
    list.count(entries, fn(entry) {
      case entry.government_level {
        government_level.Municipal(..) -> True
        _ -> False
      }
    })
  municipal_count |> should.equal(4)

  // Verify county entries
  let county_count =
    list.count(entries, fn(entry) {
      case entry.government_level {
        government_level.County(..) -> True
        _ -> False
      }
    })
  county_count |> should.equal(2)
}

pub fn get_by_client_id_cook_county_test() {
  let result = jurisdiction_registry.get_by_client_id("cookcounty")
  case result {
    Some(entry) -> {
      entry.government_level
      |> should.equal(government_level.County("IL", "Cook County"))
    }
    None -> should.fail()
  }
}
