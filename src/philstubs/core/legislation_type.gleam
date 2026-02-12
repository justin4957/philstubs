import gleam/dynamic/decode
import gleam/json

/// The form of a piece of legislation. Aligns with common legislative
/// categories across federal, state, and local government.
pub type LegislationType {
  Bill
  Resolution
  Ordinance
  Bylaw
  Amendment
  Regulation
  ExecutiveOrder
}

/// Convert a LegislationType to its display string.
pub fn to_string(legislation_type: LegislationType) -> String {
  case legislation_type {
    Bill -> "Bill"
    Resolution -> "Resolution"
    Ordinance -> "Ordinance"
    Bylaw -> "Bylaw"
    Amendment -> "Amendment"
    Regulation -> "Regulation"
    ExecutiveOrder -> "Executive Order"
  }
}

/// Encode a LegislationType to a JSON string value.
pub fn to_json(legislation_type: LegislationType) -> json.Json {
  json.string(to_json_string(legislation_type))
}

/// Decode a LegislationType from a JSON string.
pub fn decoder() -> decode.Decoder(LegislationType) {
  use value <- decode.then(decode.string)
  case value {
    "bill" -> decode.success(Bill)
    "resolution" -> decode.success(Resolution)
    "ordinance" -> decode.success(Ordinance)
    "bylaw" -> decode.success(Bylaw)
    "amendment" -> decode.success(Amendment)
    "regulation" -> decode.success(Regulation)
    "executive_order" -> decode.success(ExecutiveOrder)
    _ -> decode.failure(Bill, "LegislationType")
  }
}

fn to_json_string(legislation_type: LegislationType) -> String {
  case legislation_type {
    Bill -> "bill"
    Resolution -> "resolution"
    Ordinance -> "ordinance"
    Bylaw -> "bylaw"
    Amendment -> "amendment"
    Regulation -> "regulation"
    ExecutiveOrder -> "executive_order"
  }
}
