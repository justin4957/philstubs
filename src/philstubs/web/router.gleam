import gleam/http
import gleam/json
import gleam/option.{None, Some}
import lustre/element
import philstubs/core/user
import philstubs/data/browse_repo
import philstubs/data/legislation_repo
import philstubs/data/stats_repo
import philstubs/data/template_repo
import philstubs/search/search_query
import philstubs/search/search_repo
import philstubs/search/search_results
import philstubs/ui/pages
import philstubs/ui/search_page
import philstubs/web/api_error
import philstubs/web/api_handler
import philstubs/web/api_middleware
import philstubs/web/auth_handler
import philstubs/web/browse_handler
import philstubs/web/context.{type Context}
import philstubs/web/legislation_handler
import philstubs/web/middleware
import philstubs/web/similarity_handler
import philstubs/web/template_handler
import sqlight
import wisp.{type Request, type Response}

/// Main request handler. Applies middleware, then routes the request
/// based on HTTP method and path segments.
pub fn handle_request(
  request: Request,
  application_context: Context,
) -> Response {
  use request, enriched_context <- middleware.apply_middleware(
    request,
    application_context,
  )
  let db_connection = enriched_context.db_connection

  case wisp.path_segments(request) {
    [] -> index_page(request, db_connection)
    ["health"] -> health_check(request)
    ["browse"] -> handle_browse_root(request, db_connection)
    ["browse", "federal"] -> handle_browse_federal(request)
    ["browse", "states"] -> handle_browse_states(request, db_connection)
    ["browse", "state", state_code] ->
      handle_browse_state(request, state_code, db_connection)
    ["browse", "topics"] -> handle_browse_topics(request, db_connection)
    ["search"] -> handle_search_page(request, enriched_context)
    ["login"] -> auth_handler.handle_login(request, enriched_context)
    ["auth", "github", "callback"] ->
      auth_handler.handle_github_callback(
        request,
        enriched_context,
        auth_handler.default_dispatcher(),
      )
    ["logout"] -> auth_handler.handle_logout(request, db_connection)
    ["profile"] -> auth_handler.handle_profile(request, enriched_context)
    ["legislation", legislation_id, "download"] ->
      handle_legislation_download(request, legislation_id, db_connection)
    ["legislation", legislation_id, "diff", comparison_id] ->
      handle_diff_view(request, legislation_id, comparison_id, db_connection)
    ["legislation", legislation_id] ->
      handle_legislation_by_id(request, legislation_id, db_connection)
    ["templates"] -> handle_templates(request, enriched_context)
    ["templates", "new"] -> handle_template_new(request, enriched_context)
    ["templates", template_id, "download"] ->
      handle_template_download(request, template_id, db_connection)
    ["templates", template_id] ->
      handle_template_by_id(request, template_id, enriched_context)
    // --- API routes ---
    ["api", ..api_segments] ->
      route_api(request, api_segments, enriched_context)
    _ -> wisp.not_found()
  }
}

fn index_page(request: Request, db_connection: sqlight.Connection) -> Response {
  use <- wisp.require_method(request, http.Get)

  let stats = case stats_repo.get_legislation_stats(db_connection) {
    Ok(legislation_stats) -> legislation_stats
    Error(_) ->
      stats_repo.LegislationStats(
        total: 0,
        by_level: [],
        by_type: [],
        by_status: [],
      )
  }

  let template_count = case template_repo.count_all(db_connection) {
    Ok(count) -> count
    Error(_) -> 0
  }

  let level_counts = case browse_repo.count_by_government_level(db_connection) {
    Ok(counts) -> counts
    Error(_) -> []
  }

  let recent_legislation = case legislation_repo.list_recent(db_connection, 6) {
    Ok(legislation_list) -> legislation_list
    Error(_) -> []
  }

  pages.landing_page(stats, template_count, level_counts, recent_legislation)
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
        ["legislation", legislation_id, "similar"] ->
          handle_api_similar_legislation(request, legislation_id, db_connection)
        ["legislation", legislation_id, "adoption-timeline"] ->
          handle_api_adoption_timeline(request, legislation_id, db_connection)
        ["legislation", legislation_id] ->
          handle_api_legislation_detail(request, legislation_id, db_connection)
        ["templates"] ->
          handle_api_templates_dispatch(request, application_context)
        ["templates", template_id, "matches"] ->
          handle_api_template_matches(request, template_id, db_connection)
        ["templates", template_id, "download"] ->
          handle_api_template_download(request, template_id, db_connection)
        ["templates", template_id] ->
          handle_api_template_dispatch(
            request,
            template_id,
            application_context,
          )
        ["levels"] -> handle_api_levels_list(request, db_connection)
        ["levels", level, "jurisdictions"] ->
          handle_api_level_jurisdictions(request, level, db_connection)
        ["topics"] -> handle_api_topics_list(request, db_connection)
        ["similarity", "compute"] ->
          handle_api_compute_similarities(request, db_connection)
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
  application_context: Context,
) -> Response {
  case request.method {
    http.Get ->
      template_handler.handle_templates_api(application_context.db_connection)
    http.Post -> {
      case application_context.current_user {
        None -> api_error.unauthorized()
        Some(current_user) ->
          api_handler.handle_templates_create(
            request,
            application_context.db_connection,
            Some(user.user_id_to_string(current_user.id)),
          )
      }
    }
    _ -> api_error.method_not_allowed([http.Get, http.Post])
  }
}

