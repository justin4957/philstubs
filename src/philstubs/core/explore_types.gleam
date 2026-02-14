import gleam/json
import gleam/list
import gleam/string
import philstubs/core/government_level.{type GovernmentLevel}
import philstubs/core/legislation_status.{type LegislationStatus}
import philstubs/core/legislation_type.{type LegislationType}
import philstubs/core/reference.{type ReferenceType}

/// Edge type in the exploration graph — maps cross-reference types plus similarity.
pub type ExploreEdgeType {
  ReferencesEdge
  AmendsEdge
  SupersedesEdge
  ImplementsEdge
  DelegatesEdge
  SimilarToEdge
}

/// Convert an ExploreEdgeType to its string representation.
pub fn explore_edge_type_to_string(edge_type: ExploreEdgeType) -> String {
  case edge_type {
    ReferencesEdge -> "references"
    AmendsEdge -> "amends"
    SupersedesEdge -> "supersedes"
    ImplementsEdge -> "implements"
    DelegatesEdge -> "delegates"
    SimilarToEdge -> "similar_to"
  }
}

/// Parse a string into an ExploreEdgeType.
pub fn explore_edge_type_from_string(
  value: String,
) -> Result(ExploreEdgeType, Nil) {
  case value {
    "references" -> Ok(ReferencesEdge)
    "amends" -> Ok(AmendsEdge)
    "supersedes" -> Ok(SupersedesEdge)
    "implements" -> Ok(ImplementsEdge)
    "delegates" -> Ok(DelegatesEdge)
    "similar_to" -> Ok(SimilarToEdge)
    _ -> Error(Nil)
  }
}

/// Convert a cross-reference ReferenceType to an ExploreEdgeType.
pub fn reference_type_to_edge_type(
  reference_type: ReferenceType,
) -> ExploreEdgeType {
  case reference_type {
    reference.References -> ReferencesEdge
    reference.Amends -> AmendsEdge
    reference.Supersedes -> SupersedesEdge
    reference.Implements -> ImplementsEdge
    reference.Delegates -> DelegatesEdge
  }
}

/// Metadata for a node in the explore graph.
pub type ExploreNodeMetadata {
  ExploreNodeMetadata(
    sponsors: List(String),
    topics: List(String),
    source_identifier: String,
    legislation_type: LegislationType,
  )
}

/// A node in the explore graph representing a piece of legislation.
pub type ExploreNode {
  ExploreNode(
    id: String,
    node_type: String,
    label: String,
    level: GovernmentLevel,
    status: LegislationStatus,
    introduced_date: String,
    metadata: ExploreNodeMetadata,
  )
}

/// Metadata for an edge in the explore graph.
pub type ExploreEdgeMetadata {
  ExploreEdgeMetadata(
    citation: String,
    title_score: Float,
    body_score: Float,
    topic_score: Float,
  )
}

/// An edge connecting two nodes in the explore graph.
pub type ExploreEdge {
  ExploreEdge(
    source: String,
    target: String,
    edge_type: ExploreEdgeType,
    weight: Float,
    metadata: ExploreEdgeMetadata,
  )
}

/// A single node with all its edges and neighbor summaries.
pub type NodeNeighborhood {
  NodeNeighborhood(
    node: ExploreNode,
    edges: List(ExploreEdge),
    neighbors: List(ExploreNode),
  )
}

/// Result of BFS expansion from a root node.
pub type ExpandResult {
  ExpandResult(
    root_id: String,
    depth: Int,
    edge_types: List(ExploreEdgeType),
    nodes: List(ExploreNode),
    edges: List(ExploreEdge),
  )
}

/// Result of shortest-path search between two nodes.
pub type PathResult {
  PathResult(
    from_id: String,
    to_id: String,
    path: List(ExploreNode),
    edges: List(ExploreEdge),
    distance: Int,
  )
}

/// Result of a topic-based cluster query.
pub type ClusterResult {
  ClusterResult(
    topic_slug: String,
    topic_name: String,
    nodes: List(ExploreNode),
    edges: List(ExploreEdge),
  )
}

// --- JSON serializers ---

