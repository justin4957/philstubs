import gleam/http
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import philstubs/core/saved_exploration.{SavedExploration}
import philstubs/core/user
import philstubs/data/database
import philstubs/data/exploration_repo
import philstubs/data/test_helpers
import philstubs/data/user_repo
import philstubs/web/context.{Context}
import philstubs/web/router
import sqlight
import wisp/simulate

fn test_context(db_connection: sqlight.Connection) -> context.Context {
  Context(
    static_directory: "",
    db_connection:,
    current_user: None,
    github_client_id: "",
    github_client_secret: "",
    scheduler: None,
  )
}

fn authenticated_context(db_connection: sqlight.Connection) -> context.Context {
  let assert Ok(test_user) =
    user_repo.upsert_from_github(
      db_connection,
      99_999,
      "exploretestuser",
      "Explore Test User",
      "",
    )
  Context(
    static_directory: "",
    db_connection:,
    current_user: Some(test_user),
    github_client_id: "",
    github_client_secret: "",
    scheduler: None,
  )
}

fn insert_test_exploration(
  connection: sqlight.Connection,
  exploration_id: String,
  user_id: String,
  title: String,
  is_public: Bool,
) -> Nil {
  let exploration =
    SavedExploration(
      id: saved_exploration.exploration_id(exploration_id),
      user_id: Some(user_id),
      title:,
      description: "Test description",
      graph_state: "{\"nodes\":[],\"edges\":[]}",
      created_at: "",
      updated_at: "",
      is_public:,
    )
  let assert Ok(_) = exploration_repo.insert(connection, exploration)
  Nil
}

// --- POST /api/explorations ---

pub fn create_exploration_returns_201_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = authenticated_context(connection)

  let json_body =
    "{\"title\":\"My Graph\",\"graph_state\":\"{\\\"nodes\\\":[]}\",\"description\":\"A test\",\"is_public\":false}"

  let response =
    simulate.request(http.Post, "/api/explorations")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(201)
  let body = simulate.read_body(response)
  body |> string.contains("\"title\":\"My Graph\"") |> should.be_true
  body |> string.contains("\"graph_state\"") |> should.be_true
  body |> string.contains("\"id\"") |> should.be_true
}

pub fn create_exploration_unauthenticated_returns_401_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let json_body =
    "{\"title\":\"My Graph\",\"graph_state\":\"{\\\"nodes\\\":[]}\"}"

  let response =
    simulate.request(http.Post, "/api/explorations")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(401)
}

pub fn create_exploration_empty_title_returns_400_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = authenticated_context(connection)

  let json_body = "{\"title\":\"\",\"graph_state\":\"{\\\"nodes\\\":[]}\"}"

  let response =
    simulate.request(http.Post, "/api/explorations")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(400)
  let body = simulate.read_body(response)
  body |> string.contains("title") |> should.be_true
}

pub fn create_exploration_empty_graph_state_returns_400_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = authenticated_context(connection)

  let json_body = "{\"title\":\"Test\",\"graph_state\":\"\"}"

  let response =
    simulate.request(http.Post, "/api/explorations")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(400)
  let body = simulate.read_body(response)
  body |> string.contains("graph_state") |> should.be_true
}

// --- GET /api/explorations ---

pub fn list_explorations_authenticated_returns_own_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = authenticated_context(connection)

  let response =
    simulate.request(http.Get, "/api/explorations")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"explorations\"") |> should.be_true
}

pub fn list_explorations_public_filter_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = authenticated_context(connection)

  let response =
    simulate.request(http.Get, "/api/explorations?public=true")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"explorations\"") |> should.be_true
}

pub fn list_explorations_unauthenticated_returns_public_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/explorations")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"explorations\"") |> should.be_true
}

// --- GET /api/explorations/:id ---

pub fn get_public_exploration_returns_200_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  insert_test_exploration(
    connection,
    "expl-pub-001",
    "usr-pubuser",
    "Public Graph",
    True,
  )

  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/explorations/expl-pub-001")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"title\":\"Public Graph\"") |> should.be_true
}

pub fn get_private_exploration_owner_returns_200_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(test_user) =
    user_repo.upsert_from_github(
      connection,
      99_999,
      "exploretestuser",
      "Explore Test User",
      "",
    )

  let owner_user_id = user.user_id_to_string(test_user.id)

  insert_test_exploration(
    connection,
    "expl-priv-001",
    owner_user_id,
    "Private Graph",
    False,
  )

  let context =
    Context(
      static_directory: "",
      db_connection: connection,
      current_user: Some(test_user),
      github_client_id: "",
      github_client_secret: "",
      scheduler: None,
    )

  let response =
    simulate.request(http.Get, "/api/explorations/expl-priv-001")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"title\":\"Private Graph\"") |> should.be_true
}

