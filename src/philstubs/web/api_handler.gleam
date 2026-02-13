import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import philstubs/core/government_level.{type GovernmentLevel}
import philstubs/core/legislation_template.{
  type LegislationTemplate, LegislationTemplate,
}
import philstubs/core/legislation_type.{type LegislationType}
import philstubs/data/browse_repo
import philstubs/data/stats_repo
import philstubs/data/template_repo
import philstubs/search/search_query
import philstubs/search/search_repo
import philstubs/search/search_results
import philstubs/web/api_error
import sqlight
import wisp.{type Request, type Response}

// --- Legislation endpoints ---

/// Handle GET /api/legislation — paginated list with optional filters.
/// Accepts the same query params as /api/search.
pub fn handle_legislation_list(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  let query =
    wisp.get_query(request)
    |> search_query.from_query_params

  case search_repo.search(db_connection, query) {
    Ok(results) ->
      results
      |> search_results.to_json
      |> json.to_string
      |> wisp.json_response(200)
    Error(_) -> api_error.internal_error()
  }
}

/// Handle GET /api/legislation/stats — aggregate counts by level, type, status.
pub fn handle_legislation_stats(db_connection: sqlight.Connection) -> Response {
  case stats_repo.get_legislation_stats(db_connection) {
    Ok(stats) ->
      stats
      |> stats_repo.stats_to_json
      |> json.to_string
      |> wisp.json_response(200)
    Error(_) -> api_error.internal_error()
  }
}

// --- Template CRUD endpoints ---

/// Handle POST /api/templates — create a template from a JSON body.
pub fn handle_templates_create(
  request: Request,
  db_connection: sqlight.Connection,
  owner_user_id: option.Option(String),
) -> Response {
  use json_body <- wisp.require_json(request)

  case decode_template_request(json_body) {
    Error(validation_message) -> api_error.validation_error(validation_message)
    Ok(template_request) -> {
      let template_id =
        generate_template_id(template_request.title, template_request.author)
      let template =
        LegislationTemplate(
          id: legislation_template.template_id(template_id),
          title: template_request.title,
          description: template_request.description,
          body: template_request.body,
          suggested_level: template_request.suggested_level,
          suggested_type: template_request.suggested_type,
          author: template_request.author,
          topics: template_request.topics,
          created_at: "",
          download_count: 0,
          owner_user_id:,
        )

      case template_repo.insert(db_connection, template) {
        Ok(_) ->
          legislation_template.to_json(template)
          |> json.to_string
          |> wisp.json_response(201)
        Error(_) -> api_error.internal_error()
      }
    }
  }
}

/// Handle PUT /api/templates/:id — update a template from a JSON body.
pub fn handle_template_update(
  request: Request,
  template_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  case template_repo.get_by_id(db_connection, template_id) {
    Ok(Some(existing_template)) -> {
      use json_body <- wisp.require_json(request)
      case decode_template_request(json_body) {
        Error(validation_message) ->
          api_error.validation_error(validation_message)
        Ok(template_request) -> {
          let updated_template =
            LegislationTemplate(
              ..existing_template,
              title: template_request.title,
              description: template_request.description,
              body: template_request.body,
              suggested_level: template_request.suggested_level,
              suggested_type: template_request.suggested_type,
              author: template_request.author,
              topics: template_request.topics,
            )

          case template_repo.update(db_connection, updated_template) {
            Ok(_) ->
              legislation_template.to_json(updated_template)
              |> json.to_string
              |> wisp.json_response(200)
            Error(_) -> api_error.internal_error()
          }
        }
      }
    }
    Ok(None) -> api_error.not_found("Template")
    Error(_) -> api_error.internal_error()
  }
}

/// Handle DELETE /api/templates/:id — delete a template.
pub fn handle_template_delete(
  template_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  case template_repo.get_by_id(db_connection, template_id) {
    Ok(Some(_)) -> {
      case template_repo.delete(db_connection, template_id) {
        Ok(_) -> wisp.response(204)
        Error(_) -> api_error.internal_error()
      }
    }
    Ok(None) -> api_error.not_found("Template")
    Error(_) -> api_error.internal_error()
  }
}

/// Handle GET /api/templates/:id/download — download template in requested format.
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
      let _ = template_repo.increment_download_count(db_connection, template_id)

      let #(content, content_type, file_extension) = case format_param {
        "markdown" -> #(
          format_template_as_markdown(template),
          "text/markdown; charset=utf-8",
          ".md",
        )
        _ -> #(
          format_template_as_text(template),
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
    Ok(None) -> api_error.not_found("Template")
    Error(_) -> api_error.internal_error()
  }
}

// --- Browse data endpoints ---

