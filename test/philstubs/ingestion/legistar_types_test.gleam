import gleam/json
import gleam/option.{None, Some}
import gleeunit/should
import philstubs/ingestion/legistar_types

/// Full matter JSON with all fields populated.
const full_matter_json = "
{
  \"MatterId\": 12345,
  \"MatterGuid\": \"abc-def-123\",
  \"MatterFile\": \"CB 12345\",
  \"MatterName\": \"Zoning Update\",
  \"MatterTitle\": \"An ordinance relating to zoning in downtown districts\",
  \"MatterTypeName\": \"Ordinance\",
  \"MatterStatusName\": \"Adopted\",
  \"MatterBodyName\": \"City Council\",
  \"MatterIntroDate\": \"2024-01-10T00:00:00\",
  \"MatterAgendaDate\": \"2024-02-15T00:00:00\",
  \"MatterPassedDate\": \"2024-03-01T00:00:00\",
  \"MatterEnactmentDate\": \"2024-03-15T00:00:00\",
  \"MatterEnactmentNumber\": \"ORD-2024-100\",
  \"MatterNotes\": \"Relates to downtown zoning changes\",
  \"MatterLastModifiedUtc\": \"2024-03-20T12:00:00\"
}
"

/// Minimal matter JSON with only required fields.
const minimal_matter_json = "
{
  \"MatterId\": 99999,
  \"MatterGuid\": \"min-guid-456\"
}
"

/// Matter with null optional fields.
const null_fields_matter_json = "
{
  \"MatterId\": 77777,
  \"MatterGuid\": \"null-guid-789\",
  \"MatterFile\": null,
  \"MatterName\": null,
  \"MatterTitle\": null,
  \"MatterTypeName\": null,
  \"MatterStatusName\": null,
  \"MatterBodyName\": null,
  \"MatterIntroDate\": null,
  \"MatterAgendaDate\": null,
  \"MatterPassedDate\": null,
  \"MatterEnactmentDate\": null,
  \"MatterEnactmentNumber\": null,
  \"MatterNotes\": null,
  \"MatterLastModifiedUtc\": null
}
"

/// Sponsor JSON.
const sponsor_json = "
{
  \"MatterSponsorName\": \"Council Member Smith\"
}
"

/// Empty matters array (pagination end signal).
const empty_matters_json = "[]"

pub fn decode_full_matter_test() {
  let assert Ok(matter) =
    json.parse(full_matter_json, legistar_types.matter_decoder())
  matter.matter_id |> should.equal(12_345)
  matter.matter_guid |> should.equal("abc-def-123")
  matter.matter_file |> should.equal(Some("CB 12345"))
  matter.matter_name |> should.equal(Some("Zoning Update"))
  matter.matter_title
  |> should.equal(Some("An ordinance relating to zoning in downtown districts"))
  matter.matter_type_name |> should.equal(Some("Ordinance"))
  matter.matter_status_name |> should.equal(Some("Adopted"))
  matter.matter_body_name |> should.equal(Some("City Council"))
  matter.matter_intro_date |> should.equal(Some("2024-01-10T00:00:00"))
  matter.matter_agenda_date |> should.equal(Some("2024-02-15T00:00:00"))
  matter.matter_passed_date |> should.equal(Some("2024-03-01T00:00:00"))
  matter.matter_enactment_date |> should.equal(Some("2024-03-15T00:00:00"))
  matter.matter_enactment_number |> should.equal(Some("ORD-2024-100"))
  matter.matter_notes
  |> should.equal(Some("Relates to downtown zoning changes"))
  matter.matter_last_modified_utc
  |> should.equal(Some("2024-03-20T12:00:00"))
}

pub fn decode_minimal_matter_test() {
  let assert Ok(matter) =
    json.parse(minimal_matter_json, legistar_types.matter_decoder())
  matter.matter_id |> should.equal(99_999)
  matter.matter_guid |> should.equal("min-guid-456")
  matter.matter_file |> should.equal(None)
  matter.matter_name |> should.equal(None)
  matter.matter_title |> should.equal(None)
  matter.matter_type_name |> should.equal(None)
  matter.matter_status_name |> should.equal(None)
  matter.matter_body_name |> should.equal(None)
  matter.matter_intro_date |> should.equal(None)
  matter.matter_notes |> should.equal(None)
}

pub fn decode_null_fields_matter_test() {
  let assert Ok(matter) =
    json.parse(null_fields_matter_json, legistar_types.matter_decoder())
  matter.matter_id |> should.equal(77_777)
  matter.matter_guid |> should.equal("null-guid-789")
  matter.matter_file |> should.equal(None)
  matter.matter_title |> should.equal(None)
  matter.matter_type_name |> should.equal(None)
  matter.matter_status_name |> should.equal(None)
  matter.matter_intro_date |> should.equal(None)
  matter.matter_passed_date |> should.equal(None)
  matter.matter_enactment_date |> should.equal(None)
  matter.matter_notes |> should.equal(None)
}

pub fn decode_sponsor_test() {
  let assert Ok(sponsor) =
    json.parse(sponsor_json, legistar_types.sponsor_decoder())
  sponsor.matter_sponsor_name |> should.equal("Council Member Smith")
}

pub fn decode_empty_matters_array_test() {
  let assert Ok(matters) =
    json.parse(empty_matters_json, legistar_types.matters_list_decoder())
  matters |> should.equal([])
}

pub fn decode_matters_array_test() {
  let array_json = "[" <> full_matter_json <> "," <> minimal_matter_json <> "]"
  let assert Ok(matters) =
    json.parse(array_json, legistar_types.matters_list_decoder())
  case matters {
    [first, second] -> {
      first.matter_id |> should.equal(12_345)
      second.matter_id |> should.equal(99_999)
    }
    _ -> should.fail()
  }
}

pub fn decode_sponsors_array_test() {
  let array_json =
    "[{\"MatterSponsorName\": \"Smith\"}, {\"MatterSponsorName\": \"Jones\"}]"
  let assert Ok(sponsors) =
    json.parse(array_json, legistar_types.sponsors_list_decoder())
  case sponsors {
    [first, second] -> {
      first.matter_sponsor_name |> should.equal("Smith")
      second.matter_sponsor_name |> should.equal("Jones")
    }
    _ -> should.fail()
  }
}

pub fn default_config_test() {
  let config = legistar_types.default_config("seattle", None)
  config.base_url |> should.equal("https://webapi.legistar.com")
  config.client_id |> should.equal("seattle")
  config.token |> should.equal(None)
}

pub fn default_config_with_token_test() {
  let config = legistar_types.default_config("chicago", Some("my-token"))
  config.client_id |> should.equal("chicago")
  config.token |> should.equal(Some("my-token"))
}
