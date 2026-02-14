import gleam/dict.{type Dict}
import gleam/json
import gleam/list
import philstubs/core/government_level.{type GovernmentLevel}
import philstubs/core/legislation_type.{type LegislationType}
import philstubs/core/reference.{type ReferenceType}

/// Direction of impact traversal through the cross-reference graph.
pub type ImpactDirection {
  Incoming
  Outgoing
  Both
}

/// Convert an ImpactDirection to its string representation.
pub fn direction_to_string(direction: ImpactDirection) -> String {
  case direction {
    Incoming -> "incoming"
    Outgoing -> "outgoing"
    Both -> "both"
  }
}

/// Parse a string into an ImpactDirection, defaulting to Both.
pub fn direction_from_string(value: String) -> ImpactDirection {
  case value {
    "incoming" -> Incoming
    "outgoing" -> Outgoing
    "both" -> Both
    _ -> Both
  }
}

/// Whether an impacted node is directly or transitively connected.
pub type ImpactKind {
  Direct
  Transitive
}

/// Convert an ImpactKind to its string representation.
pub fn impact_kind_to_string(kind: ImpactKind) -> String {
  case kind {
    Direct -> "direct"
    Transitive -> "transitive"
  }
}

/// An edge in the cross-reference graph, pointing to a target legislation
/// with a typed relationship and confidence score.
pub type GraphEdge {
  GraphEdge(target_id: String, reference_type: ReferenceType, confidence: Float)
}

/// Dual adjacency-list representation of the legislation cross-reference graph.
/// Outgoing edges follow source->target direction; incoming edges reverse it.
pub type DependencyGraph {
  DependencyGraph(
    outgoing: Dict(String, List(GraphEdge)),
    incoming: Dict(String, List(GraphEdge)),
  )
}

/// Lightweight metadata for a legislation record used in impact results.
pub type LegislationSummary {
  LegislationSummary(
    legislation_id: String,
    title: String,
    level: GovernmentLevel,
    legislation_type: LegislationType,
  )
}

/// A node in the impact analysis result, representing legislation affected
/// by a change to the root legislation.
pub type ImpactNode {
  ImpactNode(
    legislation_id: String,
    title: String,
    level: GovernmentLevel,
    legislation_type: LegislationType,
    depth: Int,
    impact_kind: ImpactKind,
    reference_type: ReferenceType,
  )
}

/// Aggregate statistics for an impact analysis result.
pub type ImpactSummary {
  ImpactSummary(
    total_nodes: Int,
    direct_count: Int,
    transitive_count: Int,
    max_depth_reached: Int,
    by_level: Dict(String, Int),
    by_type: Dict(String, Int),
  )
}

/// Complete result of an impact analysis traversal.
pub type ImpactResult {
  ImpactResult(
    root_legislation_id: String,
    direction: ImpactDirection,
    max_depth: Int,
    nodes: List(ImpactNode),
    summary: ImpactSummary,
  )
}

/// Encode an ImpactNode to JSON.
pub fn impact_node_to_json(node: ImpactNode) -> json.Json {
  json.object([
    #("legislation_id", json.string(node.legislation_id)),
    #("title", json.string(node.title)),
    #("level", government_level.to_json(node.level)),
    #("legislation_type", legislation_type.to_json(node.legislation_type)),
    #("depth", json.int(node.depth)),
    #("impact_kind", json.string(impact_kind_to_string(node.impact_kind))),
    #(
      "reference_type",
      json.string(reference.reference_type_to_string(node.reference_type)),
    ),
  ])
}

/// Encode an ImpactSummary to JSON.
pub fn impact_summary_to_json(summary: ImpactSummary) -> json.Json {
  json.object([
    #("total_nodes", json.int(summary.total_nodes)),
    #("direct_count", json.int(summary.direct_count)),
    #("transitive_count", json.int(summary.transitive_count)),
    #("max_depth_reached", json.int(summary.max_depth_reached)),
    #("by_level", string_int_dict_to_json(summary.by_level)),
    #("by_type", string_int_dict_to_json(summary.by_type)),
  ])
}

/// Encode an ImpactResult to JSON.
pub fn impact_result_to_json(result: ImpactResult) -> json.Json {
  json.object([
    #("root_legislation_id", json.string(result.root_legislation_id)),
    #("direction", json.string(direction_to_string(result.direction))),
    #("max_depth", json.int(result.max_depth)),
    #("nodes", json.array(result.nodes, impact_node_to_json)),
    #("summary", impact_summary_to_json(result.summary)),
  ])
}

fn string_int_dict_to_json(entries: Dict(String, Int)) -> json.Json {
  entries
  |> dict.to_list
  |> list.map(fn(entry) {
    let #(key, value) = entry
    #(key, json.int(value))
  })
  |> json.object
}
