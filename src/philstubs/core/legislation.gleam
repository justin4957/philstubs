import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import philstubs/core/government_level.{type GovernmentLevel}
import philstubs/core/legislation_status.{type LegislationStatus}
import philstubs/core/legislation_type.{type LegislationType}

/// Opaque identifier for a piece of legislation. Wraps a string
/// (typically a UUID or database-assigned ID) to prevent accidental
/// misuse of raw strings as IDs.
pub opaque type LegislationId {
  LegislationId(String)
}

/// Create a LegislationId from a string value.
pub fn legislation_id(value: String) -> LegislationId {
  LegislationId(value)
}

/// Extract the underlying string from a LegislationId.
pub fn legislation_id_to_string(identifier: LegislationId) -> String {
  let LegislationId(value) = identifier
  value
}

/// A piece of legislation at any level of US government.
///
/// Fields are designed for future integration with regula's domain model:
/// - `introduced_date` uses ISO 8601 strings, mapping to regula's TemporalRange
/// - `source_identifier` holds official designations (e.g., "H.R. 1234"),
///   mapping to regula's ProvisionID
/// - `source_url` links to the original government source
pub type Legislation {
  Legislation(
    id: LegislationId,
    title: String,
    summary: String,
    body: String,
    level: GovernmentLevel,
    legislation_type: LegislationType,
    status: LegislationStatus,
    introduced_date: String,
    source_url: Option(String),
    source_identifier: String,
    sponsors: List(String),
    topics: List(String),
  )
}

/// Encode a Legislation record to JSON.
pub fn to_json(legislation: Legislation) -> json.Json {
  json.object([
    #("id", json.string(legislation_id_to_string(legislation.id))),
    #("title", json.string(legislation.title)),
    #("summary", json.string(legislation.summary)),
    #("body", json.string(legislation.body)),
    #("level", government_level.to_json(legislation.level)),
    #(
      "legislation_type",
      legislation_type.to_json(legislation.legislation_type),
    ),
    #("status", legislation_status.to_json(legislation.status)),
    #("introduced_date", json.string(legislation.introduced_date)),
    #("source_url", json.nullable(legislation.source_url, json.string)),
    #("source_identifier", json.string(legislation.source_identifier)),
    #("sponsors", json.array(legislation.sponsors, json.string)),
    #("topics", json.array(legislation.topics, json.string)),
  ])
}

/// Decode a Legislation record from JSON.
pub fn decoder() -> decode.Decoder(Legislation) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use summary <- decode.field("summary", decode.string)
  use body <- decode.field("body", decode.string)
  use level <- decode.field("level", government_level.decoder())
  use leg_type <- decode.field("legislation_type", legislation_type.decoder())
  use status <- decode.field("status", legislation_status.decoder())
  use introduced_date <- decode.field("introduced_date", decode.string)
  use source_url <- decode.field("source_url", decode.optional(decode.string))
  use source_identifier <- decode.field("source_identifier", decode.string)
  use sponsors <- decode.field("sponsors", decode.list(decode.string))
  use topics <- decode.field("topics", decode.list(decode.string))
  decode.success(Legislation(
    id: legislation_id(id),
    title:,
    summary:,
    body:,
    level:,
    legislation_type: leg_type,
    status:,
    introduced_date:,
    source_url:,
    source_identifier:,
    sponsors:,
    topics:,
  ))
}

/// Encode a LegislationId to JSON (as a string).
pub fn legislation_id_to_json(identifier: LegislationId) -> json.Json {
  json.string(legislation_id_to_string(identifier))
}

/// Decode a LegislationId from a JSON string.
pub fn legislation_id_decoder() -> decode.Decoder(LegislationId) {
  use value <- decode.then(decode.string)
  decode.success(legislation_id(value))
}
