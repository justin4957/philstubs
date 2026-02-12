import gleam/dynamic/decode
import gleam/option.{type Option, None}

/// Configuration for the Congress.gov API client.
pub type CongressApiConfig {
  CongressApiConfig(api_key: String, base_url: String, congress_number: Int)
}

/// Construct a config with default base URL.
pub fn default_config(
  api_key: String,
  congress_number: Int,
) -> CongressApiConfig {
  CongressApiConfig(
    api_key:,
    base_url: "https://api.congress.gov/v3",
    congress_number:,
  )
}

/// Bill types available in Congress.gov API.
pub type CongressBillType {
  Hr
  S
  Hjres
  Sjres
  Hconres
  Sconres
  Hres
  Sres
}

/// Convert a bill type to its API path segment.
pub fn bill_type_to_string(bill_type: CongressBillType) -> String {
  case bill_type {
    Hr -> "hr"
    S -> "s"
    Hjres -> "hjres"
    Sjres -> "sjres"
    Hconres -> "hconres"
    Sconres -> "sconres"
    Hres -> "hres"
    Sres -> "sres"
  }
}

/// All bill types for exhaustive ingestion.
pub fn all_bill_types() -> List(CongressBillType) {
  [Hr, S, Hjres, Sjres, Hconres, Sconres, Hres, Sres]
}

/// A latest action from the API, present on both list and detail items.
pub type CongressLatestAction {
  CongressLatestAction(action_date: String, text: String)
}

/// A bill as returned in the bill list endpoint.
pub type CongressBillListItem {
  CongressBillListItem(
    congress: Int,
    bill_type: String,
    number: String,
    title: String,
    url: String,
    update_date: String,
    origin_chamber: String,
    latest_action: Option(CongressLatestAction),
  )
}

/// A sponsor from the bill detail endpoint.
pub type CongressSponsor {
  CongressSponsor(
    full_name: String,
    party: Option(String),
    state: Option(String),
  )
}

/// A bill as returned from the bill detail endpoint.
pub type CongressBillDetail {
  CongressBillDetail(
    congress: Int,
    bill_type: String,
    number: String,
    title: String,
    introduced_date: String,
    update_date: String,
    origin_chamber: String,
    latest_action: Option(CongressLatestAction),
    sponsors: List(CongressSponsor),
    policy_area: Option(String),
  )
}

/// Pagination info from the API.
pub type CongressPagination {
  CongressPagination(count: Int, next: Option(String))
}

/// Response wrapper for the bill list endpoint.
pub type BillListResponse {
  BillListResponse(
    bills: List(CongressBillListItem),
    pagination: CongressPagination,
  )
}

/// Response wrapper for the bill detail endpoint.
pub type BillDetailResponse {
  BillDetailResponse(bill: CongressBillDetail)
}

/// API errors.
pub type ApiError {
  HttpError(String)
  JsonDecodeError(String)
  ApiKeyMissing
  RateLimitExceeded
  NotFound
  ServerError(Int)
}

// --- Decoders ---

pub fn latest_action_decoder() -> decode.Decoder(CongressLatestAction) {
  use action_date <- decode.field("actionDate", decode.string)
  use text <- decode.field("text", decode.string)
  decode.success(CongressLatestAction(action_date:, text:))
}

pub fn bill_list_item_decoder() -> decode.Decoder(CongressBillListItem) {
  use congress <- decode.field("congress", decode.int)
  use bill_type <- decode.field("type", decode.string)
  use number <- decode.field("number", decode.string)
  use title <- decode.field("title", decode.string)
  use url <- decode.field("url", decode.string)
  use update_date <- decode.field("updateDate", decode.string)
  use origin_chamber <- decode.field("originChamber", decode.string)
  use latest_action <- decode.optional_field(
    "latestAction",
    None,
    decode.optional(latest_action_decoder()),
  )
  decode.success(CongressBillListItem(
    congress:,
    bill_type:,
    number:,
    title:,
    url:,
    update_date:,
    origin_chamber:,
    latest_action:,
  ))
}

pub fn sponsor_decoder() -> decode.Decoder(CongressSponsor) {
  use full_name <- decode.field("fullName", decode.string)
  use party <- decode.optional_field(
    "party",
    None,
    decode.optional(decode.string),
  )
  use state <- decode.optional_field(
    "state",
    None,
    decode.optional(decode.string),
  )
  decode.success(CongressSponsor(full_name:, party:, state:))
}

pub fn pagination_decoder() -> decode.Decoder(CongressPagination) {
  use count <- decode.field("count", decode.int)
  use next <- decode.optional_field(
    "next",
    None,
    decode.optional(decode.string),
  )
  decode.success(CongressPagination(count:, next:))
}

pub fn bill_detail_decoder() -> decode.Decoder(CongressBillDetail) {
  use congress <- decode.field("congress", decode.int)
  use bill_type <- decode.field("type", decode.string)
  use number <- decode.field("number", decode.string)
  use title <- decode.field("title", decode.string)
  use introduced_date <- decode.field("introducedDate", decode.string)
  use update_date <- decode.field("updateDate", decode.string)
  use origin_chamber <- decode.field("originChamber", decode.string)
  use latest_action <- decode.optional_field(
    "latestAction",
    None,
    decode.optional(latest_action_decoder()),
  )
  use sponsors <- decode.optional_field(
    "sponsors",
    [],
    decode.list(sponsor_decoder()),
  )
  use policy_area <- decode.optional_field(
    "policyArea",
    None,
    decode.optional({
      use name <- decode.field("name", decode.string)
      decode.success(name)
    }),
  )
  decode.success(CongressBillDetail(
    congress:,
    bill_type:,
    number:,
    title:,
    introduced_date:,
    update_date:,
    origin_chamber:,
    latest_action:,
    sponsors:,
    policy_area:,
  ))
}

pub fn bill_list_response_decoder() -> decode.Decoder(BillListResponse) {
  use bills <- decode.field("bills", decode.list(bill_list_item_decoder()))
  use pagination <- decode.field("pagination", pagination_decoder())
  decode.success(BillListResponse(bills:, pagination:))
}

pub fn bill_detail_response_decoder() -> decode.Decoder(BillDetailResponse) {
  use bill <- decode.field("bill", bill_detail_decoder())
  decode.success(BillDetailResponse(bill:))
}
