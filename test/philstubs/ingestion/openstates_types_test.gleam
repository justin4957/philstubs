import gleam/json
import gleam/option.{None, Some}
import gleeunit/should
import philstubs/ingestion/openstates_types

pub fn decode_jurisdiction_test() {
  let jurisdiction_json =
    "{
    \"id\": \"ocd-jurisdiction/country:us/state:ca/government\",
    \"name\": \"California\",
    \"classification\": \"state\"
  }"

  let assert Ok(jurisdiction) =
    json.parse(jurisdiction_json, openstates_types.jurisdiction_decoder())

  jurisdiction.id
  |> should.equal("ocd-jurisdiction/country:us/state:ca/government")
  jurisdiction.name |> should.equal("California")
  jurisdiction.classification |> should.equal("state")
}

pub fn decode_person_test() {
  let person_json =
    "{
    \"name\": \"Jane Smith\",
    \"party\": \"Democratic\"
  }"

  let assert Ok(person) =
    json.parse(person_json, openstates_types.person_decoder())

  person.name |> should.equal("Jane Smith")
  person.party |> should.equal(Some("Democratic"))
}

pub fn decode_person_minimal_test() {
  let person_json = "{\"name\": \"John Doe\"}"

  let assert Ok(person) =
    json.parse(person_json, openstates_types.person_decoder())

  person.name |> should.equal("John Doe")
  person.party |> should.equal(None)
}

pub fn decode_sponsorship_test() {
  let sponsorship_json =
    "{
    \"name\": \"Jane Smith\",
    \"primary\": true,
    \"classification\": \"primary\",
    \"person\": {
      \"name\": \"Jane Smith\",
      \"party\": \"Democratic\"
    }
  }"

  let assert Ok(sponsorship) =
    json.parse(sponsorship_json, openstates_types.sponsorship_decoder())

  sponsorship.name |> should.equal("Jane Smith")
  sponsorship.primary |> should.equal(True)
  sponsorship.classification |> should.equal("primary")
  let assert Some(person) = sponsorship.person
  person.name |> should.equal("Jane Smith")
}

pub fn decode_sponsorship_without_person_test() {
  let sponsorship_json =
    "{
    \"name\": \"Committee on Education\",
    \"primary\": false,
    \"classification\": \"cosponsor\"
  }"

  let assert Ok(sponsorship) =
    json.parse(sponsorship_json, openstates_types.sponsorship_decoder())

  sponsorship.name |> should.equal("Committee on Education")
  sponsorship.primary |> should.equal(False)
  sponsorship.person |> should.equal(None)
}

pub fn decode_abstract_test() {
  let abstract_json =
    "{
    \"abstract\": \"An act relating to education funding.\",
    \"note\": \"As introduced\"
  }"

  let assert Ok(abstract_record) =
    json.parse(abstract_json, openstates_types.abstract_decoder())

  abstract_record.abstract_text
  |> should.equal("An act relating to education funding.")
  abstract_record.note |> should.equal(Some("As introduced"))
}

pub fn decode_abstract_without_note_test() {
  let abstract_json = "{\"abstract\": \"Summary text here.\"}"

  let assert Ok(abstract_record) =
    json.parse(abstract_json, openstates_types.abstract_decoder())

  abstract_record.abstract_text |> should.equal("Summary text here.")
  abstract_record.note |> should.equal(None)
}

pub fn decode_action_test() {
  let action_json =
    "{
    \"description\": \"Referred to Committee on Education\",
    \"date\": \"2025-01-15\",
    \"classification\": [\"committee-referral\"]
  }"

  let assert Ok(action) =
    json.parse(action_json, openstates_types.action_decoder())

  action.description
  |> should.equal("Referred to Committee on Education")
  action.date |> should.equal("2025-01-15")
  action.classification |> should.equal(["committee-referral"])
}

pub fn decode_action_without_classification_test() {
  let action_json =
    "{
    \"description\": \"Read first time\",
    \"date\": \"2025-01-10\"
  }"

  let assert Ok(action) =
    json.parse(action_json, openstates_types.action_decoder())

  action.description |> should.equal("Read first time")
  action.classification |> should.equal([])
}

pub fn decode_pagination_test() {
  let pagination_json =
    "{
    \"per_page\": 20,
    \"page\": 1,
    \"max_page\": 5,
    \"total_items\": 93
  }"

  let assert Ok(pagination) =
    json.parse(pagination_json, openstates_types.pagination_decoder())

  pagination.per_page |> should.equal(20)
  pagination.page |> should.equal(1)
  pagination.max_page |> should.equal(5)
  pagination.total_items |> should.equal(93)
}

