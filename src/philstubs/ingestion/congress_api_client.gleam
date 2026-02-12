import envoy
import gleam/dynamic/decode
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/json
import gleam/result
import gleam/string
import philstubs/ingestion/congress_types.{
  type ApiError, type BillDetailResponse, type BillListResponse,
  type CongressApiConfig, type CongressBillType, ApiKeyMissing, HttpError,
  JsonDecodeError, NotFound, RateLimitExceeded, ServerError,
}

/// A function that dispatches an HTTP request and returns a response.
/// Production uses httpc.send; tests inject mock functions.
pub type HttpDispatcher =
  fn(request.Request(String)) -> Result(Response(String), String)

/// Load the Congress.gov API key from the CONGRESS_API_KEY env var.
pub fn load_api_key() -> Result(String, ApiError) {
  envoy.get("CONGRESS_API_KEY")
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

/// Build the URL for the bill list endpoint.
pub fn build_bill_list_url(
  config: CongressApiConfig,
  bill_type: CongressBillType,
  offset: Int,
  limit: Int,
) -> String {
  config.base_url
  <> "/bill/"
  <> int.to_string(config.congress_number)
  <> "/"
  <> congress_types.bill_type_to_string(bill_type)
  <> "?offset="
  <> int.to_string(offset)
  <> "&limit="
  <> int.to_string(limit)
  <> "&format=json"
  <> "&api_key="
  <> config.api_key
}

/// Build the URL for the bill detail endpoint.
pub fn build_bill_detail_url(
  config: CongressApiConfig,
  bill_type: CongressBillType,
  bill_number: String,
) -> String {
  config.base_url
  <> "/bill/"
  <> int.to_string(config.congress_number)
  <> "/"
  <> congress_types.bill_type_to_string(bill_type)
  <> "/"
  <> bill_number
  <> "?format=json"
  <> "&api_key="
  <> config.api_key
}

/// Fetch a page of bills from the Congress.gov API.
pub fn fetch_bill_list(
  config: CongressApiConfig,
  bill_type: CongressBillType,
  offset: Int,
  limit: Int,
  dispatcher: HttpDispatcher,
) -> Result(BillListResponse, ApiError) {
  let url = build_bill_list_url(config, bill_type, offset, limit)
  use response_body <- result.try(dispatch_get_request(url, dispatcher))
  decode_response(response_body, congress_types.bill_list_response_decoder())
}

/// Fetch a single bill detail from the Congress.gov API.
pub fn fetch_bill_detail(
  config: CongressApiConfig,
  bill_type: CongressBillType,
  bill_number: String,
  dispatcher: HttpDispatcher,
) -> Result(BillDetailResponse, ApiError) {
  let url = build_bill_detail_url(config, bill_type, bill_number)
  use response_body <- result.try(dispatch_get_request(url, dispatcher))
  decode_response(response_body, congress_types.bill_detail_response_decoder())
}

fn dispatch_get_request(
  url: String,
  dispatcher: HttpDispatcher,
) -> Result(String, ApiError) {
  let request_result = request.to(url)
  case request_result {
    Error(_) -> Error(HttpError("Invalid URL: " <> url))
    Ok(req) -> {
      case dispatcher(req) {
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
