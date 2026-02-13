import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/core/government_level
import philstubs/core/similarity.{type DiffHunk, Added, Removed, Same}
import philstubs/core/similarity_types.{type AdoptionEvent}

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

/// Render a similarity score badge with color coding.
/// Green >0.8, yellow >0.5, red <=0.5.
pub fn similarity_badge(score: Float) -> Element(Nil) {
  let percentage_text = similarity.format_as_percentage(score)
  let color_class = case score >=. 0.8 {
    True -> "similarity-badge similarity-high"
    False ->
      case score >=. 0.5 {
        True -> "similarity-badge similarity-medium"
        False -> "similarity-badge similarity-low"
      }
  }

  html.span([attribute.class(color_class)], [html.text(percentage_text)])
}

/// Render an adoption timeline entry showing date, jurisdiction, and score.
pub fn adoption_timeline_item(event: AdoptionEvent) -> Element(Nil) {
  let jurisdiction_label = government_level.jurisdiction_label(event.level)

  html.li([attribute.class("adoption-timeline-item")], [
    html.span([attribute.class("adoption-timeline-date")], [
      html.text(event.introduced_date),
    ]),
    html.a([attribute.href("/legislation/" <> event.legislation_id)], [
      html.text(event.title),
    ]),
    html.span([attribute.class("adoption-timeline-jurisdiction")], [
      html.text(jurisdiction_label),
    ]),
    similarity_badge(event.similarity_score),
  ])
}

/// Render a styled diff line based on hunk type.
pub fn diff_line(hunk: DiffHunk) -> Element(Nil) {
  case hunk {
    Same(text) ->
      html.div([attribute.class("diff-line diff-same")], [
        html.span([attribute.class("diff-prefix")], [html.text("  ")]),
        html.text(text),
      ])
    Added(text) ->
      html.div([attribute.class("diff-line diff-added")], [
        html.span([attribute.class("diff-prefix")], [html.text("+ ")]),
        html.text(text),
      ])
    Removed(text) ->
      html.div([attribute.class("diff-line diff-removed")], [
        html.span([attribute.class("diff-prefix")], [html.text("- ")]),
        html.text(text),
      ])
  }
}
