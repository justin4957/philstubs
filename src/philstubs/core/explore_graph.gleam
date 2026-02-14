import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}
import philstubs/core/explore_types.{
  type ClusterResult, type ExpandResult, type ExploreEdge, type ExploreEdgeType,
  type ExploreNode, type NodeNeighborhood, type PathResult, ClusterResult,
  ExpandResult, ExploreEdge, ExploreEdgeMetadata, ExploreNode,
  ExploreNodeMetadata, NodeNeighborhood, PathResult, SimilarToEdge,
}
import philstubs/core/impact_types.{
  type DependencyGraph, type GraphEdge, type LegislationSummary,
}
import philstubs/core/legislation.{type Legislation}
import philstubs/core/legislation_status
import philstubs/core/reference
import philstubs/core/topic.{type Topic}

/// A row from the legislation_similarities table used for building edges.
pub type SimilarityEdgeRow {
  SimilarityEdgeRow(
    target_legislation_id: String,
    similarity_score: Float,
    title_score: Float,
    body_score: Float,
    topic_score: Float,
  )
}

/// Build a NodeNeighborhood from a Legislation record and its relationships.
pub fn build_neighborhood(
  legislation: Legislation,
  topics: List(Topic),
  outgoing_refs: List(reference.CrossReference),
  incoming_refs: List(reference.CrossReference),
  similar_edges: List(SimilarityEdgeRow),
  metadata: Dict(String, LegislationSummary),
) -> NodeNeighborhood {
  let legislation_id = legislation.legislation_id_to_string(legislation.id)
  let node = legislation_to_explore_node(legislation, topics)

  let outgoing_ref_edges =
    list.map(outgoing_refs, fn(ref) {
      let target_id = option.unwrap(ref.target_legislation_id, "")
      ExploreEdge(
        source: legislation_id,
        target: target_id,
        edge_type: explore_types.reference_type_to_edge_type(ref.reference_type),
        weight: ref.confidence,
        metadata: ExploreEdgeMetadata(
          citation: ref.citation_text,
          title_score: 0.0,
          body_score: 0.0,
          topic_score: 0.0,
        ),
      )
    })
    |> list.filter(fn(edge) { edge.target != "" })

  let incoming_ref_edges =
    list.map(incoming_refs, fn(ref) {
      ExploreEdge(
        source: ref.source_legislation_id,
        target: legislation_id,
        edge_type: explore_types.reference_type_to_edge_type(ref.reference_type),
        weight: ref.confidence,
        metadata: ExploreEdgeMetadata(
          citation: ref.citation_text,
          title_score: 0.0,
          body_score: 0.0,
          topic_score: 0.0,
        ),
      )
    })

  let similarity_edges =
    list.map(similar_edges, fn(row) {
      ExploreEdge(
        source: legislation_id,
        target: row.target_legislation_id,
        edge_type: SimilarToEdge,
        weight: row.similarity_score,
        metadata: ExploreEdgeMetadata(
          citation: "",
          title_score: row.title_score,
          body_score: row.body_score,
          topic_score: row.topic_score,
        ),
      )
    })

  let all_edges =
    list.flatten([outgoing_ref_edges, incoming_ref_edges, similarity_edges])

  // Collect neighbor IDs from all edges
  let neighbor_ids =
    list.flat_map(all_edges, fn(edge: ExploreEdge) {
      [edge.source, edge.target]
    })
    |> set.from_list
    |> set.delete(legislation_id)

  let neighbors =
    set.to_list(neighbor_ids)
    |> list.filter_map(fn(neighbor_id) {
      case dict.get(metadata, neighbor_id) {
        Ok(summary) -> Ok(summary_to_explore_node(summary))
        Error(_) -> Error(Nil)
      }
    })

  NodeNeighborhood(node:, edges: all_edges, neighbors:)
}

