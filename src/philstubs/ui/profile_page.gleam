import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/core/legislation_template.{type LegislationTemplate}
import philstubs/core/user.{type User}
import philstubs/ui/layout

/// Render the user profile page showing user info and their templates.
pub fn profile_page(
  current_user: User,
  user_templates: List(LegislationTemplate),
) -> Element(Nil) {
  layout.page_layout("Profile — PHILSTUBS", [
    html.div([attribute.class("profile-page")], [
      html.div([attribute.class("profile-header")], [
        case current_user.avatar_url {
          "" -> html.text("")
          avatar_src ->
            html.img([
              attribute.src(avatar_src),
              attribute.alt(current_user.username),
              attribute.class("avatar"),
              attribute.width(64),
              attribute.height(64),
            ])
        },
        html.div([], [
          html.h1([], [html.text(current_user.display_name)]),
          html.p([attribute.class("username")], [
            html.text("@" <> current_user.username),
          ]),
        ]),
      ]),
      html.h2([], [
        html.text(
          "Your Templates ("
          <> int.to_string(list.length(user_templates))
          <> ")",
        ),
      ]),
      case user_templates {
        [] ->
          html.div([attribute.class("empty-state")], [
            html.p([], [html.text("You haven't uploaded any templates yet.")]),
            html.a(
              [
                attribute.href("/templates/new"),
                attribute.class("btn btn-primary"),
              ],
              [html.text("Upload a Template")],
            ),
          ])
        templates ->
          html.ul([attribute.class("template-list")], {
            list.map(templates, fn(template) {
              let template_id_str =
                legislation_template.template_id_to_string(template.id)
              html.li([], [
                html.a([attribute.href("/templates/" <> template_id_str)], [
                  html.text(template.title),
                ]),
                html.span([attribute.class("download-count")], [
                  html.text(
                    " — "
                    <> int.to_string(template.download_count)
                    <> " downloads",
                  ),
                ]),
              ])
            })
          })
      },
    ]),
  ])
}
