import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response as http_response
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/uri
import lustre/element
import philstubs/core/user
import philstubs/data/session_repo
import philstubs/data/template_repo
import philstubs/data/user_repo
import philstubs/ui/login_page
import philstubs/ui/profile_page
import philstubs/web/context.{type Context}
import philstubs/web/middleware
import sqlight
import wisp.{type Request, type Response}

/// A function that dispatches an HTTP request and returns a response.
/// Production uses httpc.send; tests inject mock functions.
pub type HttpDispatcher =
  fn(request.Request(String)) -> Result(http_response.Response(String), String)

/// Create the default HTTP dispatcher.
pub fn default_dispatcher() -> HttpDispatcher {
  fn(req: request.Request(String)) -> Result(
    http_response.Response(String),
    String,
  ) {
    httpc.send(req)
    |> result.map_error(fn(http_error) {
      "HTTP request failed: " <> string.inspect(http_error)
    })
  }
}

/// Handle GET /login — show login page or redirect to GitHub OAuth.
pub fn handle_login(request: Request, application_context: Context) -> Response {
  use <- wisp.require_method(request, http.Get)

  case application_context.github_client_id {
    "" ->
      login_page.login_page(Some(
        "GitHub OAuth is not configured. Set GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET environment variables.",
      ))
      |> element.to_document_string
      |> wisp.html_response(200)
    client_id -> {
      let callback_url = build_callback_url(request)
      let github_auth_url =
        "https://github.com/login/oauth/authorize"
        <> "?client_id="
        <> uri.percent_encode(client_id)
        <> "&redirect_uri="
        <> uri.percent_encode(callback_url)
        <> "&scope=read:user"
      wisp.redirect(github_auth_url)
    }
  }
}

/// Handle GET /auth/github/callback — exchange code for token, create session.
pub fn handle_github_callback(
  request: Request,
  application_context: Context,
  dispatcher: HttpDispatcher,
) -> Response {
  use <- wisp.require_method(request, http.Get)

  let query_params = wisp.get_query(request)
  let code_result = list.key_find(query_params, "code")

  case code_result {
    Error(_) ->
      login_page.login_page(Some("Missing authorization code from GitHub."))
      |> element.to_document_string
      |> wisp.html_response(400)
    Ok(authorization_code) -> {
      let token_result =
        exchange_code_for_token(
          authorization_code,
          application_context.github_client_id,
          application_context.github_client_secret,
          build_callback_url(request),
          dispatcher,
        )

      case token_result {
        Error(error_message) ->
          login_page.login_page(Some("Authentication failed: " <> error_message))
          |> element.to_document_string
          |> wisp.html_response(400)
        Ok(access_token) -> {
          let user_result = fetch_github_user(access_token, dispatcher)
          case user_result {
            Error(error_message) ->
              login_page.login_page(Some(
                "Failed to fetch user info: " <> error_message,
              ))
              |> element.to_document_string
              |> wisp.html_response(400)
            Ok(github_user) ->
              complete_login(
                request,
                application_context.db_connection,
                github_user,
              )
          }
        }
      }
    }
  }
}

/// Handle POST /logout — delete session and clear cookie.
pub fn handle_logout(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Post)

  case wisp.get_cookie(request, middleware.session_cookie_name, wisp.Signed) {
    Ok(session_token) -> {
      let _ = session_repo.delete_session(db_connection, session_token)
      wisp.redirect("/")
      |> wisp.set_cookie(
        request,
        middleware.session_cookie_name,
        "",
        wisp.Signed,
        0,
      )
    }
    Error(_) -> wisp.redirect("/")
  }
}

/// Handle GET /profile — show user profile with their templates.
pub fn handle_profile(
  request: Request,
  application_context: Context,
) -> Response {
  use <- wisp.require_method(request, http.Get)

  case application_context.current_user {
    None -> wisp.redirect("/login")
    Some(current_user) -> {
      let user_id_str = user.user_id_to_string(current_user.id)
      let user_templates = case
        template_repo.list_by_owner(
          application_context.db_connection,
          user_id_str,
        )
      {
        Ok(templates) -> templates
        Error(_) -> []
      }

      profile_page.profile_page(current_user, user_templates)
      |> element.to_document_string
      |> wisp.html_response(200)
    }
  }
}

