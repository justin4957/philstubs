import gleam/dynamic/decode
import gleam/option.{type Option, None}

/// Configuration for the Open States / Plural Policy API client.
pub type OpenStatesConfig {
  OpenStatesConfig(api_key: String, base_url: String)
}

/// Construct a config with the default Open States v3 base URL.
pub fn default_config(api_key: String) -> OpenStatesConfig {
  OpenStatesConfig(api_key:, base_url: "https://v3.openstates.org")
}

/// A jurisdiction object from the Open States API.
pub type OpenStatesJurisdiction {
  OpenStatesJurisdiction(id: String, name: String, classification: String)
}

/// A person referenced in a sponsorship.
pub type OpenStatesPerson {
  OpenStatesPerson(name: String, party: Option(String))
}

/// A sponsorship on a bill.
pub type OpenStatesSponsorship {
  OpenStatesSponsorship(
    name: String,
    primary: Bool,
    classification: String,
    person: Option(OpenStatesPerson),
  )
}

/// An abstract/summary attached to a bill.
pub type OpenStatesAbstract {
  OpenStatesAbstract(abstract_text: String, note: Option(String))
}

/// An action taken on a bill.
pub type OpenStatesAction {
  OpenStatesAction(
    description: String,
    date: String,
    classification: List(String),
  )
}

/// A bill from the Open States API.
pub type OpenStatesBill {
  OpenStatesBill(
    id: String,
    session: String,
    jurisdiction: OpenStatesJurisdiction,
    identifier: String,
    title: String,
    classification: List(String),
    subject: List(String),
    openstates_url: String,
    first_action_date: Option(String),
    latest_action_date: Option(String),
    latest_action_description: Option(String),
    abstracts: List(OpenStatesAbstract),
    sponsorships: List(OpenStatesSponsorship),
    actions: List(OpenStatesAction),
  )
}

/// Pagination metadata from the Open States API.
pub type OpenStatesPagination {
  OpenStatesPagination(
    per_page: Int,
    page: Int,
    max_page: Int,
    total_items: Int,
  )
}

/// Response wrapper for the bill list endpoint.
pub type OpenStatesBillListResponse {
  OpenStatesBillListResponse(
    results: List(OpenStatesBill),
    pagination: OpenStatesPagination,
  )
}

// --- Decoders ---

pub fn jurisdiction_decoder() -> decode.Decoder(OpenStatesJurisdiction) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use classification <- decode.field("classification", decode.string)
  decode.success(OpenStatesJurisdiction(id:, name:, classification:))
}

pub fn person_decoder() -> decode.Decoder(OpenStatesPerson) {
  use name <- decode.field("name", decode.string)
  use party <- decode.optional_field(
    "party",
    None,
    decode.optional(decode.string),
  )
  decode.success(OpenStatesPerson(name:, party:))
}

pub fn sponsorship_decoder() -> decode.Decoder(OpenStatesSponsorship) {
  use name <- decode.field("name", decode.string)
  use primary <- decode.field("primary", decode.bool)
  use classification <- decode.field("classification", decode.string)
  use person <- decode.optional_field(
    "person",
    None,
    decode.optional(person_decoder()),
  )
  decode.success(OpenStatesSponsorship(
    name:,
    primary:,
    classification:,
    person:,
  ))
}

pub fn abstract_decoder() -> decode.Decoder(OpenStatesAbstract) {
  use abstract_text <- decode.field("abstract", decode.string)
  use note <- decode.optional_field(
    "note",
    None,
    decode.optional(decode.string),
  )
  decode.success(OpenStatesAbstract(abstract_text:, note:))
}

pub fn action_decoder() -> decode.Decoder(OpenStatesAction) {
  use description <- decode.field("description", decode.string)
  use date <- decode.field("date", decode.string)
  use classification <- decode.optional_field(
    "classification",
    [],
    decode.list(decode.string),
  )
  decode.success(OpenStatesAction(description:, date:, classification:))
}

pub fn bill_decoder() -> decode.Decoder(OpenStatesBill) {
  use id <- decode.field("id", decode.string)
  use session <- decode.field("session", decode.string)
  use jurisdiction <- decode.field("jurisdiction", jurisdiction_decoder())
  use identifier <- decode.field("identifier", decode.string)
  use title <- decode.field("title", decode.string)
  use classification <- decode.optional_field(
    "classification",
    [],
    decode.list(decode.string),
  )
  use subject <- decode.optional_field(
    "subject",
    [],
    decode.list(decode.string),
  )
  use openstates_url <- decode.field("openstates_url", decode.string)
  use first_action_date <- decode.optional_field(
    "first_action_date",
    None,
    decode.optional(decode.string),
  )
  use latest_action_date <- decode.optional_field(
    "latest_action_date",
    None,
    decode.optional(decode.string),
  )
  use latest_action_description <- decode.optional_field(
    "latest_action_description",
    None,
    decode.optional(decode.string),
  )
  use abstracts <- decode.optional_field(
    "abstracts",
    [],
    decode.list(abstract_decoder()),
  )
  use sponsorships <- decode.optional_field(
    "sponsorships",
    [],
    decode.list(sponsorship_decoder()),
  )
  use actions <- decode.optional_field(
    "actions",
    [],
    decode.list(action_decoder()),
  )
  decode.success(OpenStatesBill(
    id:,
    session:,
    jurisdiction:,
    identifier:,
    title:,
    classification:,
    subject:,
    openstates_url:,
    first_action_date:,
    latest_action_date:,
    latest_action_description:,
    abstracts:,
    sponsorships:,
    actions:,
  ))
}

pub fn pagination_decoder() -> decode.Decoder(OpenStatesPagination) {
  use per_page <- decode.field("per_page", decode.int)
  use page <- decode.field("page", decode.int)
  use max_page <- decode.field("max_page", decode.int)
  use total_items <- decode.field("total_items", decode.int)
  decode.success(OpenStatesPagination(per_page:, page:, max_page:, total_items:))
}

pub fn bill_list_response_decoder() -> decode.Decoder(
  OpenStatesBillListResponse,
) {
  use results <- decode.field("results", decode.list(bill_decoder()))
  use pagination <- decode.field("pagination", pagination_decoder())
  decode.success(OpenStatesBillListResponse(results:, pagination:))
}
