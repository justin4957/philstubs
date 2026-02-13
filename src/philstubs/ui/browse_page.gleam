import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/ui/layout

/// Root browse page showing all government levels as cards with counts.
pub fn browse_root_page(level_counts: List(#(String, Int))) -> Element(Nil) {
  layout.page_layout("Browse Legislation — PHILSTUBS", [
    html.div([attribute.class("browse-container")], [
      html.h1([], [html.text("Browse by Government Level")]),
      html.p([attribute.class("browse-intro")], [
        html.text(
          "Explore legislation organized by the US government hierarchy.",
        ),
      ]),
      html.div([attribute.class("browse-levels")], level_cards(level_counts)),
      html.div([attribute.class("browse-alternate")], [
        html.h2([], [html.text("Other Ways to Browse")]),
        html.div([attribute.class("browse-alternate-links")], [
          html.a(
            [
              attribute.href("/browse/topics"),
              attribute.class("browse-link-card"),
            ],
            [
              html.h3([], [html.text("Browse by Topic")]),
              html.p([], [
                html.text(
                  "Explore legislation organized by policy area across all levels",
                ),
              ]),
            ],
          ),
        ]),
      ]),
    ]),
  ])
}

/// States listing page with legislation counts per state.
pub fn browse_states_page(state_counts: List(#(String, Int))) -> Element(Nil) {
  layout.page_layout("Browse States — PHILSTUBS", [
    html.div([attribute.class("browse-container")], [
      breadcrumb_nav([#("Browse", "/browse"), #("States", "/browse/states")]),
      html.h1([], [html.text("State Legislation")]),
      html.p([attribute.class("browse-intro")], [
        html.text(
          "Browse legislation by state. Counts include state, county, and municipal levels.",
        ),
      ]),
      case state_counts {
        [] ->
          html.p([attribute.class("browse-empty")], [
            html.text("No state legislation available yet."),
          ])
        counts ->
          html.div(
            [attribute.class("browse-list")],
            list.map(counts, fn(item) {
              let #(state_code, count) = item
              jurisdiction_list_item(
                state_code,
                count,
                "/browse/state/" <> state_code,
              )
            }),
          )
      },
    ]),
  ])
}

/// State detail page showing state-level legislation link and county/municipality drill-down.
pub fn browse_state_page(
  state_code: String,
  state_legislation_count: Int,
  county_counts: List(#(String, Int)),
  municipality_counts: List(#(String, Int)),
) -> Element(Nil) {
  layout.page_layout(state_code <> " Legislation — PHILSTUBS", [
    html.div([attribute.class("browse-container")], [
      breadcrumb_nav([
        #("Browse", "/browse"),
        #("States", "/browse/states"),
        #(state_code, "/browse/state/" <> state_code),
      ]),
      html.h1([], [html.text(state_code <> " Legislation")]),
      // State-level legislation link
      html.div([attribute.class("browse-section")], [
        html.h2([], [html.text("State Legislature")]),
        html.a(
          [
            attribute.href("/search?level=state&state=" <> state_code),
            attribute.class("browse-link-large"),
          ],
          [
            html.text(
              "View all "
              <> state_code
              <> " state legislation ("
              <> int.to_string(state_legislation_count)
              <> ")",
            ),
          ],
        ),
      ]),
      // Counties section
      html.div([attribute.class("browse-section")], [
        html.h2([], [html.text("Counties")]),
        case county_counts {
          [] ->
            html.p([attribute.class("browse-empty")], [
              html.text("No county legislation available for " <> state_code),
            ])
          counts ->
            html.div(
              [attribute.class("browse-list")],
              list.map(counts, fn(item) {
                let #(county_name, count) = item
                jurisdiction_list_item(
                  county_name,
                  count,
                  "/search?level=county&state=" <> state_code,
                )
              }),
            )
        },
      ]),
      // Municipalities section
      html.div([attribute.class("browse-section")], [
        html.h2([], [html.text("Cities & Municipalities")]),
        case municipality_counts {
          [] ->
            html.p([attribute.class("browse-empty")], [
              html.text("No municipal legislation available for " <> state_code),
            ])
          counts ->
            html.div(
              [attribute.class("browse-list")],
              list.map(counts, fn(item) {
                let #(municipality_name, count) = item
                jurisdiction_list_item(
                  municipality_name,
                  count,
                  "/search?level=municipal&state=" <> state_code,
                )
              }),
            )
        },
      ]),
    ]),
  ])
}

/// Topics page showing all topics with legislation counts.
pub fn browse_topics_page(topic_counts: List(#(String, Int))) -> Element(Nil) {
  layout.page_layout("Browse by Topic — PHILSTUBS", [
    html.div([attribute.class("browse-container")], [
      breadcrumb_nav([#("Browse", "/browse"), #("Topics", "/browse/topics")]),
      html.h1([], [html.text("Browse by Topic")]),
      html.p([attribute.class("browse-intro")], [
        html.text(
          "Explore legislation organized by policy area across all government levels.",
        ),
      ]),
      case topic_counts {
        [] ->
          html.p([attribute.class("browse-empty")], [
            html.text("No topics available yet."),
          ])
        counts ->
          html.div(
            [attribute.class("browse-list")],
            list.map(counts, fn(item) {
              let #(topic, count) = item
              jurisdiction_list_item(topic, count, "/search?q=" <> topic)
            }),
          )
      },
    ]),
  ])
}

// --- Shared components ---

/// Breadcrumb navigation bar with aria label for accessibility.
/// Takes a list of (label, url) tuples representing the breadcrumb trail.
pub fn breadcrumb_nav(crumbs: List(#(String, String))) -> Element(Nil) {
  html.nav(
    [
      attribute.class("breadcrumbs"),
      attribute.attribute("aria-label", "Breadcrumb"),
    ],
    [
      html.ol(
        [attribute.class("breadcrumb-list")],
        list.map(crumbs, fn(crumb) {
          let #(label, url) = crumb
          html.li([attribute.class("breadcrumb-item")], [
            html.a([attribute.href(url)], [html.text(label)]),
          ])
        }),
      ),
    ],
  )
}

/// Reusable list item showing a jurisdiction name with a count badge.
fn jurisdiction_list_item(name: String, count: Int, url: String) -> Element(Nil) {
  html.a([attribute.href(url), attribute.class("browse-list-item")], [
    html.span([attribute.class("browse-item-name")], [html.text(name)]),
    html.span([attribute.class("browse-item-count")], [
      html.text(int.to_string(count)),
    ]),
  ])
}

// --- Level cards for root page ---

fn level_cards(level_counts: List(#(String, Int))) -> List(Element(Nil)) {
  [
    level_card(
      "Federal",
      "Congressional bills, resolutions, and federal regulations",
      get_count(level_counts, "federal"),
      "/search?level=federal",
    ),
    level_card(
      "State",
      "State legislature bills and resolutions",
      get_count(level_counts, "state"),
      "/browse/states",
    ),
    level_card(
      "County",
      "County ordinances and resolutions",
      get_count(level_counts, "county"),
      "/search?level=county",
    ),
    level_card(
      "Municipal",
      "City and town ordinances and bylaws",
      get_count(level_counts, "municipal"),
      "/search?level=municipal",
    ),
  ]
}

fn level_card(
  title: String,
  description: String,
  count: Int,
  url: String,
) -> Element(Nil) {
  html.a([attribute.href(url), attribute.class("browse-level-card")], [
    html.div([attribute.class("browse-level-header")], [
      html.h2([], [html.text(title)]),
      html.span([attribute.class("browse-level-count")], [
        html.text(int.to_string(count)),
      ]),
    ]),
    html.p([attribute.class("browse-level-description")], [
      html.text(description),
    ]),
  ])
}

fn get_count(level_counts: List(#(String, Int)), level: String) -> Int {
  case list.key_find(level_counts, level) {
    Ok(count) -> count
    Error(_) -> 0
  }
}
