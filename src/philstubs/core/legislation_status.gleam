import gleam/dynamic/decode
import gleam/json

/// The lifecycle status of a piece of legislation. Tracks where
/// legislation stands in the democratic process.
pub type LegislationStatus {
  Introduced
  InCommittee
  PassedChamber
  Enacted
  Vetoed
  Expired
  Withdrawn
}

/// Convert a LegislationStatus to its display string.
pub fn to_string(status: LegislationStatus) -> String {
  case status {
    Introduced -> "Introduced"
    InCommittee -> "In Committee"
    PassedChamber -> "Passed Chamber"
    Enacted -> "Enacted"
    Vetoed -> "Vetoed"
    Expired -> "Expired"
    Withdrawn -> "Withdrawn"
  }
}

/// Encode a LegislationStatus to a JSON string value.
pub fn to_json(status: LegislationStatus) -> json.Json {
  json.string(to_json_string(status))
}

/// Decode a LegislationStatus from a JSON string.
pub fn decoder() -> decode.Decoder(LegislationStatus) {
  use value <- decode.then(decode.string)
  case value {
    "introduced" -> decode.success(Introduced)
    "in_committee" -> decode.success(InCommittee)
    "passed_chamber" -> decode.success(PassedChamber)
    "enacted" -> decode.success(Enacted)
    "vetoed" -> decode.success(Vetoed)
    "expired" -> decode.success(Expired)
    "withdrawn" -> decode.success(Withdrawn)
    _ -> decode.failure(Introduced, "LegislationStatus")
  }
}

fn to_json_string(status: LegislationStatus) -> String {
  case status {
    Introduced -> "introduced"
    InCommittee -> "in_committee"
    PassedChamber -> "passed_chamber"
    Enacted -> "enacted"
    Vetoed -> "vetoed"
    Expired -> "expired"
    Withdrawn -> "withdrawn"
  }
}
