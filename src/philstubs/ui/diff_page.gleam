import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/core/government_level
import philstubs/core/legislation.{type Legislation}
import philstubs/core/similarity.{type DiffHunk}
import philstubs/ui/components
import philstubs/ui/layout

/// Render a full-page diff view comparing two pieces of legislation.
pub fn diff_page(
  source_record: Legislation,
  target_record: Legislation,
  diff_hunks: List(DiffHunk),
) -> Element(Nil) {
  let source_label = government_level.jurisdiction_label(source_record.level)
  let target_label = government_level.jurisdiction_label(target_record.level)

  layout.page_layout("Diff: " <> source_record.title <> " — PHILSTUBS", [
    html.div([attribute.class("diff-view")], [
      html.h1([], [html.text("Legislation Comparison")]),
      html.div([attribute.class("diff-header")], [
        html.div([attribute.class("diff-header-item")], [
          html.h2([], [html.text(source_record.title)]),
          html.span([attribute.class("diff-header-meta")], [
            html.text(source_label),
          ]),
        ]),
        html.div([attribute.class("diff-header-item")], [
          html.h2([], [html.text(target_record.title)]),
          html.span([attribute.class("diff-header-meta")], [
            html.text(target_label),
          ]),
        ]),
      ]),
      html.div(
        [attribute.class("diff-content")],
        list.map(diff_hunks, components.diff_line),
      ),
    ]),
  ])
}
