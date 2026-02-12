import gleam/dynamic/decode
import gleam/json

/// Levels of government in the US democratic hierarchy.
/// Each variant carries jurisdiction-specific data, modeled after
/// regula's Jurisdiction constructors for future integration.
///
/// - `Federal` — national-level legislation (Congress, executive orders)
/// - `State(state_code)` — state legislature (e.g., "CA", "TX")
/// - `County(state_code, county_name)` — county-level ordinances
/// - `Municipal(state_code, municipality_name)` — city/town bylaws
pub type GovernmentLevel {
  Federal
  State(state_code: String)
  County(state_code: String, county_name: String)
  Municipal(state_code: String, municipality_name: String)
}

/// Convert a GovernmentLevel to its level name string (without jurisdiction).
pub fn to_string(level: GovernmentLevel) -> String {
  case level {
    Federal -> "Federal"
    State(..) -> "State"
    County(..) -> "County"
    Municipal(..) -> "Municipal"
  }
}

/// Convert a GovernmentLevel to a display label including jurisdiction.
/// Examples: "Federal", "State (CA)", "County (Cook, IL)", "Municipal (Austin, TX)"
pub fn jurisdiction_label(level: GovernmentLevel) -> String {
  case level {
    Federal -> "Federal"
    State(state_code:) -> "State (" <> state_code <> ")"
    County(state_code:, county_name:) ->
      "County (" <> county_name <> ", " <> state_code <> ")"
    Municipal(state_code:, municipality_name:) ->
      "Municipal (" <> municipality_name <> ", " <> state_code <> ")"
  }
}

/// Encode a GovernmentLevel to JSON.
/// Federal encodes as: {"kind": "federal"}
/// State encodes as: {"kind": "state", "state_code": "CA"}
/// County encodes as: {"kind": "county", "state_code": "IL", "county_name": "Cook"}
/// Municipal encodes as: {"kind": "municipal", "state_code": "TX", "municipality_name": "Austin"}
pub fn to_json(level: GovernmentLevel) -> json.Json {
  case level {
    Federal -> json.object([#("kind", json.string("federal"))])
    State(state_code:) ->
      json.object([
        #("kind", json.string("state")),
        #("state_code", json.string(state_code)),
      ])
    County(state_code:, county_name:) ->
      json.object([
        #("kind", json.string("county")),
        #("state_code", json.string(state_code)),
        #("county_name", json.string(county_name)),
      ])
    Municipal(state_code:, municipality_name:) ->
      json.object([
        #("kind", json.string("municipal")),
        #("state_code", json.string(state_code)),
        #("municipality_name", json.string(municipality_name)),
      ])
  }
}

/// Decode a GovernmentLevel from JSON. Dispatches on the "kind" field.
pub fn decoder() -> decode.Decoder(GovernmentLevel) {
  use kind <- decode.field("kind", decode.string)
  case kind {
    "federal" -> decode.success(Federal)
    "state" -> {
      use state_code <- decode.field("state_code", decode.string)
      decode.success(State(state_code:))
    }
    "county" -> {
      use state_code <- decode.field("state_code", decode.string)
      use county_name <- decode.field("county_name", decode.string)
      decode.success(County(state_code:, county_name:))
    }
    "municipal" -> {
      use state_code <- decode.field("state_code", decode.string)
      use municipality_name <- decode.field("municipality_name", decode.string)
      decode.success(Municipal(state_code:, municipality_name:))
    }
    _ -> decode.failure(Federal, "GovernmentLevel")
  }
}
