import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/core/government_level
import philstubs/core/impact_types.{type ImpactNode}
import philstubs/core/legislation.{type Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/core/reference
import philstubs/core/similarity_types.{
  type AdoptionEvent, type SimilarLegislation,
}
import philstubs/ui/components
import philstubs/ui/layout

/// Render the full legislation detail page with header, metadata sidebar,
/// full body text, and related legislation section.
pub fn legislation_detail_page(
  record: Legislation,
  related_legislation: List(Legislation),
  similar_legislation: List(SimilarLegislation),
  adoption_timeline: List(AdoptionEvent),
  impact_nodes: List(ImpactNode),
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
          metadata_sidebar(
            record,
            legislation_id,
            related_legislation,
            similar_legislation,
            adoption_timeline,
            impact_nodes,
          ),
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
      components.badge(
        "level-badge",
        government_level.jurisdiction_label(record.level),
      ),
      components.badge(
        "type-badge",
        legislation_type.to_string(record.legislation_type),
      ),
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
  similar_legislation: List(SimilarLegislation),
  adoption_timeline: List(AdoptionEvent),
  impact_nodes: List(ImpactNode),
) -> Element(Nil) {
  html.aside([attribute.class("legislation-sidebar")], [
    html.h3([], [html.text("Details")]),
    components.metadata_item(
      "Jurisdiction",
      government_level.jurisdiction_label(record.level),
    ),
    components.metadata_item(
      "Type",
      legislation_type.to_string(record.legislation_type),
    ),
    components.metadata_item(
      "Status",
      legislation_status.to_string(record.status),
    ),
    case record.introduced_date {
      "" -> element.none()
      date_value -> components.metadata_item("Introduced", date_value)
    },
    case record.source_identifier {
      "" -> element.none()
      identifier -> components.metadata_item("Identifier", identifier)
    },
    sponsors_section(record.sponsors),
    components.topics_section(record.topics),
    source_link_section(record.source_url),
    actions_section(legislation_id, record.topics),
    similar_section(legislation_id, similar_legislation),
    adoption_timeline_section(adoption_timeline),
    impact_section(impact_nodes),
    related_section(related_legislation),
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

fn similar_section(
  legislation_id: String,
  similar_legislation: List(SimilarLegislation),
) -> Element(Nil) {
  case similar_legislation {
    [] -> element.none()
    similar_list ->
      html.div([attribute.class("similarity-section")], [
        html.h3([], [html.text("Similar Legislation")]),
        html.ul(
          [attribute.class("similar-list")],
          list.map(similar_list, fn(similar_record) {
            let similar_id =
              legislation.legislation_id_to_string(
                similar_record.legislation.id,
              )
            let jurisdiction_label =
              government_level.jurisdiction_label(
                similar_record.legislation.level,
              )
            html.li([], [
              components.similarity_badge(similar_record.similarity_score),
              html.a([attribute.href("/legislation/" <> similar_id)], [
                html.text(similar_record.legislation.title),
              ]),
              html.span([attribute.class("similar-jurisdiction")], [
                html.text(jurisdiction_label),
              ]),
              html.a(
                [
                  attribute.href(
                    "/legislation/" <> legislation_id <> "/diff/" <> similar_id,
                  ),
                  attribute.class("diff-link"),
                ],
                [html.text("diff")],
              ),
            ])
          }),
        ),
      ])
  }
}

fn adoption_timeline_section(
  adoption_timeline: List(AdoptionEvent),
) -> Element(Nil) {
  case adoption_timeline {
    [] -> element.none()
    timeline_events ->
      html.div([attribute.class("adoption-timeline")], [
        html.h3([], [html.text("Adoption Timeline")]),
        html.ul(
          [attribute.class("adoption-timeline-list")],
          list.map(timeline_events, components.adoption_timeline_item),
        ),
      ])
  }
}

fn impact_section(impact_nodes: List(ImpactNode)) -> Element(Nil) {
  case impact_nodes {
    [] -> element.none()
    nodes -> {
      let direct_count =
        list.count(nodes, fn(node) { node.impact_kind == impact_types.Direct })
      let transitive_count = list.length(nodes) - direct_count

      html.div([attribute.class("impact-section")], [
        html.h3([], [html.text("Impact Analysis")]),
        html.p([attribute.class("impact-summary-text")], [
          html.text(
            int.to_string(list.length(nodes))
            <> " affected — "
            <> int.to_string(direct_count)
            <> " direct, "
            <> int.to_string(transitive_count)
            <> " transitive",
          ),
        ]),
        html.ul(
          [attribute.class("impact-list")],
          list.map(nodes, fn(node) {
            let level_label = government_level.jurisdiction_label(node.level)
            let depth_label = "depth " <> int.to_string(node.depth)
            let reference_label =
              reference.reference_type_to_string(node.reference_type)
            html.li([], [
              components.badge("level-badge", level_label),
              html.a([attribute.href("/legislation/" <> node.legislation_id)], [
                html.text(node.title),
              ]),
              html.span([attribute.class("impact-meta")], [
                html.text(" — " <> depth_label <> ", " <> reference_label),
              ]),
            ])
          }),
        ),
      ])
    }
  }
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
