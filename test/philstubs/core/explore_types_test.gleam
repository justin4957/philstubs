import gleam/json
import gleam/string
import gleeunit/should
import philstubs/core/explore_types.{
  type ExploreEdge, type ExploreNode, ClusterResult, ExpandResult, ExploreEdge,
  ExploreEdgeMetadata, ExploreNode, ExploreNodeMetadata, NodeNeighborhood,
  PathResult,
}
import philstubs/core/government_level
import philstubs/core/legislation_status
import philstubs/core/legislation_type

fn sample_node() -> ExploreNode {
  ExploreNode(
    id: "leg-001",
    node_type: "legislation",
    label: "Clean Water Act",
    level: government_level.Federal,
    status: legislation_status.Enacted,
    introduced_date: "2024-01-15",
    metadata: ExploreNodeMetadata(
      sponsors: ["Sen. Smith"],
      topics: ["environment", "water"],
      source_identifier: "H.R.1234",
      legislation_type: legislation_type.Bill,
    ),
  )
}

fn sample_edge() -> ExploreEdge {
  ExploreEdge(
    source: "leg-001",
    target: "leg-002",
    edge_type: explore_types.ReferencesEdge,
    weight: 0.95,
    metadata: ExploreEdgeMetadata(
      citation: "42 U.S.C. 1983",
      title_score: 0.0,
      body_score: 0.0,
      topic_score: 0.0,
    ),
  )
}

// --- Edge type roundtrip tests ---

pub fn edge_type_references_roundtrip_test() {
  explore_types.ReferencesEdge
  |> explore_types.explore_edge_type_to_string
  |> explore_types.explore_edge_type_from_string
  |> should.equal(Ok(explore_types.ReferencesEdge))
}

pub fn edge_type_similar_to_roundtrip_test() {
  explore_types.SimilarToEdge
  |> explore_types.explore_edge_type_to_string
  |> explore_types.explore_edge_type_from_string
  |> should.equal(Ok(explore_types.SimilarToEdge))
}

pub fn edge_type_all_types_roundtrip_test() {
  let all_types = explore_types.all_edge_types()
  all_types
  |> should.not_equal([])

  let roundtripped =
    all_types
    |> list.map(fn(edge_type) {
      edge_type
      |> explore_types.explore_edge_type_to_string
      |> explore_types.explore_edge_type_from_string
    })
    |> list.map(fn(result) {
      let assert Ok(edge_type) = result
      edge_type
    })

  roundtripped |> should.equal(all_types)
}

pub fn edge_type_from_string_invalid_test() {
  explore_types.explore_edge_type_from_string("invalid_type")
  |> should.equal(Error(Nil))
}

// --- Node JSON serialization ---

pub fn explore_node_to_json_matches_schema_test() {
  let node = sample_node()
  let json_str =
    node
    |> explore_types.explore_node_to_json
    |> json.to_string

  json_str |> string.contains("\"id\":\"leg-001\"") |> should.be_true
  json_str |> string.contains("\"type\":\"legislation\"") |> should.be_true
  json_str |> string.contains("\"label\":\"Clean Water Act\"") |> should.be_true
  json_str |> string.contains("\"date\":\"2024-01-15\"") |> should.be_true
  json_str |> string.contains("\"kind\":\"federal\"") |> should.be_true
  json_str
  |> string.contains("\"source_identifier\":\"H.R.1234\"")
  |> should.be_true
  json_str |> string.contains("\"Sen. Smith\"") |> should.be_true
}

// --- Edge JSON serialization ---

pub fn explore_edge_to_json_matches_schema_test() {
  let edge = sample_edge()
  let json_str =
    edge
    |> explore_types.explore_edge_to_json
    |> json.to_string

  json_str |> string.contains("\"source\":\"leg-001\"") |> should.be_true
  json_str |> string.contains("\"target\":\"leg-002\"") |> should.be_true
  json_str |> string.contains("\"type\":\"references\"") |> should.be_true
  json_str
  |> string.contains("\"citation\":\"42 U.S.C. 1983\"")
  |> should.be_true
}

// --- Result type serializers ---

pub fn node_neighborhood_to_json_test() {
  let neighborhood =
    NodeNeighborhood(node: sample_node(), edges: [sample_edge()], neighbors: [])
  let json_str =
    neighborhood
    |> explore_types.node_neighborhood_to_json
    |> json.to_string

  json_str |> string.contains("\"node\"") |> should.be_true
  json_str |> string.contains("\"edges\"") |> should.be_true
  json_str |> string.contains("\"neighbors\"") |> should.be_true
}

pub fn expand_result_to_json_test() {
  let expand_result =
    ExpandResult(
      root_id: "leg-001",
      depth: 2,
      edge_types: [explore_types.ReferencesEdge],
      nodes: [sample_node()],
      edges: [sample_edge()],
    )
  let json_str =
    expand_result
    |> explore_types.expand_result_to_json
    |> json.to_string

  json_str |> string.contains("\"root_id\":\"leg-001\"") |> should.be_true
  json_str |> string.contains("\"depth\":2") |> should.be_true
  json_str |> string.contains("\"edge_types\"") |> should.be_true
}

pub fn path_result_to_json_test() {
  let path_result =
    PathResult(
      from_id: "leg-001",
      to_id: "leg-003",
      path: [sample_node()],
      edges: [sample_edge()],
      distance: 2,
    )
  let json_str =
    path_result
    |> explore_types.path_result_to_json
    |> json.to_string

  json_str |> string.contains("\"from_id\":\"leg-001\"") |> should.be_true
  json_str |> string.contains("\"to_id\":\"leg-003\"") |> should.be_true
  json_str |> string.contains("\"distance\":2") |> should.be_true
}

pub fn cluster_result_to_json_test() {
  let cluster_result =
    ClusterResult(
      topic_slug: "healthcare",
      topic_name: "Healthcare",
      nodes: [sample_node()],
      edges: [sample_edge()],
    )
  let json_str =
    cluster_result
    |> explore_types.cluster_result_to_json
    |> json.to_string

  json_str |> string.contains("\"topic_slug\":\"healthcare\"") |> should.be_true
  json_str |> string.contains("\"topic_name\":\"Healthcare\"") |> should.be_true
}

// --- parse_edge_types ---

pub fn parse_edge_types_empty_returns_all_test() {
  let result = explore_types.parse_edge_types("")
  result |> should.equal(explore_types.all_edge_types())
}

pub fn parse_edge_types_single_test() {
  let result = explore_types.parse_edge_types("references")
  result |> should.equal([explore_types.ReferencesEdge])
}

pub fn parse_edge_types_multiple_test() {
  let result = explore_types.parse_edge_types("references,similar_to")
  result
  |> should.equal([explore_types.ReferencesEdge, explore_types.SimilarToEdge])
}

// Need list import for the roundtrip test
import gleam/list
