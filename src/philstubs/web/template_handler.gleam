import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import lustre/element
import philstubs/core/government_level.{
  type GovernmentLevel, County, Federal, Municipal, State,
}
import philstubs/core/legislation_template.{
  type LegislationTemplate, LegislationTemplate,
}
import philstubs/core/legislation_type.{type LegislationType}
import philstubs/data/similarity_repo
import philstubs/data/template_repo
import philstubs/ui/template_detail_page
import philstubs/ui/template_form_page
import philstubs/ui/templates_page
import sqlight
import wisp.{type Request, type Response}

/// Handle GET /templates — list all templates with sorting.
pub fn handle_templates_list(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  let sort_param =
    wisp.get_query(request)
    |> list.key_find("sort")
    |> result.unwrap("")

  let current_sort = templates_page.sort_order_from_string(sort_param)

  case template_repo.list_all(db_connection) {
    Ok(templates) -> {
      let sorted_templates =
        templates_page.sort_templates(templates, current_sort)
      templates_page.templates_page(sorted_templates, current_sort)
      |> element.to_document_string
      |> wisp.html_response(200)
    }
    Error(_) -> {
      templates_page.templates_page([], templates_page.Newest)
      |> element.to_document_string
      |> wisp.html_response(200)
    }
  }
}

/// Handle GET /templates/new — show the upload form.
pub fn handle_template_new_form() -> Response {
  template_form_page.template_form_page(template_form_page.empty_form(), None)
  |> element.to_document_string
  |> wisp.html_response(200)
}

/// Handle POST /templates — create a new template from form data.
pub fn handle_template_create(
  request: Request,
  db_connection: sqlight.Connection,
  owner_user_id: option.Option(String),
) -> Response {
  use form_data <- wisp.require_form(request)

  let form_values = form_data.values
  let title = find_form_value(form_values, "title")
  let description = find_form_value(form_values, "description")
  let body = find_form_value(form_values, "body")
  let suggested_level_str = find_form_value(form_values, "suggested_level")
  let suggested_type_str = find_form_value(form_values, "suggested_type")
  let author = find_form_value(form_values, "author")
  let topics_str = find_form_value(form_values, "topics")

  let repopulated_form =
    template_form_page.TemplateFormData(
      title:,
      description:,
      body:,
      suggested_level: suggested_level_str,
      suggested_type: suggested_type_str,
      author:,
      topics: topics_str,
    )

  // Validate required fields
  case validate_required_fields(title, body, author) {
    Error(error_message) -> {
      template_form_page.template_form_page(
        repopulated_form,
        Some(error_message),
      )
      |> element.to_document_string
      |> wisp.html_response(400)
    }
    Ok(_) -> {
      let template_id = generate_template_id(title, author)
      let suggested_level = parse_government_level(suggested_level_str)
      let suggested_type = parse_legislation_type(suggested_type_str)
      let topics = parse_topics(topics_str)

      let template =
        LegislationTemplate(
          id: legislation_template.template_id(template_id),
          title: sanitize_text(title),
          description: sanitize_text(description),
          body: sanitize_text(body),
          suggested_level:,
          suggested_type:,
          author: sanitize_text(author),
          topics:,
          created_at: "",
          download_count: 0,
          owner_user_id:,
        )

      case template_repo.insert(db_connection, template) {
        Ok(_) -> wisp.redirect("/templates/" <> template_id)
        Error(_) -> {
          template_form_page.template_form_page(
            repopulated_form,
            Some("Failed to save template. Please try again."),
          )
          |> element.to_document_string
          |> wisp.html_response(500)
        }
      }
    }
  }
}

/// Handle GET /templates/:id — show template detail.
pub fn handle_template_detail(
  template_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  case template_repo.get_by_id(db_connection, template_id) {
    Ok(Some(template)) -> {
      let template_matches =
        similarity_repo.find_template_matches(
          db_connection,
          template_id,
          0.3,
          10,
        )
        |> result.unwrap([])

      template_detail_page.template_detail_page(template, template_matches)
      |> element.to_document_string
      |> wisp.html_response(200)
    }
    Ok(None) -> wisp.not_found()
    Error(_) -> wisp.internal_server_error()
  }
}

/// Handle GET /templates/:id/download — download template in requested format.
pub fn handle_template_download(
  request: Request,
  template_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  let format_param =
    wisp.get_query(request)
    |> list.key_find("format")
    |> result.unwrap("text")

  case template_repo.get_by_id(db_connection, template_id) {
    Ok(Some(template)) -> {
      // Increment download count
      let _ = template_repo.increment_download_count(db_connection, template_id)

      let #(content, content_type, file_extension) = case format_param {
        "markdown" -> #(
          format_as_markdown(template),
          "text/markdown; charset=utf-8",
          ".md",
        )
        _ -> #(
          format_as_plain_text(template),
          "text/plain; charset=utf-8",
          ".txt",
        )
      }

      let safe_filename = slugify(template.title) <> file_extension

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