pub fn decode_bill_test() {
  let bill_json =
    "{
    \"id\": \"ocd-bill/abc123\",
    \"session\": \"20252026\",
    \"jurisdiction\": {
      \"id\": \"ocd-jurisdiction/country:us/state:ca/government\",
      \"name\": \"California\",
      \"classification\": \"state\"
    },
    \"identifier\": \"SB 1038\",
    \"title\": \"Education Funding Act\",
    \"classification\": [\"bill\"],
    \"subject\": [\"Education\", \"Budget\"],
    \"openstates_url\": \"https://openstates.org/ca/bills/20252026/SB1038/\",
    \"first_action_date\": \"2025-01-15\",
    \"latest_action_date\": \"2025-03-10\",
    \"latest_action_description\": \"Referred to Committee on Education\",
    \"abstracts\": [
      {\"abstract\": \"An act relating to education funding.\", \"note\": \"As introduced\"}
    ],
    \"sponsorships\": [
      {
        \"name\": \"Jane Smith\",
        \"primary\": true,
        \"classification\": \"primary\",
        \"person\": {\"name\": \"Jane Smith\", \"party\": \"Democratic\"}
      }
    ],
    \"actions\": [
      {
        \"description\": \"Introduced\",
        \"date\": \"2025-01-15\",
        \"classification\": [\"introduction\"]
      },
      {
        \"description\": \"Referred to Committee on Education\",
        \"date\": \"2025-01-20\",
        \"classification\": [\"committee-referral\"]
      }
    ]
  }"

  let assert Ok(bill) = json.parse(bill_json, openstates_types.bill_decoder())

  bill.id |> should.equal("ocd-bill/abc123")
  bill.session |> should.equal("20252026")
  bill.jurisdiction.name |> should.equal("California")
  bill.identifier |> should.equal("SB 1038")
  bill.title |> should.equal("Education Funding Act")
  bill.classification |> should.equal(["bill"])
  bill.subject |> should.equal(["Education", "Budget"])
  bill.first_action_date |> should.equal(Some("2025-01-15"))
  bill.latest_action_date |> should.equal(Some("2025-03-10"))

  let assert [abstract_record] = bill.abstracts
  abstract_record.abstract_text
  |> should.equal("An act relating to education funding.")

  let assert [sponsorship] = bill.sponsorships
  sponsorship.name |> should.equal("Jane Smith")
  sponsorship.primary |> should.equal(True)

  let assert [_introduction_action, referral_action] = bill.actions
  referral_action.classification |> should.equal(["committee-referral"])
}

pub fn decode_bill_minimal_test() {
  let bill_json =
    "{
    \"id\": \"ocd-bill/minimal\",
    \"session\": \"2025\",
    \"jurisdiction\": {
      \"id\": \"ocd-jurisdiction/country:us/state:tx/government\",
      \"name\": \"Texas\",
      \"classification\": \"state\"
    },
    \"identifier\": \"HB 100\",
    \"title\": \"Minimal Bill\",
    \"openstates_url\": \"https://openstates.org/tx/bills/2025/HB100/\"
  }"

  let assert Ok(bill) = json.parse(bill_json, openstates_types.bill_decoder())

  bill.id |> should.equal("ocd-bill/minimal")
  bill.classification |> should.equal([])
  bill.subject |> should.equal([])
  bill.first_action_date |> should.equal(None)
  bill.abstracts |> should.equal([])
  bill.sponsorships |> should.equal([])
  bill.actions |> should.equal([])
}

pub fn decode_bill_list_response_test() {
  let response_json =
    "{
    \"results\": [
      {
        \"id\": \"ocd-bill/bill1\",
        \"session\": \"20252026\",
        \"jurisdiction\": {
          \"id\": \"ocd-jurisdiction/country:us/state:ca/government\",
          \"name\": \"California\",
          \"classification\": \"state\"
        },
        \"identifier\": \"SB 100\",
        \"title\": \"Test Bill\",
        \"openstates_url\": \"https://openstates.org/ca/bills/20252026/SB100/\"
      }
    ],
    \"pagination\": {
      \"per_page\": 20,
      \"page\": 1,
      \"max_page\": 3,
      \"total_items\": 50
    }
  }"

  let assert Ok(bill_list_response) =
    json.parse(response_json, openstates_types.bill_list_response_decoder())

  let assert [first_bill] = bill_list_response.results
  first_bill.identifier |> should.equal("SB 100")
  bill_list_response.pagination.max_page |> should.equal(3)
  bill_list_response.pagination.total_items |> should.equal(50)
}

pub fn default_config_test() {
  let config = openstates_types.default_config("test-api-key")

  config.api_key |> should.equal("test-api-key")
  config.base_url |> should.equal("https://v3.openstates.org")
}
