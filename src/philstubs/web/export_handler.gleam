import gleam/json
import gleam/list
import gleam/option
import gleam/result
import philstubs/core/csv_export
import philstubs/core/export_format.{type ExportFormat, Csv, Json}
import philstubs/core/legislation
import philstubs/core/legislation_template
import philstubs/data/legislation_repo
import philstubs/data/template_repo
import philstubs/search/search_query.{type SearchQuery}
import philstubs/search/search_repo
import philstubs/web/api_error
import sqlight
import wisp.{type Request, type Response}

/// Handle GET /api/export/legislation — bulk export of legislation data.
/// Supports ?format=json|csv and the same search filters as /api/search.
pub fn handle_export_legislation(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  let query_params = wisp.get_query(request)
  let format = resolve_format(query_params)
  let search_query = parse_export_filters(query_params)

  let has_filters =
    search_query.has_filters(search_query) || option.is_some(search_query.text)

  case has_filters {
    False -> {
      // No filters: use list_all for efficiency
      case legislation_repo.list_all(db_connection) {
        Ok(legislation_records) -> {
          let content = format_legislation(legislation_records, format)
          build_export_response(content, format, "legislation-export")
        }
        Error(_) -> api_error.internal_error()
      }
    }
    True -> {
      // Filters present: use search_repo with high per_page
      let bulk_query =
        search_query.SearchQuery(..search_query, per_page: 100_000, page: 1)
      case search_repo.search(db_connection, bulk_query) {
        Ok(search_results) -> {
          let legislation_records =
            list.map(search_results.items, fn(search_result) {
              search_result.legislation
            })
          let content = format_legislation(legislation_records, format)
          build_export_response(content, format, "legislation-export")
        }
        Error(_) -> api_error.internal_error()
      }
    }
  }
}

/// Handle GET /api/export/templates — bulk export of template data.
/// Supports ?format=json|csv.
pub fn handle_export_templates(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  let query_params = wisp.get_query(request)
  let format = resolve_format(query_params)

  case template_repo.list_all(db_connection) {
    Ok(template_records) -> {
      let content = format_templates(template_records, format)
      build_export_response(content, format, "templates-export")
    }
    Error(_) -> api_error.internal_error()
  }
}

/// Handle GET /api/export/search — export search results.
/// Supports ?format=json|csv and all search filters.
pub fn handle_export_search(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  let query_params = wisp.get_query(request)
  let format = resolve_format(query_params)
  let search_query = parse_export_filters(query_params)

  let bulk_query =
    search_query.SearchQuery(..search_query, per_page: 100_000, page: 1)

  case search_repo.search(db_connection, bulk_query) {
    Ok(search_results) -> {
      let legislation_records =
        list.map(search_results.items, fn(search_result) {
          search_result.legislation
        })
      let content = format_legislation(legislation_records, format)
      build_export_response(content, format, "search-export")
    }
    Error(_) -> api_error.internal_error()
  }
}

// --- Private helpers ---

fn resolve_format(query_params: List(#(String, String))) -> ExportFormat {
  query_params
  |> list.key_find("format")
  |> result.unwrap("json")
  |> export_format.from_string
}

fn parse_export_filters(query_params: List(#(String, String))) -> SearchQuery {
  // Reuse the search query parser for filter extraction
  search_query.from_query_params(query_params)
}

fn format_legislation(
  legislation_records: List(legislation.Legislation),
  format: ExportFormat,
) -> String {
  case format {
    Json -> {
      let items = list.map(legislation_records, legislation.to_json)
      json.object([
        #("export_format", json.string("json")),
        #("total_count", json.int(list.length(legislation_records))),
        #("items", json.array(items, fn(item) { item })),
      ])
      |> json.to_string
    }
    Csv -> csv_export.legislation_to_csv(legislation_records)
  }
}

fn format_templates(
  template_records: List(legislation_template.LegislationTemplate),
  format: ExportFormat,
) -> String {
  case format {
    Json -> {
      let items = list.map(template_records, legislation_template.to_json)
      json.object([
        #("export_format", json.string("json")),
        #("total_count", json.int(list.length(template_records))),
        #("items", json.array(items, fn(item) { item })),
      ])
      |> json.to_string
    }
    Csv -> csv_export.templates_to_csv(template_records)
  }
}

fn build_export_response(
  content: String,
  format: ExportFormat,
  filename_prefix: String,
) -> Response {
  let content_type_value = export_format.content_type(format)
  let extension = export_format.file_extension(format)
  let filename = filename_prefix <> extension

  wisp.response(200)
  |> wisp.set_header("content-type", content_type_value)
  |> wisp.set_header(
    "content-disposition",
    "attachment; filename=\"" <> filename <> "\"",
  )
  |> wisp.string_body(content)
}
