import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import philstubs/core/explore_graph.{SimilarityEdgeRow}
import philstubs/core/explore_types
import philstubs/core/government_level
import philstubs/core/impact_types.{
  type LegislationSummary, DependencyGraph, GraphEdge, LegislationSummary,
}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/core/reference
import philstubs/core/topic.{type Topic, Topic}

fn sample_legislation(legislation_id: String, title: String) -> Legislation {
  Legislation(
    id: legislation.legislation_id(legislation_id),
    title:,
    summary: "",
    body: "",
    level: government_level.Federal,
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-01-01",
    source_url: None,
    source_identifier: "TEST",
    sponsors: ["Sen. Smith"],
    topics: ["healthcare"],
  )
}

fn sample_topic(name: String) -> Topic {
  Topic(
    id: topic.topic_id("topic-" <> name),
    name:,
    slug: name,
    description: "",
    parent_id: None,
    display_order: 0,
  )
}

fn sample_metadata() -> dict.Dict(String, LegislationSummary) {
  dict.from_list([
    #(
      "leg-A",
      LegislationSummary(
        legislation_id: "leg-A",
        title: "Bill A",
        level: government_level.Federal,
        legislation_type: legislation_type.Bill,
      ),
    ),
    #(
      "leg-B",
      LegislationSummary(
        legislation_id: "leg-B",
        title: "Bill B",
        level: government_level.State("CA"),
        legislation_type: legislation_type.Bill,
      ),
    ),
    #(
      "leg-C",
      LegislationSummary(
        legislation_id: "leg-C",
        title: "Bill C",
        level: government_level.Federal,
        legislation_type: legislation_type.Resolution,
      ),
    ),
  ])
}

// --- build_neighborhood tests ---

pub fn empty_neighborhood_test() {
  let legislation = sample_legislation("leg-A", "Bill A")
  let topics = [sample_topic("health")]

  let neighborhood =
    explore_graph.build_neighborhood(
      legislation,
      topics,
      [],
      [],
      [],
      dict.new(),
    )

  neighborhood.node.id |> should.equal("leg-A")
  neighborhood.node.label |> should.equal("Bill A")
  neighborhood.edges |> should.equal([])
  neighborhood.neighbors |> should.equal([])
}

pub fn neighborhood_with_mixed_edges_test() {
  let legislation = sample_legislation("leg-A", "Bill A")
  let topics = [sample_topic("health")]
  let metadata = sample_metadata()

  let outgoing_ref =
    reference.CrossReference(
      id: reference.reference_id("ref-1"),
      source_legislation_id: "leg-A",
      target_legislation_id: Some("leg-B"),
      citation_text: "Section 42",
      reference_type: reference.References,
      confidence: 0.9,
      extractor: reference.GleamNative,
      extracted_at: "2024-01-01",
    )

  let similarity =
    SimilarityEdgeRow(
      target_legislation_id: "leg-C",
      similarity_score: 0.85,
      title_score: 0.7,
      body_score: 0.9,
      topic_score: 0.8,
    )

  let neighborhood =
    explore_graph.build_neighborhood(
      legislation,
      topics,
      [outgoing_ref],
      [],
      [similarity],
      metadata,
    )

  list.length(neighborhood.edges) |> should.equal(2)
  list.length(neighborhood.neighbors) |> should.equal(2)

  // Check that topic name is in the node metadata
  neighborhood.node.metadata.topics |> should.equal(["health"])
}

// --- build_expand_result tests ---

pub fn expand_references_only_test() {
  let metadata = sample_metadata()
  let graph =
    DependencyGraph(
      outgoing: dict.from_list([
        #("leg-A", [
          GraphEdge(
            target_id: "leg-B",
            reference_type: reference.References,
            confidence: 0.9,
          ),
        ]),
      ]),
      incoming: dict.new(),
    )

  let result =
    explore_graph.build_expand_result(
      "leg-A",
      1,
      [explore_types.ReferencesEdge],
      graph,
      dict.new(),
      metadata,
    )

  result.root_id |> should.equal("leg-A")
  // Root + leg-B
  list.length(result.nodes) |> should.equal(2)
  list.length(result.edges) |> should.equal(1)
}

pub fn expand_similarity_only_test() {
  let metadata = sample_metadata()
  let graph = DependencyGraph(outgoing: dict.new(), incoming: dict.new())
  let similarity_adjacency =
    dict.from_list([
      #("leg-A", [
        SimilarityEdgeRow(
          target_legislation_id: "leg-C",
          similarity_score: 0.8,
          title_score: 0.7,
          body_score: 0.85,
          topic_score: 0.6,
        ),
      ]),
    ])

  let result =
    explore_graph.build_expand_result(
      "leg-A",
      1,
      [explore_types.SimilarToEdge],
      graph,
      similarity_adjacency,
      metadata,
    )

  result.root_id |> should.equal("leg-A")
  // Root + leg-C
  list.length(result.nodes) |> should.equal(2)
  list.length(result.edges) |> should.equal(1)
}

pub fn expand_depth_limiting_test() {
  let metadata = sample_metadata()
  let graph =
    DependencyGraph(
      outgoing: dict.from_list([
        #("leg-A", [
          GraphEdge(
            target_id: "leg-B",
            reference_type: reference.References,
            confidence: 0.9,
          ),
        ]),
        #("leg-B", [
          GraphEdge(
            target_id: "leg-C",
            reference_type: reference.References,
            confidence: 0.8,
          ),
        ]),
      ]),
      incoming: dict.new(),
    )

  // Depth 1: should only get leg-B
  let result_depth1 =
    explore_graph.build_expand_result(
      "leg-A",
      1,
      explore_types.all_edge_types(),
      graph,
      dict.new(),
      metadata,
    )

  // Root + leg-B (but not leg-C)
  list.length(result_depth1.nodes) |> should.equal(2)

  // Depth 2: should get leg-B and leg-C
  let result_depth2 =
    explore_graph.build_expand_result(
      "leg-A",
      2,
      explore_types.all_edge_types(),
      graph,
      dict.new(),
      metadata,
    )

  // Root + leg-B + leg-C
  list.length(result_depth2.nodes) |> should.equal(3)
}

