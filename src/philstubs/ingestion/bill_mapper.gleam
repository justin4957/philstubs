import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string
import philstubs/core/government_level
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status.{type LegislationStatus}
import philstubs/core/legislation_type.{type LegislationType}
import philstubs/ingestion/congress_types.{
  type CongressBillDetail, type CongressBillListItem, type CongressLatestAction,
}

/// Build a deterministic legislation ID from congress number, bill type, and number.
pub fn build_legislation_id(
  congress: Int,
  bill_type: String,
  bill_number: String,
) -> String {
  "congress_gov-"
  <> int.to_string(congress)
  <> "-"
  <> string.lowercase(bill_type)
  <> "-"
  <> bill_number
}

/// Map a Congress.gov bill type string to a LegislationType.
pub fn map_bill_type(bill_type_string: String) -> LegislationType {
  case string.lowercase(bill_type_string) {
    "hr" | "s" -> legislation_type.Bill
    "hjres" | "sjres" | "hconres" | "sconres" | "hres" | "sres" ->
      legislation_type.Resolution
    _ -> legislation_type.Bill
  }
}

/// Infer a LegislationStatus from the latest action text.
pub fn infer_status_from_action(
  latest_action: Option(CongressLatestAction),
) -> LegislationStatus {
  case latest_action {
    None -> legislation_status.Introduced
    Some(action) -> infer_status_from_text(string.lowercase(action.text))
  }
}

fn infer_status_from_text(action_text: String) -> LegislationStatus {
  case
    string.contains(action_text, "became public law")
    || string.contains(action_text, "signed by president")
    || string.contains(action_text, "became law")
  {
    True -> legislation_status.Enacted
    False ->
      case string.contains(action_text, "vetoed") {
        True -> legislation_status.Vetoed
        False ->
          case
            string.contains(action_text, "passed house")
            || string.contains(action_text, "passed senate")
            || string.contains(action_text, "agreed to in")
            || string.contains(action_text, "passed/agreed to in")
          {
            True -> legislation_status.PassedChamber
            False ->
              case
                string.contains(action_text, "referred to")
                || string.contains(action_text, "committee")
              {
                True -> legislation_status.InCommittee
                False -> legislation_status.Introduced
              }
          }
      }
  }
}

/// Build a human-readable source identifier like "H.R. 1234" or "S. 456".
pub fn build_source_identifier(bill_type: String, bill_number: String) -> String {
  let prefix = case string.lowercase(bill_type) {
    "hr" -> "H.R."
    "s" -> "S."
    "hjres" -> "H.J.Res."
    "sjres" -> "S.J.Res."
    "hconres" -> "H.Con.Res."
    "sconres" -> "S.Con.Res."
    "hres" -> "H.Res."
    "sres" -> "S.Res."
    _ -> string.uppercase(bill_type) <> "."
  }
  prefix <> " " <> bill_number
}

/// Build the Congress.gov URL for a bill.
pub fn build_source_url(
  congress: Int,
  bill_type: String,
  bill_number: String,
) -> String {
  let chamber_path = case string.lowercase(bill_type) {
    "hr" | "hres" | "hjres" | "hconres" -> "house-bill"
    "s" | "sres" | "sjres" | "sconres" -> "senate-bill"
    _ -> "house-bill"
  }
  "https://www.congress.gov/bill/"
  <> int.to_string(congress)
  <> "th-congress/"
  <> chamber_path
  <> "/"
  <> bill_number
}

/// Map a CongressBillListItem to a Legislation record.
/// Uses only the data available from the list endpoint (no sponsors, no policyArea).
pub fn map_list_item_to_legislation(
  bill_item: CongressBillListItem,
) -> Legislation {
  let legislation_id =
    build_legislation_id(
      bill_item.congress,
      bill_item.bill_type,
      bill_item.number,
    )

  Legislation(
    id: legislation.legislation_id(legislation_id),
    title: bill_item.title,
    summary: "",
    body: "",
    level: government_level.Federal,
    legislation_type: map_bill_type(bill_item.bill_type),
    status: infer_status_from_action(bill_item.latest_action),
    introduced_date: "",
    source_url: Some(build_source_url(
      bill_item.congress,
      bill_item.bill_type,
      bill_item.number,
    )),
    source_identifier: build_source_identifier(
      bill_item.bill_type,
      bill_item.number,
    ),
    sponsors: [],
    topics: [],
  )
}

/// Map a CongressBillDetail to a Legislation record.
/// Includes full detail data: sponsors, policyArea, introducedDate.
pub fn map_detail_to_legislation(bill_detail: CongressBillDetail) -> Legislation {
  let legislation_id =
    build_legislation_id(
      bill_detail.congress,
      bill_detail.bill_type,
      bill_detail.number,
    )

  let sponsor_names =
    bill_detail.sponsors
    |> list_map_sponsor_names

  let topic_list = case bill_detail.policy_area {
    Some(area_name) -> [area_name]
    None -> []
  }

  Legislation(
    id: legislation.legislation_id(legislation_id),
    title: bill_detail.title,
    summary: "",
    body: "",
    level: government_level.Federal,
    legislation_type: map_bill_type(bill_detail.bill_type),
    status: infer_status_from_action(bill_detail.latest_action),
    introduced_date: bill_detail.introduced_date,
    source_url: Some(build_source_url(
      bill_detail.congress,
      bill_detail.bill_type,
      bill_detail.number,
    )),
    source_identifier: build_source_identifier(
      bill_detail.bill_type,
      bill_detail.number,
    ),
    sponsors: sponsor_names,
    topics: topic_list,
  )
}

fn list_map_sponsor_names(
  sponsors: List(congress_types.CongressSponsor),
) -> List(String) {
  case sponsors {
    [] -> []
    [sponsor, ..rest] -> [sponsor.full_name, ..list_map_sponsor_names(rest)]
  }
}
