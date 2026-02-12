import gleam/json
import gleam/option
import gleeunit/should
import philstubs/core/government_level.{County, Federal, Municipal, State}
import philstubs/core/legislation
import philstubs/core/legislation_status
import philstubs/core/legislation_template
import philstubs/core/legislation_type

// --- GovernmentLevel tests ---

pub fn government_level_to_string_federal_test() {
  government_level.to_string(Federal)
  |> should.equal("Federal")
}

pub fn government_level_to_string_state_test() {
  government_level.to_string(State("CA"))
  |> should.equal("State")
}

pub fn government_level_to_string_county_test() {
  government_level.to_string(County("IL", "Cook"))
  |> should.equal("County")
}

pub fn government_level_to_string_municipal_test() {
  government_level.to_string(Municipal("TX", "Austin"))
  |> should.equal("Municipal")
}

pub fn jurisdiction_label_federal_test() {
  government_level.jurisdiction_label(Federal)
  |> should.equal("Federal")
}

pub fn jurisdiction_label_state_test() {
  government_level.jurisdiction_label(State("CA"))
  |> should.equal("State (CA)")
}

pub fn jurisdiction_label_county_test() {
  government_level.jurisdiction_label(County("IL", "Cook"))
  |> should.equal("County (Cook, IL)")
}

pub fn jurisdiction_label_municipal_test() {
  government_level.jurisdiction_label(Municipal("TX", "Austin"))
  |> should.equal("Municipal (Austin, TX)")
}

pub fn government_level_json_roundtrip_federal_test() {
  let level = Federal
  let encoded = government_level.to_json(level) |> json.to_string
  let decoded = json.parse(encoded, government_level.decoder())
  decoded |> should.equal(Ok(Federal))
}

pub fn government_level_json_roundtrip_state_test() {
  let level = State("NY")
  let encoded = government_level.to_json(level) |> json.to_string
  let decoded = json.parse(encoded, government_level.decoder())
  decoded |> should.equal(Ok(State("NY")))
}

pub fn government_level_json_roundtrip_county_test() {
  let level = County("IL", "Cook")
  let encoded = government_level.to_json(level) |> json.to_string
  let decoded = json.parse(encoded, government_level.decoder())
  decoded |> should.equal(Ok(County("IL", "Cook")))
}

pub fn government_level_json_roundtrip_municipal_test() {
  let level = Municipal("TX", "Austin")
  let encoded = government_level.to_json(level) |> json.to_string
  let decoded = json.parse(encoded, government_level.decoder())
  decoded |> should.equal(Ok(Municipal("TX", "Austin")))
}

// --- LegislationType tests ---

pub fn legislation_type_to_string_all_variants_test() {
  legislation_type.to_string(legislation_type.Bill)
  |> should.equal("Bill")

  legislation_type.to_string(legislation_type.Resolution)
  |> should.equal("Resolution")

  legislation_type.to_string(legislation_type.Ordinance)
  |> should.equal("Ordinance")

  legislation_type.to_string(legislation_type.Bylaw)
  |> should.equal("Bylaw")

  legislation_type.to_string(legislation_type.Amendment)
  |> should.equal("Amendment")

  legislation_type.to_string(legislation_type.Regulation)
  |> should.equal("Regulation")

  legislation_type.to_string(legislation_type.ExecutiveOrder)
  |> should.equal("Executive Order")
}

pub fn legislation_type_json_roundtrip_test() {
  let variants = [
    legislation_type.Bill,
    legislation_type.Resolution,
    legislation_type.Ordinance,
    legislation_type.Bylaw,
    legislation_type.Amendment,
    legislation_type.Regulation,
    legislation_type.ExecutiveOrder,
  ]
  use variant <- list_each(variants)
  let encoded = legislation_type.to_json(variant) |> json.to_string
  let decoded = json.parse(encoded, legislation_type.decoder())
  decoded |> should.equal(Ok(variant))
}

// --- LegislationStatus tests ---

pub fn legislation_status_to_string_all_variants_test() {
  legislation_status.to_string(legislation_status.Introduced)
  |> should.equal("Introduced")

  legislation_status.to_string(legislation_status.InCommittee)
  |> should.equal("In Committee")

  legislation_status.to_string(legislation_status.PassedChamber)
  |> should.equal("Passed Chamber")

  legislation_status.to_string(legislation_status.Enacted)
  |> should.equal("Enacted")

  legislation_status.to_string(legislation_status.Vetoed)
  |> should.equal("Vetoed")

  legislation_status.to_string(legislation_status.Expired)
  |> should.equal("Expired")

  legislation_status.to_string(legislation_status.Withdrawn)
  |> should.equal("Withdrawn")
}

pub fn legislation_status_json_roundtrip_test() {
  let variants = [
    legislation_status.Introduced,
    legislation_status.InCommittee,
    legislation_status.PassedChamber,
    legislation_status.Enacted,
    legislation_status.Vetoed,
    legislation_status.Expired,
    legislation_status.Withdrawn,
  ]
  use variant <- list_each(variants)
  let encoded = legislation_status.to_json(variant) |> json.to_string
  let decoded = json.parse(encoded, legislation_status.decoder())
  decoded |> should.equal(Ok(variant))
}

