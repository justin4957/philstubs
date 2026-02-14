import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/core/government_level
import philstubs/core/legislation.{type Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/data/stats_repo.{type LegislationStats}
import philstubs/ui/components
import philstubs/ui/layout

/// The landing page for PHILSTUBS, displayed at the root URL.
/// Accepts live data: legislation stats, template count, counts per level,
/// and a list of recently added legislation records.
pub fn landing_page(
  stats: LegislationStats,
  template_count: Int,
  level_counts: List(#(String, Int)),
  recent_legislation: List(Legislation),
) -> Element(Nil) {
  layout.page_layout("PHILSTUBS", [
    html.div([attribute.class("landing-page")], [
      hero_section(stats, template_count),
      recent_legislation_section(recent_legislation),
      how_it_works_section(),
      level_overview_section(level_counts),
      footer_cta_section(),
    ]),
  ])
}

fn hero_section(stats: LegislationStats, template_count: Int) -> Element(Nil) {
  html.section([attribute.class("hero")], [
    html.h1([], [html.text("PHILSTUBS")]),
    html.p([attribute.class("hero-acronym")], [
      html.text(
        "People Hardly Inspect Legislation \u{2014} Searchable Templates Used Before anyone readS",
      ),
    ]),
    html.p([attribute.class("hero-tagline")], [
      html.text("Because someone should read these"),
    ]),
    components.search_bar(
      "Search legislation across all levels of government...",
    ),
    components.stats_row([
      #(int.to_string(stats.total), "Legislation"),
      #(int.to_string(template_count), "Templates"),
      #(int.to_string(list.length(stats.by_level)), "Gov. Levels"),
    ]),
  ])
}

fn recent_legislation_section(
  recent_legislation: List(Legislation),
) -> Element(Nil) {
  case recent_legislation {
    [] -> element.none()
    legislation_list ->
      html.section([attribute.class("recent-legislation")], [
        html.h2([], [html.text("Recent Legislation")]),
        html.div(
          [attribute.class("recent-legislation-list")],
          list.map(legislation_list, recent_legislation_item),
        ),
        html.div([attribute.class("recent-legislation-footer")], [
          html.a([attribute.href("/search"), attribute.class("view-all-link")], [
            html.text("View all legislation"),
          ]),
        ]),
      ])
  }
}

fn recent_legislation_item(record: Legislation) -> Element(Nil) {
  let legislation_id = legislation.legislation_id_to_string(record.id)

  html.a(
    [
      attribute.href("/legislation/" <> legislation_id),
      attribute.class("recent-legislation-item"),
    ],
    [
      html.div([attribute.class("recent-legislation-info")], [
        html.span([attribute.class("recent-legislation-title")], [
          html.text(record.title),
        ]),
        html.div([attribute.class("recent-legislation-meta")], [
          components.badge(
            "level-badge",
            government_level.jurisdiction_label(record.level),
          ),
          components.badge(
            "type-badge",
            legislation_type.to_string(record.legislation_type),
          ),
          components.badge(
            "status-badge",
            legislation_status.to_string(record.status),
          ),
        ]),
      ]),
      case record.introduced_date {
        "" -> element.none()
        date_value ->
          html.span([attribute.class("recent-legislation-date")], [
            html.text(date_value),
          ])
      },
    ],
  )
}

fn how_it_works_section() -> Element(Nil) {
  html.section([attribute.class("how-it-works")], [
    html.h2([], [html.text("How It Works")]),
    html.div([attribute.class("action-cards")], [
      components.action_card(
        "Browse",
        "Explore legislation organized by government level, state, and topic",
        "/browse",
        "1",
      ),
      components.action_card(
        "Search",
        "Full-text search with filters for level, type, status, and date range",
        "/search",
        "2",
      ),
      components.action_card(
        "Templates",
        "Download and share model legislation templates for any government level",
        "/templates",
        "3",
      ),
    ]),
  ])
}

fn level_overview_section(level_counts: List(#(String, Int))) -> Element(Nil) {
  html.section([attribute.class("level-overview")], [
    html.h2([], [html.text("Government Levels")]),
    html.div([attribute.class("level-overview-grid")], [
      components.level_overview_card(
        "Federal",
        get_count(level_counts, "federal"),
        "Congressional bills, resolutions, and federal regulations",
        "/search?level=federal",
      ),
      components.level_overview_card(
        "State",
        get_count(level_counts, "state"),
        "State legislature bills and resolutions",
        "/browse/states",
      ),
      components.level_overview_card(
        "County",
        get_count(level_counts, "county"),
        "County ordinances and resolutions",
        "/search?level=county",
      ),
      components.level_overview_card(
        "Municipal",
        get_count(level_counts, "municipal"),
        "City and town ordinances and bylaws",
        "/search?level=municipal",
      ),
    ]),
  ])
}

fn footer_cta_section() -> Element(Nil) {
  html.section([attribute.class("landing-cta")], [
    html.p([], [
      html.text(
        "An open platform for ingesting, browsing, and sharing legislation across all levels of US democracy.",
      ),
    ]),
    html.a([attribute.href("/browse"), attribute.class("btn btn-primary")], [
      html.text("Start Exploring"),
    ]),
  ])
}

fn get_count(level_counts: List(#(String, Int)), level: String) -> Int {
  case list.key_find(level_counts, level) {
    Ok(count) -> count
    Error(_) -> 0
  }
}
