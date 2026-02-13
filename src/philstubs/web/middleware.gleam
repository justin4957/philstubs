import gleam/option.{None, Some}
import philstubs/data/session_repo
import philstubs/web/context.{type Context, Context}
import wisp.{type Request, type Response}

/// The cookie name used for session tokens.
pub const session_cookie_name = "philstubs_session"

/// Apply the standard middleware chain to a request before routing.
/// Loads the current user from the session cookie and enriches the context.
pub fn apply_middleware(
  request: Request,
  application_context: Context,
  next_handler: fn(Request, Context) -> Response,
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

  let enriched_context = load_current_user(request, application_context)
  next_handler(request, enriched_context)
}

/// Read the session cookie and load the associated user from the database.
/// If the context already has a current_user set, preserve it (useful for tests).
fn load_current_user(request: Request, application_context: Context) -> Context {
  case application_context.current_user {
    Some(_) -> application_context
    None ->
      case wisp.get_cookie(request, session_cookie_name, wisp.Signed) {
        Ok(session_token) -> {
          case
            session_repo.get_user_by_session(
              application_context.db_connection,
              session_token,
            )
          {
            Ok(Some(found_user)) ->
              Context(..application_context, current_user: Some(found_user))
            _ -> application_context
          }
        }
        Error(_) -> application_context
      }
  }
}
