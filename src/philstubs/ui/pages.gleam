import lustre/element.{type Element}
import lustre/element/html
import philstubs/ui/layout

/// The landing page for PHILSTUBS, displayed at the root URL.
pub fn landing_page() -> Element(Nil) {
  layout.page_layout("PHILSTUBS", [
    html.h1([], [html.text("PHILSTUBS")]),
    html.p([], [
      html.text(
        "People Hardly Inspect Legislation — Searchable Templates Used Before anyone readS",
      ),
    ]),
    html.p([], [
      html.text(
        "An open platform for ingesting, browsing, and sharing legislation across all levels of US democracy.",
      ),
    ]),
    html.section([], [
      html.h2([], [html.text("Government Levels")]),
      html.ul([], [
        html.li([], [
          html.text(
            "Federal — Congressional bills, resolutions, federal regulations",
          ),
        ]),
        html.li([], [
          html.text(
            "State — State legislature bills, state constitutional amendments",
          ),
        ]),
        html.li([], [
          html.text("County — County ordinances, resolutions"),
        ]),
        html.li([], [
          html.text(
            "Municipal — City ordinances, local bylaws, town resolutions",
          ),
        ]),
      ]),
    ]),
  ])
}
