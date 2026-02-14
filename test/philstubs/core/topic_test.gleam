import gleam/json
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import philstubs/core/topic

pub fn topic_id_roundtrip_test() {
  let identifier = topic.topic_id("housing")
  topic.topic_id_to_string(identifier)
  |> should.equal("housing")
}

pub fn assignment_method_manual_roundtrip_test() {
  topic.Manual
  |> topic.assignment_method_to_string
  |> topic.assignment_method_from_string
  |> should.equal(topic.Manual)
}

pub fn assignment_method_auto_keyword_roundtrip_test() {
  topic.AutoKeyword
  |> topic.assignment_method_to_string
  |> topic.assignment_method_from_string
  |> should.equal(topic.AutoKeyword)
}

pub fn assignment_method_ingestion_roundtrip_test() {
  topic.Ingestion
  |> topic.assignment_method_to_string
  |> topic.assignment_method_from_string
  |> should.equal(topic.Ingestion)
}

pub fn assignment_method_unknown_defaults_to_manual_test() {
  topic.assignment_method_from_string("unknown")
  |> should.equal(topic.Manual)
}

pub fn topic_to_json_test() {
  let test_topic =
    topic.Topic(
      id: topic.topic_id("housing"),
      name: "Housing",
      slug: "housing",
      description: "Housing policy",
      parent_id: None,
      display_order: 6,
    )

  let json_string =
    topic.to_json(test_topic)
    |> json.to_string

  json_string |> string.contains("\"id\":\"housing\"") |> should.be_true
  json_string |> string.contains("\"name\":\"Housing\"") |> should.be_true
  json_string |> string.contains("\"slug\":\"housing\"") |> should.be_true
  json_string |> string.contains("\"display_order\":6") |> should.be_true
  json_string |> string.contains("\"parent_id\":null") |> should.be_true
}

pub fn topic_with_parent_to_json_test() {
  let child_topic =
    topic.Topic(
      id: topic.topic_id("zoning"),
      name: "Zoning",
      slug: "zoning",
      description: "Zoning regulations",
      parent_id: Some(topic.topic_id("housing")),
      display_order: 1,
    )

  let json_string =
    topic.to_json(child_topic)
    |> json.to_string

  json_string |> string.contains("\"parent_id\":\"housing\"") |> should.be_true
}
