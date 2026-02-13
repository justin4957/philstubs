import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/core/government_level
import philstubs/core/legislation.{type Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/search/search_query.{type SearchQuery}
import philstubs/search/search_results.{type SearchResult, type SearchResults}
import philstubs/ui/layout

/// Render the full search page with form, filters, results, and pagination.
pub fn search_page(query: SearchQuery, results: SearchResults) -> Element(Nil) {
  layout.page_layout("Search — PHILSTUBS", [
    html.div([attribute.class("search-container")], [
      search_form(query),
      filter_panel(query),
      results_section(results),
    ]),
  ])
}

fn search_form(query: SearchQuery) -> Element(Nil) {
  let query_value = case query.text {
    Some(text) -> text
    None -> ""
  }

  html.form(
    [
      attribute.class("search-form"),
      attribute.method("GET"),
      attribute.action("/search"),
    ],
    [
      html.div([attribute.class("search-input-group")], [
        html.input([
          attribute.type_("search"),
          attribute.name("q"),
          attribute.value(query_value),
          attribute.placeholder("Search legislation..."),
          attribute.class("search-input"),
        ]),
        html.button(
          [attribute.type_("submit"), attribute.class("search-button")],
          [html.text("Search")],
        ),
      ]),
      // Preserve active filters as hidden inputs
      ..hidden_filter_inputs(query)
    ],
  )
}

fn hidden_filter_inputs(query: SearchQuery) -> List(Element(Nil)) {
  let inputs = []
  let inputs = case query.government_level {
    Some(level) -> [hidden_input("level", level), ..inputs]
    None -> inputs
  }
  let inputs = case query.state_code {
    Some(state_code) -> [hidden_input("state", state_code), ..inputs]
    None -> inputs
  }
  let inputs = case query.legislation_type {
    Some(legislation_type) -> [hidden_input("type", legislation_type), ..inputs]
    None -> inputs
  }
  let inputs = case query.status {
    Some(status) -> [hidden_input("status", status), ..inputs]
    None -> inputs
  }
  let inputs = case query.date_from {
    Some(date_from) -> [hidden_input("date_from", date_from), ..inputs]
    None -> inputs
  }
  let inputs = case query.date_to {
    Some(date_to) -> [hidden_input("date_to", date_to), ..inputs]
    None -> inputs
  }
  let inputs = case query.sort_by {
    search_query.Relevance -> inputs
    search_query.Date -> [hidden_input("sort", "date"), ..inputs]
    search_query.Title -> [hidden_input("sort", "title"), ..inputs]
  }
  inputs
}

fn hidden_input(input_name: String, input_value: String) -> Element(Nil) {
  html.input([
    attribute.type_("hidden"),
    attribute.name(input_name),
    attribute.value(input_value),
  ])
}

fn filter_panel(query: SearchQuery) -> Element(Nil) {
  html.aside([attribute.class("filter-panel")], [
    html.h3([], [html.text("Filters")]),
    filter_form(query),
  ])
}

fn filter_form(query: SearchQuery) -> Element(Nil) {
  let query_value = case query.text {
    Some(text) -> text
    None -> ""
  }

  html.form(
    [
      attribute.class("filter-form"),
      attribute.method("GET"),
      attribute.action("/search"),
    ],
    [
      // Carry over the text query
      case query.text {
        Some(_) -> hidden_input("q", query_value)
        None -> element.none()
      },
      filter_select("level", "Government Level", query.government_level, [
        #("", "All Levels"),
        #("federal", "Federal"),
        #("state", "State"),
        #("county", "County"),
        #("municipal", "Municipal"),
      ]),
      filter_select("type", "Legislation Type", query.legislation_type, [
        #("", "All Types"),
        #("bill", "Bill"),
        #("resolution", "Resolution"),
        #("ordinance", "Ordinance"),
        #("bylaw", "Bylaw"),
        #("amendment", "Amendment"),
        #("regulation", "Regulation"),
        #("executive_order", "Executive Order"),
      ]),
      filter_select("status", "Status", query.status, [
        #("", "All Statuses"),
        #("introduced", "Introduced"),
        #("in_committee", "In Committee"),
        #("passed_chamber", "Passed Chamber"),
        #("enacted", "Enacted"),
        #("vetoed", "Vetoed"),
        #("expired", "Expired"),
        #("withdrawn", "Withdrawn"),
      ]),
      html.div([attribute.class("filter-group")], [
        html.label([attribute.for("date_from")], [html.text("From Date")]),
        html.input([
          attribute.type_("date"),
          attribute.id("date_from"),
          attribute.name("date_from"),
          attribute.value(option.unwrap(query.date_from, "")),
        ]),
      ]),
      html.div([attribute.class("filter-group")], [
        html.label([attribute.for("date_to")], [html.text("To Date")]),
        html.input([
          attribute.type_("date"),
          attribute.id("date_to"),
          attribute.name("date_to"),
          attribute.value(option.unwrap(query.date_to, "")),
        ]),
      ]),
      filter_select(
        "sort",
        "Sort By",
        case query.sort_by {
          search_query.Relevance -> None
          search_query.Date -> Some("date")
          search_query.Title -> Some("title")
        },
        [
          #("", "Relevance"),
          #("date", "Date"),
          #("title", "Title"),
        ],
      ),
      html.button(
        [attribute.type_("submit"), attribute.class("filter-button")],
        [html.text("Apply Filters")],
      ),
      html.a([attribute.href("/search"), attribute.class("clear-filters")], [
        html.text("Clear All"),
      ]),
    ],
  )
}

fn filter_select(
  select_name: String,
  label_text: String,
  current_value: option.Option(String),
  options: List(#(String, String)),
) -> Element(Nil) {
  let selected_value = option.unwrap(current_value, "")

  html.div([attribute.class("filter-group")], [
    html.label([attribute.for(select_name)], [html.text(label_text)]),
    html.select(
      [attribute.id(select_name), attribute.name(select_name)],
      list.map(options, fn(opt) {
        let #(option_value, option_label) = opt
        html.option(
          [
            attribute.value(option_value),
            attribute.selected(option_value == selected_value),
          ],
          option_label,
        )
      }),
    ),
  ])
}

fn results_section(results: SearchResults) -> Element(Nil) {
  html.div([attribute.class("results-section")], [
    html.p([attribute.class("results-count")], [
      html.text(search_results.showing_label(results)),
    ]),
    html.div(
      [attribute.class("results-list")],
      list.map(results.items, render_result),
    ),
    pagination(results),
  ])
}

fn render_result(search_result: SearchResult) -> Element(Nil) {
  let legislation = search_result.legislation

  html.article([attribute.class("result-card")], [
    html.h3([attribute.class("result-title")], [
      result_link(legislation),
    ]),
    html.div([attribute.class("result-meta")], [
      badge(
        "level-badge",
        government_level.jurisdiction_label(legislation.level),
      ),
      badge(
        "type-badge",
        legislation_type.to_string(legislation.legislation_type),
      ),
      badge("status-badge", legislation_status.to_string(legislation.status)),
      case legislation.introduced_date {
        "" -> element.none()
        date_value ->
          html.span([attribute.class("result-date")], [
            html.text(date_value),
          ])
      },
    ]),
    snippet_element(search_result.snippet),
    sponsors_line(legislation),
  ])
}

fn result_link(legislation: Legislation) -> Element(Nil) {
  case legislation.source_url {
    Some(url) ->
      html.a(
        [
          attribute.href(url),
          attribute.target("_blank"),
          attribute.rel("noopener"),
        ],
        [html.text(legislation.title)],
      )
    None -> html.text(legislation.title)
  }
}

fn badge(class_name: String, badge_text: String) -> Element(Nil) {
  html.span([attribute.class("badge " <> class_name)], [
    html.text(badge_text),
  ])
}

fn snippet_element(snippet_text: String) -> Element(Nil) {
  case snippet_text {
    "" -> element.none()
    content ->
      // Use unsafe_raw_html to render <mark> tags from FTS5 snippet()
      element.unsafe_raw_html(
        "",
        "p",
        [attribute.class("result-snippet")],
        content,
      )
  }
}

fn sponsors_line(legislation: Legislation) -> Element(Nil) {
  case legislation.sponsors {
    [] -> element.none()
    sponsor_names ->
      html.p([attribute.class("result-sponsors")], [
        html.text("Sponsors: " <> string.join(sponsor_names, ", ")),
      ])
  }
}

fn pagination(results: SearchResults) -> Element(Nil) {
  case results.total_pages {
    pages if pages <= 1 -> element.none()
    _ -> {
      let query = results.query

      html.nav([attribute.class("pagination")], [
        case results.page > 1 {
          True ->
            pagination_link(
              search_query.to_query_params(
                search_query.SearchQuery(..query, page: results.page - 1),
              ),
              "Previous",
            )
          False ->
            html.span([attribute.class("pagination-disabled")], [
              html.text("Previous"),
            ])
        },
        html.span([attribute.class("pagination-info")], [
          html.text(
            "Page "
            <> int.to_string(results.page)
            <> " of "
            <> int.to_string(results.total_pages),
          ),
        ]),
        case results.page < results.total_pages {
          True ->
            pagination_link(
              search_query.to_query_params(
                search_query.SearchQuery(..query, page: results.page + 1),
              ),
              "Next",
            )
          False ->
            html.span([attribute.class("pagination-disabled")], [
              html.text("Next"),
            ])
        },
      ])
    }
  }
}

fn pagination_link(
  params: List(#(String, String)),
  link_text: String,
) -> Element(Nil) {
  let query_string =
    params
    |> list.map(fn(param) {
      let #(key, value) = param
      key <> "=" <> value
    })
    |> string.join("&")

  html.a(
    [
      attribute.href("/search?" <> query_string),
      attribute.class("pagination-link"),
    ],
    [html.text(link_text)],
  )
}