pub fn get_private_exploration_non_owner_returns_403_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  insert_test_exploration(
    connection,
    "expl-priv-002",
    "some-other-user-id",
    "Secret Graph",
    False,
  )

  let context = authenticated_context(connection)

  let response =
    simulate.request(http.Get, "/api/explorations/expl-priv-002")
    |> router.handle_request(context)

  response.status |> should.equal(403)
}

pub fn get_exploration_not_found_returns_404_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/explorations/nonexistent")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

// --- PUT /api/explorations/:id ---

pub fn update_exploration_owner_returns_200_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(test_user) =
    user_repo.upsert_from_github(
      connection,
      99_999,
      "exploretestuser",
      "Explore Test User",
      "",
    )

  let owner_user_id = user.user_id_to_string(test_user.id)

  insert_test_exploration(
    connection,
    "expl-upd-001",
    owner_user_id,
    "Original Title",
    False,
  )

  let context =
    Context(
      static_directory: "",
      db_connection: connection,
      current_user: Some(test_user),
      github_client_id: "",
      github_client_secret: "",
      scheduler: None,
    )

  let json_body =
    "{\"title\":\"Updated Title\",\"graph_state\":\"{\\\"nodes\\\":[{\\\"id\\\":\\\"new\\\"}]}\",\"description\":\"Updated\",\"is_public\":true}"

  let response =
    simulate.request(http.Put, "/api/explorations/expl-upd-001")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"title\":\"Updated Title\"") |> should.be_true
}

pub fn update_exploration_non_owner_returns_403_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  insert_test_exploration(
    connection,
    "expl-upd-002",
    "some-other-user-id",
    "Original Title",
    False,
  )

  let context = authenticated_context(connection)

  let json_body =
    "{\"title\":\"Hacked Title\",\"graph_state\":\"{\\\"nodes\\\":[]}\"}"

  let response =
    simulate.request(http.Put, "/api/explorations/expl-upd-002")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(403)
}

pub fn update_exploration_unauthenticated_returns_401_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let json_body = "{\"title\":\"Test\",\"graph_state\":\"{\\\"nodes\\\":[]}\"}"

  let response =
    simulate.request(http.Put, "/api/explorations/some-id")
    |> simulate.string_body(json_body)
    |> simulate.header("content-type", "application/json")
    |> router.handle_request(context)

  response.status |> should.equal(401)
}

// --- DELETE /api/explorations/:id ---

pub fn delete_exploration_owner_returns_204_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(test_user) =
    user_repo.upsert_from_github(
      connection,
      99_999,
      "exploretestuser",
      "Explore Test User",
      "",
    )

  let owner_user_id = user.user_id_to_string(test_user.id)

  insert_test_exploration(
    connection,
    "expl-del-001",
    owner_user_id,
    "To Delete",
    False,
  )

  let context =
    Context(
      static_directory: "",
      db_connection: connection,
      current_user: Some(test_user),
      github_client_id: "",
      github_client_secret: "",
      scheduler: None,
    )

  let response =
    simulate.request(http.Delete, "/api/explorations/expl-del-001")
    |> router.handle_request(context)

  response.status |> should.equal(204)

  // Verify it's gone
  let assert Ok(None) = exploration_repo.get_by_id(connection, "expl-del-001")
}

pub fn delete_exploration_non_owner_returns_403_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  insert_test_exploration(
    connection,
    "expl-del-002",
    "some-other-user-id",
    "Protected",
    False,
  )

  let context = authenticated_context(connection)

  let response =
    simulate.request(http.Delete, "/api/explorations/expl-del-002")
    |> router.handle_request(context)

  response.status |> should.equal(403)
}

pub fn delete_exploration_unauthenticated_returns_401_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Delete, "/api/explorations/some-id")
    |> router.handle_request(context)

  response.status |> should.equal(401)
}

pub fn delete_exploration_not_found_returns_404_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = authenticated_context(connection)

  let response =
    simulate.request(http.Delete, "/api/explorations/nonexistent")
    |> router.handle_request(context)

  response.status |> should.equal(404)
}

// --- Explore page with ?state= ---

pub fn explore_page_with_state_param_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore?state=expl-abc123")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("expl-abc123") |> should.be_true
}

pub fn explore_page_without_state_param_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("PhilstubsExplorer.init") |> should.be_true
}
