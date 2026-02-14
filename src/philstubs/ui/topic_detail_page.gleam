import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/core/topic.{type Topic, type TopicCrossLevelSummary}
import philstubs/data/topic_repo.{type LegislationSummary}
import philstubs/ui/browse_page
import philstubs/ui/layout

/// Render the topic detail page with cross-level comparison.
pub fn topic_detail_page(
  summary: TopicCrossLevelSummary,
  child_topics: List(Topic),
  recent_legislation: List(LegislationSummary),
) -> Element(Nil) {
  let topic_name = summary.topic.name

  layout.page_layout(topic_name <> " — PHILSTUBS", [
    html.div([attribute.class("browse-container")], [
      browse_page.breadcrumb_nav([
        #("Browse", "/browse"),
        #("Topics", "/browse/topics"),
        #(topic_name, "/browse/topics/" <> summary.topic.slug),
      ]),
      html.h1([], [html.text(topic_name)]),
      html.p([attribute.class("browse-intro")], [
        html.text(summary.topic.description),
      ]),
      // Cross-level stat cards
      html.div([attribute.class("topic-cross-level")], [
        topic_level_stat("Federal", summary.federal_count),
        topic_level_stat("State", summary.state_count),
        topic_level_stat("County", summary.county_count),
        topic_level_stat("Municipal", summary.municipal_count),
      ]),
      // State breakdown
      case summary.state_breakdown {
        [] -> element.none()
        state_counts ->
          html.div([attribute.class("browse-section")], [
            html.h2([], [html.text("By State")]),
            html.div([attribute.class("topic-state-breakdown")], [
              html.div(
                [attribute.class("browse-list")],
                list.map(state_counts, fn(item) {
                  let #(state_code, count) = item
                  html.div([attribute.class("browse-list-item")], [
                    html.span([attribute.class("browse-item-name")], [
                      html.text(state_code),
                    ]),
                    html.span([attribute.class("browse-item-count")], [
                      html.text(int.to_string(count)),
                    ]),
                  ])
                }),
              ),
            ]),
          ])
      },
      // Child topics section
      case child_topics {
        [] -> element.none()
        children ->
          html.div([attribute.class("browse-section")], [
            html.h2([], [html.text("Subtopics")]),
            html.div(
              [attribute.class("browse-list")],
              list.map(children, fn(child) {
                html.a(
                  [
                    attribute.href("/browse/topics/" <> child.slug),
                    attribute.class("browse-list-item"),
                  ],
                  [
                    html.span([attribute.class("browse-item-name")], [
                      html.text(child.name),
                    ]),
                  ],
                )
              }),
            ),
          ])
      },
      // Recent legislation
      case recent_legislation {
        [] -> element.none()
        legislation_list ->
          html.div([attribute.class("browse-section")], [
            html.h2([], [html.text("Recent Legislation")]),
            html.div(
              [attribute.class("browse-list")],
              list.map(legislation_list, fn(item) {
                html.a(
                  [
                    attribute.href("/legislation/" <> item.id),
                    attribute.class("browse-list-item"),
                  ],
                  [
                    html.span([attribute.class("browse-item-name")], [
                      html.text(item.title),
                    ]),
                    html.span([attribute.class("browse-item-count")], [
                      html.text(item.government_level),
                    ]),
                  ],
                )
              }),
            ),
          ])
      },
    ]),
  ])
}

fn topic_level_stat(level_label: String, count: Int) -> Element(Nil) {
  html.div([attribute.class("topic-level-stat")], [
    html.span([attribute.class("stat-value")], [
      html.text(int.to_string(count)),
    ]),
    html.span([attribute.class("stat-label")], [html.text(level_label)]),
  ])
}
