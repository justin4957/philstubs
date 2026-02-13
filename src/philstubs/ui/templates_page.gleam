import gleam/int
import gleam/list
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/core/government_level
import philstubs/core/legislation_template.{type LegislationTemplate}
import philstubs/core/legislation_type
import philstubs/ui/layout

/// Sort options for the template listing page.
pub type TemplateSortOrder {
  Newest
  MostDownloaded
  Alphabetical
}

/// Parse a sort order from a query parameter string.
pub fn sort_order_from_string(value: String) -> TemplateSortOrder {
  case value {
    "downloads" -> MostDownloaded
    "title" -> Alphabetical
    _ -> Newest
  }
}

/// Render the template listing page with sort controls and upload action.
pub fn templates_page(
  templates: List(LegislationTemplate),
  current_sort: TemplateSortOrder,
) -> Element(Nil) {
  layout.page_layout("Templates — PHILSTUBS", [
    html.div([attribute.class("templates-container")], [
      html.div([attribute.class("templates-header")], [
        html.h1([], [html.text("Legislation Templates")]),
        html.p([], [
          html.text(
            "Browse and download model legislation templates. Upload your own to share with others.",
          ),
        ]),
        html.a(
          [
            attribute.href("/templates/new"),
            attribute.class("upload-button"),
          ],
          [html.text("Upload Template")],
        ),
      ]),
      sort_controls(current_sort),
      templates_list(templates),
    ]),
  ])
}

fn sort_controls(current_sort: TemplateSortOrder) -> Element(Nil) {
  html.nav([attribute.class("sort-controls")], [
    html.span([attribute.class("sort-label")], [html.text("Sort by: ")]),
    sort_link("newest", "Newest", current_sort == Newest),
    sort_link("downloads", "Most Downloaded", current_sort == MostDownloaded),
    sort_link("title", "Title", current_sort == Alphabetical),
  ])
}

fn sort_link(
  sort_value: String,
  link_text: String,
  is_active: Bool,
) -> Element(Nil) {
  let class_name = case is_active {
    True -> "sort-link active"
    False -> "sort-link"
  }
  html.a(
    [
      attribute.href("/templates?sort=" <> sort_value),
      attribute.class(class_name),
    ],
    [html.text(link_text)],
  )
}

fn templates_list(templates: List(LegislationTemplate)) -> Element(Nil) {
  case templates {
    [] ->
      html.div([attribute.class("empty-state")], [
        html.p([], [
          html.text("No templates yet. Be the first to upload one!"),
        ]),
      ])
    template_list ->
      html.div(
        [attribute.class("templates-list")],
        list.map(template_list, render_template_card),
      )
  }
}

fn render_template_card(template: LegislationTemplate) -> Element(Nil) {
  let template_id = legislation_template.template_id_to_string(template.id)

  html.article([attribute.class("template-card")], [
    html.h3([attribute.class("template-card-title")], [
      html.a([attribute.href("/templates/" <> template_id)], [
        html.text(template.title),
      ]),
    ]),
    html.div([attribute.class("template-card-meta")], [
      html.span([attribute.class("badge level-badge")], [
        html.text(government_level.jurisdiction_label(template.suggested_level)),
      ]),
      html.span([attribute.class("badge type-badge")], [
        html.text(legislation_type.to_string(template.suggested_type)),
      ]),
      html.span([attribute.class("template-downloads")], [
        html.text(int.to_string(template.download_count) <> " downloads"),
      ]),
    ]),
    html.p([attribute.class("template-card-description")], [
      html.text(truncate_description(template.description, 200)),
    ]),
    html.div([attribute.class("template-card-footer")], [
      html.span([attribute.class("template-author-label")], [
        html.text("By " <> template.author),
      ]),
      topics_inline(template.topics),
    ]),
  ])
}

fn truncate_description(description: String, max_length: Int) -> String {
  case string.length(description) > max_length {
    True -> string.slice(description, 0, max_length) <> "..."
    False -> description
  }
}

fn topics_inline(topics: List(String)) -> Element(Nil) {
  case topics {
    [] -> element.none()
    topic_list ->
      html.span([attribute.class("template-topics-inline")], [
        html.text(string.join(topic_list, ", ")),
      ])
  }
}

/// Sort templates by the given sort order.
pub fn sort_templates(
  templates: List(LegislationTemplate),
  sort_order: TemplateSortOrder,
) -> List(LegislationTemplate) {
  case sort_order {
    Newest ->
      list.sort(templates, fn(template_a, template_b) {
        string.compare(template_b.created_at, template_a.created_at)
      })
    MostDownloaded ->
      list.sort(templates, fn(template_a, template_b) {
        int.compare(template_b.download_count, template_a.download_count)
      })
    Alphabetical ->
      list.sort(templates, fn(template_a, template_b) {
        string.compare(template_a.title, template_b.title)
      })
  }
}
