import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// Wrap page content in a full HTML document layout with head metadata,
/// CSS link, and consistent page structure.
pub fn page_layout(
  page_title: String,
  page_content: List(Element(Nil)),
) -> Element(Nil) {
  html.html([], [
    html.head([], [
      html.meta([attribute.attribute("charset", "utf-8")]),
      html.meta([
        attribute.name("viewport"),
        attribute.attribute("content", "width=device-width, initial-scale=1"),
      ]),
      html.title([], page_title),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/css/app.css"),
      ]),
    ]),
    html.body([], [
      html.header([], [
        html.nav([], [
          html.a([attribute.href("/")], [html.text("PHILSTUBS")]),
        ]),
      ]),
      html.main([], page_content),
      html.footer([], [
        html.p([], [
          html.text("PHILSTUBS — People Hardly Inspect Legislation"),
        ]),
      ]),
    ]),
  ])
}