/// BFS expansion from a root node, filtered by edge types and depth.
pub fn build_expand_result(
  root_id: String,
  depth: Int,
  edge_types: List(ExploreEdgeType),
  graph: DependencyGraph,
  similarity_adjacency: Dict(String, List(SimilarityEdgeRow)),
  metadata: Dict(String, LegislationSummary),
) -> ExpandResult {
  let edge_type_set = set.from_list(edge_types)
  let include_references = has_any_reference_edge(edge_type_set)
  let include_similarity = set.contains(edge_type_set, SimilarToEdge)

  let initial_visited = set.from_list([root_id])
  let initial_queue = [#(root_id, 0)]

  let #(collected_nodes, collected_edges) =
    do_expand_bfs(
      graph,
      similarity_adjacency,
      metadata,
      edge_type_set,
      include_references,
      include_similarity,
      depth,
      initial_queue,
      initial_visited,
      [],
      [],
    )

  // Include root node in the result if it has metadata
  let root_nodes = case dict.get(metadata, root_id) {
    Ok(summary) -> [summary_to_explore_node(summary)]
    Error(_) -> []
  }

  ExpandResult(
    root_id:,
    depth:,
    edge_types:,
    nodes: list.append(root_nodes, list.reverse(collected_nodes)),
    edges: list.reverse(collected_edges),
  )
}

/// Find the shortest path between two legislation nodes via BFS.
/// Returns distance=-1 if unreachable within max_depth.
pub fn find_shortest_path(
  graph: DependencyGraph,
  metadata: Dict(String, LegislationSummary),
  from_id: String,
  to_id: String,
  max_depth: Int,
) -> PathResult {
  case from_id == to_id {
    True -> {
      let path_nodes = case dict.get(metadata, from_id) {
        Ok(summary) -> [summary_to_explore_node(summary)]
        Error(_) -> []
      }
      PathResult(from_id:, to_id:, path: path_nodes, edges: [], distance: 0)
    }
    False -> {
      let initial_visited = set.from_list([from_id])
      let initial_queue = [#(from_id, 0)]

      case
        do_path_bfs(
          graph,
          max_depth,
          to_id,
          initial_queue,
          initial_visited,
          dict.new(),
        )
      {
        Some(parent_map) -> {
          let #(path_ids, path_edges) =
            reconstruct_path(parent_map, from_id, to_id, [], [])
          let path_nodes =
            list.filter_map(path_ids, fn(node_id) {
              case dict.get(metadata, node_id) {
                Ok(summary) -> Ok(summary_to_explore_node(summary))
                Error(_) -> Error(Nil)
              }
            })
          PathResult(
            from_id:,
            to_id:,
            path: path_nodes,
            edges: path_edges,
            distance: list.length(path_ids) - 1,
          )
        }
        None -> PathResult(from_id:, to_id:, path: [], edges: [], distance: -1)
      }
    }
  }
}

/// Build a cluster of legislation within a topic.
pub fn build_cluster(
  topic_slug: String,
  topic_name: String,
  legislation_ids: List(String),
  references: List(reference.CrossReference),
  similarities: List(SimilarityEdgeRow),
  metadata: Dict(String, LegislationSummary),
) -> ClusterResult {
  let id_set = set.from_list(legislation_ids)

  let nodes =
    list.filter_map(legislation_ids, fn(legislation_id) {
      case dict.get(metadata, legislation_id) {
        Ok(summary) -> Ok(summary_to_explore_node(summary))
        Error(_) -> Error(Nil)
      }
    })

  let reference_edges =
    list.filter_map(references, fn(ref) {
      let target_id = option.unwrap(ref.target_legislation_id, "")
      case
        set.contains(id_set, ref.source_legislation_id)
        && set.contains(id_set, target_id)
      {
        True ->
          Ok(ExploreEdge(
            source: ref.source_legislation_id,
            target: target_id,
            edge_type: explore_types.reference_type_to_edge_type(
              ref.reference_type,
            ),
            weight: ref.confidence,
            metadata: ExploreEdgeMetadata(
              citation: ref.citation_text,
              title_score: 0.0,
              body_score: 0.0,
              topic_score: 0.0,
            ),
          ))
        False -> Error(Nil)
      }
    })

  let similarity_edges =
    list.flat_map(legislation_ids, fn(source_id) {
      list.filter_map(similarities, fn(row) {
        case
          source_id != row.target_legislation_id
          && set.contains(id_set, row.target_legislation_id)
        {
          True ->
            Ok(ExploreEdge(
              source: source_id,
              target: row.target_legislation_id,
              edge_type: SimilarToEdge,
              weight: row.similarity_score,
              metadata: ExploreEdgeMetadata(
                citation: "",
                title_score: row.title_score,
                body_score: row.body_score,
                topic_score: row.topic_score,
              ),
            ))
          False -> Error(Nil)
        }
      })
    })

  ClusterResult(
    topic_slug:,
    topic_name:,
    nodes:,
    edges: list.append(reference_edges, similarity_edges),
  )
}

/// Convert a Legislation record to an ExploreNode.
pub fn legislation_to_explore_node(
  legislation: Legislation,
  topics: List(Topic),
) -> ExploreNode {
  let topic_names = list.map(topics, fn(t) { t.name })
  ExploreNode(
    id: legislation.legislation_id_to_string(legislation.id),
    node_type: "legislation",
    label: legislation.title,
    level: legislation.level,
    status: legislation.status,
    introduced_date: legislation.introduced_date,
    metadata: ExploreNodeMetadata(
      sponsors: legislation.sponsors,
      topics: topic_names,
      source_identifier: legislation.source_identifier,
      legislation_type: legislation.legislation_type,
    ),
  )
}

/// Convert a LegislationSummary to an ExploreNode (lightweight version).
pub fn summary_to_explore_node(summary: LegislationSummary) -> ExploreNode {
  ExploreNode(
    id: summary.legislation_id,
    node_type: "legislation",
    label: summary.title,
    level: summary.level,
    status: legislation_status.Introduced,
    introduced_date: "",
    metadata: ExploreNodeMetadata(
      sponsors: [],
      topics: [],
      source_identifier: "",
      legislation_type: summary.legislation_type,
    ),
  )
}

// --- Internal BFS for expand ---

fn do_expand_bfs(
  graph: DependencyGraph,
  similarity_adjacency: Dict(String, List(SimilarityEdgeRow)),
  metadata: Dict(String, LegislationSummary),
  edge_type_set: Set(ExploreEdgeType),
  include_references: Bool,
  include_similarity: Bool,
  max_depth: Int,
  queue: List(#(String, Int)),
  visited: Set(String),
  accumulated_nodes: List(ExploreNode),
  accumulated_edges: List(ExploreEdge),
) -> #(List(ExploreNode), List(ExploreEdge)) {
  case queue {
    [] -> #(accumulated_nodes, accumulated_edges)
    [#(current_id, current_depth), ..rest_queue] -> {
      case current_depth >= max_depth {
        True ->
          do_expand_bfs(
            graph,
            similarity_adjacency,
            metadata,
            edge_type_set,
            include_references,
            include_similarity,
            max_depth,
            rest_queue,
            visited,
            accumulated_nodes,
            accumulated_edges,
          )
        False -> {
          let next_depth = current_depth + 1

          // Collect reference edges
          let #(ref_nodes, ref_edges, ref_visited, ref_queue) = case
            include_references
          {
            True -> {
              let outgoing_edges =
                dict.get(graph.outgoing, current_id)
                |> unwrap_or_empty
              let incoming_edges =
                dict.get(graph.incoming, current_id)
                |> unwrap_or_empty

              let filtered_outgoing =
                list.filter(outgoing_edges, fn(edge) {
                  set.contains(
                    edge_type_set,
                    explore_types.reference_type_to_edge_type(
                      edge.reference_type,
                    ),
                  )
                  && !set.contains(visited, edge.target_id)
                })

              let filtered_incoming =
                list.filter(incoming_edges, fn(edge) {
                  set.contains(
                    edge_type_set,
                    explore_types.reference_type_to_edge_type(
                      edge.reference_type,
                    ),
                  )
                  && !set.contains(visited, edge.target_id)
                })

              let outgoing_explore_edges =
                list.map(filtered_outgoing, fn(edge) {
                  ExploreEdge(
                    source: current_id,
                    target: edge.target_id,
                    edge_type: explore_types.reference_type_to_edge_type(
                      edge.reference_type,
                    ),
                    weight: edge.confidence,
                    metadata: ExploreEdgeMetadata(
                      citation: "",
                      title_score: 0.0,
                      body_score: 0.0,
                      topic_score: 0.0,
                    ),
                  )
                })

              let incoming_explore_edges =
                list.map(filtered_incoming, fn(edge) {
                  ExploreEdge(
                    source: edge.target_id,
                    target: current_id,
                    edge_type: explore_types.reference_type_to_edge_type(
                      edge.reference_type,
                    ),
                    weight: edge.confidence,
                    metadata: ExploreEdgeMetadata(
                      citation: "",
                      title_score: 0.0,
                      body_score: 0.0,
                      topic_score: 0.0,
                    ),
                  )
                })

              let all_ref_target_ids =
                list.map(filtered_outgoing, fn(edge) { edge.target_id })
                |> list.append(
                  list.map(filtered_incoming, fn(edge) { edge.target_id }),
                )

              let ref_nodes_collected =
                list.filter_map(all_ref_target_ids, fn(target_id) {
                  case dict.get(metadata, target_id) {
                    Ok(summary) -> Ok(summary_to_explore_node(summary))
                    Error(_) -> Error(Nil)
                  }
                })

              let updated_visited =
                list.fold(all_ref_target_ids, visited, set.insert)
              let new_queue_items =
                list.map(all_ref_target_ids, fn(target_id) {
                  #(target_id, next_depth)
                })

              #(
                ref_nodes_collected,
                list.append(outgoing_explore_edges, incoming_explore_edges),
                updated_visited,
                new_queue_items,
              )
            }
            False -> #([], [], visited, [])
          }

          // Collect similarity edges
          let #(sim_nodes, sim_edges, sim_visited, sim_queue) = case
            include_similarity
          {
            True -> {
              let sim_rows =
                dict.get(similarity_adjacency, current_id)
                |> unwrap_or_empty

              let filtered_sim =
                list.filter(sim_rows, fn(row) {
                  !set.contains(ref_visited, row.target_legislation_id)
                })

              let sim_explore_edges =
                list.map(filtered_sim, fn(row) {
                  ExploreEdge(
                    source: current_id,
                    target: row.target_legislation_id,
                    edge_type: SimilarToEdge,
                    weight: row.similarity_score,
                    metadata: ExploreEdgeMetadata(
                      citation: "",
                      title_score: row.title_score,
                      body_score: row.body_score,
                      topic_score: row.topic_score,
                    ),
                  )
                })

              let sim_target_ids =
                list.map(filtered_sim, fn(row) { row.target_legislation_id })

              let sim_nodes_collected =
                list.filter_map(sim_target_ids, fn(target_id) {
                  case dict.get(metadata, target_id) {
                    Ok(summary) -> Ok(summary_to_explore_node(summary))
                    Error(_) -> Error(Nil)
                  }
                })

              let updated_sim_visited =
                list.fold(sim_target_ids, ref_visited, set.insert)
              let new_sim_queue =
                list.map(sim_target_ids, fn(target_id) {
                  #(target_id, next_depth)
                })

              #(
                sim_nodes_collected,
                sim_explore_edges,
                updated_sim_visited,
                new_sim_queue,
              )
            }
            False -> #([], [], ref_visited, [])
          }

          let all_new_nodes = list.append(ref_nodes, sim_nodes)
          let all_new_edges = list.append(ref_edges, sim_edges)
          let all_new_queue = list.append(ref_queue, sim_queue)

          do_expand_bfs(
            graph,
            similarity_adjacency,
            metadata,
            edge_type_set,
            include_references,
            include_similarity,
            max_depth,
            list.append(rest_queue, all_new_queue),
            sim_visited,
            list.append(accumulated_nodes, all_new_nodes),
            list.append(accumulated_edges, all_new_edges),
          )
        }
      }
    }
  }
}

