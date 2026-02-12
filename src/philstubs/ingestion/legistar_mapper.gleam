import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import philstubs/core/government_level.{type GovernmentLevel}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status.{type LegislationStatus}
import philstubs/core/legislation_type.{type LegislationType}
import philstubs/ingestion/legistar_types.{
  type LegistarMatter, type LegistarSponsor,
}

/// Build a deterministic legislation ID from client_id and matter_id.
/// Produces IDs like "legistar-seattle-12345".
pub fn build_legislation_id(client_id: String, matter_id: Int) -> String {
  "legistar-" <> client_id <> "-" <> int.to_string(matter_id)
}

/// Map a Legistar matter type name to a LegislationType.
pub fn map_matter_type(matter_type_name: Option(String)) -> LegislationType {
  case matter_type_name {
    None -> legislation_type.Bill
    Some(type_name) ->
      case string.lowercase(type_name) {
        "ordinance" -> legislation_type.Ordinance
        "resolution" -> legislation_type.Resolution
        "motion" -> legislation_type.Bill
        "executive order" -> legislation_type.ExecutiveOrder
        "amendment" -> legislation_type.Amendment
        "regulation" -> legislation_type.Regulation
        "bylaw" -> legislation_type.Bylaw
        _ -> legislation_type.Bill
      }
  }
}

/// Map a Legistar matter status name to a LegislationStatus.
pub fn map_matter_status(
  matter_status_name: Option(String),
) -> LegislationStatus {
  case matter_status_name {
    None -> legislation_status.Introduced
    Some(status_name) ->
      case string.lowercase(status_name) {
        "adopted" | "passed" | "signed" | "approved" | "enacted" ->
          legislation_status.Enacted
        "vetoed" -> legislation_status.Vetoed
        "referred" | "in committee" -> legislation_status.InCommittee
        "filed" | "introduced" -> legislation_status.Introduced
        "withdrawn" | "defeated" -> legislation_status.Withdrawn
        "expired" | "lapsed" -> legislation_status.Expired
        _ -> legislation_status.Introduced
      }
  }
}

/// Extract the title from a matter, using a fallback chain:
/// matter_title -> matter_name -> matter_file -> "Untitled"
pub fn extract_title(matter: LegistarMatter) -> String {
  case matter.matter_title {
    Some(title) if title != "" -> title
    _ ->
      case matter.matter_name {
        Some(name) if name != "" -> name
        _ ->
          case matter.matter_file {
            Some(file) if file != "" -> file
            _ -> "Untitled"
          }
      }
  }
}

/// Parse a Legistar date string, stripping the T00:00:00 suffix.
/// Input: "2024-01-10T00:00:00" -> Output: "2024-01-10"
pub fn parse_date(date_string: Option(String)) -> String {
  case date_string {
    None -> ""
    Some(date_value) ->
      case string.split(date_value, "T") {
        [date_part, ..] -> date_part
        _ -> date_value
      }
  }
}

/// Build the Legistar web URL for a matter.
pub fn build_source_url(client_id: String, matter_id: Int) -> String {
  "https://"
  <> client_id
  <> ".legistar.com/LegislationDetail.aspx?ID="
  <> int.to_string(matter_id)
}

/// Extract sponsor names from a list of LegistarSponsors.
pub fn extract_sponsor_names(sponsors: List(LegistarSponsor)) -> List(String) {
  list.map(sponsors, fn(sponsor) { sponsor.matter_sponsor_name })
}

/// Map a Legistar Matter plus sponsors to the domain Legislation type.
pub fn map_matter_to_legislation(
  matter: LegistarMatter,
  client_id: String,
  government_level: GovernmentLevel,
  sponsors: List(LegistarSponsor),
) -> Legislation {
  let legislation_id_string = build_legislation_id(client_id, matter.matter_id)

  let source_identifier = case matter.matter_file {
    Some(file) -> file
    None -> int.to_string(matter.matter_id)
  }

  let summary = case matter.matter_notes {
    Some(notes) -> notes
    None -> ""
  }

  Legislation(
    id: legislation.legislation_id(legislation_id_string),
    title: extract_title(matter),
    summary: summary,
    body: "",
    level: government_level,
    legislation_type: map_matter_type(matter.matter_type_name),
    status: map_matter_status(matter.matter_status_name),
    introduced_date: parse_date(matter.matter_intro_date),
    source_url: Some(build_source_url(client_id, matter.matter_id)),
    source_identifier: source_identifier,
    sponsors: extract_sponsor_names(sponsors),
    topics: [],
  )
}
