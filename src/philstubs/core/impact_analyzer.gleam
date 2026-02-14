import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/set.{type Set}
import philstubs/core/government_level
import philstubs/core/impact_types.{
  type DependencyGraph, type GraphEdge, type ImpactDirection, type ImpactKind,
  type ImpactNode, type ImpactResult, type ImpactSummary,
  type LegislationSummary, Both, Direct, ImpactNode, ImpactResult, ImpactSummary,
  Incoming, Outgoing, Transitive,
}
import philstubs/core/legislation_type

/// Perform BFS-based impact analysis from a root legislation node.
/// Traverses the cross-reference graph in the specified direction up to
/// max_depth, returning all directly and transitively impacted legislation.
pub fn analyze_impact(
  graph: DependencyGraph,
  metadata: Dict(String, LegislationSummary),
  root_id: String,
  direction: ImpactDirection,
  max_depth: Int,
) -> ImpactResult {
  let nodes = case direction {
    Outgoing -> bfs(graph.outgoing, metadata, root_id, max_depth)
    Incoming -> bfs(graph.incoming, metadata, root_id, max_depth)
    Both -> {
      let outgoing_nodes = bfs(graph.outgoing, metadata, root_id, max_depth)
      let incoming_nodes = bfs(graph.incoming, metadata, root_id, max_depth)
      merge_nodes(outgoing_nodes, incoming_nodes)
    }
  }

  let summary = summarize_impact(nodes)

  ImpactResult(
    root_legislation_id: root_id,
    direction:,
    max_depth:,
    nodes:,
    summary:,
  )
}

/// Compute aggregate statistics from a list of impact nodes.
pub fn summarize_impact(nodes: List(ImpactNode)) -> ImpactSummary {
  let initial_summary =
    ImpactSummary(
      total_nodes: 0,
      direct_count: 0,
      transitive_count: 0,
      max_depth_reached: 0,
      by_level: dict.new(),
      by_type: dict.new(),
    )

  list.fold(nodes, initial_summary, fn(summary, node) {
    let direct_increment = case node.impact_kind {
      Direct -> 1
      Transitive -> 0
    }
    let transitive_increment = case node.impact_kind {
      Direct -> 0
      Transitive -> 1
    }

    let level_key = government_level.to_string(node.level)
    let type_key = legislation_type.to_string(node.legislation_type)

    ImpactSummary(
      total_nodes: summary.total_nodes + 1,
      direct_count: summary.direct_count + direct_increment,
      transitive_count: summary.transitive_count + transitive_increment,
      max_depth_reached: int.max(summary.max_depth_reached, node.depth),
      by_level: increment_dict(summary.by_level, level_key),
      by_type: increment_dict(summary.by_type, type_key),
    )
  })
}

/// Group impact nodes by their government level label.
pub fn group_by_level(nodes: List(ImpactNode)) -> Dict(String, List(ImpactNode)) {
  list.group(nodes, fn(node) { government_level.to_string(node.level) })
}

/// Group impact nodes by their legislation type label.
pub fn group_by_type(nodes: List(ImpactNode)) -> Dict(String, List(ImpactNode)) {
  list.group(nodes, fn(node) {
    legislation_type.to_string(node.legislation_type)
  })
}

// --- Internal BFS ---

