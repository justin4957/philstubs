import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/ui/layout

/// Render the API documentation page.
pub fn api_docs_page() -> Element(Nil) {
  layout.page_layout("API Documentation — PHILSTUBS", [
    html.div([attribute.class("api-docs")], [
      html.h1([], [html.text("API Documentation")]),
      html.p([attribute.class("api-intro")], [
        html.text(
          "PHILSTUBS provides a free, open API for accessing legislation data across all levels of US government. All data is available for download in JSON and CSV formats.",
        ),
      ]),
      html.p([], [
        html.text("Base URL: "),
        html.code([], [html.text("http://localhost:8000/api")]),
        html.text(" | "),
        html.a([attribute.href("/static/openapi.json")], [
          html.text("OpenAPI Specification (JSON)"),
        ]),
      ]),
      // Export Endpoints
      export_section(),
      // Search API
      search_section(),
      // Legislation API
      legislation_section(),
      // Templates API
      templates_section(),
      // Topics API
      topics_section(),
      // Browse Data API
      browse_section(),
      // Error Format
      error_format_section(),
    ]),
  ])
}

fn export_section() -> Element(Nil) {
  html.section([attribute.class("endpoint-section")], [
    html.h2([], [html.text("Bulk Data Export")]),
    html.p([], [
      html.text(
        "Download legislation and template data in JSON or CSV format. CSV exports exclude the full body text for spreadsheet compatibility.",
      ),
    ]),
    endpoint_card(
      "GET",
      "/api/export/legislation",
      "Export all legislation. Supports search filters.",
      [
        param_row("format", "json | csv", "Export format (default: json)"),
        param_row("level", "string", "Filter by government level"),
        param_row("state", "string", "Filter by state code"),
        param_row("type", "string", "Filter by legislation type"),
        param_row("status", "string", "Filter by status"),
        param_row("q", "string", "Full-text search query"),
        param_row("date_from", "YYYY-MM-DD", "Filter by start date"),
        param_row("date_to", "YYYY-MM-DD", "Filter by end date"),
      ],
      "curl \"http://localhost:8000/api/export/legislation?format=csv&level=federal\"",
    ),
    endpoint_card(
      "GET",
      "/api/export/templates",
      "Export all legislation templates.",
      [param_row("format", "json | csv", "Export format (default: json)")],
      "curl \"http://localhost:8000/api/export/templates?format=csv\"",
    ),
    endpoint_card(
      "GET",
      "/api/export/search",
      "Export search results. Same filters as /api/search.",
      [
        param_row("format", "json | csv", "Export format (default: json)"),
        param_row("q", "string", "Search query (required for relevance)"),
        param_row("level", "string", "Filter by government level"),
        param_row("type", "string", "Filter by legislation type"),
      ],
      "curl \"http://localhost:8000/api/export/search?q=climate&format=csv\"",
    ),
  ])
}

fn search_section() -> Element(Nil) {
  html.section([attribute.class("endpoint-section")], [
    html.h2([], [html.text("Search API")]),
    endpoint_card(
      "GET",
      "/api/search",
      "Full-text search with faceted filtering and pagination.",
      [
        param_row("q", "string", "Search query text"),
        param_row("level", "string", "federal | state | county | municipal"),
        param_row("state", "string", "Two-letter state code (e.g., CA)"),
        param_row("type", "string", "bill | resolution | ordinance | ..."),
        param_row(
          "status",
          "string",
          "introduced | enacted | vetoed | in_committee | ...",
        ),
        param_row("date_from", "YYYY-MM-DD", "Introduced after date"),
        param_row("date_to", "YYYY-MM-DD", "Introduced before date"),
        param_row("page", "integer", "Page number (default: 1)"),
        param_row(
          "per_page",
          "integer",
          "Results per page (default: 20, max: 100)",
        ),
        param_row("sort", "string", "relevance | date | title"),
      ],
      "curl \"http://localhost:8000/api/search?q=healthcare&level=federal&sort=date\"",
    ),
  ])
}