// --- find_shortest_path tests ---

pub fn path_direct_test() {
  let metadata = sample_metadata()
  let graph =
    DependencyGraph(
      outgoing: dict.from_list([
        #("leg-A", [
          GraphEdge(
            target_id: "leg-B",
            reference_type: reference.References,
            confidence: 0.9,
          ),
        ]),
      ]),
      incoming: dict.from_list([
        #("leg-B", [
          GraphEdge(
            target_id: "leg-A",
            reference_type: reference.References,
            confidence: 0.9,
          ),
        ]),
      ]),
    )

  let result =
    explore_graph.find_shortest_path(graph, metadata, "leg-A", "leg-B", 10)

  result.distance |> should.equal(1)
  list.length(result.path) |> should.equal(2)
}

pub fn path_two_hops_test() {
  let metadata = sample_metadata()
  let graph =
    DependencyGraph(
      outgoing: dict.from_list([
        #("leg-A", [
          GraphEdge(
            target_id: "leg-B",
            reference_type: reference.References,
            confidence: 0.9,
          ),
        ]),
        #("leg-B", [
          GraphEdge(
            target_id: "leg-C",
            reference_type: reference.References,
            confidence: 0.8,
          ),
        ]),
      ]),
      incoming: dict.from_list([
        #("leg-B", [
          GraphEdge(
            target_id: "leg-A",
            reference_type: reference.References,
            confidence: 0.9,
          ),
        ]),
        #("leg-C", [
          GraphEdge(
            target_id: "leg-B",
            reference_type: reference.References,
            confidence: 0.8,
          ),
        ]),
      ]),
    )

  let result =
    explore_graph.find_shortest_path(graph, metadata, "leg-A", "leg-C", 10)

  result.distance |> should.equal(2)
  list.length(result.path) |> should.equal(3)
}

pub fn path_unreachable_test() {
  let metadata = sample_metadata()
  let graph = DependencyGraph(outgoing: dict.new(), incoming: dict.new())

  let result =
    explore_graph.find_shortest_path(graph, metadata, "leg-A", "leg-C", 10)

  result.distance |> should.equal(-1)
  result.path |> should.equal([])
}

pub fn path_same_node_test() {
  let metadata = sample_metadata()
  let graph = DependencyGraph(outgoing: dict.new(), incoming: dict.new())

  let result =
    explore_graph.find_shortest_path(graph, metadata, "leg-A", "leg-A", 10)

  result.distance |> should.equal(0)
  list.length(result.path) |> should.equal(1)
}

pub fn path_cycle_safe_test() {
  let metadata = sample_metadata()
  // Create a cycle: A -> B -> A (should not infinite loop)
  let graph =
    DependencyGraph(
      outgoing: dict.from_list([
        #("leg-A", [
          GraphEdge(
            target_id: "leg-B",
            reference_type: reference.References,
            confidence: 0.9,
          ),
        ]),
        #("leg-B", [
          GraphEdge(
            target_id: "leg-A",
            reference_type: reference.References,
            confidence: 0.9,
          ),
        ]),
      ]),
      incoming: dict.from_list([
        #("leg-B", [
          GraphEdge(
            target_id: "leg-A",
            reference_type: reference.References,
            confidence: 0.9,
          ),
        ]),
        #("leg-A", [
          GraphEdge(
            target_id: "leg-B",
            reference_type: reference.References,
            confidence: 0.9,
          ),
        ]),
      ]),
    )

  // Target leg-C is unreachable from cycle A<->B
  let result =
    explore_graph.find_shortest_path(graph, metadata, "leg-A", "leg-C", 10)

  result.distance |> should.equal(-1)
}

// --- build_cluster tests ---

pub fn cluster_edge_filtering_test() {
  let metadata = sample_metadata()
  let legislation_ids = ["leg-A", "leg-B"]

  // Reference between A and B (both in cluster)
  let in_cluster_ref =
    reference.CrossReference(
      id: reference.reference_id("ref-ab"),
      source_legislation_id: "leg-A",
      target_legislation_id: Some("leg-B"),
      citation_text: "Section 5",
      reference_type: reference.References,
      confidence: 0.9,
      extractor: reference.GleamNative,
      extracted_at: "2024-01-01",
    )

  // Reference from A to C (C not in cluster — should be filtered out)
  let out_of_cluster_ref =
    reference.CrossReference(
      id: reference.reference_id("ref-ac"),
      source_legislation_id: "leg-A",
      target_legislation_id: Some("leg-C"),
      citation_text: "Section 10",
      reference_type: reference.References,
      confidence: 0.8,
      extractor: reference.GleamNative,
      extracted_at: "2024-01-01",
    )

  let result =
    explore_graph.build_cluster(
      "healthcare",
      "Healthcare",
      legislation_ids,
      [in_cluster_ref, out_of_cluster_ref],
      [],
      metadata,
    )

  result.topic_slug |> should.equal("healthcare")
  result.topic_name |> should.equal("Healthcare")
  list.length(result.nodes) |> should.equal(2)
  // Only the in-cluster reference should remain
  list.length(result.edges) |> should.equal(1)
}
