import gleam/json
import gleam/option.{None, Some}
import gleeunit/should
import philstubs/ingestion/congress_types

// --- Canned JSON for testing ---

const sample_bill_list_json = "
{
  \"bills\": [
    {
      \"congress\": 118,
      \"latestAction\": {
        \"actionDate\": \"2024-01-15\",
        \"text\": \"Referred to the Committee on Energy and Commerce.\"
      },
      \"number\": \"1234\",
      \"originChamber\": \"House\",
      \"originChamberCode\": \"H\",
      \"title\": \"Clean Energy Innovation Act\",
      \"type\": \"HR\",
      \"updateDate\": \"2024-01-16T00:00:00Z\",
      \"updateDateIncludingText\": \"2024-01-16T00:00:00Z\",
      \"url\": \"https://api.congress.gov/v3/bill/118/hr/1234\"
    },
    {
      \"congress\": 118,
      \"number\": \"567\",
      \"originChamber\": \"Senate\",
      \"originChamberCode\": \"S\",
      \"title\": \"Rural Broadband Expansion Act\",
      \"type\": \"S\",
      \"updateDate\": \"2024-02-01T00:00:00Z\",
      \"updateDateIncludingText\": \"2024-02-01T00:00:00Z\",
      \"url\": \"https://api.congress.gov/v3/bill/118/s/567\"
    }
  ],
  \"pagination\": {
    \"count\": 10564,
    \"next\": \"https://api.congress.gov/v3/bill/118/hr?offset=20&limit=20\"
  }
}
"

const sample_bill_detail_json = "
{
  \"bill\": {
    \"congress\": 118,
    \"type\": \"HR\",
    \"number\": \"1234\",
    \"title\": \"Clean Energy Innovation Act\",
    \"introducedDate\": \"2024-01-10\",
    \"updateDate\": \"2024-01-16T00:00:00Z\",
    \"originChamber\": \"House\",
    \"latestAction\": {
      \"actionDate\": \"2024-01-15\",
      \"text\": \"Became Public Law No: 118-42.\"
    },
    \"sponsors\": [
      {
        \"bioguideId\": \"S001234\",
        \"district\": 5,
        \"firstName\": \"Jane\",
        \"fullName\": \"Rep. Smith, Jane [D-CA-5]\",
        \"isByRequest\": \"N\",
        \"lastName\": \"Smith\",
        \"party\": \"D\",
        \"state\": \"CA\",
        \"url\": \"https://api.congress.gov/v3/member/S001234\"
      }
    ],
    \"policyArea\": {
      \"name\": \"Energy\"
    }
  }
}
"

const sample_bill_detail_minimal_json = "
{
  \"bill\": {
    \"congress\": 118,
    \"type\": \"S\",
    \"number\": \"99\",
    \"title\": \"A bill with minimal fields\",
    \"introducedDate\": \"2024-03-01\",
    \"updateDate\": \"2024-03-02\",
    \"originChamber\": \"Senate\"
  }
}
"

// --- Bill list decoder tests ---

pub fn decode_bill_list_response_test() {
  let decoded =
    json.parse(
      sample_bill_list_json,
      congress_types.bill_list_response_decoder(),
    )

  let assert Ok(response) = decoded
  should.equal(list_length(response.bills), 2)

  // First bill has latestAction
  let assert [first_bill, ..] = response.bills
  first_bill.congress |> should.equal(118)
  first_bill.bill_type |> should.equal("HR")
  first_bill.number |> should.equal("1234")
  first_bill.title |> should.equal("Clean Energy Innovation Act")
  first_bill.origin_chamber |> should.equal("House")

  let assert Some(latest_action) = first_bill.latest_action
  latest_action.action_date |> should.equal("2024-01-15")
  latest_action.text
  |> should.equal("Referred to the Committee on Energy and Commerce.")

  // Pagination
  response.pagination.count |> should.equal(10_564)
  response.pagination.next
  |> should.equal(Some(
    "https://api.congress.gov/v3/bill/118/hr?offset=20&limit=20",
  ))
}

pub fn decode_bill_list_item_without_latest_action_test() {
  let decoded =
    json.parse(
      sample_bill_list_json,
      congress_types.bill_list_response_decoder(),
    )

  let assert Ok(response) = decoded
  let assert [_, second_bill] = response.bills

  // Second bill has no latestAction field
  second_bill.number |> should.equal("567")
  second_bill.bill_type |> should.equal("S")
  second_bill.latest_action |> should.equal(None)
}

// --- Bill detail decoder tests ---

