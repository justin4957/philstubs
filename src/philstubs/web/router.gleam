import gleam/http
import gleam/json
import lustre/element
import philstubs/search/search_query
import philstubs/search/search_repo
import philstubs/search/search_results
import philstubs/ui/pages
import philstubs/ui/search_page
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
    ["search"] -> handle_search_page(request, application_context)
    ["api", "search"] -> handle_search_api(request, application_context)
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

fn handle_search_page(
  request: Request,
  application_context: Context,
) -> Response {
  use <- wisp.require_method(request, http.Get)

  let query =
    wisp.get_query(request)
    |> search_query.from_query_params

  let results = case
    search_repo.search(application_context.db_connection, query)
  {
    Ok(search_results) -> search_results
    Error(_) -> search_results.empty(query)
  }

  search_page.search_page(query, results)
  |> element.to_document_string
  |> wisp.html_response(200)
}

fn handle_search_api(request: Request, application_context: Context) -> Response {
  use <- wisp.require_method(request, http.Get)

  let query =
    wisp.get_query(request)
    |> search_query.from_query_params

  case search_repo.search(application_context.db_connection, query) {
    Ok(results) ->
      results
      |> search_results.to_json
      |> json.to_string
      |> wisp.json_response(200)
    Error(_) ->
      search_results.empty(query)
      |> search_results.to_json
      |> json.to_string
      |> wisp.json_response(500)
  }
}