/// BFS traversal over an adjacency list from a root node.
/// Returns impact nodes discovered up to max_depth.
fn bfs(
  adjacency: Dict(String, List(GraphEdge)),
  metadata: Dict(String, LegislationSummary),
  root_id: String,
  max_depth: Int,
) -> List(ImpactNode) {
  let initial_visited = set.from_list([root_id])
  let initial_queue = [#(root_id, 0)]

  do_bfs(adjacency, metadata, max_depth, initial_queue, initial_visited, [])
  |> list.reverse
}

/// Tail-recursive BFS worker. Processes queue items, discovers neighbors,
/// and accumulates impact nodes.
fn do_bfs(
  adjacency: Dict(String, List(GraphEdge)),
  metadata: Dict(String, LegislationSummary),
  max_depth: Int,
  queue: List(#(String, Int)),
  visited: Set(String),
  accumulated_nodes: List(ImpactNode),
) -> List(ImpactNode) {
  case queue {
    [] -> accumulated_nodes
    [#(current_id, current_depth), ..rest_queue] -> {
      case current_depth >= max_depth {
        True ->
          do_bfs(
            adjacency,
            metadata,
            max_depth,
            rest_queue,
            visited,
            accumulated_nodes,
          )
        False -> {
          let edges = case dict.get(adjacency, current_id) {
            Ok(edge_list) -> edge_list
            Error(_) -> []
          }

          let unvisited_edges =
            list.filter(edges, fn(edge) {
              !set.contains(visited, edge.target_id)
            })

          let next_depth = current_depth + 1
          let impact_kind = classify_impact_kind(next_depth)

          let #(new_nodes, new_queue_items, new_visited) =
            process_edges(
              unvisited_edges,
              metadata,
              next_depth,
              impact_kind,
              [],
              [],
              visited,
            )

          do_bfs(
            adjacency,
            metadata,
            max_depth,
            list.append(rest_queue, list.reverse(new_queue_items)),
            new_visited,
            list.append(accumulated_nodes, list.reverse(new_nodes)),
          )
        }
      }
    }
  }
}

/// Process a batch of unvisited edges, creating impact nodes for those
/// with available metadata and enqueuing them for further traversal.
fn process_edges(
  edges: List(GraphEdge),
  metadata: Dict(String, LegislationSummary),
  depth: Int,
  impact_kind: ImpactKind,
  accumulated_nodes: List(ImpactNode),
  accumulated_queue: List(#(String, Int)),
  visited: Set(String),
) -> #(List(ImpactNode), List(#(String, Int)), Set(String)) {
  case edges {
    [] -> #(accumulated_nodes, accumulated_queue, visited)
    [edge, ..remaining_edges] -> {
      let updated_visited = set.insert(visited, edge.target_id)
      case dict.get(metadata, edge.target_id) {
        Ok(summary) -> {
          let node =
            ImpactNode(
              legislation_id: edge.target_id,
              title: summary.title,
              level: summary.level,
              legislation_type: summary.legislation_type,
              depth:,
              impact_kind:,
              reference_type: edge.reference_type,
            )
          process_edges(
            remaining_edges,
            metadata,
            depth,
            impact_kind,
            [node, ..accumulated_nodes],
            [#(edge.target_id, depth), ..accumulated_queue],
            updated_visited,
          )
        }
        Error(_) -> {
          process_edges(
            remaining_edges,
            metadata,
            depth,
            impact_kind,
            accumulated_nodes,
            [#(edge.target_id, depth), ..accumulated_queue],
            updated_visited,
          )
        }
      }
    }
  }
}

/// Merge two lists of impact nodes, deduplicating by legislation_id
/// and keeping the node with the lower depth.
fn merge_nodes(
  first_nodes: List(ImpactNode),
  second_nodes: List(ImpactNode),
) -> List(ImpactNode) {
  let first_by_id =
    list.fold(first_nodes, dict.new(), fn(accumulated, node) {
      dict.insert(accumulated, node.legislation_id, node)
    })

  let merged =
    list.fold(second_nodes, first_by_id, fn(accumulated, node) {
      case dict.get(accumulated, node.legislation_id) {
        Ok(existing) if existing.depth <= node.depth -> accumulated
        _ -> dict.insert(accumulated, node.legislation_id, node)
      }
    })

  merged
  |> dict.values
  |> list.sort(fn(node_a, node_b) { int.compare(node_a.depth, node_b.depth) })
}

fn classify_impact_kind(depth: Int) -> ImpactKind {
  case depth {
    1 -> Direct
    _ -> Transitive
  }
}

fn increment_dict(entries: Dict(String, Int), key: String) -> Dict(String, Int) {
  dict.upsert(entries, key, fn(existing) {
    case existing {
      Some(count) -> count + 1
      None -> 1
    }
  })
}
