import gleam/json
import gleam/option.{type Option}

/// Opaque identifier for a topic. Wraps a string to prevent
/// accidental misuse of raw strings as topic IDs.
pub opaque type TopicId {
  TopicId(String)
}

/// Create a TopicId from a string value.
pub fn topic_id(value: String) -> TopicId {
  TopicId(value)
}

/// Extract the underlying string from a TopicId.
pub fn topic_id_to_string(identifier: TopicId) -> String {
  let TopicId(value) = identifier
  value
}

/// How a topic was assigned to a piece of legislation or template.
pub type AssignmentMethod {
  Manual
  AutoKeyword
  Ingestion
}

/// Convert an AssignmentMethod to its database string representation.
pub fn assignment_method_to_string(method: AssignmentMethod) -> String {
  case method {
    Manual -> "manual"
    AutoKeyword -> "auto_keyword"
    Ingestion -> "ingestion"
  }
}

/// Parse a database string into an AssignmentMethod.
pub fn assignment_method_from_string(value: String) -> AssignmentMethod {
  case value {
    "auto_keyword" -> AutoKeyword
    "ingestion" -> Ingestion
    _ -> Manual
  }
}

/// A topic in the taxonomy hierarchy.
pub type Topic {
  Topic(
    id: TopicId,
    name: String,
    slug: String,
    description: String,
    parent_id: Option(TopicId),
    display_order: Int,
  )
}

/// A topic with aggregated legislation and template counts.
pub type TopicWithCount {
  TopicWithCount(topic: Topic, legislation_count: Int, template_count: Int)
}

/// A parent topic with its children and legislation count, for tree rendering.
pub type TopicTreeNode {
  TopicTreeNode(
    topic: Topic,
    children: List(TopicWithCount),
    legislation_count: Int,
  )
}

/// Cross-level summary for a topic: counts broken down by government level.
pub type TopicCrossLevelSummary {
  TopicCrossLevelSummary(
    topic: Topic,
    federal_count: Int,
    state_count: Int,
    county_count: Int,
    municipal_count: Int,
    state_breakdown: List(#(String, Int)),
  )
}

/// Encode a Topic to JSON.
pub fn to_json(topic: Topic) -> json.Json {
  json.object([
    #("id", json.string(topic_id_to_string(topic.id))),
    #("name", json.string(topic.name)),
    #("slug", json.string(topic.slug)),
    #("description", json.string(topic.description)),
    #(
      "parent_id",
      json.nullable(
        option.map(topic.parent_id, topic_id_to_string),
        json.string,
      ),
    ),
    #("display_order", json.int(topic.display_order)),
  ])
}

/// Encode a TopicWithCount to JSON.
pub fn topic_with_count_to_json(topic_with_count: TopicWithCount) -> json.Json {
  json.object([
    #("topic", to_json(topic_with_count.topic)),
    #("legislation_count", json.int(topic_with_count.legislation_count)),
    #("template_count", json.int(topic_with_count.template_count)),
  ])
}

/// Encode a TopicTreeNode to JSON.
pub fn topic_tree_node_to_json(node: TopicTreeNode) -> json.Json {
  json.object([
    #("topic", to_json(node.topic)),
    #("children", json.array(node.children, topic_with_count_to_json)),
    #("legislation_count", json.int(node.legislation_count)),
  ])
}

/// Encode a TopicCrossLevelSummary to JSON.
pub fn cross_level_summary_to_json(summary: TopicCrossLevelSummary) -> json.Json {
  json.object([
    #("topic", to_json(summary.topic)),
    #("federal_count", json.int(summary.federal_count)),
    #("state_count", json.int(summary.state_count)),
    #("county_count", json.int(summary.county_count)),
    #("municipal_count", json.int(summary.municipal_count)),
    #(
      "state_breakdown",
      json.array(summary.state_breakdown, fn(item) {
        let #(state_code, count) = item
        json.object([
          #("state_code", json.string(state_code)),
          #("count", json.int(count)),
        ])
      }),
    ),
  ])
}
