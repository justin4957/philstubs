import envoy
import gleam/dynamic/decode
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import philstubs/ingestion/congress_api_client.{type HttpDispatcher}
import philstubs/ingestion/congress_types.{
  type ApiError, ApiKeyMissing, HttpError, JsonDecodeError, NotFound,
  RateLimitExceeded, ServerError,
}
import philstubs/ingestion/openstates_types.{
  type OpenStatesBillListResponse, type OpenStatesConfig,
}

/// Load the Open States API key from the PLURAL_POLICY_KEY env var.
pub fn load_api_key() -> Result(String, ApiError) {
  envoy.get("PLURAL_POLICY_KEY")
  |> result.replace_error(ApiKeyMissing)
}

/// Create the default HTTP dispatcher wrapping gleam_httpc.
pub fn default_dispatcher() -> HttpDispatcher {
  fn(req: request.Request(String)) -> Result(Response(String), String) {
    httpc.send(req)
    |> result.map_error(fn(http_error) {
      "HTTP request failed: " <> string.inspect(http_error)
    })
  }
}

/// Construct a default OpenStatesConfig from an API key.
pub fn default_config(api_key: String) -> OpenStatesConfig {
  openstates_types.default_config(api_key)
}

/// Build the URL for the Open States bill list endpoint.
pub fn build_bills_url(
  config: OpenStatesConfig,
  jurisdiction: String,
  page: Int,
  per_page: Int,
  updated_since: Option(String),
) -> String {
  let base_query_url =
    config.base_url
    <> "/bills?jurisdiction="
    <> jurisdiction
    <> "&per_page="
    <> int.to_string(per_page)
    <> "&page="
    <> int.to_string(page)
    <> "&include=sponsorships&include=abstracts&include=actions"

  case updated_since {
    Some(date_string) -> base_query_url <> "&updated_since=" <> date_string
    None -> base_query_url
  }
}

/// Fetch a page of bills from the Open States API.
pub fn fetch_bills(
  config: OpenStatesConfig,
  jurisdiction: String,
  page: Int,
  per_page: Int,
  updated_since: Option(String),
  dispatcher: HttpDispatcher,
) -> Result(OpenStatesBillListResponse, ApiError) {
  let url = build_bills_url(config, jurisdiction, page, per_page, updated_since)
  use response_body <- result.try(dispatch_authenticated_request(
    url,
    config.api_key,
    dispatcher,
  ))
  decode_response(response_body, openstates_types.bill_list_response_decoder())
}

fn dispatch_authenticated_request(
  url: String,
  api_key: String,
  dispatcher: HttpDispatcher,
) -> Result(String, ApiError) {
  let request_result = request.to(url)
  case request_result {
    Error(_) -> Error(HttpError("Invalid URL: " <> url))
    Ok(req) -> {
      let authenticated_request = request.set_header(req, "x-api-key", api_key)
      case dispatcher(authenticated_request) {
        Error(message) -> Error(HttpError(message))
        Ok(resp) -> classify_response(resp)
      }
    }
  }
}

fn classify_response(resp: Response(String)) -> Result(String, ApiError) {
  case resp.status {
    200 -> Ok(resp.body)
    404 -> Error(NotFound)
    429 -> Error(RateLimitExceeded)
    status if status >= 500 -> Error(ServerError(status))
    status ->
      Error(HttpError(
        "Unexpected status " <> int.to_string(status) <> ": " <> resp.body,
      ))
  }
}

fn decode_response(
  body: String,
  decoder: decode.Decoder(a),
) -> Result(a, ApiError) {
  json.parse(body, decoder)
  |> result.map_error(fn(json_error) {
    JsonDecodeError("Failed to decode response: " <> string.inspect(json_error))
  })
}