// --- Private helpers ---

/// Build the callback URL from the current request.
fn build_callback_url(request: Request) -> String {
  let scheme = case request.scheme {
    http.Https -> "https"
    http.Http -> "http"
  }
  let host = request.host
  let port_suffix = case request.port {
    Some(80) | Some(443) | None -> ""
    Some(port_number) -> ":" <> string.inspect(port_number)
  }
  scheme <> "://" <> host <> port_suffix <> "/auth/github/callback"
}

/// Exchange an authorization code for an access token via GitHub's OAuth API.
fn exchange_code_for_token(
  authorization_code: String,
  client_id: String,
  client_secret: String,
  redirect_uri: String,
  dispatcher: HttpDispatcher,
) -> Result(String, String) {
  let request_body =
    json.object([
      #("client_id", json.string(client_id)),
      #("client_secret", json.string(client_secret)),
      #("code", json.string(authorization_code)),
      #("redirect_uri", json.string(redirect_uri)),
    ])
    |> json.to_string

  let assert Ok(token_request) =
    request.to("https://github.com/login/oauth/access_token")

  let token_request =
    token_request
    |> request.set_method(http.Post)
    |> request.set_body(request_body)
    |> request.prepend_header("content-type", "application/json")
    |> request.prepend_header("accept", "application/json")

  use response <- result.try(dispatcher(token_request))

  let token_decoder = {
    use access_token <- decode.field("access_token", decode.string)
    decode.success(access_token)
  }

  case json.parse(response.body, token_decoder) {
    Ok(access_token) -> Ok(access_token)
    Error(_) -> Error("Failed to parse access token response")
  }
}

/// GitHub user info returned from the API.
pub type GitHubUser {
  GitHubUser(
    github_id: Int,
    username: String,
    display_name: String,
    avatar_url: String,
  )
}

/// Fetch user info from GitHub's API using an access token.
fn fetch_github_user(
  access_token: String,
  dispatcher: HttpDispatcher,
) -> Result(GitHubUser, String) {
  let assert Ok(user_request) = request.to("https://api.github.com/user")

  let user_request =
    user_request
    |> request.prepend_header("authorization", "Bearer " <> access_token)
    |> request.prepend_header("accept", "application/json")
    |> request.prepend_header("user-agent", "philstubs")

  use response <- result.try(dispatcher(user_request))

  let github_user_decoder = {
    use github_id <- decode.field("id", decode.int)
    use username <- decode.field("login", decode.string)
    use display_name <- decode.optional_field("name", "", decode.string)
    use avatar_url <- decode.optional_field("avatar_url", "", decode.string)
    decode.success(GitHubUser(github_id:, username:, display_name:, avatar_url:))
  }

  case json.parse(response.body, github_user_decoder) {
    Ok(github_user) -> Ok(github_user)
    Error(_) -> Error("Failed to parse GitHub user response")
  }
}

/// Complete the login flow: upsert user, create session, set cookie, redirect.
fn complete_login(
  request: Request,
  db_connection: sqlight.Connection,
  github_user: GitHubUser,
) -> Response {
  case
    user_repo.upsert_from_github(
      db_connection,
      github_user.github_id,
      github_user.username,
      github_user.display_name,
      github_user.avatar_url,
    )
  {
    Error(_) ->
      login_page.login_page(Some("Failed to create user account."))
      |> element.to_document_string
      |> wisp.html_response(500)
    Ok(created_user) -> {
      let user_id_str = user.user_id_to_string(created_user.id)
      case session_repo.create_session(db_connection, user_id_str) {
        Error(_) ->
          login_page.login_page(Some("Failed to create session."))
          |> element.to_document_string
          |> wisp.html_response(500)
        Ok(session_token) ->
          wisp.redirect("/")
          |> wisp.set_cookie(
            request,
            middleware.session_cookie_name,
            session_token,
            wisp.Signed,
            session_repo.max_age_seconds(),
          )
      }
    }
  }
}
