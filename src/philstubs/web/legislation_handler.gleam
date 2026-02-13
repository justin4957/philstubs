import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import lustre/element
import philstubs/core/government_level
import philstubs/core/legislation.{type Legislation}
import philstubs/core/legislation_type
import philstubs/data/legislation_repo
import philstubs/data/similarity_repo
import philstubs/ui/legislation_detail_page
import sqlight
import wisp.{type Request, type Response}

/// Handle GET /legislation/:id — render the legislation detail page.
pub fn handle_legislation_detail(
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  case legislation_repo.get_by_id(db_connection, legislation_id) {
    Ok(Some(record)) -> {
      let related_legislation =
        legislation_repo.find_related(
          db_connection,
          legislation_id,
          record.topics,
          5,
        )
        |> result.unwrap([])

      let similar_legislation =
        similarity_repo.find_similar(db_connection, legislation_id, 0.3, 10)
        |> result.unwrap([])

      let adoption_timeline =
        similarity_repo.adoption_timeline(db_connection, legislation_id, 0.3)
        |> result.unwrap([])

      legislation_detail_page.legislation_detail_page(
        record,
        related_legislation,
        similar_legislation,
        adoption_timeline,
      )
      |> element.to_document_string
      |> wisp.html_response(200)
    }
    Ok(None) -> wisp.not_found()
    Error(_) -> wisp.internal_server_error()
  }
}

/// Handle GET /api/legislation/:id — return legislation as JSON.
pub fn handle_legislation_api_detail(
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  case legislation_repo.get_by_id(db_connection, legislation_id) {
    Ok(Some(record)) ->
      legislation.to_json(record)
      |> json.to_string
      |> wisp.json_response(200)
    Ok(None) -> wisp.not_found()
    Error(_) -> wisp.internal_server_error()
  }
}

/// Handle GET /legislation/:id/download — download legislation as text or markdown.
pub fn handle_legislation_download(
  request: Request,
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  let format_param =
    wisp.get_query(request)
    |> list.key_find("format")
    |> result.unwrap("text")

  case legislation_repo.get_by_id(db_connection, legislation_id) {
    Ok(Some(record)) -> {
      let #(content, content_type, file_extension) = case format_param {
        "markdown" -> #(
          format_as_markdown(record),
          "text/markdown; charset=utf-8",
          ".md",
        )
        _ -> #(
          format_as_plain_text(record),
          "text/plain; charset=utf-8",
          ".txt",
        )
      }

      let safe_filename = slugify(record.title) <> file_extension

      wisp.response(200)
      |> wisp.set_header("content-type", content_type)
      |> wisp.set_header(
        "content-disposition",
        "attachment; filename=\"" <> safe_filename <> "\"",
      )
      |> wisp.string_body(content)
    }
    Ok(None) -> wisp.not_found()
    Error(_) -> wisp.internal_server_error()
  }
}

// --- Format helpers ---

fn format_as_plain_text(record: Legislation) -> String {
  let level_label = government_level.jurisdiction_label(record.level)
  let type_label = legislation_type.to_string(record.legislation_type)
  let sponsors_label = string.join(record.sponsors, ", ")
  let topics_label = string.join(record.topics, ", ")

  let header_lines = [
    record.title,
    string.repeat("=", string.length(record.title)),
    "",
    "Identifier: " <> record.source_identifier,
    "Jurisdiction: " <> level_label,
    "Type: " <> type_label,
    "Introduced: " <> record.introduced_date,
  ]

  let sponsor_lines = case record.sponsors {
    [] -> []
    _ -> ["Sponsors: " <> sponsors_label]
  }

  let topic_lines = case record.topics {
    [] -> []
    _ -> ["Topics: " <> topics_label]
  }

  let summary_lines = case record.summary {
    "" -> []
    summary_text -> ["", "Summary:", summary_text]
  }

  let body_lines = ["", "---", "", record.body]

  string.join(
    list.flatten([
      header_lines,
      sponsor_lines,
      topic_lines,
      summary_lines,
      body_lines,
    ]),
    "\n",
  )
}

fn format_as_markdown(record: Legislation) -> String {
  let level_label = government_level.jurisdiction_label(record.level)
  let type_label = legislation_type.to_string(record.legislation_type)
  let sponsors_label = string.join(record.sponsors, ", ")
  let topics_label = string.join(record.topics, ", ")

  let header_lines = [
    "# " <> record.title,
    "",
    "**Identifier:** " <> record.source_identifier <> "  ",
    "**Jurisdiction:** " <> level_label <> "  ",
    "**Type:** " <> type_label <> "  ",
    "**Introduced:** " <> record.introduced_date,
  ]

  let sponsor_lines = case record.sponsors {
    [] -> []
    _ -> ["**Sponsors:** " <> sponsors_label]
  }

  let topic_lines = case record.topics {
    [] -> []
    _ -> ["**Topics:** " <> topics_label]
  }

  let summary_lines = case record.summary {
    "" -> []
    summary_text -> ["", "## Summary", "", summary_text]
  }

  let body_lines = ["", "## Full Text", "", record.body]

  string.join(
    list.flatten([
      header_lines,
      sponsor_lines,
      topic_lines,
      summary_lines,
      body_lines,
    ]),
    "\n",
  )
}

fn slugify(text: String) -> String {
  text
  |> string.lowercase
  |> string.replace(" ", "-")
  |> string.replace("'", "")
  |> string.replace("\"", "")
  |> string.replace(",", "")
  |> string.replace(".", "")
  |> string.replace("(", "")
  |> string.replace(")", "")
  |> string.to_graphemes
  |> list.filter(fn(grapheme) {
    case grapheme {
      "-" | "_" -> True
      _ -> {
        case string.to_utf_codepoints(grapheme) {
          [codepoint] -> {
            let code = string.utf_codepoint_to_int(codepoint)
            { code >= 97 && code <= 122 } || { code >= 48 && code <= 57 }
          }
          _ -> False
        }
      }
    }
  })
  |> string.join("")
}
