import gleam/option.{None, Some}
import gleeunit/should
import philstubs/core/government_level
import philstubs/core/legislation
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/ingestion/bill_mapper
import philstubs/ingestion/congress_types.{
  CongressBillDetail, CongressBillListItem, CongressLatestAction,
  CongressSponsor,
}

// --- build_legislation_id tests ---

pub fn build_legislation_id_test() {
  bill_mapper.build_legislation_id(118, "HR", "1234")
  |> should.equal("congress_gov-118-hr-1234")
}

pub fn build_legislation_id_senate_test() {
  bill_mapper.build_legislation_id(117, "S", "42")
  |> should.equal("congress_gov-117-s-42")
}

// --- map_bill_type tests ---

pub fn map_bill_type_hr_test() {
  bill_mapper.map_bill_type("HR")
  |> should.equal(legislation_type.Bill)
}

pub fn map_bill_type_s_test() {
  bill_mapper.map_bill_type("S")
  |> should.equal(legislation_type.Bill)
}

pub fn map_bill_type_hjres_test() {
  bill_mapper.map_bill_type("HJRES")
  |> should.equal(legislation_type.Resolution)
}

pub fn map_bill_type_sconres_test() {
  bill_mapper.map_bill_type("SCONRES")
  |> should.equal(legislation_type.Resolution)
}

pub fn map_bill_type_unknown_test() {
  bill_mapper.map_bill_type("UNKNOWN")
  |> should.equal(legislation_type.Bill)
}

// --- infer_status_from_action tests ---

pub fn infer_status_none_test() {
  bill_mapper.infer_status_from_action(None)
  |> should.equal(legislation_status.Introduced)
}

pub fn infer_status_became_law_test() {
  let action =
    CongressLatestAction(
      action_date: "2024-01-01",
      text: "Became Public Law No: 118-42.",
    )
  bill_mapper.infer_status_from_action(Some(action))
  |> should.equal(legislation_status.Enacted)
}

pub fn infer_status_signed_by_president_test() {
  let action =
    CongressLatestAction(
      action_date: "2024-01-01",
      text: "Signed by President.",
    )
  bill_mapper.infer_status_from_action(Some(action))
  |> should.equal(legislation_status.Enacted)
}

pub fn infer_status_vetoed_test() {
  let action =
    CongressLatestAction(
      action_date: "2024-01-01",
      text: "Vetoed by the President.",
    )
  bill_mapper.infer_status_from_action(Some(action))
  |> should.equal(legislation_status.Vetoed)
}

pub fn infer_status_passed_house_test() {
  let action =
    CongressLatestAction(
      action_date: "2024-01-01",
      text: "Passed House by voice vote.",
    )
  bill_mapper.infer_status_from_action(Some(action))
  |> should.equal(legislation_status.PassedChamber)
}

pub fn infer_status_passed_senate_test() {
  let action =
    CongressLatestAction(
      action_date: "2024-01-01",
      text: "Passed Senate with amendments.",
    )
  bill_mapper.infer_status_from_action(Some(action))
  |> should.equal(legislation_status.PassedChamber)
}

pub fn infer_status_referred_to_committee_test() {
  let action =
    CongressLatestAction(
      action_date: "2024-01-01",
      text: "Referred to the Committee on Energy and Commerce.",
    )
  bill_mapper.infer_status_from_action(Some(action))
  |> should.equal(legislation_status.InCommittee)
}

pub fn infer_status_committee_keyword_test() {
  let action =
    CongressLatestAction(
      action_date: "2024-01-01",
      text: "Ordered to be reported by the Committee on Finance.",
    )
  bill_mapper.infer_status_from_action(Some(action))
  |> should.equal(legislation_status.InCommittee)
}

pub fn infer_status_introduced_fallback_test() {
  let action =
    CongressLatestAction(
      action_date: "2024-01-01",
      text: "Sponsor introductory remarks on measure.",
    )
  bill_mapper.infer_status_from_action(Some(action))
  |> should.equal(legislation_status.Introduced)
}

// --- build_source_identifier tests ---

pub fn build_source_identifier_hr_test() {
  bill_mapper.build_source_identifier("HR", "1234")
  |> should.equal("H.R. 1234")
}

pub fn build_source_identifier_s_test() {
  bill_mapper.build_source_identifier("S", "456")
  |> should.equal("S. 456")
}

pub fn build_source_identifier_hjres_test() {
  bill_mapper.build_source_identifier("HJRES", "10")
  |> should.equal("H.J.Res. 10")
}

