import gleam/dynamic/decode
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import philstubs/ingestion/congress_api_client.{type HttpDispatcher}
import philstubs/ingestion/congress_types.{
  type ApiError, HttpError, JsonDecodeError, NotFound, RateLimitExceeded,
  ServerError,
}
import philstubs/ingestion/legistar_types.{
  type LegistarConfig, type LegistarMatter, type LegistarSponsor,
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

/// Build the URL for the Matters list endpoint with OData pagination.
pub fn build_matters_url(config: LegistarConfig, skip: Int, top: Int) -> String {
  let base_url =
    config.base_url
    <> "/v1/"
    <> config.client_id
    <> "/Matters?$top="
    <> int.to_string(top)
    <> "&$skip="
    <> int.to_string(skip)

  case config.token {
    Some(token_value) -> base_url <> "&token=" <> token_value
    None -> base_url
  }
}

/// Build the URL for the Sponsors endpoint for a specific Matter.
pub fn build_sponsors_url(config: LegistarConfig, matter_id: Int) -> String {
  let base_url =
    config.base_url
    <> "/v1/"
    <> config.client_id
    <> "/Matters/"
    <> int.to_string(matter_id)
    <> "/Sponsors"

  case config.token {
    Some(token_value) -> base_url <> "?token=" <> token_value
    None -> base_url
  }
}

/// Fetch a page of Matters from the Legistar API.
pub fn fetch_matters(
  config: LegistarConfig,
  skip: Int,
  top: Int,
  dispatcher: HttpDispatcher,
) -> Result(List(LegistarMatter), ApiError) {
  let url = build_matters_url(config, skip, top)
  use response_body <- result.try(dispatch_get_request(url, dispatcher))
  decode_response(response_body, legistar_types.matters_list_decoder())
}

/// Fetch the sponsors for a specific Matter.
pub fn fetch_sponsors(
  config: LegistarConfig,
  matter_id: Int,
  dispatcher: HttpDispatcher,
) -> Result(List(LegistarSponsor), ApiError) {
  let url = build_sponsors_url(config, matter_id)
  use response_body <- result.try(dispatch_get_request(url, dispatcher))
  decode_response(response_body, legistar_types.sponsors_list_decoder())
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
