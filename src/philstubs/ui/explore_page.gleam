import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/ui/layout

/// Render the explore page, optionally pre-loading a specific node via ?id=...
/// or a saved exploration via ?state=...
pub fn explore_page(
  initial_node_id: Option(String),
  initial_exploration_id: Option(String),
) -> Element(Nil) {
  layout.page_layout_with_meta("Explore — PHILSTUBS", head_scripts(), [
    html.div([attribute.class("explore-page")], [
      controls_sidebar(),
      graph_container(),
      detail_panel(),
    ]),
    initialization_script(initial_node_id, initial_exploration_id),
  ])
}

fn head_scripts() -> List(Element(Nil)) {
  [
    element.element(
      "script",
      [
        attribute.attribute(
          "src",
          "https://cdn.jsdelivr.net/npm/d3@7/dist/d3.min.js",
        ),
      ],
      [],
    ),
    element.element(
      "script",
      [
        attribute.attribute("src", "/static/js/explore.js"),
        attribute.attribute("defer", ""),
      ],
      [],
    ),
  ]
}

fn controls_sidebar() -> Element(Nil) {
  html.aside([attribute.class("explore-controls")], [
    // Search
    html.h2([], [html.text("Search")]),
    html.div([attribute.class("explore-search-group")], [
      html.input([
        attribute.id("explore-search-input"),
        attribute.class("explore-search-input"),
        attribute.type_("text"),
        attribute.placeholder("Search legislation..."),
      ]),
      html.button(
        [
          attribute.id("explore-search-button"),
          attribute.class("explore-action-button"),
        ],
        [html.text("Go")],
      ),
    ]),
    // Edge type filters
    html.h2([], [html.text("Edge Types")]),
    html.ul([attribute.class("explore-filter-list")], edge_type_filters()),
    // Depth selector
    html.h2([], [html.text("Expansion Depth")]),
    html.select(
      [
        attribute.id("explore-depth-select"),
        attribute.class("explore-depth-select"),
      ],
      [
        html.option(
          [attribute.value("1"), attribute.attribute("selected", "")],
          "1",
        ),
        html.option([attribute.value("2")], "2"),
        html.option([attribute.value("3")], "3"),
      ],
    ),
    // Path finder
    html.h2([], [html.text("Find Path")]),
    html.div([attribute.class("explore-path-group")], [
      html.input([
        attribute.id("explore-path-from"),
        attribute.class("explore-path-input"),
        attribute.type_("text"),
        attribute.placeholder("From ID..."),
      ]),
      html.input([
        attribute.id("explore-path-to"),
        attribute.class("explore-path-input"),
        attribute.type_("text"),
        attribute.placeholder("To ID..."),
      ]),
      html.button(
        [
          attribute.id("explore-path-button"),
          attribute.class("explore-action-button"),
        ],
        [html.text("Find Path")],
      ),
    ]),
    // Cluster loader
    html.h2([], [html.text("Topic Cluster")]),
    html.div([attribute.class("explore-cluster-group")], [
      html.input([
        attribute.id("explore-cluster-input"),
        attribute.class("explore-cluster-input-field"),
        attribute.type_("text"),
        attribute.placeholder("Topic slug..."),
      ]),
      html.button(
        [
          attribute.id("explore-cluster-button"),
          attribute.class("explore-action-button"),
        ],
        [html.text("Load Cluster")],
      ),
    ]),
    // Explorations (save/load)
    html.h2([], [html.text("Explorations")]),
    html.div([attribute.class("explore-save-group")], [
      html.button(
        [
          attribute.id("explore-save-button"),
          attribute.class("explore-action-button"),
        ],
        [html.text("Save")],
      ),
      html.button(
        [
          attribute.id("explore-load-button"),
          attribute.class("explore-action-button explore-action-secondary"),
        ],
        [html.text("Load")],
      ),
    ]),
    // Save dialog (hidden by default)
    html.div(
      [
        attribute.id("explore-save-dialog"),
        attribute.class("explore-save-dialog"),
      ],
      [
        html.input([
          attribute.id("explore-save-title"),
          attribute.class("explore-save-input"),
          attribute.type_("text"),
          attribute.placeholder("Title..."),
        ]),
        html.input([
          attribute.id("explore-save-description"),
          attribute.class("explore-save-input"),
          attribute.type_("text"),
          attribute.placeholder("Description (optional)..."),
        ]),
        html.label([attribute.class("explore-save-checkbox-label")], [
          html.input([
            attribute.id("explore-save-public"),
            attribute.type_("checkbox"),
          ]),
          html.text(" Public"),
        ]),
        html.div([attribute.class("explore-save-actions")], [
          html.button(
            [
              attribute.id("explore-save-confirm"),
              attribute.class("explore-action-button"),
            ],
            [html.text("Confirm")],
          ),
          html.button(
            [
              attribute.id("explore-save-cancel"),
              attribute.class("explore-action-button explore-action-secondary"),
            ],
            [html.text("Cancel")],
          ),
        ]),
      ],
    ),
    // Explorations list panel (hidden by default)
    html.div(
      [
        attribute.id("explore-list-panel"),
        attribute.class("explore-list-panel"),
      ],
      [],
    ),
    // Zoom controls
    html.div([attribute.class("explore-zoom-controls")], [
      html.button(
        [
          attribute.id("explore-zoom-in"),
          attribute.class("explore-zoom-button"),
        ],
        [html.text("+")],
      ),
      html.button(
        [
          attribute.id("explore-zoom-out"),
          attribute.class("explore-zoom-button"),
        ],
        [html.text("\u{2013}")],
      ),
      html.button(
        [
          attribute.id("explore-zoom-reset"),
          attribute.class("explore-zoom-button"),
        ],
        [html.text("Reset")],
      ),
    ]),
    // Legend
    color_legend(),
  ])
}

