import philstubs/web/context.{type Context}
import wisp.{type Request, type Response}

/// Apply the standard middleware chain to a request before routing.
pub fn apply_middleware(
  request: Request,
  application_context: Context,
  next_handler: fn(Request) -> Response,
) -> Response {
  let request = wisp.method_override(request)
  use <- wisp.serve_static(
    request,
    under: "/static",
    from: application_context.static_directory,
  )
  use <- wisp.log_request(request)
  use <- wisp.rescue_crashes
  use request <- wisp.handle_head(request)

  next_handler(request)
}
