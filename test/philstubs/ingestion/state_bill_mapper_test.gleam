import gleam/option.{None, Some}
import gleeunit/should
import philstubs/core/government_level
import philstubs/core/legislation
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/ingestion/openstates_types.{
  type OpenStatesBill, type OpenStatesJurisdiction, OpenStatesAbstract,
  OpenStatesAction, OpenStatesBill, OpenStatesJurisdiction, OpenStatesPerson,
  OpenStatesSponsorship,
}
import philstubs/ingestion/state_bill_mapper

fn sample_jurisdiction() -> OpenStatesJurisdiction {
  OpenStatesJurisdiction(
    id: "ocd-jurisdiction/country:us/state:ca/government",
    name: "California",
    classification: "state",
  )
}

fn sample_bill() -> OpenStatesBill {
  OpenStatesBill(
    id: "ocd-bill/abc123",
    session: "20252026",
    jurisdiction: sample_jurisdiction(),
    identifier: "SB 1038",
    title: "Education Funding Act",
    classification: ["bill"],
    subject: ["Education", "Budget"],
    openstates_url: "https://openstates.org/ca/bills/20252026/SB1038/",
    first_action_date: Some("2025-01-15"),
    latest_action_date: Some("2025-03-10"),
    latest_action_description: Some("Referred to Committee on Education"),
    abstracts: [
      OpenStatesAbstract(
        abstract_text: "An act relating to education funding.",
        note: Some("As introduced"),
      ),
    ],
    sponsorships: [
      OpenStatesSponsorship(
        name: "Jane Smith",
        primary: True,
        classification: "primary",
        person: Some(OpenStatesPerson(
          name: "Jane Smith",
          party: Some("Democratic"),
        )),
      ),
    ],
    actions: [
      OpenStatesAction(
        description: "Introduced",
        date: "2025-01-15",
        classification: ["introduction"],
      ),
      OpenStatesAction(
        description: "Referred to Committee on Education",
        date: "2025-01-20",
        classification: ["committee-referral"],
      ),
    ],
  )
}

pub fn build_legislation_id_test() {
  state_bill_mapper.build_legislation_id("CA", "20252026", "SB 1038")
  |> should.equal("openstates-ca-20252026-SB1038")
}

pub fn build_legislation_id_house_bill_test() {
  state_bill_mapper.build_legislation_id("TX", "2025", "HB 100")
  |> should.equal("openstates-tx-2025-HB100")
}

pub fn extract_state_code_california_test() {
  state_bill_mapper.extract_state_code(
    "ocd-jurisdiction/country:us/state:ca/government",
  )
  |> should.equal("CA")
}

pub fn extract_state_code_texas_test() {
  state_bill_mapper.extract_state_code(
    "ocd-jurisdiction/country:us/state:tx/government",
  )
  |> should.equal("TX")
}

pub fn extract_state_code_new_york_test() {
  state_bill_mapper.extract_state_code(
    "ocd-jurisdiction/country:us/state:ny/government",
  )
  |> should.equal("NY")
}

pub fn extract_state_code_empty_test() {
  state_bill_mapper.extract_state_code("no-state-here")
  |> should.equal("")
}

pub fn map_classification_bill_test() {
  state_bill_mapper.map_classification_to_type(["bill"])
  |> should.equal(legislation_type.Bill)
}

pub fn map_classification_resolution_test() {
  state_bill_mapper.map_classification_to_type(["resolution"])
  |> should.equal(legislation_type.Resolution)
}

pub fn map_classification_joint_resolution_test() {
  state_bill_mapper.map_classification_to_type(["joint resolution"])
  |> should.equal(legislation_type.Resolution)
}

pub fn map_classification_concurrent_resolution_test() {
  state_bill_mapper.map_classification_to_type(["concurrent resolution"])
  |> should.equal(legislation_type.Resolution)
}

pub fn map_classification_empty_test() {
  state_bill_mapper.map_classification_to_type([])
  |> should.equal(legislation_type.Bill)
}

pub fn map_classification_unknown_test() {
  state_bill_mapper.map_classification_to_type(["unknown_type"])
  |> should.equal(legislation_type.Bill)
}

pub fn infer_status_enacted_test() {
  let actions = [
    OpenStatesAction(
      description: "Signed by governor",
      date: "2025-03-01",
      classification: ["became-law"],
    ),
  ]
  state_bill_mapper.infer_status_from_actions(actions)
  |> should.equal(legislation_status.Enacted)
}

pub fn infer_status_executive_signature_test() {
  let actions = [
    OpenStatesAction(
      description: "Signed by governor",
      date: "2025-03-01",
      classification: ["executive-signature"],
    ),
  ]
  state_bill_mapper.infer_status_from_actions(actions)
  |> should.equal(legislation_status.Enacted)
}

pub fn infer_status_vetoed_test() {
  let actions = [
    OpenStatesAction(
      description: "Vetoed by governor",
      date: "2025-03-01",
      classification: ["executive-veto"],
    ),
  ]
  state_bill_mapper.infer_status_from_actions(actions)
  |> should.equal(legislation_status.Vetoed)
}

pub fn infer_status_passed_chamber_test() {
  let actions = [
    OpenStatesAction(
      description: "Passed Senate",
      date: "2025-02-15",
      classification: ["passage"],
    ),
  ]
  state_bill_mapper.infer_status_from_actions(actions)
  |> should.equal(legislation_status.PassedChamber)
}

