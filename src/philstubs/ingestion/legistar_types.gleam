import gleam/dynamic/decode
import gleam/option.{type Option, None}

/// Configuration for a Legistar API client instance.
pub type LegistarConfig {
  LegistarConfig(base_url: String, client_id: String, token: Option(String))
}

/// Construct a config with the default Legistar base URL.
pub fn default_config(
  client_id: String,
  token: Option(String),
) -> LegistarConfig {
  LegistarConfig(base_url: "https://webapi.legistar.com", client_id:, token:)
}

/// A Matter (legislation item) from the Legistar API.
/// Most fields are optional because Legistar returns null for many fields
/// depending on municipality configuration.
pub type LegistarMatter {
  LegistarMatter(
    matter_id: Int,
    matter_guid: String,
    matter_file: Option(String),
    matter_name: Option(String),
    matter_title: Option(String),
    matter_type_name: Option(String),
    matter_status_name: Option(String),
    matter_body_name: Option(String),
    matter_intro_date: Option(String),
    matter_agenda_date: Option(String),
    matter_passed_date: Option(String),
    matter_enactment_date: Option(String),
    matter_enactment_number: Option(String),
    matter_notes: Option(String),
    matter_last_modified_utc: Option(String),
  )
}

/// A sponsor of a Matter from the Legistar API.
pub type LegistarSponsor {
  LegistarSponsor(matter_sponsor_name: String)
}

// --- Decoders ---

pub fn matter_decoder() -> decode.Decoder(LegistarMatter) {
  use matter_id <- decode.field("MatterId", decode.int)
  use matter_guid <- decode.field("MatterGuid", decode.string)
  use matter_file <- decode.optional_field(
    "MatterFile",
    None,
    decode.optional(decode.string),
  )
  use matter_name <- decode.optional_field(
    "MatterName",
    None,
    decode.optional(decode.string),
  )
  use matter_title <- decode.optional_field(
    "MatterTitle",
    None,
    decode.optional(decode.string),
  )
  use matter_type_name <- decode.optional_field(
    "MatterTypeName",
    None,
    decode.optional(decode.string),
  )
  use matter_status_name <- decode.optional_field(
    "MatterStatusName",
    None,
    decode.optional(decode.string),
  )
  use matter_body_name <- decode.optional_field(
    "MatterBodyName",
    None,
    decode.optional(decode.string),
  )
  use matter_intro_date <- decode.optional_field(
    "MatterIntroDate",
    None,
    decode.optional(decode.string),
  )
  use matter_agenda_date <- decode.optional_field(
    "MatterAgendaDate",
    None,
    decode.optional(decode.string),
  )
  use matter_passed_date <- decode.optional_field(
    "MatterPassedDate",
    None,
    decode.optional(decode.string),
  )
  use matter_enactment_date <- decode.optional_field(
    "MatterEnactmentDate",
    None,
    decode.optional(decode.string),
  )
  use matter_enactment_number <- decode.optional_field(
    "MatterEnactmentNumber",
    None,
    decode.optional(decode.string),
  )
  use matter_notes <- decode.optional_field(
    "MatterNotes",
    None,
    decode.optional(decode.string),
  )
  use matter_last_modified_utc <- decode.optional_field(
    "MatterLastModifiedUtc",
    None,
    decode.optional(decode.string),
  )
  decode.success(LegistarMatter(
    matter_id:,
    matter_guid:,
    matter_file:,
    matter_name:,
    matter_title:,
    matter_type_name:,
    matter_status_name:,
    matter_body_name:,
    matter_intro_date:,
    matter_agenda_date:,
    matter_passed_date:,
    matter_enactment_date:,
    matter_enactment_number:,
    matter_notes:,
    matter_last_modified_utc:,
  ))
}

pub fn sponsor_decoder() -> decode.Decoder(LegistarSponsor) {
  use matter_sponsor_name <- decode.field("MatterSponsorName", decode.string)
  decode.success(LegistarSponsor(matter_sponsor_name:))
}

/// Decode a JSON array of matters (Legistar returns plain arrays).
pub fn matters_list_decoder() -> decode.Decoder(List(LegistarMatter)) {
  decode.list(matter_decoder())
}

/// Decode a JSON array of sponsors.
pub fn sponsors_list_decoder() -> decode.Decoder(List(LegistarSponsor)) {
  decode.list(sponsor_decoder())
}