pub fn build_source_identifier_sconres_test() {
  bill_mapper.build_source_identifier("SCONRES", "7")
  |> should.equal("S.Con.Res. 7")
}

// --- build_source_url tests ---

pub fn build_source_url_hr_test() {
  bill_mapper.build_source_url(118, "HR", "1234")
  |> should.equal(
    "https://www.congress.gov/bill/118th-congress/house-bill/1234",
  )
}

pub fn build_source_url_s_test() {
  bill_mapper.build_source_url(117, "S", "99")
  |> should.equal("https://www.congress.gov/bill/117th-congress/senate-bill/99")
}

// --- map_list_item_to_legislation tests ---

pub fn map_list_item_to_legislation_test() {
  let bill_item =
    CongressBillListItem(
      congress: 118,
      bill_type: "HR",
      number: "1234",
      title: "Clean Energy Act",
      url: "https://api.congress.gov/v3/bill/118/hr/1234",
      update_date: "2024-01-16T00:00:00Z",
      origin_chamber: "House",
      latest_action: Some(CongressLatestAction(
        action_date: "2024-01-15",
        text: "Referred to the Committee on Energy and Commerce.",
      )),
    )

  let result = bill_mapper.map_list_item_to_legislation(bill_item)

  legislation.legislation_id_to_string(result.id)
  |> should.equal("congress_gov-118-hr-1234")
  result.title |> should.equal("Clean Energy Act")
  result.level |> should.equal(government_level.Federal)
  result.legislation_type |> should.equal(legislation_type.Bill)
  result.status |> should.equal(legislation_status.InCommittee)
  result.source_identifier |> should.equal("H.R. 1234")
  result.source_url
  |> should.equal(Some(
    "https://www.congress.gov/bill/118th-congress/house-bill/1234",
  ))
  result.sponsors |> should.equal([])
  result.topics |> should.equal([])
}

// --- map_detail_to_legislation tests ---

pub fn map_detail_to_legislation_test() {
  let bill_detail =
    CongressBillDetail(
      congress: 118,
      bill_type: "HR",
      number: "1234",
      title: "Clean Energy Innovation Act",
      introduced_date: "2024-01-10",
      update_date: "2024-01-16T00:00:00Z",
      origin_chamber: "House",
      latest_action: Some(CongressLatestAction(
        action_date: "2024-01-15",
        text: "Became Public Law No: 118-42.",
      )),
      sponsors: [
        CongressSponsor(
          full_name: "Rep. Smith, Jane [D-CA-5]",
          party: Some("D"),
          state: Some("CA"),
        ),
      ],
      policy_area: Some("Energy"),
    )

  let result = bill_mapper.map_detail_to_legislation(bill_detail)

  legislation.legislation_id_to_string(result.id)
  |> should.equal("congress_gov-118-hr-1234")
  result.title |> should.equal("Clean Energy Innovation Act")
  result.level |> should.equal(government_level.Federal)
  result.legislation_type |> should.equal(legislation_type.Bill)
  result.status |> should.equal(legislation_status.Enacted)
  result.introduced_date |> should.equal("2024-01-10")
  result.source_identifier |> should.equal("H.R. 1234")
  result.sponsors |> should.equal(["Rep. Smith, Jane [D-CA-5]"])
  result.topics |> should.equal(["Energy"])
}

pub fn map_detail_to_legislation_no_policy_area_test() {
  let bill_detail =
    CongressBillDetail(
      congress: 118,
      bill_type: "S",
      number: "99",
      title: "Minimal Bill",
      introduced_date: "2024-03-01",
      update_date: "2024-03-02",
      origin_chamber: "Senate",
      latest_action: None,
      sponsors: [],
      policy_area: None,
    )

  let result = bill_mapper.map_detail_to_legislation(bill_detail)

  result.status |> should.equal(legislation_status.Introduced)
  result.sponsors |> should.equal([])
  result.topics |> should.equal([])
}

pub fn map_list_item_resolution_type_test() {
  let bill_item =
    CongressBillListItem(
      congress: 118,
      bill_type: "HJRES",
      number: "5",
      title: "Joint Resolution",
      url: "https://api.congress.gov/v3/bill/118/hjres/5",
      update_date: "2024-01-01",
      origin_chamber: "House",
      latest_action: None,
    )

  let result = bill_mapper.map_list_item_to_legislation(bill_item)
  result.legislation_type |> should.equal(legislation_type.Resolution)
  result.source_identifier |> should.equal("H.J.Res. 5")
}