pub fn infer_status_in_committee_test() {
  let actions = [
    OpenStatesAction(
      description: "Referred to Committee",
      date: "2025-01-20",
      classification: ["committee-referral"],
    ),
  ]
  state_bill_mapper.infer_status_from_actions(actions)
  |> should.equal(legislation_status.InCommittee)
}

pub fn infer_status_committee_passage_test() {
  let actions = [
    OpenStatesAction(
      description: "Passed out of committee",
      date: "2025-02-01",
      classification: ["committee-passage"],
    ),
  ]
  state_bill_mapper.infer_status_from_actions(actions)
  |> should.equal(legislation_status.InCommittee)
}

pub fn infer_status_introduced_test() {
  let actions = [
    OpenStatesAction(
      description: "Introduced",
      date: "2025-01-15",
      classification: ["introduction"],
    ),
  ]
  state_bill_mapper.infer_status_from_actions(actions)
  |> should.equal(legislation_status.Introduced)
}

pub fn infer_status_no_actions_test() {
  state_bill_mapper.infer_status_from_actions([])
  |> should.equal(legislation_status.Introduced)
}

pub fn infer_status_uses_last_action_test() {
  let actions = [
    OpenStatesAction(
      description: "Introduced",
      date: "2025-01-15",
      classification: ["introduction"],
    ),
    OpenStatesAction(
      description: "Passed Senate",
      date: "2025-02-15",
      classification: ["passage"],
    ),
  ]
  state_bill_mapper.infer_status_from_actions(actions)
  |> should.equal(legislation_status.PassedChamber)
}

pub fn extract_sponsor_names_with_person_test() {
  let sponsorships = [
    OpenStatesSponsorship(
      name: "Sen. Smith",
      primary: True,
      classification: "primary",
      person: Some(OpenStatesPerson(
        name: "Jane Smith",
        party: Some("Democratic"),
      )),
    ),
  ]
  state_bill_mapper.extract_sponsor_names(sponsorships)
  |> should.equal(["Jane Smith"])
}

pub fn extract_sponsor_names_without_person_test() {
  let sponsorships = [
    OpenStatesSponsorship(
      name: "Committee on Education",
      primary: False,
      classification: "cosponsor",
      person: None,
    ),
  ]
  state_bill_mapper.extract_sponsor_names(sponsorships)
  |> should.equal(["Committee on Education"])
}

pub fn extract_sponsor_names_mixed_test() {
  let sponsorships = [
    OpenStatesSponsorship(
      name: "Sen. Smith",
      primary: True,
      classification: "primary",
      person: Some(OpenStatesPerson(name: "Jane Smith", party: None)),
    ),
    OpenStatesSponsorship(
      name: "Committee on Finance",
      primary: False,
      classification: "cosponsor",
      person: None,
    ),
  ]
  state_bill_mapper.extract_sponsor_names(sponsorships)
  |> should.equal(["Jane Smith", "Committee on Finance"])
}

pub fn extract_summary_test() {
  let bill = sample_bill()
  state_bill_mapper.extract_summary(bill)
  |> should.equal("An act relating to education funding.")
}

pub fn extract_summary_empty_test() {
  let bill = OpenStatesBill(..sample_bill(), abstracts: [])
  state_bill_mapper.extract_summary(bill)
  |> should.equal("")
}

pub fn map_bill_to_legislation_test() {
  let bill = sample_bill()
  let legislation_record = state_bill_mapper.map_bill_to_legislation(bill)

  legislation.legislation_id_to_string(legislation_record.id)
  |> should.equal("openstates-ca-20252026-SB1038")

  legislation_record.title |> should.equal("Education Funding Act")
  legislation_record.summary
  |> should.equal("An act relating to education funding.")
  legislation_record.body |> should.equal("")
  legislation_record.level |> should.equal(government_level.State("CA"))
  legislation_record.legislation_type |> should.equal(legislation_type.Bill)
  legislation_record.status |> should.equal(legislation_status.InCommittee)
  legislation_record.introduced_date |> should.equal("2025-01-15")
  legislation_record.source_url
  |> should.equal(Some("https://openstates.org/ca/bills/20252026/SB1038/"))
  legislation_record.source_identifier |> should.equal("SB 1038")
  legislation_record.sponsors |> should.equal(["Jane Smith"])
  legislation_record.topics |> should.equal(["Education", "Budget"])
}

pub fn map_bill_resolution_type_test() {
  let bill =
    OpenStatesBill(
      ..sample_bill(),
      classification: ["resolution"],
      identifier: "SR 42",
    )
  let legislation_record = state_bill_mapper.map_bill_to_legislation(bill)

  legislation_record.legislation_type
  |> should.equal(legislation_type.Resolution)
}

pub fn map_bill_no_abstracts_test() {
  let bill = OpenStatesBill(..sample_bill(), abstracts: [])
  let legislation_record = state_bill_mapper.map_bill_to_legislation(bill)

  legislation_record.summary |> should.equal("")
}

pub fn map_bill_no_first_action_date_test() {
  let bill = OpenStatesBill(..sample_bill(), first_action_date: None)
  let legislation_record = state_bill_mapper.map_bill_to_legislation(bill)

  legislation_record.introduced_date |> should.equal("")
}