// --- LegislationId tests ---

pub fn legislation_id_roundtrip_test() {
  let identifier = legislation.legislation_id("abc-123")
  legislation.legislation_id_to_string(identifier)
  |> should.equal("abc-123")
}

pub fn legislation_id_json_roundtrip_test() {
  let identifier = legislation.legislation_id("leg-456")
  let encoded = legislation.legislation_id_to_json(identifier) |> json.to_string
  let decoded = json.parse(encoded, legislation.legislation_id_decoder())
  decoded
  |> should.be_ok
}

// --- TemplateId tests ---

pub fn template_id_roundtrip_test() {
  let identifier = legislation_template.template_id("tmpl-789")
  legislation_template.template_id_to_string(identifier)
  |> should.equal("tmpl-789")
}

pub fn template_id_json_roundtrip_test() {
  let identifier = legislation_template.template_id("tmpl-012")
  let encoded =
    legislation_template.template_id_to_json(identifier) |> json.to_string
  let decoded = json.parse(encoded, legislation_template.template_id_decoder())
  decoded
  |> should.be_ok
}

// --- Legislation full record tests ---

pub fn legislation_json_roundtrip_test() {
  let sample_legislation =
    legislation.Legislation(
      id: legislation.legislation_id("fed-001"),
      title: "Clean Air Standards Act",
      summary: "Establishes new air quality standards for industrial emissions",
      body: "Section 1. Short Title.\nThis Act may be cited as the Clean Air Standards Act.",
      level: Federal,
      legislation_type: legislation_type.Bill,
      status: legislation_status.Introduced,
      introduced_date: "2024-03-15",
      source_url: option.Some("https://congress.gov/bill/118th/hr1234"),
      source_identifier: "H.R. 1234",
      sponsors: ["Rep. Smith", "Rep. Jones"],
      topics: ["environment", "air quality", "regulation"],
    )

  let encoded = legislation.to_json(sample_legislation) |> json.to_string
  let decoded = json.parse(encoded, legislation.decoder())

  let assert Ok(result) = decoded
  result.title |> should.equal("Clean Air Standards Act")
  result.summary
  |> should.equal(
    "Establishes new air quality standards for industrial emissions",
  )
  result.introduced_date |> should.equal("2024-03-15")
  result.source_url
  |> should.equal(option.Some("https://congress.gov/bill/118th/hr1234"))
  result.source_identifier |> should.equal("H.R. 1234")
  result.sponsors |> should.equal(["Rep. Smith", "Rep. Jones"])
  result.topics |> should.equal(["environment", "air quality", "regulation"])
  legislation.legislation_id_to_string(result.id)
  |> should.equal("fed-001")
}

pub fn legislation_json_roundtrip_with_none_source_url_test() {
  let sample_legislation =
    legislation.Legislation(
      id: legislation.legislation_id("county-001"),
      title: "Noise Ordinance Amendment",
      summary: "Amends noise restrictions for residential zones",
      body: "Be it ordained...",
      level: County("IL", "Cook"),
      legislation_type: legislation_type.Ordinance,
      status: legislation_status.Enacted,
      introduced_date: "2024-01-10",
      source_url: option.None,
      source_identifier: "Ord. 2024-15",
      sponsors: ["Commissioner Davis"],
      topics: ["noise", "zoning"],
    )

  let encoded = legislation.to_json(sample_legislation) |> json.to_string
  let decoded = json.parse(encoded, legislation.decoder())

  let assert Ok(result) = decoded
  result.source_url |> should.equal(option.None)
  result.level |> should.equal(County("IL", "Cook"))
}

// --- LegislationTemplate full record tests ---

pub fn legislation_template_json_roundtrip_test() {
  let sample_template =
    legislation_template.LegislationTemplate(
      id: legislation_template.template_id("tmpl-housing-001"),
      title: "Model Affordable Housing Ordinance",
      description: "A template ordinance for municipalities to adopt inclusionary zoning requirements",
      body: "WHEREAS the [Municipality] recognizes the need for affordable housing...",
      suggested_level: Municipal("", ""),
      suggested_type: legislation_type.Ordinance,
      author: "Housing Policy Institute",
      topics: ["housing", "zoning", "affordable housing"],
      created_at: "2024-06-01T12:00:00Z",
      download_count: 42,
    )

  let encoded = legislation_template.to_json(sample_template) |> json.to_string
  let decoded = json.parse(encoded, legislation_template.decoder())

  let assert Ok(result) = decoded
  result.title |> should.equal("Model Affordable Housing Ordinance")
  result.author |> should.equal("Housing Policy Institute")
  result.topics
  |> should.equal(["housing", "zoning", "affordable housing"])
  result.created_at |> should.equal("2024-06-01T12:00:00Z")
  result.download_count |> should.equal(42)
  legislation_template.template_id_to_string(result.id)
  |> should.equal("tmpl-housing-001")
}

// --- Helper ---

fn list_each(items: List(a), check: fn(a) -> Nil) -> Nil {
  case items {
    [] -> Nil
    [first, ..rest] -> {
      check(first)
      list_each(rest, check)
    }
  }
}