/// Handle DELETE /templates/:id — delete a template.
pub fn handle_template_delete(
  template_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  case template_repo.get_by_id(db_connection, template_id) {
    Ok(Some(_)) -> {
      case template_repo.delete(db_connection, template_id) {
        Ok(_) -> wisp.redirect("/templates")
        Error(_) -> wisp.internal_server_error()
      }
    }
    Ok(None) -> wisp.not_found()
    Error(_) -> wisp.internal_server_error()
  }
}

/// Handle GET /api/templates — JSON list of all templates.
pub fn handle_templates_api(db_connection: sqlight.Connection) -> Response {
  case template_repo.list_all(db_connection) {
    Ok(templates) -> {
      let json_items = list.map(templates, legislation_template.to_json)
      json.array(json_items, fn(item) { item })
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> {
      json.array([], fn(item: json.Json) { item })
      |> json.to_string
      |> wisp.json_response(500)
    }
  }
}

/// Handle GET /api/templates/:id — JSON for a single template.
pub fn handle_template_api_detail(
  template_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  case template_repo.get_by_id(db_connection, template_id) {
    Ok(Some(template)) ->
      legislation_template.to_json(template)
      |> json.to_string
      |> wisp.json_response(200)
    Ok(None) -> wisp.not_found()
    Error(_) -> wisp.internal_server_error()
  }
}

// --- Private helpers ---

fn find_form_value(form_values: List(#(String, String)), key: String) -> String {
  list.key_find(form_values, key)
  |> result.unwrap("")
}

fn validate_required_fields(
  title: String,
  body: String,
  author: String,
) -> Result(Nil, String) {
  case string.trim(title), string.trim(body), string.trim(author) {
    "", _, _ -> Error("Title is required.")
    _, "", _ -> Error("Template body is required.")
    _, _, "" -> Error("Author is required.")
    _, _, _ -> Ok(Nil)
  }
}

fn parse_government_level(level_str: String) -> GovernmentLevel {
  case level_str {
    "state" -> State("")
    "county" -> County("", "")
    "municipal" -> Municipal("", "")
    _ -> Federal
  }
}

fn parse_legislation_type(type_str: String) -> LegislationType {
  case type_str {
    "resolution" -> legislation_type.Resolution
    "ordinance" -> legislation_type.Ordinance
    "bylaw" -> legislation_type.Bylaw
    "amendment" -> legislation_type.Amendment
    "regulation" -> legislation_type.Regulation
    "executive_order" -> legislation_type.ExecutiveOrder
    _ -> legislation_type.Bill
  }
}

fn parse_topics(topics_str: String) -> List(String) {
  topics_str
  |> string.split(",")
  |> list.map(string.trim)
  |> list.filter(fn(topic) { topic != "" })
}

fn generate_template_id(title: String, author: String) -> String {
  let slug =
    slugify(title)
    |> string.slice(0, 40)

  let author_slug =
    slugify(author)
    |> string.slice(0, 20)

  "tmpl-" <> slug <> "-" <> author_slug
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
            // Allow a-z, 0-9
            { code >= 97 && code <= 122 } || { code >= 48 && code <= 57 }
          }
          _ -> False
        }
      }
    }
  })
  |> string.join("")
}

/// Sanitize text input by stripping HTML tags to prevent XSS.
fn sanitize_text(input: String) -> String {
  input
  |> string.replace("<script", "&lt;script")
  |> string.replace("</script", "&lt;/script")
  |> string.replace("<iframe", "&lt;iframe")
  |> string.replace("</iframe", "&lt;/iframe")
  |> string.replace("javascript:", "")
  |> string.replace("onerror=", "")
  |> string.replace("onload=", "")
}

fn format_as_plain_text(template: LegislationTemplate) -> String {
  let level_label =
    government_level.jurisdiction_label(template.suggested_level)
  let type_label = legislation_type.to_string(template.suggested_type)
  let topics_label = string.join(template.topics, ", ")

  string.join(
    [
      template.title,
      string.repeat("=", string.length(template.title)),
      "",
      "Author: " <> template.author,
      "Suggested Level: " <> level_label,
      "Legislation Type: " <> type_label,
      "Topics: " <> topics_label,
      "",
      "Description:",
      template.description,
      "",
      "---",
      "",
      template.body,
    ],
    "\n",
  )
}

fn format_as_markdown(template: LegislationTemplate) -> String {
  let level_label =
    government_level.jurisdiction_label(template.suggested_level)
  let type_label = legislation_type.to_string(template.suggested_type)
  let topics_label = string.join(template.topics, ", ")

  string.join(
    [
      "# " <> template.title,
      "",
      "**Author:** " <> template.author,
      "**Suggested Level:** " <> level_label <> "  ",
      "**Legislation Type:** " <> type_label <> "  ",
      "**Topics:** " <> topics_label,
      "",
      "## Description",
      "",
      template.description,
      "",
      "## Template Text",
      "",
      template.body,
    ],
    "\n",
  )
}
