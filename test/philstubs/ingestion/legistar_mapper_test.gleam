import gleam/option.{None, Some}
import gleeunit/should
import philstubs/core/government_level
import philstubs/core/legislation
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/ingestion/legistar_mapper
import philstubs/ingestion/legistar_types.{
  type LegistarMatter, LegistarMatter, LegistarSponsor,
}

fn sample_matter() -> LegistarMatter {
  LegistarMatter(
    matter_id: 12_345,
    matter_guid: "abc-def-123",
    matter_file: Some("CB 12345"),
    matter_name: Some("Zoning Update"),
    matter_title: Some("An ordinance relating to zoning"),
    matter_type_name: Some("Ordinance"),
    matter_status_name: Some("Adopted"),
    matter_body_name: Some("City Council"),
    matter_intro_date: Some("2024-01-10T00:00:00"),
    matter_agenda_date: Some("2024-02-15T00:00:00"),
    matter_passed_date: Some("2024-03-01T00:00:00"),
    matter_enactment_date: Some("2024-03-15T00:00:00"),
    matter_enactment_number: Some("ORD-2024-100"),
    matter_notes: Some("Relates to downtown zoning changes"),
    matter_last_modified_utc: Some("2024-03-20T12:00:00"),
  )
}

fn minimal_matter() -> LegistarMatter {
  LegistarMatter(
    matter_id: 99_999,
    matter_guid: "min-guid-456",
    matter_file: None,
    matter_name: None,
    matter_title: None,
    matter_type_name: None,
    matter_status_name: None,
    matter_body_name: None,
    matter_intro_date: None,
    matter_agenda_date: None,
    matter_passed_date: None,
    matter_enactment_date: None,
    matter_enactment_number: None,
    matter_notes: None,
    matter_last_modified_utc: None,
  )
}

// --- ID Construction ---

pub fn build_legislation_id_test() {
  legistar_mapper.build_legislation_id("seattle", 12_345)
  |> should.equal("legistar-seattle-12345")
}

pub fn build_legislation_id_county_test() {
  legistar_mapper.build_legislation_id("kingcounty", 67_890)
  |> should.equal("legistar-kingcounty-67890")
}

// --- Type Mapping ---

pub fn map_type_ordinance_test() {
  legistar_mapper.map_matter_type(Some("Ordinance"))
  |> should.equal(legislation_type.Ordinance)
}

pub fn map_type_resolution_test() {
  legistar_mapper.map_matter_type(Some("Resolution"))
  |> should.equal(legislation_type.Resolution)
}

pub fn map_type_motion_test() {
  legistar_mapper.map_matter_type(Some("Motion"))
  |> should.equal(legislation_type.Bill)
}

pub fn map_type_none_test() {
  legistar_mapper.map_matter_type(None)
  |> should.equal(legislation_type.Bill)
}

pub fn map_type_unknown_test() {
  legistar_mapper.map_matter_type(Some("Special Report"))
  |> should.equal(legislation_type.Bill)
}

pub fn map_type_executive_order_test() {
  legistar_mapper.map_matter_type(Some("Executive Order"))
  |> should.equal(legislation_type.ExecutiveOrder)
}

// --- Status Mapping ---

pub fn map_status_adopted_test() {
  legistar_mapper.map_matter_status(Some("Adopted"))
  |> should.equal(legislation_status.Enacted)
}

pub fn map_status_passed_test() {
  legistar_mapper.map_matter_status(Some("Passed"))
  |> should.equal(legislation_status.Enacted)
}

pub fn map_status_vetoed_test() {
  legistar_mapper.map_matter_status(Some("Vetoed"))
  |> should.equal(legislation_status.Vetoed)
}

pub fn map_status_referred_test() {
  legistar_mapper.map_matter_status(Some("Referred"))
  |> should.equal(legislation_status.InCommittee)
}

pub fn map_status_filed_test() {
  legistar_mapper.map_matter_status(Some("Filed"))
  |> should.equal(legislation_status.Introduced)
}

pub fn map_status_withdrawn_test() {
  legistar_mapper.map_matter_status(Some("Withdrawn"))
  |> should.equal(legislation_status.Withdrawn)
}

pub fn map_status_none_test() {
  legistar_mapper.map_matter_status(None)
  |> should.equal(legislation_status.Introduced)
}

pub fn map_status_expired_test() {
  legistar_mapper.map_matter_status(Some("Expired"))
  |> should.equal(legislation_status.Expired)
}

// --- Title Extraction ---

