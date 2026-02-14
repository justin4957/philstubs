import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/option.{None, Some}
import gleam/string
import philstubs/core/citation_extractor
import philstubs/core/reference
import philstubs/data/reference_repo
import philstubs/web/api_error
import sqlight
import wisp.{type Request, type Response}

/// Handle GET /api/legislation/:id/references — outgoing cross-references.
pub fn handle_references_from(
  request: Request,
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)

  case reference_repo.find_references_from(db_connection, legislation_id, 100) {
    Ok(references) ->
      json.object([
        #("legislation_id", json.string(legislation_id)),
        #(
          "references",
          json.array(references, reference.cross_reference_to_json),
        ),
        #("count", json.int(count_list(references))),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    Error(_) -> api_error.internal_error()
  }
}

/// Handle GET /api/legislation/:id/referenced-by — incoming cross-references.
pub fn handle_referenced_by(
  request: Request,
  legislation_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)

  case reference_repo.find_references_to(db_connection, legislation_id, 100) {
    Ok(references) ->
      json.object([
        #("legislation_id", json.string(legislation_id)),
        #(
          "referenced_by",
          json.array(references, reference.cross_reference_to_json),
        ),
        #("count", json.int(count_list(references))),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    Error(_) -> api_error.internal_error()
  }
}

/// Handle /api/query-maps — dispatch GET (list) and POST (create).
pub fn handle_query_maps_dispatch(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  case request.method {
    http.Get -> handle_list_query_maps(db_connection)
    http.Post -> handle_create_query_map(request, db_connection)
    _ -> api_error.method_not_allowed([http.Get, http.Post])
  }
}

/// Handle GET /api/query-maps — list all query maps.
fn handle_list_query_maps(db_connection: sqlight.Connection) -> Response {
  case reference_repo.list_query_maps(db_connection) {
    Ok(query_maps) ->
      json.object([
        #("query_maps", json.array(query_maps, reference.query_map_to_json)),
        #("count", json.int(count_list(query_maps))),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    Error(_) -> api_error.internal_error()
  }
}

/// Handle POST /api/query-maps — create a new query map.
fn handle_create_query_map(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use json_body <- wisp.require_json(request)

  case decode_query_map_request(json_body) {
    Error(validation_message) -> api_error.validation_error(validation_message)
    Ok(query_map) -> {
      case reference_repo.insert_query_map(db_connection, query_map) {
        Ok(_) ->
          reference.query_map_to_json(query_map)
          |> json.to_string
          |> wisp.json_response(201)
        Error(_) -> api_error.internal_error()
      }
    }
  }
}

/// Handle GET /api/query-maps/:id — get a single query map.
pub fn handle_query_map_detail(
  request: Request,
  query_map_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)

  case reference_repo.get_query_map_by_id(db_connection, query_map_id) {
    Ok(Some(query_map)) ->
      reference.query_map_to_json(query_map)
      |> json.to_string
      |> wisp.json_response(200)
    Ok(None) -> api_error.not_found("Query map")
    Error(_) -> api_error.internal_error()
  }
}

/// Handle POST /api/references/extract — extract citations from posted text.
pub fn handle_extract_citations(
  request: Request,
  _db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Post)
  use json_body <- wisp.require_json(request)

  case decode_extract_request(json_body) {
    Error(validation_message) -> api_error.validation_error(validation_message)
    Ok(text_to_extract) -> {
      let citations = citation_extractor.extract_citations(text_to_extract)
      json.object([
        #("citations", json.array(citations, citation_to_json)),
        #("count", json.int(count_list(citations))),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    }
  }
}

// --- Request decoders ---

fn decode_query_map_request(
  json_body: dynamic.Dynamic,
) -> Result(reference.QueryMap, String) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use description <- decode.optional_field("description", "", decode.string)
    use query_template <- decode.field("query_template", decode.string)
    use parameters <- decode.optional_field("parameters", "{}", decode.string)
    decode.success(#(name, description, query_template, parameters))
  }

  case decode.run(json_body, decoder) {
    Ok(#(name, description, query_template, parameters)) -> {
      case string.is_empty(string.trim(name)) {
        True -> Error("name is required")
        False -> {
          case string.is_empty(string.trim(query_template)) {
            True -> Error("query_template is required")
            False -> {
              let query_map_id = generate_query_map_id(name)
              Ok(reference.QueryMap(
                id: reference.query_map_id(query_map_id),
                name:,
                description:,
                query_template:,
                parameters:,
                created_at: "",
              ))
            }
          }
        }
      }
    }
    Error(_) -> Error("Invalid JSON: expected name and query_template fields")
  }
}

fn decode_extract_request(json_body: dynamic.Dynamic) -> Result(String, String) {
  let decoder = {
    use text <- decode.field("text", decode.string)
    decode.success(text)
  }

  case decode.run(json_body, decoder) {
    Ok(text) -> {
      case string.is_empty(string.trim(text)) {
        True -> Error("text is required and must not be empty")
        False -> Ok(text)
      }
    }
    Error(_) -> Error("Invalid JSON: expected a 'text' field")
  }
}

// --- Helpers ---

fn generate_query_map_id(name: String) -> String {
  name
  |> string.lowercase
  |> string.replace(" ", "-")
  |> string.replace("_", "-")
}

fn citation_to_json(citation: citation_extractor.ExtractedCitation) -> json.Json {
  json.object([
    #("citation_text", json.string(citation.citation_text)),
    #(
      "citation_type",
      json.string(citation_extractor.citation_type_to_string(
        citation.citation_type,
      )),
    ),
    #(
      "reference_type",
      json.string(reference.reference_type_to_string(citation.reference_type)),
    ),
    #("confidence", json.float(citation.confidence)),
  ])
}

fn count_list(items: List(a)) -> Int {
  do_count(items, 0)
}

fn do_count(items: List(a), accumulated: Int) -> Int {
  case items {
    [] -> accumulated
    [_, ..rest] -> do_count(rest, accumulated + 1)
  }
}
