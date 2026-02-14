import gleam/dict
import gleam/json
import gleam/string
import gleeunit/should
import philstubs/core/government_level
import philstubs/core/impact_types.{
  Both, Direct, ImpactNode, ImpactResult, ImpactSummary, Incoming, Outgoing,
  Transitive,
}
import philstubs/core/legislation_type
import philstubs/core/reference

// --- Direction string conversion ---

pub fn direction_to_string_incoming_test() {
  impact_types.direction_to_string(Incoming)
  |> should.equal("incoming")
}

pub fn direction_to_string_outgoing_test() {
  impact_types.direction_to_string(Outgoing)
  |> should.equal("outgoing")
}

pub fn direction_to_string_both_test() {
  impact_types.direction_to_string(Both)
  |> should.equal("both")
}

pub fn direction_from_string_valid_test() {
  impact_types.direction_from_string("incoming") |> should.equal(Incoming)
  impact_types.direction_from_string("outgoing") |> should.equal(Outgoing)
  impact_types.direction_from_string("both") |> should.equal(Both)
}

pub fn direction_from_string_unknown_defaults_to_both_test() {
  impact_types.direction_from_string("invalid") |> should.equal(Both)
  impact_types.direction_from_string("") |> should.equal(Both)
}

// --- ImpactKind string conversion ---

pub fn impact_kind_to_string_test() {
  impact_types.impact_kind_to_string(Direct)
  |> should.equal("direct")

  impact_types.impact_kind_to_string(Transitive)
  |> should.equal("transitive")
}

// --- JSON serialization ---

pub fn impact_node_json_contains_expected_fields_test() {
  let node =
    ImpactNode(
      legislation_id: "leg-001",
      title: "Test Bill",
      level: government_level.State("CA"),
      legislation_type: legislation_type.Bill,
      depth: 1,
      impact_kind: Direct,
      reference_type: reference.Implements,
    )

  let json_string =
    node
    |> impact_types.impact_node_to_json
    |> json.to_string

  json_string |> string.contains("leg-001") |> should.be_true
  json_string |> string.contains("Test Bill") |> should.be_true
  json_string |> string.contains("direct") |> should.be_true
  json_string |> string.contains("implements") |> should.be_true
  json_string |> string.contains("state") |> should.be_true
}

pub fn impact_result_json_structure_test() {
  let node =
    ImpactNode(
      legislation_id: "leg-002",
      title: "Related Act",
      level: government_level.Federal,
      legislation_type: legislation_type.Resolution,
      depth: 2,
      impact_kind: Transitive,
      reference_type: reference.References,
    )

  let summary =
    ImpactSummary(
      total_nodes: 1,
      direct_count: 0,
      transitive_count: 1,
      max_depth_reached: 2,
      by_level: dict.from_list([#("Federal", 1)]),
      by_type: dict.from_list([#("Resolution", 1)]),
    )

  let result =
    ImpactResult(
      root_legislation_id: "leg-001",
      direction: Both,
      max_depth: 3,
      nodes: [node],
      summary:,
    )

  let json_string =
    result
    |> impact_types.impact_result_to_json
    |> json.to_string

  json_string |> string.contains("root_legislation_id") |> should.be_true
  json_string |> string.contains("leg-001") |> should.be_true
  json_string |> string.contains("both") |> should.be_true
  json_string |> string.contains("nodes") |> should.be_true
  json_string |> string.contains("summary") |> should.be_true
  json_string |> string.contains("total_nodes") |> should.be_true
  json_string |> string.contains("by_level") |> should.be_true
  json_string |> string.contains("by_type") |> should.be_true
}
