import gleam/http
import gleam/http/request
import gleam/http/response as http_response
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import philstubs/data/database
import philstubs/data/test_helpers
import philstubs/data/user_repo
import philstubs/web/auth_handler
import philstubs/web/context.{Context}
import philstubs/web/router
import wisp/simulate

fn test_context(db_connection) -> context.Context {
  Context(
    static_directory: "",
    db_connection:,
    current_user: None,
    github_client_id: "",
    github_client_secret: "",
    scheduler: None,
  )
}

fn configured_context(db_connection) -> context.Context {
  Context(
    static_directory: "",
    db_connection:,
    current_user: None,
    github_client_id: "test-client-id",
    github_client_secret: "test-client-secret",
    scheduler: None,
  )
}

fn authenticated_context(db_connection) -> context.Context {
  let assert Ok(test_user) =
    user_repo.upsert_from_github(
      db_connection,
      55_555,
      "authuser",
      "Auth User",
      "",
    )
  Context(
    static_directory: "",
    db_connection:,
    current_user: Some(test_user),
    github_client_id: "test-client-id",
    github_client_secret: "test-client-secret",
    scheduler: None,
  )
}

// --- GET /login tests ---

pub fn login_shows_error_when_not_configured_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/login")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("not configured") |> should.be_true
}

pub fn login_redirects_to_github_when_configured_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = configured_context(connection)

  let response =
    simulate.request(http.Get, "/login")
    |> router.handle_request(context)

  response.status |> should.equal(303)
  let location = list.key_find(response.headers, "location")
  location |> should.be_ok
  let assert Ok(redirect_url) = location
  redirect_url
  |> string.contains("github.com/login/oauth/authorize")
  |> should.be_true
  redirect_url
  |> string.contains("client_id=test-client-id")
  |> should.be_true
}

// --- GET /auth/github/callback tests ---

pub fn callback_missing_code_shows_error_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = configured_context(connection)

  let mock_dispatcher = fn(_req: request.Request(String)) {
    Ok(http_response.new(200) |> http_response.set_body("{}"))
  }

  let response =
    simulate.request(http.Get, "/auth/github/callback")
    |> auth_handler.handle_github_callback(context, mock_dispatcher)

  response.status |> should.equal(400)
  let body = simulate.read_body(response)
  body |> string.contains("Missing authorization code") |> should.be_true
}

pub fn callback_token_exchange_failure_shows_error_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = configured_context(connection)

  let failing_dispatcher = fn(_req: request.Request(String)) {
    Error("Connection refused")
  }

  let response =
    simulate.request(http.Get, "/auth/github/callback?code=test-code")
    |> auth_handler.handle_github_callback(context, failing_dispatcher)

  response.status |> should.equal(400)
  let body = simulate.read_body(response)
  body |> string.contains("Authentication failed") |> should.be_true
}

pub fn callback_invalid_token_response_shows_error_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = configured_context(connection)

  let invalid_token_dispatcher = fn(_req: request.Request(String)) {
    Ok(
      http_response.new(200)
      |> http_response.set_body("{\"error\":\"bad_verification_code\"}"),
    )
  }

  let response =
    simulate.request(http.Get, "/auth/github/callback?code=test-code")
    |> auth_handler.handle_github_callback(context, invalid_token_dispatcher)

  response.status |> should.equal(400)
  let body = simulate.read_body(response)
  body |> string.contains("Authentication failed") |> should.be_true
}

pub fn callback_successful_login_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = configured_context(connection)

  let token_response =
    json.object([#("access_token", json.string("mock-token-123"))])
    |> json.to_string

  let user_response =
    json.object([
      #("id", json.int(77_777)),
      #("login", json.string("testghuser")),
      #("name", json.string("Test GitHub User")),
      #("avatar_url", json.string("https://avatars.example.com/testghuser")),
    ])
    |> json.to_string

  // Dispatch based on the request host to distinguish token exchange vs user info
  let mock_dispatcher = fn(req: request.Request(String)) {
    case string.contains(req.path, "access_token") {
      True ->
        Ok(http_response.new(200) |> http_response.set_body(token_response))
      False ->
        Ok(http_response.new(200) |> http_response.set_body(user_response))
    }
  }

  let response =
    simulate.request(http.Get, "/auth/github/callback?code=valid-code")
    |> auth_handler.handle_github_callback(context, mock_dispatcher)

  // Should redirect to / on success
  response.status |> should.equal(303)
  let location = list.key_find(response.headers, "location")
  location |> should.equal(Ok("/"))

  // User should have been created
  let assert Ok(Some(created_user)) =
    user_repo.get_by_github_id(connection, 77_777)
  created_user.username |> should.equal("testghuser")
}

// --- GET /profile tests ---

pub fn profile_redirects_when_not_logged_in_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/profile")
    |> router.handle_request(context)

  response.status |> should.equal(303)
  let location = list.key_find(response.headers, "location")
  location |> should.equal(Ok("/login"))
}

pub fn profile_shows_user_info_when_logged_in_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = authenticated_context(connection)

  let response =
    simulate.request(http.Get, "/profile")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("authuser") |> should.be_true
}

// --- Auth protection tests ---

pub fn unauthenticated_template_create_redirects_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Post, "/templates")
    |> simulate.form_body([
      #("title", "Test"),
      #("body", "Body"),
      #("author", "Author"),
    ])
    |> router.handle_request(context)

  // Should redirect to login
  response.status |> should.equal(303)
  let location = list.key_find(response.headers, "location")
  location |> should.equal(Ok("/login"))
}

pub fn unauthenticated_api_template_create_returns_401_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Post, "/api/templates")
    |> simulate.string_body("{\"title\":\"Test\"}")
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(401)
}

pub fn unauthenticated_api_template_delete_returns_401_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Delete, "/api/templates/some-id")
    |> router.handle_request(context)

  response.status |> should.equal(401)
}

pub fn unauthenticated_api_template_update_returns_401_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Put, "/api/templates/some-id")
    |> simulate.string_body("{\"title\":\"Test\"}")
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(401)
}
