import gleam/int
import gleam/json
import gleam/list
import gleam/result
import philstubs/core/impact_analyzer
import philstubs/core/impact_types
import philstubs/data/impact_repo
import sqlight
import wisp.{type Request, type Response}

/// Handle GET /api/legislation/:id/impact — analyze cross-reference impact.
///
/// Query params:
/// - direction: "incoming", "outgoing", or "both" (default: "both")
/// - max_depth: 1-10 (default: 3)
pub fn handle_impact_analysis(
  request: Request,
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  let query_params = wisp.get_query(request)

  let direction =
    list.key_find(query_params, "direction")
    |> result.unwrap("both")
    |> impact_types.direction_from_string

  let max_depth =
    list.key_find(query_params, "max_depth")
    |> result.try(int.parse)
    |> result.unwrap(3)
    |> clamp_depth

  case
    impact_repo.load_dependency_graph(db_connection),
    impact_repo.load_legislation_metadata(db_connection)
  {
    Ok(graph), Ok(metadata) -> {
      let impact_result =
        impact_analyzer.analyze_impact(
          graph,
          metadata,
          legislation_id,
          direction,
          max_depth,
        )

      impact_result
      |> impact_types.impact_result_to_json
      |> json.to_string
      |> wisp.json_response(200)
    }
    _, _ -> wisp.internal_server_error()
  }
}

fn clamp_depth(value: Int) -> Int {
  case value {
    depth if depth < 1 -> 1
    depth if depth > 10 -> 10
    depth -> depth
  }
}
