import gleam/http
import gleam/json
import lustre/element
import philstubs/search/search_query
import philstubs/search/search_repo
import philstubs/search/search_results
import philstubs/ui/pages
import philstubs/ui/search_page
import philstubs/web/api_error
import philstubs/web/api_handler
import philstubs/web/api_middleware
import philstubs/web/browse_handler
import philstubs/web/context.{type Context}
import philstubs/web/legislation_handler
import philstubs/web/middleware
import philstubs/web/template_handler
import sqlight
import wisp.{type Request, type Response}

/// Main request handler. Applies middleware, then routes the request
/// based on HTTP method and path segments.
pub fn handle_request(
  request: Request,
  application_context: Context,
) -> Response {
  use request <- middleware.apply_middleware(request, application_context)
  let db_connection = application_context.db_connection

  case wisp.path_segments(request) {
    [] -> index_page(request)
    ["health"] -> health_check(request)
    ["browse"] -> handle_browse_root(request, db_connection)
    ["browse", "federal"] -> handle_browse_federal(request)
    ["browse", "states"] -> handle_browse_states(request, db_connection)
    ["browse", "state", state_code] ->
      handle_browse_state(request, state_code, db_connection)
    ["browse", "topics"] -> handle_browse_topics(request, db_connection)
    ["search"] -> handle_search_page(request, application_context)
    ["legislation", legislation_id, "download"] ->
      handle_legislation_download(request, legislation_id, db_connection)
    ["legislation", legislation_id] ->
      handle_legislation_by_id(request, legislation_id, db_connection)
    ["templates"] -> handle_templates(request, db_connection)
    ["templates", "new"] -> handle_template_new(request)
    ["templates", template_id, "download"] ->
      handle_template_download(request, template_id, db_connection)
    ["templates", template_id] ->
      handle_template_by_id(request, template_id, db_connection)
    // --- API routes ---
    ["api", ..api_segments] ->
      route_api(request, api_segments, application_context)
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

// --- API routing ---

/// Route all /api/* requests. Applies CORS headers and handles OPTIONS preflight.
fn route_api(
  request: Request,
  api_segments: List(String),
  application_context: Context,
) -> Response {
  let db_connection = application_context.db_connection

  // Handle OPTIONS preflight for any API route
  case request.method {
    http.Options -> api_middleware.handle_preflight()
    _ -> {
      let response = case api_segments {
        ["search"] -> handle_search_api(request, application_context)
        ["legislation"] -> handle_api_legislation_list(request, db_connection)
        ["legislation", "stats"] ->
          handle_api_legislation_stats(request, db_connection)
        ["legislation", legislation_id] ->
          handle_api_legislation_detail(request, legislation_id, db_connection)
        ["templates"] -> handle_api_templates_dispatch(request, db_connection)
        ["templates", template_id, "download"] ->
          handle_api_template_download(request, template_id, db_connection)
        ["templates", template_id] ->
          handle_api_template_dispatch(request, template_id, db_connection)
        ["levels"] -> handle_api_levels_list(request, db_connection)
        ["levels", level, "jurisdictions"] ->
          handle_api_level_jurisdictions(request, level, db_connection)
        ["topics"] -> handle_api_topics_list(request, db_connection)
        _ -> api_error.not_found("Endpoint")
      }
      api_middleware.apply_cors(response)
    }
  }
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

fn handle_api_legislation_list(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  api_handler.handle_legislation_list(request, db_connection)
}

fn handle_api_legislation_stats(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  api_handler.handle_legislation_stats(db_connection)
}

fn handle_api_legislation_detail(
  request: Request,
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  legislation_handler.handle_legislation_api_detail(
    legislation_id,
    db_connection,
  )
}

fn handle_api_templates_dispatch(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  case request.method {
    http.Get -> template_handler.handle_templates_api(db_connection)
    http.Post -> api_handler.handle_templates_create(request, db_connection)
    _ -> api_error.method_not_allowed([http.Get, http.Post])
  }
}

fn handle_api_template_dispatch(
  request: Request,
  template_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  case request.method {
    http.Get ->
      template_handler.handle_template_api_detail(template_id, db_connection)
    http.Put ->
      api_handler.handle_template_update(request, template_id, db_connection)
    http.Delete ->
      api_handler.handle_template_delete(template_id, db_connection)
    _ -> api_error.method_not_allowed([http.Get, http.Put, http.Delete])
  }
}

fn handle_api_template_download(
  request: Request,
  template_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  api_handler.handle_template_download(request, template_id, db_connection)
}

fn handle_api_levels_list(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  api_handler.handle_levels_list(db_connection)
}

fn handle_api_level_jurisdictions(
  request: Request,
  level: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  api_handler.handle_level_jurisdictions(request, level, db_connection)
}

fn handle_api_topics_list(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  api_handler.handle_topics_list(db_connection)
}

// --- Browse routes ---

fn handle_browse_root(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  browse_handler.handle_browse_root(db_connection)
}

fn handle_browse_federal(request: Request) -> Response {
  use <- wisp.require_method(request, http.Get)
  wisp.redirect("/search?level=federal")
}

fn handle_browse_states(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  browse_handler.handle_browse_states(db_connection)
}

fn handle_browse_state(
  request: Request,
  state_code: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  browse_handler.handle_browse_state(state_code, db_connection)
}

fn handle_browse_topics(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  browse_handler.handle_browse_topics(db_connection)
}

// --- Legislation routes ---

fn handle_legislation_by_id(
  request: Request,
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  legislation_handler.handle_legislation_detail(legislation_id, db_connection)
}

fn handle_legislation_download(
  request: Request,
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  legislation_handler.handle_legislation_download(
    request,
    legislation_id,
    db_connection,
  )
}

// --- Template routes ---

fn handle_templates(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  case request.method {
    http.Get -> template_handler.handle_templates_list(request, db_connection)
    http.Post -> template_handler.handle_template_create(request, db_connection)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn handle_template_new(request: Request) -> Response {
  use <- wisp.require_method(request, http.Get)
  template_handler.handle_template_new_form()
}

fn handle_template_by_id(
  request: Request,
  template_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  case request.method {
    http.Get ->
      template_handler.handle_template_detail(template_id, db_connection)
    http.Post ->
      template_handler.handle_template_delete(template_id, db_connection)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn handle_template_download(
  request: Request,
  template_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  template_handler.handle_template_download(request, template_id, db_connection)
}
