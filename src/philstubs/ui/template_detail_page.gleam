import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/core/government_level
import philstubs/core/legislation_template.{type LegislationTemplate}
import philstubs/core/legislation_type
import philstubs/ui/layout

/// Render the template detail page showing full template content,
/// metadata sidebar, and download/copy actions.
pub fn template_detail_page(template: LegislationTemplate) -> Element(Nil) {
  let template_id = legislation_template.template_id_to_string(template.id)

  layout.page_layout(template.title <> " — PHILSTUBS", [
    html.div([attribute.class("template-detail")], [
      html.div([attribute.class("template-header")], [
        html.h1([], [html.text(template.title)]),
        html.p([attribute.class("template-author")], [
          html.text("By " <> template.author),
        ]),
      ]),
      html.div([attribute.class("template-content-layout")], [
        html.div([attribute.class("template-body-section")], [
          html.h2([], [html.text("Description")]),
          html.p([attribute.class("template-description")], [
            html.text(template.description),
          ]),
          html.h2([], [html.text("Template Text")]),
          html.pre([attribute.class("template-body")], [
            html.text(template.body),
          ]),
        ]),
        metadata_sidebar(template, template_id),
      ]),
    ]),
  ])
}

fn metadata_sidebar(
  template: LegislationTemplate,
  template_id: String,
) -> Element(Nil) {
  html.aside([attribute.class("template-sidebar")], [
    html.h3([], [html.text("Details")]),
    metadata_item(
      "Suggested Level",
      government_level.jurisdiction_label(template.suggested_level),
    ),
    metadata_item(
      "Legislation Type",
      legislation_type.to_string(template.suggested_type),
    ),
    metadata_item("Downloads", int.to_string(template.download_count)),
    metadata_item("Created", template.created_at),
    topics_section(template.topics),
    html.div([attribute.class("template-actions")], [
      html.a(
        [
          attribute.href(
            "/templates/" <> template_id <> "/download?format=text",
          ),
          attribute.class("download-button"),
        ],
        [html.text("Download as Text")],
      ),
      html.a(
        [
          attribute.href(
            "/templates/" <> template_id <> "/download?format=markdown",
          ),
          attribute.class("download-button secondary"),
        ],
        [html.text("Download as Markdown")],
      ),
    ]),
  ])
}

fn metadata_item(label_text: String, value_text: String) -> Element(Nil) {
  html.div([attribute.class("metadata-item")], [
    html.span([attribute.class("metadata-label")], [html.text(label_text)]),
    html.span([attribute.class("metadata-value")], [html.text(value_text)]),
  ])
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