fn handle_api_template_dispatch(
  request: Request,
  template_id: String,
  application_context: Context,
) -> Response {
  let db_connection = application_context.db_connection
  case request.method {
    http.Get ->
      template_handler.handle_template_api_detail(template_id, db_connection)
    http.Put -> {
      case application_context.current_user {
        None -> api_error.unauthorized()
        Some(current_user) ->
          require_template_owner(template_id, current_user, db_connection, fn() {
            api_handler.handle_template_update(
              request,
              template_id,
              db_connection,
            )
          })
      }
    }
    http.Delete -> {
      case application_context.current_user {
        None -> api_error.unauthorized()
        Some(current_user) ->
          require_template_owner(template_id, current_user, db_connection, fn() {
            api_handler.handle_template_delete(template_id, db_connection)
          })
      }
    }
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

// --- Diff view ---

fn handle_diff_view(
  request: Request,
  legislation_id: String,
  comparison_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  similarity_handler.handle_diff_view(
    legislation_id,
    comparison_id,
    db_connection,
  )
}

// --- Similarity API routes ---

fn handle_api_similar_legislation(
  request: Request,
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  similarity_handler.handle_similar_legislation(legislation_id, db_connection)
}

fn handle_api_adoption_timeline(
  request: Request,
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  similarity_handler.handle_adoption_timeline(legislation_id, db_connection)
}

fn handle_api_template_matches(
  request: Request,
  template_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  similarity_handler.handle_template_matches(template_id, db_connection)
}

fn handle_api_compute_similarities(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Post)
  similarity_handler.handle_compute_similarities(db_connection)
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

fn handle_templates(request: Request, application_context: Context) -> Response {
  let db_connection = application_context.db_connection
  case request.method {
    http.Get -> template_handler.handle_templates_list(request, db_connection)
    http.Post -> {
      case application_context.current_user {
        None -> wisp.redirect("/login")
        Some(current_user) ->
          template_handler.handle_template_create(
            request,
            db_connection,
            Some(user.user_id_to_string(current_user.id)),
          )
      }
    }
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

fn handle_template_new(
  request: Request,
  application_context: Context,
) -> Response {
  use <- wisp.require_method(request, http.Get)
  case application_context.current_user {
    None -> wisp.redirect("/login")
    Some(_) -> template_handler.handle_template_new_form()
  }
}

fn handle_template_by_id(
  request: Request,
  template_id: String,
  application_context: Context,
) -> Response {
  let db_connection = application_context.db_connection
  case request.method {
    http.Get ->
      template_handler.handle_template_detail(template_id, db_connection)
    http.Post -> {
      case application_context.current_user {
        None -> wisp.redirect("/login")
        Some(current_user) ->
          require_template_owner_html(
            template_id,
            current_user,
            db_connection,
            fn() {
              template_handler.handle_template_delete(
                template_id,
                db_connection,
              )
            },
          )
      }
    }
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

// --- Authorization helpers ---

/// Check that the current user owns the template (or the template is unowned).
/// Returns 403 Forbidden for API routes if the user is not the owner.
fn require_template_owner(
  template_id: String,
  current_user: user.User,
  db_connection: sqlight.Connection,
  next: fn() -> Response,
) -> Response {
  case template_repo_get_owner(template_id, db_connection) {
    Error(_) -> api_error.internal_error()
    Ok(None) -> api_error.not_found("Template")
    Ok(Some(owner_user_id)) -> {
      let current_user_id = user.user_id_to_string(current_user.id)
      case owner_user_id == current_user_id || owner_user_id == "" {
        True -> next()
        False -> api_error.forbidden()
      }
    }
  }
}

/// Check ownership for HTML routes — redirects to template detail on forbidden.
fn require_template_owner_html(
  template_id: String,
  current_user: user.User,
  db_connection: sqlight.Connection,
  next: fn() -> Response,
) -> Response {
  case template_repo_get_owner(template_id, db_connection) {
    Error(_) -> wisp.internal_server_error()
    Ok(None) -> wisp.not_found()
    Ok(Some(owner_user_id)) -> {
      let current_user_id = user.user_id_to_string(current_user.id)
      case owner_user_id == current_user_id || owner_user_id == "" {
        True -> next()
        False -> wisp.response(403) |> wisp.string_body("Forbidden")
      }
    }
  }
}

/// Get the owner_user_id for a template. Returns Some("") for unowned templates.
fn template_repo_get_owner(
  template_id: String,
  db_connection: sqlight.Connection,
) -> Result(option.Option(String), Nil) {
  case template_repo.get_by_id(db_connection, template_id) {
    Ok(Some(template)) ->
      case template.owner_user_id {
        Some(owner_id) -> Ok(Some(owner_id))
        None -> Ok(Some(""))
      }
    Ok(None) -> Ok(None)
    Error(_) -> Error(Nil)
  }
}
