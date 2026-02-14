import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import philstubs/core/government_level
import philstubs/core/legislation.{type Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_template.{type LegislationTemplate}
import philstubs/core/legislation_type

/// Escape a CSV field value per RFC 4180.
/// If the field contains commas, double quotes, or newlines,
/// wrap it in double quotes and double any internal quotes.
pub fn escape_csv_field(field_value: String) -> String {
  let needs_quoting =
    string.contains(field_value, ",")
    || string.contains(field_value, "\"")
    || string.contains(field_value, "\n")

  case needs_quoting {
    True -> {
      let escaped_value = string.replace(field_value, "\"", "\"\"")
      "\"" <> escaped_value <> "\""
    }
    False -> field_value
  }
}

/// Convert a list of Legislation records to a CSV string with headers.
/// Body is excluded from CSV export (too large for spreadsheet use).
pub fn legislation_to_csv(legislation_records: List(Legislation)) -> String {
  let header_row = legislation_csv_header()
  let data_rows = list.map(legislation_records, legislation_to_csv_row)
  [header_row, ..data_rows]
  |> string.join("\n")
}

/// Convert a list of LegislationTemplate records to a CSV string with headers.
/// Body is excluded from CSV export (too large for spreadsheet use).
pub fn templates_to_csv(template_records: List(LegislationTemplate)) -> String {
  let header_row = templates_csv_header()
  let data_rows = list.map(template_records, template_to_csv_row)
  [header_row, ..data_rows]
  |> string.join("\n")
}

/// Join a list of strings with semicolons for use in a single CSV field.
pub fn join_with_semicolons(values: List(String)) -> String {
  string.join(values, ";")
}

// --- Private helpers ---

fn legislation_csv_header() -> String {
  "id,title,summary,level,jurisdiction,legislation_type,status,introduced_date,source_url,source_identifier,sponsors,topics"
}

fn legislation_to_csv_row(record: Legislation) -> String {
  let legislation_id =
    legislation.legislation_id_to_string(record.id)
    |> escape_csv_field

  let title = escape_csv_field(record.title)
  let summary = escape_csv_field(record.summary)
  let level =
    government_level.to_string(record.level)
    |> escape_csv_field
  let jurisdiction =
    government_level.jurisdiction_label(record.level)
    |> escape_csv_field
  let leg_type =
    legislation_type.to_string(record.legislation_type)
    |> escape_csv_field
  let status =
    legislation_status.to_string(record.status)
    |> escape_csv_field
  let introduced_date = escape_csv_field(record.introduced_date)
  let source_url = case record.source_url {
    Some(url) -> escape_csv_field(url)
    None -> ""
  }
  let source_identifier = escape_csv_field(record.source_identifier)
  let sponsors =
    join_with_semicolons(record.sponsors)
    |> escape_csv_field
  let topics =
    join_with_semicolons(record.topics)
    |> escape_csv_field

  [
    legislation_id,
    title,
    summary,
    level,
    jurisdiction,
    leg_type,
    status,
    introduced_date,
    source_url,
    source_identifier,
    sponsors,
    topics,
  ]
  |> string.join(",")
}

fn templates_csv_header() -> String {
  "id,title,description,suggested_level,suggested_jurisdiction,suggested_type,author,topics,created_at,download_count"
}

fn template_to_csv_row(record: LegislationTemplate) -> String {
  let template_id =
    legislation_template.template_id_to_string(record.id)
    |> escape_csv_field

  let title = escape_csv_field(record.title)
  let description = escape_csv_field(record.description)
  let suggested_level =
    government_level.to_string(record.suggested_level)
    |> escape_csv_field
  let suggested_jurisdiction =
    government_level.jurisdiction_label(record.suggested_level)
    |> escape_csv_field
  let suggested_type =
    legislation_type.to_string(record.suggested_type)
    |> escape_csv_field
  let author = escape_csv_field(record.author)
  let topics =
    join_with_semicolons(record.topics)
    |> escape_csv_field
  let created_at = escape_csv_field(record.created_at)
  let download_count = int.to_string(record.download_count)

  [
    template_id,
    title,
    description,
    suggested_level,
    suggested_jurisdiction,
    suggested_type,
    author,
    topics,
    created_at,
    download_count,
  ]
  |> string.join(",")
}