pub fn decode_bill_detail_response_test() {
  let decoded =
    json.parse(
      sample_bill_detail_json,
      congress_types.bill_detail_response_decoder(),
    )

  let assert Ok(response) = decoded
  let bill = response.bill
  bill.congress |> should.equal(118)
  bill.bill_type |> should.equal("HR")
  bill.number |> should.equal("1234")
  bill.title |> should.equal("Clean Energy Innovation Act")
  bill.introduced_date |> should.equal("2024-01-10")
  bill.origin_chamber |> should.equal("House")

  // Sponsors
  should.equal(list_length(bill.sponsors), 1)
  let assert [sponsor] = bill.sponsors
  sponsor.full_name |> should.equal("Rep. Smith, Jane [D-CA-5]")
  sponsor.party |> should.equal(Some("D"))
  sponsor.state |> should.equal(Some("CA"))

  // Policy area
  bill.policy_area |> should.equal(Some("Energy"))

  // Latest action
  let assert Some(action) = bill.latest_action
  action.text |> should.equal("Became Public Law No: 118-42.")
}

pub fn decode_bill_detail_minimal_test() {
  let decoded =
    json.parse(
      sample_bill_detail_minimal_json,
      congress_types.bill_detail_response_decoder(),
    )

  let assert Ok(response) = decoded
  let bill = response.bill
  bill.congress |> should.equal(118)
  bill.bill_type |> should.equal("S")
  bill.number |> should.equal("99")
  bill.title |> should.equal("A bill with minimal fields")

  // Optional fields should default
  bill.latest_action |> should.equal(None)
  should.equal(list_length(bill.sponsors), 0)
  bill.policy_area |> should.equal(None)
}

// --- Latest action decoder test ---

pub fn decode_latest_action_test() {
  let action_json =
    "{\"actionDate\": \"2024-05-10\", \"text\": \"Signed by President.\"}"
  let decoded = json.parse(action_json, congress_types.latest_action_decoder())

  let assert Ok(action) = decoded
  action.action_date |> should.equal("2024-05-10")
  action.text |> should.equal("Signed by President.")
}

// --- Sponsor decoder test ---

pub fn decode_sponsor_test() {
  let sponsor_json =
    "{\"fullName\": \"Sen. Doe, John [R-TX]\", \"party\": \"R\", \"state\": \"TX\"}"
  let decoded = json.parse(sponsor_json, congress_types.sponsor_decoder())

  let assert Ok(sponsor) = decoded
  sponsor.full_name |> should.equal("Sen. Doe, John [R-TX]")
  sponsor.party |> should.equal(Some("R"))
  sponsor.state |> should.equal(Some("TX"))
}

pub fn decode_sponsor_minimal_test() {
  let sponsor_json = "{\"fullName\": \"Rep. Anonymous\"}"
  let decoded = json.parse(sponsor_json, congress_types.sponsor_decoder())

  let assert Ok(sponsor) = decoded
  sponsor.full_name |> should.equal("Rep. Anonymous")
  sponsor.party |> should.equal(None)
  sponsor.state |> should.equal(None)
}

// --- Bill type helper tests ---

pub fn bill_type_to_string_test() {
  congress_types.bill_type_to_string(congress_types.Hr)
  |> should.equal("hr")
  congress_types.bill_type_to_string(congress_types.S)
  |> should.equal("s")
  congress_types.bill_type_to_string(congress_types.Hjres)
  |> should.equal("hjres")
  congress_types.bill_type_to_string(congress_types.Sconres)
  |> should.equal("sconres")
}

pub fn all_bill_types_test() {
  let types = congress_types.all_bill_types()
  should.equal(list_length(types), 8)
}

// --- Config helper test ---

pub fn default_config_test() {
  let config = congress_types.default_config("test-key", 118)
  config.api_key |> should.equal("test-key")
  config.base_url |> should.equal("https://api.congress.gov/v3")
  config.congress_number |> should.equal(118)
}

// --- Pagination decoder test ---

pub fn decode_pagination_without_next_test() {
  let pagination_json = "{\"count\": 5}"
  let decoded = json.parse(pagination_json, congress_types.pagination_decoder())

  let assert Ok(pagination) = decoded
  pagination.count |> should.equal(5)
  pagination.next |> should.equal(None)
}

fn list_length(items: List(a)) -> Int {
  count_items(items, 0)
}

fn count_items(items: List(a), accumulator: Int) -> Int {
  case items {
    [] -> accumulator
    [_, ..rest] -> count_items(rest, accumulator + 1)
  }
}