fn legislation_section() -> Element(Nil) {
  html.section([attribute.class("endpoint-section")], [
    html.h2([], [html.text("Legislation API")]),
    endpoint_card(
      "GET",
      "/api/legislation",
      "Paginated list of legislation with optional filters.",
      [
        param_row("level", "string", "Filter by government level"),
        param_row("page", "integer", "Page number"),
        param_row("per_page", "integer", "Results per page"),
      ],
      "curl \"http://localhost:8000/api/legislation?level=federal\"",
    ),
    endpoint_card(
      "GET",
      "/api/legislation/:id",
      "Get a single legislation record by ID.",
      [],
      "curl http://localhost:8000/api/legislation/hr-42-118",
    ),
    endpoint_card(
      "GET",
      "/api/legislation/stats",
      "Aggregate statistics: total count, breakdowns by level, type, and status.",
      [],
      "curl http://localhost:8000/api/legislation/stats",
    ),
    endpoint_card(
      "GET",
      "/api/legislation/:id/similar",
      "Find legislation similar to a given record based on text and topic overlap.",
      [],
      "curl http://localhost:8000/api/legislation/hr-42-118/similar",
    ),
    endpoint_card(
      "GET",
      "/api/legislation/:id/adoption-timeline",
      "Chronological timeline of similar legislation adoption across jurisdictions.",
      [],
      "curl http://localhost:8000/api/legislation/hr-42-118/adoption-timeline",
    ),
  ])
}

fn templates_section() -> Element(Nil) {
  html.section([attribute.class("endpoint-section")], [
    html.h2([], [html.text("Templates API")]),
    endpoint_card(
      "GET",
      "/api/templates",
      "List all legislation templates.",
      [],
      "curl http://localhost:8000/api/templates",
    ),
    endpoint_card(
      "GET",
      "/api/templates/:id",
      "Get a single template by ID.",
      [],
      "curl http://localhost:8000/api/templates/tmpl-example",
    ),
    endpoint_card(
      "POST",
      "/api/templates",
      "Create a new template. Requires authentication.",
      [],
      "curl -X POST http://localhost:8000/api/templates -H \"Content-Type: application/json\" -d '{\"title\":\"...\",\"body\":\"...\"}'",
    ),
    endpoint_card(
      "PUT",
      "/api/templates/:id",
      "Update an existing template. Requires authentication and ownership.",
      [],
      "curl -X PUT http://localhost:8000/api/templates/tmpl-example -H \"Content-Type: application/json\" -d '{...}'",
    ),
    endpoint_card(
      "DELETE",
      "/api/templates/:id",
      "Delete a template. Requires authentication and ownership.",
      [],
      "curl -X DELETE http://localhost:8000/api/templates/tmpl-example",
    ),
    endpoint_card(
      "GET",
      "/api/templates/:id/download",
      "Download a template as plain text or markdown.",
      [
        param_row(
          "format",
          "text | markdown",
          "Download format (default: text)",
        ),
      ],
      "curl \"http://localhost:8000/api/templates/tmpl-example/download?format=markdown\"",
    ),
    endpoint_card(
      "GET",
      "/api/templates/:id/matches",
      "Find legislation that matches a template based on similarity analysis.",
      [],
      "curl http://localhost:8000/api/templates/tmpl-example/matches",
    ),
  ])
}

fn topics_section() -> Element(Nil) {
  html.section([attribute.class("endpoint-section")], [
    html.h2([], [html.text("Topics API")]),
    endpoint_card(
      "GET",
      "/api/topics/taxonomy",
      "Full hierarchical topic taxonomy with parent topics, children, and legislation counts.",
      [],
      "curl http://localhost:8000/api/topics/taxonomy",
    ),
    endpoint_card(
      "GET",
      "/api/topics/:slug",
      "Topic detail with cross-level legislation breakdown (federal, state, county, municipal counts).",
      [],
      "curl http://localhost:8000/api/topics/housing",
    ),
    endpoint_card(
      "GET",
      "/api/topics/:slug/legislation",
      "Paginated legislation for a topic.",
      [
        param_row("limit", "integer", "Results per page (default: 20)"),
        param_row("page", "integer", "Page number (default: 1)"),
      ],
      "curl \"http://localhost:8000/api/topics/housing/legislation?limit=10\"",
    ),
    endpoint_card(
      "GET",
      "/api/topics/search",
      "Search topics by name prefix for autocomplete.",
      [param_row("q", "string", "Search prefix")],
      "curl \"http://localhost:8000/api/topics/search?q=Hou\"",
    ),
    endpoint_card(
      "POST",
      "/api/topics/auto-tag",
      "Trigger bulk auto-tagging of legislation based on keyword matching.",
      [],
      "curl -X POST http://localhost:8000/api/topics/auto-tag",
    ),
  ])
}

