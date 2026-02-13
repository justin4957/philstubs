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
import philstubs/ui/layout

/// Render the full legislation detail page with header, metadata sidebar,
/// full body text, and related legislation section.
pub fn legislation_detail_page(
  record: Legislation,
  related_legislation: List(Legislation),
) -> Element(Nil) {
  let legislation_id = legislation.legislation_id_to_string(record.id)

  layout.page_layout_with_meta(
    record.title <> " — PHILSTUBS",
    open_graph_meta(record),
    [
      html.div([attribute.class("legislation-detail")], [
        legislation_header(record),
        html.div([attribute.class("legislation-content-layout")], [
          body_section(record),
          metadata_sidebar(record, legislation_id, related_legislation),
        ]),
      ]),
    ],
  )
}

fn open_graph_meta(record: Legislation) -> List(Element(Nil)) {
  let description = case record.summary {
    "" -> string.slice(record.body, 0, 200)
    summary_text -> string.slice(summary_text, 0, 200)
  }

  [
    html.meta([
      attribute.attribute("property", "og:title"),
      attribute.attribute("content", record.title),
    ]),
    html.meta([
      attribute.attribute("property", "og:description"),
      attribute.attribute("content", description),
    ]),
    html.meta([
      attribute.attribute("property", "og:type"),
      attribute.attribute("content", "article"),
    ]),
  ]
}

fn legislation_header(record: Legislation) -> Element(Nil) {
  html.div([attribute.class("legislation-header")], [
    html.div([attribute.class("legislation-header-top")], [
      html.h1([], [html.text(record.title)]),
      case record.source_identifier {
        "" -> element.none()
        identifier ->
          html.span([attribute.class("legislation-identifier")], [
            html.text(identifier),
          ])
      },
    ]),
    html.div([attribute.class("legislation-badges")], [
      badge("level-badge", government_level.jurisdiction_label(record.level)),
      badge("type-badge", legislation_type.to_string(record.legislation_type)),
      status_badge(record.status),
      case record.introduced_date {
        "" -> element.none()
        date_value ->
          html.span([attribute.class("legislation-date")], [
            html.text("Introduced " <> date_value),
          ])
      },
    ]),
  ])
}

fn status_badge(status: legislation_status.LegislationStatus) -> Element(Nil) {
  let status_class = case status {
    legislation_status.Enacted -> "status-badge status-enacted"
    legislation_status.Vetoed -> "status-badge status-vetoed"
    legislation_status.Withdrawn -> "status-badge status-withdrawn"
    legislation_status.Expired -> "status-badge status-expired"
    _ -> "status-badge"
  }

  html.span([attribute.class(status_class)], [
    html.text(legislation_status.to_string(status)),
  ])
}

fn body_section(record: Legislation) -> Element(Nil) {
  html.div([attribute.class("legislation-body-section")], [
    case record.summary {
      "" -> element.none()
      summary_text ->
        html.div([attribute.class("legislation-summary-section")], [
          html.h2([], [html.text("Summary")]),
          html.p([attribute.class("legislation-summary")], [
            html.text(summary_text),
          ]),
        ])
    },
    html.h2([], [html.text("Full Text")]),
    html.pre([attribute.class("legislation-body")], [
      html.text(record.body),
    ]),
  ])
}

fn metadata_sidebar(
  record: Legislation,
  legislation_id: String,
  related_legislation: List(Legislation),
) -> Element(Nil) {
  html.aside([attribute.class("legislation-sidebar")], [
    html.h3([], [html.text("Details")]),
    metadata_item(
      "Jurisdiction",
      government_level.jurisdiction_label(record.level),
    ),
    metadata_item("Type", legislation_type.to_string(record.legislation_type)),
    metadata_item("Status", legislation_status.to_string(record.status)),
    case record.introduced_date {
      "" -> element.none()
      date_value -> metadata_item("Introduced", date_value)
    },
    case record.source_identifier {
      "" -> element.none()
      identifier -> metadata_item("Identifier", identifier)
    },
    sponsors_section(record.sponsors),
    topics_section(record.topics),
    source_link_section(record.source_url),
    actions_section(legislation_id, record.topics),
    related_section(related_legislation),
  ])
}

fn metadata_item(label_text: String, value_text: String) -> Element(Nil) {
  html.div([attribute.class("metadata-item")], [
    html.span([attribute.class("metadata-label")], [html.text(label_text)]),
    html.span([attribute.class("metadata-value")], [html.text(value_text)]),
  ])
}

fn sponsors_section(sponsors: List(String)) -> Element(Nil) {
  case sponsors {
    [] -> element.none()
    sponsor_list ->
      html.div([attribute.class("metadata-item")], [
        html.span([attribute.class("metadata-label")], [html.text("Sponsors")]),
        html.ul(
          [attribute.class("sponsors-list")],
          list.map(sponsor_list, fn(sponsor_name) {
            html.li([], [html.text(sponsor_name)])
          }),
        ),
      ])
  }
}

fn topics_section(topics: List(String)) -> Element(Nil) {
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

fn source_link_section(source_url: option.Option(String)) -> Element(Nil) {
  case source_url {
    None -> element.none()
    Some(url) ->
      html.div([attribute.class("metadata-item")], [
        html.span([attribute.class("metadata-label")], [html.text("Source")]),
        html.a(
          [
            attribute.href(url),
            attribute.target("_blank"),
            attribute.rel("noopener"),
            attribute.class("source-link"),
          ],
          [html.text("View original")],
        ),
      ])
  }
}

fn actions_section(legislation_id: String, topics: List(String)) -> Element(Nil) {
  html.div([attribute.class("legislation-actions")], [
    html.a(
      [
        attribute.href(
          "/legislation/" <> legislation_id <> "/download?format=text",
        ),
        attribute.class("download-button"),
      ],
      [html.text("Download as Text")],
    ),
    html.a(
      [
        attribute.href(
          "/legislation/" <> legislation_id <> "/download?format=markdown",
        ),
        attribute.class("download-button secondary"),
      ],
      [html.text("Download as Markdown")],
    ),
    case topics {
      [] -> element.none()
      topic_list -> {
        let search_query = string.join(topic_list, " ")
        html.a(
          [
            attribute.href("/search?q=" <> search_query),
            attribute.class("find-similar-link"),
          ],
          [html.text("Find similar legislation")],
        )
      }
    },
  ])
}

fn related_section(related_legislation: List(Legislation)) -> Element(Nil) {
  case related_legislation {
    [] -> element.none()
    related_list ->
      html.div([attribute.class("related-section")], [
        html.h3([], [html.text("Related Legislation")]),
        html.ul(
          [attribute.class("related-list")],
          list.map(related_list, fn(related_record) {
            let related_id =
              legislation.legislation_id_to_string(related_record.id)
            html.li([], [
              html.a([attribute.href("/legislation/" <> related_id)], [
                html.text(related_record.title),
              ]),
              html.span([attribute.class("related-meta")], [
                html.text(
                  " — "
                  <> government_level.jurisdiction_label(related_record.level)
                  <> ", "
                  <> legislation_type.to_string(related_record.legislation_type),
                ),
              ]),
            ])
          }),
        ),
      ])
  }
}

fn badge(class_name: String, badge_text: String) -> Element(Nil) {
  html.span([attribute.class("badge " <> class_name)], [
    html.text(badge_text),
  ])
}
