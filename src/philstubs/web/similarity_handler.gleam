import gleam/json
import gleam/option.{None, Some}
import gleam/result
import lustre/element
import philstubs/core/similarity
import philstubs/core/similarity_pipeline
import philstubs/core/similarity_types
import philstubs/data/legislation_repo
import philstubs/data/similarity_repo
import philstubs/ui/diff_page
import sqlight
import wisp.{type Response}

/// Handle GET /api/legislation/:id/similar — return similar legislation as JSON.
pub fn handle_similar_legislation(
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  case similarity_repo.find_similar(db_connection, legislation_id, 0.0, 20) {
    Ok(similar_list) -> {
      json.object([
        #("legislation_id", json.string(legislation_id)),
        #(
          "similar",
          json.array(similar_list, similarity_types.similar_legislation_to_json),
        ),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> wisp.internal_server_error()
  }
}

/// Handle GET /api/legislation/:id/adoption-timeline — chronological events.
pub fn handle_adoption_timeline(
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  case similarity_repo.adoption_timeline(db_connection, legislation_id, 0.0) {
    Ok(timeline_events) -> {
      json.object([
        #("legislation_id", json.string(legislation_id)),
        #(
          "timeline",
          json.array(timeline_events, similarity_types.adoption_event_to_json),
        ),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> wisp.internal_server_error()
  }
}

/// Handle GET /api/templates/:id/matches — legislation matching a template.
pub fn handle_template_matches(
  template_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  case
    similarity_repo.find_template_matches(db_connection, template_id, 0.0, 20)
  {
    Ok(match_list) -> {
      json.object([
        #("template_id", json.string(template_id)),
        #(
          "matches",
          json.array(match_list, similarity_types.template_match_to_json),
        ),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> wisp.internal_server_error()
  }
}

/// Handle GET /legislation/:id/diff/:comparison_id — HTML diff view.
pub fn handle_diff_view(
  legislation_id: String,
  comparison_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  let source_result = legislation_repo.get_by_id(db_connection, legislation_id)
  let target_result = legislation_repo.get_by_id(db_connection, comparison_id)

  case source_result, target_result {
    Ok(Some(source_record)), Ok(Some(target_record)) -> {
      let diff_hunks =
        similarity.compute_diff(source_record.body, target_record.body)

      diff_page.diff_page(source_record, target_record, diff_hunks)
      |> element.to_document_string
      |> wisp.html_response(200)
    }
    Ok(None), _ | _, Ok(None) -> wisp.not_found()
    Error(_), _ | _, Error(_) -> wisp.internal_server_error()
  }
}

/// Handle POST /api/similarity/compute — trigger similarity computation.
pub fn handle_compute_similarities(
  db_connection: sqlight.Connection,
) -> Response {
  let legislation_result =
    similarity_pipeline.compute_all_similarities(db_connection, 0.3)
  let template_result =
    similarity_pipeline.compute_template_matches(db_connection, 0.3)

  case legislation_result, template_result {
    Ok(legislation_pairs), Ok(template_matches) -> {
      json.object([
        #("legislation_pairs_stored", json.int(legislation_pairs)),
        #("template_matches_stored", json.int(template_matches)),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_), _ | _, Error(_) -> {
      let partial_legislation_count = result.unwrap(legislation_result, 0)
      let partial_template_count = result.unwrap(template_result, 0)
      json.object([
        #("legislation_pairs_stored", json.int(partial_legislation_count)),
        #("template_matches_stored", json.int(partial_template_count)),
        #("error", json.string("Partial computation failure")),
      ])
      |> json.to_string
      |> wisp.json_response(500)
    }
  }
}
