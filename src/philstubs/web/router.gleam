import gleam/http
import gleam/json
import lustre/element
import philstubs/search/search_query
import philstubs/search/search_repo
import philstubs/search/search_results
import philstubs/ui/pages
import philstubs/ui/search_page
import philstubs/web/context.{type Context}
import philstubs/web/legislation_handler
import philstubs/web/middleware
import philstubs/web/template_handler
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
    ["api", "search"] -> handle_search_api(request, application_context)
    ["api", "legislation", legislation_id] ->
      handle_legislation_api(request, legislation_id, db_connection)
    ["api", "templates"] -> handle_templates_api(request, db_connection)
    ["api", "templates", template_id] ->
      handle_template_api_by_id(request, template_id, db_connection)
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

fn handle_legislation_api(
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

fn handle_templates_api(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  template_handler.handle_templates_api(db_connection)
}

fn handle_template_api_by_id(
  request: Request,
  template_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  template_handler.handle_template_api_detail(template_id, db_connection)
}

import sqlight
