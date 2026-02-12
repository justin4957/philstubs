import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import philstubs/core/government_level
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status.{type LegislationStatus}
import philstubs/core/legislation_type.{type LegislationType}
import philstubs/ingestion/openstates_types.{
  type OpenStatesAction, type OpenStatesBill, type OpenStatesSponsorship,
}

/// Build a deterministic legislation ID from state code, session, and identifier.
pub fn build_legislation_id(
  state_code: String,
  session: String,
  identifier: String,
) -> String {
  let normalized_identifier =
    identifier
    |> string.replace(" ", "")
    |> string.replace(".", "")
  "openstates-"
  <> string.lowercase(state_code)
  <> "-"
  <> session
  <> "-"
  <> normalized_identifier
}

/// Extract the 2-letter state code from an Open States jurisdiction ID.
/// Format: "ocd-jurisdiction/country:us/state:ca/government" → "CA"
pub fn extract_state_code(jurisdiction_id: String) -> String {
  jurisdiction_id
  |> string.split("/")
  |> find_state_segment
}

fn find_state_segment(segments: List(String)) -> String {
  case segments {
    [] -> ""
    [segment, ..rest] ->
      case string.starts_with(segment, "state:") {
        True ->
          segment
          |> string.drop_start(6)
          |> string.uppercase
        False -> find_state_segment(rest)
      }
  }
}

/// Map a bill classification list to a LegislationType.
pub fn map_classification_to_type(
  classification: List(String),
) -> LegislationType {
  case classification {
    [] -> legislation_type.Bill
    [first, ..] ->
      case string.lowercase(first) {
        "bill" -> legislation_type.Bill
        "resolution" -> legislation_type.Resolution
        "joint resolution" -> legislation_type.Resolution
        "concurrent resolution" -> legislation_type.Resolution
        "memorial" -> legislation_type.Resolution
        _ -> legislation_type.Bill
      }
  }
}

/// Infer a LegislationStatus from the last action's classification list.
pub fn infer_status_from_actions(
  actions: List(OpenStatesAction),
) -> LegislationStatus {
  case last_action(actions) {
    None -> legislation_status.Introduced
    Some(action) -> infer_status_from_classification(action.classification)
  }
}

fn last_action(actions: List(OpenStatesAction)) -> Option(OpenStatesAction) {
  case actions {
    [] -> None
    [single] -> Some(single)
    [_, ..rest] -> last_action(rest)
  }
}

fn infer_status_from_classification(
  classification: List(String),
) -> LegislationStatus {
  case
    has_any_classification(classification, ["became-law", "executive-signature"])
  {
    True -> legislation_status.Enacted
    False ->
      case has_any_classification(classification, ["executive-veto"]) {
        True -> legislation_status.Vetoed
        False ->
          case has_any_classification(classification, ["passage"]) {
            True -> legislation_status.PassedChamber
            False ->
              case
                has_any_classification(classification, [
                  "committee-referral", "committee-passage",
                ])
              {
                True -> legislation_status.InCommittee
                False ->
                  case
                    has_any_classification(classification, [
                      "introduction", "reading-1",
                    ])
                  {
                    True -> legislation_status.Introduced
                    False -> legislation_status.Introduced
                  }
              }
          }
      }
  }
}

fn has_any_classification(
  action_classifications: List(String),
  target_classifications: List(String),
) -> Bool {
  list.any(action_classifications, fn(action_class) {
    list.contains(target_classifications, action_class)
  })
}

/// Extract sponsor names from a list of sponsorships.
pub fn extract_sponsor_names(
  sponsorships: List(OpenStatesSponsorship),
) -> List(String) {
  list.map(sponsorships, fn(sponsorship) {
    case sponsorship.person {
      Some(person) -> person.name
      None -> sponsorship.name
    }
  })
}

/// Extract the first abstract text from a bill's abstracts.
pub fn extract_summary(bill: OpenStatesBill) -> String {
  case bill.abstracts {
    [] -> ""
    [first_abstract, ..] -> first_abstract.abstract_text
  }
}

/// Map an OpenStatesBill to the domain Legislation type.
pub fn map_bill_to_legislation(bill: OpenStatesBill) -> Legislation {
  let state_code = extract_state_code(bill.jurisdiction.id)
  let legislation_id_string =
    build_legislation_id(state_code, bill.session, bill.identifier)

  let introduced_date = case bill.first_action_date {
    Some(date_value) -> date_value
    None -> ""
  }

  Legislation(
    id: legislation.legislation_id(legislation_id_string),
    title: bill.title,
    summary: extract_summary(bill),
    body: "",
    level: government_level.State(state_code),
    legislation_type: map_classification_to_type(bill.classification),
    status: infer_status_from_actions(bill.actions),
    introduced_date: introduced_date,
    source_url: Some(bill.openstates_url),
    source_identifier: bill.identifier,
    sponsors: extract_sponsor_names(bill.sponsorships),
    topics: bill.subject,
  )
}
