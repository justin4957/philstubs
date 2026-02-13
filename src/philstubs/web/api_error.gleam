import gleam/http
import gleam/json
import gleam/list
import gleam/string
import wisp.{type Response}

/// Error codes for the REST API, providing machine-readable classification.
pub type ErrorCode {
  NotFound
  InvalidJson
  ValidationError
  MissingField
  InternalError
  MethodNotAllowed
  Unauthorized
  Forbidden
}

/// Convert an ErrorCode to its JSON string representation.
pub fn error_code_to_string(error_code: ErrorCode) -> String {
  case error_code {
    NotFound -> "NOT_FOUND"
    InvalidJson -> "INVALID_JSON"
    ValidationError -> "VALIDATION_ERROR"
    MissingField -> "MISSING_FIELD"
    InternalError -> "INTERNAL_ERROR"
    MethodNotAllowed -> "METHOD_NOT_ALLOWED"
    Unauthorized -> "UNAUTHORIZED"
    Forbidden -> "FORBIDDEN"
  }
}

/// Build a JSON error response with a message, code, and HTTP status.
pub fn error_response(
  message: String,
  error_code: ErrorCode,
  status: Int,
) -> Response {
  json.object([
    #("error", json.string(message)),
    #("code", json.string(error_code_to_string(error_code))),
  ])
  |> json.to_string
  |> wisp.json_response(status)
}

/// 404 error response for a missing resource.
pub fn not_found(resource: String) -> Response {
  error_response(resource <> " not found", NotFound, 404)
}

/// 400 error response for validation failures.
pub fn validation_error(message: String) -> Response {
  error_response(message, ValidationError, 400)
}

/// 400 error response for malformed JSON.
pub fn invalid_json() -> Response {
  error_response("Invalid or malformed JSON body", InvalidJson, 400)
}

/// 500 error response for internal server errors.
pub fn internal_error() -> Response {
  error_response("Internal server error", InternalError, 500)
}

/// 401 error response for unauthenticated requests.
pub fn unauthorized() -> Response {
  error_response("Authentication required", Unauthorized, 401)
}

/// 403 error response for unauthorized access.
pub fn forbidden() -> Response {
  error_response(
    "You do not have permission to perform this action",
    Forbidden,
    403,
  )
}

/// 405 error response listing allowed methods.
pub fn method_not_allowed(allowed_methods: List(http.Method)) -> Response {
  let allowed_label =
    allowed_methods
    |> list.map(http.method_to_string)
    |> string.join(", ")

  error_response(
    "Method not allowed. Allowed: " <> allowed_label,
    MethodNotAllowed,
    405,
  )
}
