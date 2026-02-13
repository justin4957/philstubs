import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// Render an inline badge with a CSS class and text label.
pub fn badge(class_name: String, badge_text: String) -> Element(Nil) {
  html.span([attribute.class("badge " <> class_name)], [
    html.text(badge_text),
  ])
}

/// Render a labeled metadata item with uppercase label and value.
pub fn metadata_item(label_text: String, value_text: String) -> Element(Nil) {
  html.div([attribute.class("metadata-item")], [
    html.span([attribute.class("metadata-label")], [html.text(label_text)]),
    html.span([attribute.class("metadata-value")], [html.text(value_text)]),
  ])
}

/// Render a topic tags section. Returns element.none() when topics list is empty.
pub fn topics_section(topics: List(String)) -> Element(Nil) {
  case topics {
    [] -> element.none()
    topic_list ->
      html.div([attribute.class("metadata-item")], [
        html.span([attribute.class("metadata-label")], [html.text("Topics")]),
        html.div(
          [attribute.class("topic-tags")],
          list.map(topic_list, fn(topic) {
            html.span([attribute.class("topic-tag")], [html.text(topic)])
          }),
        ),
      ])
  }
}

/// Render a stat card with a large number value and descriptive label.
pub fn stat_card(value: String, label: String) -> Element(Nil) {
  html.div([attribute.class("stat-card")], [
    html.span([attribute.class("stat-value")], [html.text(value)]),
    html.span([attribute.class("stat-label")], [html.text(label)]),
  ])
}

/// Render a search bar form that submits to /search.
pub fn search_bar(placeholder: String) -> Element(Nil) {
  html.form(
    [
      attribute.class("hero-search-form"),
      attribute.method("GET"),
      attribute.action("/search"),
      attribute.attribute("role", "search"),
    ],
    [
      html.div([attribute.class("hero-search-group")], [
        html.label([attribute.for("hero-search"), attribute.class("sr-only")], [
          html.text("Search legislation"),
        ]),
        html.input([
          attribute.type_("search"),
          attribute.name("q"),
          attribute.id("hero-search"),
          attribute.placeholder(placeholder),
          attribute.class("hero-search-input"),
        ]),
        html.button(
          [attribute.type_("submit"), attribute.class("btn btn-primary")],
          [html.text("Search")],
        ),
      ]),
    ],
  )
}

/// Render a stats row from a list of (value, label) tuples.
pub fn stats_row(stats: List(#(String, String))) -> Element(Nil) {
  html.div(
    [attribute.class("stats-row")],
    list.map(stats, fn(stat_pair) {
      let #(value, label) = stat_pair
      stat_card(value, label)
    }),
  )
}

/// Render an action card with icon, title, description, and link.
pub fn action_card(
  title: String,
  description: String,
  url: String,
  icon_text: String,
) -> Element(Nil) {
  html.a([attribute.href(url), attribute.class("action-card")], [
    html.span(
      [
        attribute.class("action-card-icon"),
        attribute.attribute("aria-hidden", "true"),
      ],
      [html.text(icon_text)],
    ),
    html.h3([], [html.text(title)]),
    html.p([], [html.text(description)]),
  ])
}

/// Render a level overview card with title, count, description, and link.
pub fn level_overview_card(
  title: String,
  count: Int,
  description: String,
  url: String,
) -> Element(Nil) {
  html.a([attribute.href(url), attribute.class("level-overview-card")], [
    html.div([attribute.class("level-overview-header")], [
      html.h3([], [html.text(title)]),
      html.span([attribute.class("level-overview-count")], [
        html.text(int.to_string(count)),
      ]),
    ]),
    html.p([attribute.class("level-overview-description")], [
      html.text(description),
    ]),
  ])
}
