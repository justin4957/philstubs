import gleam/http
import gleam/option.{None}
import gleam/string
import gleeunit/should
import philstubs/data/database
import philstubs/data/test_helpers
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

// --- Page rendering tests ---

pub fn explore_page_renders_200_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  response.status |> should.equal(200)
}

pub fn explore_page_contains_d3_script_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("d3@7") |> should.be_true
}

pub fn explore_page_contains_explore_js_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("/static/js/explore.js") |> should.be_true
}

pub fn explore_page_contains_graph_container_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("explore-graph") |> should.be_true
}

pub fn explore_page_contains_edge_filters_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body
  |> string.contains("explore-edge-filter-references")
  |> should.be_true
  body |> string.contains("explore-edge-filter-amends") |> should.be_true
  body
  |> string.contains("explore-edge-filter-supersedes")
  |> should.be_true
  body
  |> string.contains("explore-edge-filter-implements")
  |> should.be_true
  body
  |> string.contains("explore-edge-filter-delegates")
  |> should.be_true
  body
  |> string.contains("explore-edge-filter-similar_to")
  |> should.be_true
}

pub fn explore_page_contains_search_input_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("explore-search-input") |> should.be_true
  body |> string.contains("explore-search-button") |> should.be_true
}

pub fn explore_page_contains_path_finder_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("explore-path-from") |> should.be_true
  body |> string.contains("explore-path-to") |> should.be_true
  body |> string.contains("explore-path-button") |> should.be_true
}

pub fn explore_page_contains_cluster_loader_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("explore-cluster-input") |> should.be_true
  body |> string.contains("explore-cluster-button") |> should.be_true
}

pub fn explore_page_contains_detail_panel_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("explore-detail-panel") |> should.be_true
}

pub fn explore_page_with_initial_id_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore?id=leg-001")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("leg-001") |> should.be_true
}

pub fn explore_page_contains_zoom_controls_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("explore-zoom-in") |> should.be_true
  body |> string.contains("explore-zoom-out") |> should.be_true
  body |> string.contains("explore-zoom-reset") |> should.be_true
}

pub fn explore_page_init_without_id_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body
  |> string.contains("PhilstubsExplorer.init({})")
  |> should.be_true
}

pub fn explore_page_contains_depth_selector_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("explore-depth-select") |> should.be_true
}

pub fn explore_page_contains_legend_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("explore-legend") |> should.be_true
  body |> string.contains("Federal") |> should.be_true
  body |> string.contains("State") |> should.be_true
  body |> string.contains("County") |> should.be_true
  body |> string.contains("Municipal") |> should.be_true
}

pub fn explore_page_navigation_link_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/explore")
    |> router.handle_request(context)

  let body = simulate.read_body(response)
  body |> string.contains("/explore") |> should.be_true
  body |> string.contains("Explore") |> should.be_true
}