fn edge_type_filters() -> List(Element(Nil)) {
  let edge_types = [
    #("references", "References", "#333"),
    #("amends", "Amends", "#e65100"),
    #("supersedes", "Supersedes", "#c62828"),
    #("implements", "Implements", "#1565c0"),
    #("delegates", "Delegates", "#6a1b9a"),
    #("similar_to", "Similar To", "#999"),
  ]

  list.map(edge_types, fn(entry) {
    let #(edge_type_id, label, color) = entry
    html.li([attribute.class("explore-filter-item")], [
      html.input([
        attribute.id("explore-edge-filter-" <> edge_type_id),
        attribute.type_("checkbox"),
        attribute.attribute("checked", ""),
      ]),
      html.span(
        [
          attribute.class("explore-edge-indicator"),
          attribute.attribute("style", "background:" <> color),
        ],
        [],
      ),
      html.label([attribute.for("explore-edge-filter-" <> edge_type_id)], [
        html.text(label),
      ]),
    ])
  })
}

fn color_legend() -> Element(Nil) {
  let levels = [
    #("Federal", "#1565c0"),
    #("State", "#2e7d32"),
    #("County", "#e65100"),
    #("Municipal", "#6a1b9a"),
  ]

  html.div([attribute.class("explore-legend")], [
    html.h2([], [html.text("Legend")]),
    html.div(
      [],
      list.map(levels, fn(entry) {
        let #(label, color) = entry
        html.div([attribute.class("explore-legend-item")], [
          html.span(
            [
              attribute.class("explore-legend-dot"),
              attribute.attribute("style", "background:" <> color),
            ],
            [],
          ),
          html.text(label),
        ])
      }),
    ),
  ])
}

fn graph_container() -> Element(Nil) {
  html.div(
    [
      attribute.id("explore-graph"),
      attribute.class("explore-graph-container"),
    ],
    [],
  )
}

fn detail_panel() -> Element(Nil) {
  html.div(
    [
      attribute.id("explore-detail-panel"),
      attribute.class("explore-detail-panel"),
    ],
    [],
  )
}

fn initialization_script(
  initial_node_id: Option(String),
  initial_exploration_id: Option(String),
) -> Element(Nil) {
  let init_call = case initial_node_id, initial_exploration_id {
    Some(node_id), _ -> {
      let sanitized_id = sanitize_js_string(node_id)
      "PhilstubsExplorer.init({ initialNodeId: '" <> sanitized_id <> "' });"
    }
    None, Some(exploration_id) -> {
      let sanitized_id = sanitize_js_string(exploration_id)
      "PhilstubsExplorer.init({ initialExplorationId: '"
      <> sanitized_id
      <> "' });"
    }
    None, None -> "PhilstubsExplorer.init({});"
  }
  element.element("script", [], [html.text(init_call)])
}

/// Sanitize a string for safe embedding in a JavaScript single-quoted string.
/// Removes any characters that are not alphanumeric, hyphens, underscores, or dots.
fn sanitize_js_string(value: String) -> String {
  value
  |> string.to_graphemes
  |> list.filter(fn(character) {
    case character {
      "a"
      | "b"
      | "c"
      | "d"
      | "e"
      | "f"
      | "g"
      | "h"
      | "i"
      | "j"
      | "k"
      | "l"
      | "m"
      | "n"
      | "o"
      | "p"
      | "q"
      | "r"
      | "s"
      | "t"
      | "u"
      | "v"
      | "w"
      | "x"
      | "y"
      | "z"
      | "A"
      | "B"
      | "C"
      | "D"
      | "E"
      | "F"
      | "G"
      | "H"
      | "I"
      | "J"
      | "K"
      | "L"
      | "M"
      | "N"
      | "O"
      | "P"
      | "Q"
      | "R"
      | "S"
      | "T"
      | "U"
      | "V"
      | "W"
      | "X"
      | "Y"
      | "Z"
      | "0"
      | "1"
      | "2"
      | "3"
      | "4"
      | "5"
      | "6"
      | "7"
      | "8"
      | "9"
      | "-"
      | "_"
      | "." -> True
      _ -> False
    }
  })
  |> string.join("")
}