pub fn extract_title_from_title_test() {
  let matter = sample_matter()
  legistar_mapper.extract_title(matter)
  |> should.equal("An ordinance relating to zoning")
}

pub fn extract_title_fallback_to_name_test() {
  let matter = LegistarMatter(..sample_matter(), matter_title: None)
  legistar_mapper.extract_title(matter)
  |> should.equal("Zoning Update")
}

pub fn extract_title_fallback_to_file_test() {
  let matter =
    LegistarMatter(..sample_matter(), matter_title: None, matter_name: None)
  legistar_mapper.extract_title(matter)
  |> should.equal("CB 12345")
}

pub fn extract_title_fallback_to_untitled_test() {
  legistar_mapper.extract_title(minimal_matter())
  |> should.equal("Untitled")
}

// --- Date Parsing ---

pub fn parse_date_with_time_test() {
  legistar_mapper.parse_date(Some("2024-01-10T00:00:00"))
  |> should.equal("2024-01-10")
}

pub fn parse_date_without_time_test() {
  legistar_mapper.parse_date(Some("2024-01-10"))
  |> should.equal("2024-01-10")
}

pub fn parse_date_none_test() {
  legistar_mapper.parse_date(None)
  |> should.equal("")
}

// --- Source URL ---

pub fn build_source_url_test() {
  legistar_mapper.build_source_url("seattle", 12_345)
  |> should.equal(
    "https://seattle.legistar.com/LegislationDetail.aspx?ID=12345",
  )
}

// --- Sponsor Extraction ---

pub fn extract_sponsor_names_test() {
  let sponsors = [
    LegistarSponsor(matter_sponsor_name: "Smith"),
    LegistarSponsor(matter_sponsor_name: "Jones"),
  ]
  legistar_mapper.extract_sponsor_names(sponsors)
  |> should.equal(["Smith", "Jones"])
}

pub fn extract_sponsor_names_empty_test() {
  legistar_mapper.extract_sponsor_names([])
  |> should.equal([])
}

// --- Full Mapping ---

pub fn map_matter_to_legislation_municipal_test() {
  let matter = sample_matter()
  let sponsors = [
    LegistarSponsor(matter_sponsor_name: "Council Member Smith"),
    LegistarSponsor(matter_sponsor_name: "Council Member Jones"),
  ]
  let level = government_level.Municipal("WA", "Seattle")

  let result =
    legistar_mapper.map_matter_to_legislation(
      matter,
      "seattle",
      level,
      sponsors,
    )

  legislation.legislation_id_to_string(result.id)
  |> should.equal("legistar-seattle-12345")
  result.title |> should.equal("An ordinance relating to zoning")
  result.summary |> should.equal("Relates to downtown zoning changes")
  result.level |> should.equal(government_level.Municipal("WA", "Seattle"))
  result.legislation_type |> should.equal(legislation_type.Ordinance)
  result.status |> should.equal(legislation_status.Enacted)
  result.introduced_date |> should.equal("2024-01-10")
  result.source_identifier |> should.equal("CB 12345")
  result.sponsors
  |> should.equal(["Council Member Smith", "Council Member Jones"])
  result.topics |> should.equal([])

  case result.source_url {
    Some(url) ->
      url
      |> should.equal(
        "https://seattle.legistar.com/LegislationDetail.aspx?ID=12345",
      )
    None -> should.fail()
  }
}

pub fn map_matter_to_legislation_county_test() {
  let matter = sample_matter()
  let level = government_level.County("WA", "King County")

  let result =
    legistar_mapper.map_matter_to_legislation(matter, "kingcounty", level, [])

  result.level |> should.equal(government_level.County("WA", "King County"))

  case result.source_url {
    Some(url) ->
      url
      |> should.equal(
        "https://kingcounty.legistar.com/LegislationDetail.aspx?ID=12345",
      )
    None -> should.fail()
  }
}

pub fn map_matter_minimal_test() {
  let matter = minimal_matter()
  let level = government_level.Municipal("IL", "Chicago")

  let result =
    legistar_mapper.map_matter_to_legislation(matter, "chicago", level, [])

  legislation.legislation_id_to_string(result.id)
  |> should.equal("legistar-chicago-99999")
  result.title |> should.equal("Untitled")
  result.summary |> should.equal("")
  result.legislation_type |> should.equal(legislation_type.Bill)
  result.status |> should.equal(legislation_status.Introduced)
  result.introduced_date |> should.equal("")
  result.source_identifier |> should.equal("99999")
  result.sponsors |> should.equal([])
}
