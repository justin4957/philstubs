import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/core/government_level
import philstubs/core/legislation
import philstubs/core/legislation_template.{type LegislationTemplate}
import philstubs/core/legislation_type
import philstubs/core/similarity_types.{type TemplateMatch}
import philstubs/ui/components
import philstubs/ui/layout

/// Render the template detail page showing full template content,
/// metadata sidebar, and download/copy actions.
pub fn template_detail_page(
  template: LegislationTemplate,
  template_matches: List(TemplateMatch),
) -> Element(Nil) {
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
        metadata_sidebar(template, template_id, template_matches),
      ]),
    ]),
  ])
}

fn metadata_sidebar(
  template: LegislationTemplate,
  template_id: String,
  template_matches: List(TemplateMatch),
) -> Element(Nil) {
  html.aside([attribute.class("template-sidebar")], [
    html.h3([], [html.text("Details")]),
    components.metadata_item(
      "Suggested Level",
      government_level.jurisdiction_label(template.suggested_level),
    ),
    components.metadata_item(
      "Legislation Type",
      legislation_type.to_string(template.suggested_type),
    ),
    components.metadata_item(
      "Downloads",
      int.to_string(template.download_count),
    ),
    components.metadata_item("Created", template.created_at),
    components.topics_section(template.topics),
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
    template_matches_section(template_matches),
  ])
}

fn template_matches_section(
  template_matches: List(TemplateMatch),
) -> Element(Nil) {
  case template_matches {
    [] -> element.none()
    match_list ->
      html.div([attribute.class("template-matches-section")], [
        html.h3([], [html.text("Adopted Legislation")]),
        html.ul(
          [attribute.class("template-matches-list")],
          list.map(match_list, fn(template_match) {
            let match_id =
              legislation.legislation_id_to_string(
                template_match.legislation.id,
              )
            let jurisdiction_label =
              government_level.jurisdiction_label(
                template_match.legislation.level,
              )
            html.li([], [
              components.similarity_badge(template_match.similarity_score),
              html.a([attribute.href("/legislation/" <> match_id)], [
                html.text(template_match.legislation.title),
              ]),
              html.span([attribute.class("similar-jurisdiction")], [
                html.text(jurisdiction_label),
              ]),
            ])
          }),
        ),
      ])
  }
}
