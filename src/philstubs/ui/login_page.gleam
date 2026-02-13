import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/ui/layout

/// Render the login page with an optional error message.
pub fn login_page(error_message: Option(String)) -> Element(Nil) {
  layout.page_layout("Sign In — PHILSTUBS", [
    html.div([attribute.class("login-page")], [
      html.h1([], [html.text("Sign In")]),
      html.p([], [
        html.text(
          "Sign in to upload and manage legislation templates. Browsing, searching, and downloading are available without an account.",
        ),
      ]),
      case error_message {
        Some(message) ->
          html.div([attribute.class("error-message")], [
            html.p([], [html.text(message)]),
          ])
        None -> html.text("")
      },
      html.div([attribute.class("login-actions")], [
        html.a([attribute.href("/login"), attribute.class("btn btn-primary")], [
          html.text("Sign in with GitHub"),
        ]),
      ]),
    ]),
  ])
}