/// Encode an ExploreNode to JSON.
pub fn explore_node_to_json(node: ExploreNode) -> json.Json {
  json.object([
    #("id", json.string(node.id)),
    #("type", json.string(node.node_type)),
    #("label", json.string(node.label)),
    #("level", government_level.to_json(node.level)),
    #("status", legislation_status.to_json(node.status)),
    #("date", json.string(node.introduced_date)),
    #("metadata", explore_node_metadata_to_json(node.metadata)),
  ])
}

/// Encode ExploreNodeMetadata to JSON.
pub fn explore_node_metadata_to_json(metadata: ExploreNodeMetadata) -> json.Json {
  json.object([
    #("sponsors", json.array(metadata.sponsors, json.string)),
    #("topics", json.array(metadata.topics, json.string)),
    #("source_identifier", json.string(metadata.source_identifier)),
    #("legislation_type", legislation_type.to_json(metadata.legislation_type)),
  ])
}

/// Encode an ExploreEdge to JSON.
pub fn explore_edge_to_json(edge: ExploreEdge) -> json.Json {
  json.object([
    #("source", json.string(edge.source)),
    #("target", json.string(edge.target)),
    #("type", json.string(explore_edge_type_to_string(edge.edge_type))),
    #("weight", json.float(edge.weight)),
    #("metadata", explore_edge_metadata_to_json(edge.metadata)),
  ])
}

/// Encode ExploreEdgeMetadata to JSON.
pub fn explore_edge_metadata_to_json(metadata: ExploreEdgeMetadata) -> json.Json {
  json.object([
    #("citation", json.string(metadata.citation)),
    #("title_score", json.float(metadata.title_score)),
    #("body_score", json.float(metadata.body_score)),
    #("topic_score", json.float(metadata.topic_score)),
  ])
}

/// Encode a NodeNeighborhood to JSON.
pub fn node_neighborhood_to_json(neighborhood: NodeNeighborhood) -> json.Json {
  json.object([
    #("node", explore_node_to_json(neighborhood.node)),
    #("edges", json.array(neighborhood.edges, explore_edge_to_json)),
    #("neighbors", json.array(neighborhood.neighbors, explore_node_to_json)),
  ])
}

/// Encode an ExpandResult to JSON.
pub fn expand_result_to_json(result: ExpandResult) -> json.Json {
  json.object([
    #("root_id", json.string(result.root_id)),
    #("depth", json.int(result.depth)),
    #(
      "edge_types",
      json.array(result.edge_types, fn(edge_type) {
        json.string(explore_edge_type_to_string(edge_type))
      }),
    ),
    #("nodes", json.array(result.nodes, explore_node_to_json)),
    #("edges", json.array(result.edges, explore_edge_to_json)),
  ])
}

/// Encode a PathResult to JSON.
pub fn path_result_to_json(result: PathResult) -> json.Json {
  json.object([
    #("from_id", json.string(result.from_id)),
    #("to_id", json.string(result.to_id)),
    #("path", json.array(result.path, explore_node_to_json)),
    #("edges", json.array(result.edges, explore_edge_to_json)),
    #("distance", json.int(result.distance)),
  ])
}

/// Encode a ClusterResult to JSON.
pub fn cluster_result_to_json(result: ClusterResult) -> json.Json {
  json.object([
    #("topic_slug", json.string(result.topic_slug)),
    #("topic_name", json.string(result.topic_name)),
    #("nodes", json.array(result.nodes, explore_node_to_json)),
    #("edges", json.array(result.edges, explore_edge_to_json)),
  ])
}

/// Parse a comma-separated edge_types string into a list of ExploreEdgeType.
/// Returns all edge types if the input is empty.
pub fn parse_edge_types(value: String) -> List(ExploreEdgeType) {
  case value {
    "" -> all_edge_types()
    _ -> {
      let parsed =
        value
        |> split_comma_trimmed
        |> list.filter_map(explore_edge_type_from_string)
      case parsed {
        [] -> all_edge_types()
        types -> types
      }
    }
  }
}

/// All possible edge types.
pub fn all_edge_types() -> List(ExploreEdgeType) {
  [
    ReferencesEdge, AmendsEdge, SupersedesEdge, ImplementsEdge, DelegatesEdge,
    SimilarToEdge,
  ]
}

fn split_comma_trimmed(value: String) -> List(String) {
  value
  |> string.split(",")
  |> list.map(string.trim)
  |> list.filter(fn(segment) { segment != "" })
}
