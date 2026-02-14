import gleam/dict
import gleam/list
import gleeunit/should
import philstubs/core/government_level
import philstubs/core/impact_analyzer
import philstubs/core/impact_types.{
  type ImpactNode, DependencyGraph, Direct, GraphEdge, ImpactNode,
  LegislationSummary, Transitive,
}
import philstubs/core/legislation_type
import philstubs/core/reference

// --- Test helpers ---

fn empty_graph() -> impact_types.DependencyGraph {
  DependencyGraph(outgoing: dict.new(), incoming: dict.new())
}

fn make_metadata(
  entries: List(#(String, String)),
) -> dict.Dict(String, impact_types.LegislationSummary) {
  list.fold(entries, dict.new(), fn(accumulated, entry) {
    let #(legislation_id, title) = entry
    dict.insert(
      accumulated,
      legislation_id,
      LegislationSummary(
        legislation_id:,
        title:,
        level: government_level.Federal,
        legislation_type: legislation_type.Bill,
      ),
    )
  })
}

fn make_edge(target_id: String) -> impact_types.GraphEdge {
  GraphEdge(target_id:, reference_type: reference.References, confidence: 1.0)
}

// --- BFS tests ---

pub fn empty_graph_produces_no_nodes_test() {
  let metadata = make_metadata([#("root", "Root Bill")])
  let result =
    impact_analyzer.analyze_impact(
      empty_graph(),
      metadata,
      "root",
      impact_types.Both,
      3,
    )

  result.nodes |> list.length |> should.equal(0)
  result.summary.total_nodes |> should.equal(0)
}

pub fn single_outgoing_edge_test() {
  let graph =
    DependencyGraph(
      outgoing: dict.from_list([#("A", [make_edge("B")])]),
      incoming: dict.new(),
    )
  let metadata = make_metadata([#("A", "Bill A"), #("B", "Bill B")])

  let result =
    impact_analyzer.analyze_impact(
      graph,
      metadata,
      "A",
      impact_types.Outgoing,
      3,
    )

  result.nodes |> list.length |> should.equal(1)
  let assert Ok(first_node) = list.first(result.nodes)
  first_node.legislation_id |> should.equal("B")
  first_node.depth |> should.equal(1)
  first_node.impact_kind |> should.equal(Direct)
}

pub fn single_incoming_edge_test() {
  let graph =
    DependencyGraph(
      outgoing: dict.new(),
      incoming: dict.from_list([#("B", [make_edge("A")])]),
    )
  let metadata = make_metadata([#("A", "Bill A"), #("B", "Bill B")])

  let result =
    impact_analyzer.analyze_impact(
      graph,
      metadata,
      "B",
      impact_types.Incoming,
      3,
    )

  result.nodes |> list.length |> should.equal(1)
  let assert Ok(first_node) = list.first(result.nodes)
  first_node.legislation_id |> should.equal("A")
  first_node.depth |> should.equal(1)
  first_node.impact_kind |> should.equal(Direct)
}

pub fn chain_a_b_c_produces_direct_and_transitive_test() {
  let graph =
    DependencyGraph(
      outgoing: dict.from_list([
        #("A", [make_edge("B")]),
        #("B", [make_edge("C")]),
      ]),
      incoming: dict.new(),
    )
  let metadata =
    make_metadata([#("A", "Bill A"), #("B", "Bill B"), #("C", "Bill C")])

  let result =
    impact_analyzer.analyze_impact(
      graph,
      metadata,
      "A",
      impact_types.Outgoing,
      3,
    )

  result.nodes |> list.length |> should.equal(2)

  let node_b = find_node(result.nodes, "B")
  node_b.depth |> should.equal(1)
  node_b.impact_kind |> should.equal(Direct)

  let node_c = find_node(result.nodes, "C")
  node_c.depth |> should.equal(2)
  node_c.impact_kind |> should.equal(Transitive)
}

pub fn depth_limiting_stops_traversal_test() {
  let graph =
    DependencyGraph(
      outgoing: dict.from_list([
        #("A", [make_edge("B")]),
        #("B", [make_edge("C")]),
        #("C", [make_edge("D")]),
      ]),
      incoming: dict.new(),
    )
  let metadata =
    make_metadata([
      #("A", "Bill A"),
      #("B", "Bill B"),
      #("C", "Bill C"),
      #("D", "Bill D"),
    ])

  let result =
    impact_analyzer.analyze_impact(
      graph,
      metadata,
      "A",
      impact_types.Outgoing,
      2,
    )

  result.nodes |> list.length |> should.equal(2)
  let node_ids = list.map(result.nodes, fn(node) { node.legislation_id })
  node_ids |> list.contains("B") |> should.be_true
  node_ids |> list.contains("C") |> should.be_true
  node_ids |> list.contains("D") |> should.be_false
}

pub fn cycle_prevention_test() {
  let graph =
    DependencyGraph(
      outgoing: dict.from_list([
        #("A", [make_edge("B")]),
        #("B", [make_edge("C")]),
        #("C", [make_edge("A")]),
      ]),
      incoming: dict.new(),
    )
  let metadata =
    make_metadata([#("A", "Bill A"), #("B", "Bill B"), #("C", "Bill C")])

  let result =
    impact_analyzer.analyze_impact(
      graph,
      metadata,
      "A",
      impact_types.Outgoing,
      10,
    )

  result.nodes |> list.length |> should.equal(2)
  let node_ids = list.map(result.nodes, fn(node) { node.legislation_id })
  node_ids |> list.contains("B") |> should.be_true
  node_ids |> list.contains("C") |> should.be_true
  node_ids |> list.contains("A") |> should.be_false
}

pub fn diamond_deduplication_test() {
  // A -> B, A -> C, B -> D, C -> D
  let graph =
    DependencyGraph(
      outgoing: dict.from_list([
        #("A", [make_edge("B"), make_edge("C")]),
        #("B", [make_edge("D")]),
        #("C", [make_edge("D")]),
      ]),
      incoming: dict.new(),
    )
  let metadata =
    make_metadata([
      #("A", "Bill A"),
      #("B", "Bill B"),
      #("C", "Bill C"),
      #("D", "Bill D"),
    ])

  let result =
    impact_analyzer.analyze_impact(
      graph,
      metadata,
      "A",
      impact_types.Outgoing,
      3,
    )

  // D should appear only once
  let d_nodes =
    list.filter(result.nodes, fn(node) { node.legislation_id == "D" })
  d_nodes |> list.length |> should.equal(1)
  result.nodes |> list.length |> should.equal(3)
}

pub fn both_directions_merges_results_test() {
  let graph =
    DependencyGraph(
      outgoing: dict.from_list([#("A", [make_edge("B")])]),
      incoming: dict.from_list([#("A", [make_edge("C")])]),
    )
  let metadata =
    make_metadata([#("A", "Bill A"), #("B", "Bill B"), #("C", "Bill C")])

  let result =
    impact_analyzer.analyze_impact(graph, metadata, "A", impact_types.Both, 3)

  result.nodes |> list.length |> should.equal(2)
  let node_ids = list.map(result.nodes, fn(node) { node.legislation_id })
  node_ids |> list.contains("B") |> should.be_true
  node_ids |> list.contains("C") |> should.be_true
}

pub fn missing_metadata_skips_node_test() {
  let graph =
    DependencyGraph(
      outgoing: dict.from_list([
        #("A", [make_edge("B"), make_edge("C")]),
      ]),
      incoming: dict.new(),
    )
  // Only A and B have metadata; C is missing
  let metadata = make_metadata([#("A", "Bill A"), #("B", "Bill B")])

  let result =
    impact_analyzer.analyze_impact(
      graph,
      metadata,
      "A",
      impact_types.Outgoing,
      3,
    )

  // B should appear, C should be skipped (no metadata)
  result.nodes |> list.length |> should.equal(1)
  let assert Ok(first_node) = list.first(result.nodes)
  first_node.legislation_id |> should.equal("B")
}

pub fn max_depth_zero_returns_no_nodes_test() {
  let graph =
    DependencyGraph(
      outgoing: dict.from_list([#("A", [make_edge("B")])]),
      incoming: dict.new(),
    )
  let metadata = make_metadata([#("A", "Bill A"), #("B", "Bill B")])

  let result =
    impact_analyzer.analyze_impact(
      graph,
      metadata,
      "A",
      impact_types.Outgoing,
      0,
    )

  result.nodes |> list.length |> should.equal(0)
}

// --- Summarize tests ---

pub fn summarize_impact_counts_correctly_test() {
  let nodes = [
    make_test_node("B", 1, Direct),
    make_test_node("C", 2, Transitive),
    make_test_node("D", 2, Transitive),
  ]

  let summary = impact_analyzer.summarize_impact(nodes)
  summary.total_nodes |> should.equal(3)
  summary.direct_count |> should.equal(1)
  summary.transitive_count |> should.equal(2)
  summary.max_depth_reached |> should.equal(2)
}

// --- Group by tests ---

pub fn group_by_level_test() {
  let federal_node =
    ImpactNode(
      legislation_id: "A",
      title: "Federal Bill",
      level: government_level.Federal,
      legislation_type: legislation_type.Bill,
      depth: 1,
      impact_kind: Direct,
      reference_type: reference.References,
    )
  let state_node =
    ImpactNode(
      legislation_id: "B",
      title: "State Bill",
      level: government_level.State("CA"),
      legislation_type: legislation_type.Bill,
      depth: 1,
      impact_kind: Direct,
      reference_type: reference.References,
    )

  let grouped = impact_analyzer.group_by_level([federal_node, state_node])

  let assert Ok(federal_list) = dict.get(grouped, "Federal")
  federal_list |> list.length |> should.equal(1)

  let assert Ok(state_list) = dict.get(grouped, "State")
  state_list |> list.length |> should.equal(1)
}

// --- Helpers ---

fn find_node(nodes: List(ImpactNode), target_id: String) -> ImpactNode {
  let assert Ok(found) =
    list.find(nodes, fn(node) { node.legislation_id == target_id })
  found
}

fn make_test_node(
  legislation_id: String,
  depth: Int,
  impact_kind: impact_types.ImpactKind,
) -> ImpactNode {
  ImpactNode(
    legislation_id:,
    title: "Test " <> legislation_id,
    level: government_level.Federal,
    legislation_type: legislation_type.Bill,
    depth:,
    impact_kind:,
    reference_type: reference.References,
  )
}
