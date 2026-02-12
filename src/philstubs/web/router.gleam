import gleam/http
import lustre/element
import philstubs/ui/pages
import philstubs/web/context.{type Context}
import philstubs/web/middleware
import wisp.{type Request, type Response}

/// Main request handler. Applies middleware, then routes the request
/// based on HTTP method and path segments.
pub fn handle_request(
  request: Request,
  application_context: Context,
) -> Response {
  use request <- middleware.apply_middleware(request, application_context)

  case wisp.path_segments(request) {
    [] -> index_page(request)
    ["health"] -> health_check(request)
    _ -> wisp.not_found()
  }
}

fn index_page(request: Request) -> Response {
  use <- wisp.require_method(request, http.Get)

  pages.landing_page()
  |> element.to_document_string
  |> wisp.html_response(200)
}

fn health_check(request: Request) -> Response {
  use <- wisp.require_method(request, http.Get)
  wisp.ok()
}
