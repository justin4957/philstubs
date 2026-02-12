import gleam/list
import gleam/option.{type Option, None, Some}
import philstubs/core/government_level.{type GovernmentLevel}

/// A registered Legistar jurisdiction with its government level and metadata.
pub type JurisdictionEntry {
  JurisdictionEntry(
    client_id: String,
    display_name: String,
    government_level: GovernmentLevel,
    requires_token: Bool,
  )
}

/// All known Legistar jurisdictions.
/// These are well-known public Legistar clients that can be ingested
/// without an API token (unless requires_token is True).
pub fn all_jurisdictions() -> List(JurisdictionEntry) {
  [
    JurisdictionEntry(
      client_id: "seattle",
      display_name: "Seattle",
      government_level: government_level.Municipal("WA", "Seattle"),
      requires_token: False,
    ),
    JurisdictionEntry(
      client_id: "chicago",
      display_name: "Chicago",
      government_level: government_level.Municipal("IL", "Chicago"),
      requires_token: False,
    ),
    JurisdictionEntry(
      client_id: "portland",
      display_name: "Portland",
      government_level: government_level.Municipal("OR", "Portland"),
      requires_token: False,
    ),
    JurisdictionEntry(
      client_id: "baltimore",
      display_name: "Baltimore",
      government_level: government_level.Municipal("MD", "Baltimore"),
      requires_token: False,
    ),
    JurisdictionEntry(
      client_id: "kingcounty",
      display_name: "King County",
      government_level: government_level.County("WA", "King County"),
      requires_token: False,
    ),
    JurisdictionEntry(
      client_id: "cookcounty",
      display_name: "Cook County",
      government_level: government_level.County("IL", "Cook County"),
      requires_token: False,
    ),
  ]
}

/// Look up a jurisdiction by its Legistar client ID.
pub fn get_by_client_id(client_id: String) -> Option(JurisdictionEntry) {
  all_jurisdictions()
  |> list.find(fn(entry) { entry.client_id == client_id })
  |> option_from_result
}

fn option_from_result(
  result_value: Result(JurisdictionEntry, Nil),
) -> Option(JurisdictionEntry) {
  case result_value {
    Ok(entry) -> Some(entry)
    Error(Nil) -> None
  }
}
