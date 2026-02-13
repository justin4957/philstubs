import wisp.{type Response}

/// Add CORS headers to an API response, allowing cross-origin requests.
pub fn apply_cors(response: Response) -> Response {
  response
  |> wisp.set_header("access-control-allow-origin", "*")
  |> wisp.set_header(
    "access-control-allow-methods",
    "GET, POST, PUT, DELETE, OPTIONS",
  )
  |> wisp.set_header(
    "access-control-allow-headers",
    "Content-Type, Accept, Authorization",
  )
  |> wisp.set_header("access-control-max-age", "86400")
}

/// Handle an OPTIONS preflight request with a 204 No Content + CORS headers.
pub fn handle_preflight() -> Response {
  wisp.response(204)
  |> apply_cors
}