fn browse_section() -> Element(Nil) {
  html.section([attribute.class("endpoint-section")], [
    html.h2([], [html.text("Browse Data API")]),
    endpoint_card(
      "GET",
      "/api/levels",
      "Government levels with legislation counts.",
      [],
      "curl http://localhost:8000/api/levels",
    ),
    endpoint_card(
      "GET",
      "/api/levels/:level/jurisdictions",
      "Jurisdictions at a government level with counts.",
      [param_row("state", "string", "Required for county and municipal levels")],
      "curl \"http://localhost:8000/api/levels/county/jurisdictions?state=CA\"",
    ),
    endpoint_card(
      "GET",
      "/api/topics",
      "All topics with legislation counts (flat list).",
      [],
      "curl http://localhost:8000/api/topics",
    ),
  ])
}

fn error_format_section() -> Element(Nil) {
  html.section([attribute.class("endpoint-section")], [
    html.h2([], [html.text("Error Responses")]),
    html.p([], [
      html.text(
        "All API errors return a JSON object with an error message and machine-readable code:",
      ),
    ]),
    html.pre([attribute.class("code-example")], [
      html.code([], [
        html.text(
          "{\n  \"error\": \"Resource not found\",\n  \"code\": \"NOT_FOUND\"\n}",
        ),
      ]),
    ]),
    html.p([], [
      html.text("Error codes: "),
      html.code([], [html.text("NOT_FOUND")]),
      html.text(", "),
      html.code([], [html.text("VALIDATION_ERROR")]),
      html.text(", "),
      html.code([], [html.text("UNAUTHORIZED")]),
      html.text(", "),
      html.code([], [html.text("FORBIDDEN")]),
      html.text(", "),
      html.code([], [html.text("METHOD_NOT_ALLOWED")]),
      html.text(", "),
      html.code([], [html.text("INTERNAL_ERROR")]),
    ]),
    html.h3([], [html.text("CORS")]),
    html.p([], [
      html.text(
        "All API responses include CORS headers allowing cross-origin requests from any origin.",
      ),
    ]),
  ])
}

// --- Reusable components ---

fn endpoint_card(
  method: String,
  path: String,
  description: String,
  params: List(Element(Nil)),
  example: String,
) -> Element(Nil) {
  html.div([attribute.class("endpoint-card")], [
    html.div([attribute.class("endpoint-header")], [
      html.span(
        [attribute.class("method-badge method-" <> method_class(method))],
        [
          html.text(method),
        ],
      ),
      html.code([attribute.class("endpoint-path")], [html.text(path)]),
    ]),
    html.p([], [html.text(description)]),
    case params {
      [] -> element.none()
      _ ->
        html.table([attribute.class("param-table")], [
          html.thead([], [
            html.tr([], [
              html.th([], [html.text("Parameter")]),
              html.th([], [html.text("Type")]),
              html.th([], [html.text("Description")]),
            ]),
          ]),
          html.tbody([], params),
        ])
    },
    html.pre([attribute.class("code-example")], [
      html.code([], [html.text(example)]),
    ]),
  ])
}

fn param_row(
  param_name: String,
  param_type: String,
  description: String,
) -> Element(Nil) {
  html.tr([], [
    html.td([], [html.code([], [html.text(param_name)])]),
    html.td([], [html.text(param_type)]),
    html.td([], [html.text(description)]),
  ])
}

fn method_class(method: String) -> String {
  case method {
    "GET" -> "get"
    "POST" -> "post"
    "PUT" -> "put"
    "DELETE" -> "delete"
    _ -> "get"
  }
}
