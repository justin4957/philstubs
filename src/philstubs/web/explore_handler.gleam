import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import philstubs/core/explore_graph
import philstubs/core/explore_types
import philstubs/data/explore_repo
import philstubs/data/impact_repo
import philstubs/web/api_error
import sqlight
import wisp.{type Request, type Response}

/// Handle GET /api/explore/node/:legislation_id
/// Returns a single node with all its edges and neighbor summaries.
pub fn handle_node(
  _request: Request,
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  case
    explore_repo.load_node(db_connection, legislation_id),
    explore_repo.load_node_edges(db_connection, legislation_id),
    impact_repo.load_legislation_metadata(db_connection)
  {
    Ok(node_result), Ok(#(outgoing, incoming, similarities)), Ok(metadata) -> {
      case node_result {
        Some(#(legislation, topics)) -> {
          let neighborhood =
            explore_graph.build_neighborhood(
              legislation,
              topics,
              outgoing,
              incoming,
              similarities,
              metadata,
            )
          neighborhood
          |> explore_types.node_neighborhood_to_json
          |> json.to_string
          |> wisp.json_response(200)
        }
        None -> api_error.not_found("Legislation")
      }
    }
    _, _, _ -> api_error.internal_error()
  }
}

/// Handle GET /api/explore/expand/:legislation_id?edge_types=...&depth=N
/// BFS expansion from a root node, filtered by edge types and depth.
pub fn handle_expand(
  request: Request,
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  let query_params = wisp.get_query(request)

  let edge_types =
    list.key_find(query_params, "edge_types")
    |> result.unwrap("")
    |> explore_types.parse_edge_types

  let depth =
    list.key_find(query_params, "depth")
    |> result.try(int.parse)
    |> result.unwrap(1)
    |> clamp_depth

  case
    impact_repo.load_dependency_graph(db_connection),
    explore_repo.load_similarity_adjacency(db_connection, 0.1),
    impact_repo.load_legislation_metadata(db_connection)
  {
    Ok(graph), Ok(similarity_adjacency), Ok(metadata) -> {
      let expand_result =
        explore_graph.build_expand_result(
          legislation_id,
          depth,
          edge_types,
          graph,
          similarity_adjacency,
          metadata,
        )
      expand_result
      |> explore_types.expand_result_to_json
      |> json.to_string
      |> wisp.json_response(200)
    }
    _, _, _ -> api_error.internal_error()
  }
}

/// Handle GET /api/explore/path/:from_id/:to_id
/// Shortest path through the cross-reference graph.
pub fn handle_path(
  _request: Request,
  from_id: String,
  to_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  case
    impact_repo.load_dependency_graph(db_connection),
    impact_repo.load_legislation_metadata(db_connection)
  {
    Ok(graph), Ok(metadata) -> {
      let path_result =
        explore_graph.find_shortest_path(graph, metadata, from_id, to_id, 10)
      path_result
      |> explore_types.path_result_to_json
      |> json.to_string
      |> wisp.json_response(200)
    }
    _, _ -> api_error.internal_error()
  }
}

/// Handle GET /api/explore/cluster/:topic_slug?limit=50&min_similarity=0.3
/// All legislation in a topic with inter-connections.
pub fn handle_cluster(
  request: Request,
  topic_slug: String,
  db_connection: sqlight.Connection,
) -> Response {
  let query_params = wisp.get_query(request)

  let limit =
    list.key_find(query_params, "limit")
    |> result.try(int.parse)
    |> result.unwrap(50)
    |> clamp_limit

  let min_similarity =
    list.key_find(query_params, "min_similarity")
    |> result.try(float.parse)
    |> result.unwrap(0.3)

  case
    explore_repo.load_legislation_ids_for_topic(
      db_connection,
      topic_slug,
      limit,
    ),
    impact_repo.load_legislation_metadata(db_connection)
  {
    Ok(topic_result), Ok(metadata) -> {
      case topic_result {
        Some(#(found_topic, legislation_ids)) -> {
          case
            explore_repo.load_inter_references(db_connection, legislation_ids),
            explore_repo.load_inter_similarities(
              db_connection,
              legislation_ids,
              min_similarity,
            )
          {
            Ok(references), Ok(similarities) -> {
              let cluster_result =
                explore_graph.build_cluster(
                  topic_slug,
                  found_topic.name,
                  legislation_ids,
                  references,
                  similarities,
                  metadata,
                )
              cluster_result
              |> explore_types.cluster_result_to_json
              |> json.to_string
              |> wisp.json_response(200)
            }
            _, _ -> api_error.internal_error()
          }
        }
        None -> api_error.not_found("Topic")
      }
    }
    _, _ -> api_error.internal_error()
  }
}

fn clamp_depth(value: Int) -> Int {
  case value {
    depth if depth < 1 -> 1
    depth if depth > 3 -> 3
    depth -> depth
  }
}

fn clamp_limit(value: Int) -> Int {
  case value {
    limit if limit < 1 -> 1
    limit if limit > 200 -> 200
    limit -> limit
  }
}
