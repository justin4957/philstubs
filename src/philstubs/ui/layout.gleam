import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/core/user.{type User}

/// Wrap page content in a full HTML document layout with head metadata,
/// CSS link, and consistent page structure.
pub fn page_layout(
  page_title: String,
  page_content: List(Element(Nil)),
) -> Element(Nil) {
  page_layout_with_user(page_title, [], page_content, None)
}

/// Wrap page content with additional meta tags (e.g., Open Graph) in the head.
pub fn page_layout_with_meta(
  page_title: String,
  extra_head_elements: List(Element(Nil)),
  page_content: List(Element(Nil)),
) -> Element(Nil) {
  page_layout_with_user(page_title, extra_head_elements, page_content, None)
}

/// Wrap page content with auth-aware navigation showing login/logout.
pub fn page_layout_with_user(
  page_title: String,
  extra_head_elements: List(Element(Nil)),
  page_content: List(Element(Nil)),
  current_user: Option(User),
) -> Element(Nil) {
  let base_head = [
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
  ]

  let auth_nav_items = case current_user {
    Some(logged_in_user) -> [
      html.a([attribute.href("/profile")], [
        html.text(logged_in_user.username),
      ]),
      html.form([attribute.method("post"), attribute.action("/logout")], [
        html.button([attribute.type_("submit")], [html.text("Logout")]),
      ]),
    ]
    None -> [
      html.a([attribute.href("/login")], [html.text("Sign In")]),
    ]
  }

  html.html([], [
    html.head([], list.append(base_head, extra_head_elements)),
    html.body([], [
      html.header([], [
        html.nav([], [
          html.a([attribute.href("/")], [html.text("PHILSTUBS")]),
          html.a([attribute.href("/browse")], [html.text("Browse")]),
          html.a([attribute.href("/search")], [html.text("Search")]),
          html.a([attribute.href("/templates")], [html.text("Templates")]),
          html.span([attribute.class("auth-nav")], auth_nav_items),
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