/// Handle GET /api/levels — list government levels with legislation counts.
pub fn handle_levels_list(db_connection: sqlight.Connection) -> Response {
  case browse_repo.count_by_government_level(db_connection) {
    Ok(level_counts) -> {
      let levels =
        list.map(level_counts, fn(item) {
          let #(level_key, count) = item
          json.object([
            #("level", json.string(level_key)),
            #("label", json.string(level_label(level_key))),
            #("count", json.int(count)),
          ])
        })

      json.object([#("levels", json.preprocessed_array(levels))])
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> api_error.internal_error()
  }
}

/// Handle GET /api/levels/:level/jurisdictions — list jurisdictions at a level.
/// For "state": returns all states. For "county"/"municipal": accepts ?state=XX filter.
pub fn handle_level_jurisdictions(
  request: Request,
  level: String,
  db_connection: sqlight.Connection,
) -> Response {
  let state_filter =
    wisp.get_query(request)
    |> list.key_find("state")
    |> option.from_result

  case level {
    "state" -> {
      case browse_repo.count_by_state(db_connection) {
        Ok(state_counts) -> jurisdictions_response("state", state_counts)
        Error(_) -> api_error.internal_error()
      }
    }
    "county" -> {
      case state_filter {
        Some(state_code) -> {
          case browse_repo.count_counties_in_state(db_connection, state_code) {
            Ok(county_counts) -> jurisdictions_response("county", county_counts)
            Error(_) -> api_error.internal_error()
          }
        }
        None ->
          api_error.validation_error(
            "state query parameter required for county jurisdictions",
          )
      }
    }
    "municipal" -> {
      case state_filter {
        Some(state_code) -> {
          case
            browse_repo.count_municipalities_in_state(db_connection, state_code)
          {
            Ok(municipal_counts) ->
              jurisdictions_response("municipal", municipal_counts)
            Error(_) -> api_error.internal_error()
          }
        }
        None ->
          api_error.validation_error(
            "state query parameter required for municipal jurisdictions",
          )
      }
    }
    _ -> api_error.not_found("Level")
  }
}

/// Handle GET /api/topics — list all topics with legislation counts.
pub fn handle_topics_list(db_connection: sqlight.Connection) -> Response {
  case browse_repo.count_topics(db_connection) {
    Ok(topic_counts) -> {
      let topics =
        list.map(topic_counts, fn(item) {
          let #(topic_name, count) = item
          json.object([
            #("topic", json.string(topic_name)),
            #("count", json.int(count)),
          ])
        })

      json.object([#("topics", json.preprocessed_array(topics))])
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> api_error.internal_error()
  }
}

// --- Template request decoder ---

/// Decoded template creation/update request body.
type TemplateRequest {
  TemplateRequest(
    title: String,
    description: String,
    body: String,
    suggested_level: GovernmentLevel,
    suggested_type: LegislationType,
    author: String,
    topics: List(String),
  )
}

/// Decode and validate a template request from a Dynamic JSON value.
fn decode_template_request(
  json_body: Dynamic,
) -> Result(TemplateRequest, String) {
  let template_decoder = {
    use title <- decode.field("title", decode.string)
    use description <- decode.field("description", decode.string)
    use body <- decode.field("body", decode.string)
    use suggested_level <- decode.field(
      "suggested_level",
      government_level.decoder(),
    )
    use suggested_type <- decode.field(
      "suggested_type",
      legislation_type.decoder(),
    )
    use author <- decode.field("author", decode.string)
    use topics <- decode.field("topics", decode.list(decode.string))
    decode.success(TemplateRequest(
      title:,
      description:,
      body:,
      suggested_level:,
      suggested_type:,
      author:,
      topics:,
    ))
  }

  case decode.run(json_body, template_decoder) {
    Ok(template_request) -> validate_template_request(template_request)
    Error(_) ->
      Error(
        "Invalid request body. Required fields: title, description, body, suggested_level, suggested_type, author, topics",
      )
  }
}

fn validate_template_request(
  template_request: TemplateRequest,
) -> Result(TemplateRequest, String) {
  case
    string.trim(template_request.title),
    string.trim(template_request.body),
    string.trim(template_request.author)
  {
    "", _, _ -> Error("title is required and cannot be empty")
    _, "", _ -> Error("body is required and cannot be empty")
    _, _, "" -> Error("author is required and cannot be empty")
    _, _, _ -> Ok(template_request)
  }
}

// --- Private helpers ---

fn jurisdictions_response(
  level: String,
  jurisdiction_counts: List(#(String, Int)),
) -> Response {
  let jurisdictions =
    list.map(jurisdiction_counts, fn(item) {
      let #(jurisdiction_name, count) = item
      json.object([
        #("name", json.string(jurisdiction_name)),
        #("count", json.int(count)),
      ])
    })

  json.object([
    #("level", json.string(level)),
    #("jurisdictions", json.preprocessed_array(jurisdictions)),
  ])
  |> json.to_string
  |> wisp.json_response(200)
}

fn level_label(level_key: String) -> String {
  case level_key {
    "federal" -> "Federal"
    "state" -> "State"
    "county" -> "County"
    "municipal" -> "Municipal"
    other -> other
  }
}

fn generate_template_id(title: String, author: String) -> String {
  let title_slug =
    slugify(title)
    |> string.slice(0, 40)

  let author_slug =
    slugify(author)
    |> string.slice(0, 20)

  "tmpl-" <> title_slug <> "-" <> author_slug
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

fn format_template_as_text(template: LegislationTemplate) -> String {
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

fn format_template_as_markdown(template: LegislationTemplate) -> String {
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
