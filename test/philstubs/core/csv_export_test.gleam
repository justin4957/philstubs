import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import philstubs/core/csv_export
import philstubs/core/government_level.{Federal, State}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_template.{
  type LegislationTemplate, LegislationTemplate,
}
import philstubs/core/legislation_type

// --- Field escaping tests ---

pub fn escape_csv_field_plain_text_test() {
  csv_export.escape_csv_field("Hello World")
  |> should.equal("Hello World")
}

pub fn escape_csv_field_with_comma_test() {
  csv_export.escape_csv_field("Hello, World")
  |> should.equal("\"Hello, World\"")
}

pub fn escape_csv_field_with_quotes_test() {
  csv_export.escape_csv_field("Say \"hello\"")
  |> should.equal("\"Say \"\"hello\"\"\"")
}

pub fn escape_csv_field_with_newline_test() {
  csv_export.escape_csv_field("Line 1\nLine 2")
  |> should.equal("\"Line 1\nLine 2\"")
}

pub fn escape_csv_field_empty_string_test() {
  csv_export.escape_csv_field("")
  |> should.equal("")
}

pub fn escape_csv_field_with_all_special_chars_test() {
  csv_export.escape_csv_field("Has \"quotes\", commas, and\nnewlines")
  |> should.equal("\"Has \"\"quotes\"\", commas, and\nnewlines\"")
}

// --- Semicolon joining tests ---

pub fn join_with_semicolons_test() {
  csv_export.join_with_semicolons(["climate", "environment", "energy"])
  |> should.equal("climate;environment;energy")
}

pub fn join_with_semicolons_empty_test() {
  csv_export.join_with_semicolons([])
  |> should.equal("")
}

pub fn join_with_semicolons_single_test() {
  csv_export.join_with_semicolons(["housing"])
  |> should.equal("housing")
}

// --- Legislation CSV tests ---

fn sample_legislation() -> Legislation {
  Legislation(
    id: legislation.legislation_id("test-fed-1"),
    title: "Federal Climate Act",
    summary: "A bill about climate.",
    body: "SECTION 1. Climate change mitigation.",
    level: Federal,
    legislation_type: legislation_type.Bill,
    status: legislation_status.Introduced,
    introduced_date: "2024-01-15",
    source_url: Some("https://congress.gov/bill/118/hr42"),
    source_identifier: "H.R. 42",
    sponsors: ["Rep. Smith", "Rep. Jones"],
    topics: ["climate", "environment"],
  )
}

fn sample_state_legislation() -> Legislation {
  Legislation(
    id: legislation.legislation_id("test-ca-1"),
    title: "California Water, Conservation & Rights Act",
    summary: "A bill about water rights.",
    body: "SECTION 1. Water.",
    level: State(state_code: "CA"),
    legislation_type: legislation_type.Resolution,
    status: legislation_status.Enacted,
    introduced_date: "2024-03-01",
    source_url: None,
    source_identifier: "AB 55",
    sponsors: [],
    topics: ["water"],
  )
}

pub fn legislation_to_csv_single_record_test() {
  let csv_output = csv_export.legislation_to_csv([sample_legislation()])
  let lines = string.split(csv_output, "\n")

  // Header row
  let assert [header_row, data_row] = lines
  header_row
  |> should.equal(
    "id,title,summary,level,jurisdiction,legislation_type,status,introduced_date,source_url,source_identifier,sponsors,topics",
  )

  // Data row should contain key values
  data_row |> string.contains("test-fed-1") |> should.be_true
  data_row |> string.contains("Federal Climate Act") |> should.be_true
  data_row |> string.contains("Bill") |> should.be_true
  data_row |> string.contains("Introduced") |> should.be_true
  data_row |> string.contains("2024-01-15") |> should.be_true
  data_row
  |> string.contains("https://congress.gov/bill/118/hr42")
  |> should.be_true
  data_row |> string.contains("Rep. Smith;Rep. Jones") |> should.be_true
  data_row |> string.contains("climate;environment") |> should.be_true
}

pub fn legislation_to_csv_multiple_records_test() {
  let csv_output =
    csv_export.legislation_to_csv([
      sample_legislation(),
      sample_state_legislation(),
    ])
  let lines = string.split(csv_output, "\n")

  // Header + 2 data rows
  lines |> list_length |> should.equal(3)
}

pub fn legislation_to_csv_empty_list_test() {
  let csv_output = csv_export.legislation_to_csv([])
  // Should only have the header row
  csv_output
  |> should.equal(
    "id,title,summary,level,jurisdiction,legislation_type,status,introduced_date,source_url,source_identifier,sponsors,topics",
  )
}

pub fn legislation_to_csv_special_characters_test() {
  let csv_output = csv_export.legislation_to_csv([sample_state_legislation()])
  let lines = string.split(csv_output, "\n")
  let assert [_, data_row] = lines

  // Title with commas should be quoted
  data_row
  |> string.contains("\"California Water, Conservation & Rights Act\"")
  |> should.be_true

  // None source_url should be empty
  data_row |> string.contains("AB 55") |> should.be_true
}

pub fn legislation_to_csv_none_source_url_test() {
  let csv_output = csv_export.legislation_to_csv([sample_state_legislation()])
  // The empty string for source_url should appear as consecutive commas
  csv_output |> string.contains(",,") |> should.be_true
}

// --- Template CSV tests ---

fn sample_template() -> LegislationTemplate {
  LegislationTemplate(
    id: legislation_template.template_id("tmpl-housing-1"),
    title: "Model Housing Ordinance",
    description: "A template for housing ordinances.",
    body: "SECTION 1. Housing standards.",
    suggested_level: Federal,
    suggested_type: legislation_type.Ordinance,
    author: "Policy Institute",
    topics: ["housing", "zoning"],
    created_at: "2024-06-01",
    download_count: 42,
    owner_user_id: None,
  )
}

pub fn templates_to_csv_single_record_test() {
  let csv_output = csv_export.templates_to_csv([sample_template()])
  let lines = string.split(csv_output, "\n")

  let assert [header_row, data_row] = lines
  header_row
  |> should.equal(
    "id,title,description,suggested_level,suggested_jurisdiction,suggested_type,author,topics,created_at,download_count",
  )

  data_row |> string.contains("tmpl-housing-1") |> should.be_true
  data_row |> string.contains("Model Housing Ordinance") |> should.be_true
  data_row |> string.contains("Policy Institute") |> should.be_true
  data_row |> string.contains("housing;zoning") |> should.be_true
  data_row |> string.contains("42") |> should.be_true
}

pub fn templates_to_csv_empty_list_test() {
  let csv_output = csv_export.templates_to_csv([])
  csv_output
  |> should.equal(
    "id,title,description,suggested_level,suggested_jurisdiction,suggested_type,author,topics,created_at,download_count",
  )
}

// --- Helper ---

import gleam/list

fn list_length(items: List(a)) -> Int {
  list.length(items)
}