// --- Internal BFS for shortest path ---

fn do_path_bfs(
  graph: DependencyGraph,
  max_depth: Int,
  target_id: String,
  queue: List(#(String, Int)),
  visited: Set(String),
  parent_map: Dict(String, #(String, GraphEdge)),
) -> Option(Dict(String, #(String, GraphEdge))) {
  case queue {
    [] -> None
    [#(current_id, current_depth), ..rest_queue] -> {
      case current_depth >= max_depth {
        True ->
          do_path_bfs(
            graph,
            max_depth,
            target_id,
            rest_queue,
            visited,
            parent_map,
          )
        False -> {
          // Combine outgoing and incoming edges for bidirectional traversal
          let outgoing_edges =
            dict.get(graph.outgoing, current_id) |> unwrap_or_empty
          let incoming_edges =
            dict.get(graph.incoming, current_id) |> unwrap_or_empty

          let all_edges = list.append(outgoing_edges, incoming_edges)

          let unvisited_edges =
            list.filter(all_edges, fn(edge) {
              !set.contains(visited, edge.target_id)
            })

          let next_depth = current_depth + 1

          // Process edges, check if target found
          let #(new_visited, new_queue, new_parent_map, found) =
            process_path_edges(
              unvisited_edges,
              current_id,
              target_id,
              next_depth,
              visited,
              [],
              parent_map,
            )

          case found {
            True -> Some(new_parent_map)
            False ->
              do_path_bfs(
                graph,
                max_depth,
                target_id,
                list.append(rest_queue, list.reverse(new_queue)),
                new_visited,
                new_parent_map,
              )
          }
        }
      }
    }
  }
}

fn process_path_edges(
  edges: List(GraphEdge),
  current_id: String,
  target_id: String,
  depth: Int,
  visited: Set(String),
  accumulated_queue: List(#(String, Int)),
  parent_map: Dict(String, #(String, GraphEdge)),
) -> #(
  Set(String),
  List(#(String, Int)),
  Dict(String, #(String, GraphEdge)),
  Bool,
) {
  case edges {
    [] -> #(visited, accumulated_queue, parent_map, False)
    [edge, ..remaining] -> {
      let updated_visited = set.insert(visited, edge.target_id)
      let updated_parent_map =
        dict.insert(parent_map, edge.target_id, #(current_id, edge))
      let updated_queue = [#(edge.target_id, depth), ..accumulated_queue]

      case edge.target_id == target_id {
        True -> #(updated_visited, updated_queue, updated_parent_map, True)
        False ->
          process_path_edges(
            remaining,
            current_id,
            target_id,
            depth,
            updated_visited,
            updated_queue,
            updated_parent_map,
          )
      }
    }
  }
}

fn reconstruct_path(
  parent_map: Dict(String, #(String, GraphEdge)),
  from_id: String,
  current_id: String,
  path_accumulator: List(String),
  edge_accumulator: List(ExploreEdge),
) -> #(List(String), List(ExploreEdge)) {
  case current_id == from_id {
    True -> #([from_id, ..path_accumulator], edge_accumulator)
    False -> {
      case dict.get(parent_map, current_id) {
        Ok(#(parent_id, graph_edge)) -> {
          let explore_edge =
            ExploreEdge(
              source: parent_id,
              target: current_id,
              edge_type: explore_types.reference_type_to_edge_type(
                graph_edge.reference_type,
              ),
              weight: graph_edge.confidence,
              metadata: ExploreEdgeMetadata(
                citation: "",
                title_score: 0.0,
                body_score: 0.0,
                topic_score: 0.0,
              ),
            )
          reconstruct_path(
            parent_map,
            from_id,
            parent_id,
            [current_id, ..path_accumulator],
            [explore_edge, ..edge_accumulator],
          )
        }
        Error(_) -> #([current_id, ..path_accumulator], edge_accumulator)
      }
    }
  }
}

// --- Helpers ---

fn unwrap_or_empty(result: Result(List(a), b)) -> List(a) {
  case result {
    Ok(items) -> items
    Error(_) -> []
  }
}

fn has_any_reference_edge(edge_type_set: Set(ExploreEdgeType)) -> Bool {
  set.contains(edge_type_set, explore_types.ReferencesEdge)
  || set.contains(edge_type_set, explore_types.AmendsEdge)
  || set.contains(edge_type_set, explore_types.SupersedesEdge)
  || set.contains(edge_type_set, explore_types.ImplementsEdge)
  || set.contains(edge_type_set, explore_types.DelegatesEdge)
}
