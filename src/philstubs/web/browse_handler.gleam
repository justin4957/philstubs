import gleam/result
import lustre/element
import philstubs/data/browse_repo
import philstubs/ui/browse_page
import sqlight
import wisp.{type Response}

/// Handle GET /browse — render the root browse page with level counts.
pub fn handle_browse_root(db_connection: sqlight.Connection) -> Response {
  case browse_repo.count_by_government_level(db_connection) {
    Ok(level_counts) ->
      browse_page.browse_root_page(level_counts)
      |> element.to_document_string
      |> wisp.html_response(200)
    Error(_) -> wisp.internal_server_error()
  }
}

/// Handle GET /browse/states — render the states listing page.
pub fn handle_browse_states(db_connection: sqlight.Connection) -> Response {
  case browse_repo.count_by_state(db_connection) {
    Ok(state_counts) ->
      browse_page.browse_states_page(state_counts)
      |> element.to_document_string
      |> wisp.html_response(200)
    Error(_) -> wisp.internal_server_error()
  }
}

/// Handle GET /browse/state/:state_code — render the state detail page
/// with counties and municipalities.
pub fn handle_browse_state(
  state_code: String,
  db_connection: sqlight.Connection,
) -> Response {
  let state_legislation_count =
    browse_repo.count_state_legislation(db_connection, state_code)
    |> result.unwrap(0)

  let county_counts =
    browse_repo.count_counties_in_state(db_connection, state_code)
    |> result.unwrap([])

  let municipality_counts =
    browse_repo.count_municipalities_in_state(db_connection, state_code)
    |> result.unwrap([])

  browse_page.browse_state_page(
    state_code,
    state_legislation_count,
    county_counts,
    municipality_counts,
  )
  |> element.to_document_string
  |> wisp.html_response(200)
}

/// Handle GET /browse/topics — render the topics listing page.
/// Falls back to flat topic list when no taxonomy is available.
pub fn handle_browse_topics(db_connection: sqlight.Connection) -> Response {
  let flat_topic_counts = case browse_repo.count_topics(db_connection) {
    Ok(counts) -> counts
    Error(_) -> []
  }

  browse_page.browse_topics_page([], flat_topic_counts)
  |> element.to_document_string
  |> wisp.html_response(200)
}
