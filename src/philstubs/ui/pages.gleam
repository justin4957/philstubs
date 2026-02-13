import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/data/stats_repo.{type LegislationStats}
import philstubs/ui/components
import philstubs/ui/layout

/// The landing page for PHILSTUBS, displayed at the root URL.
/// Accepts live data: legislation stats, template count, and counts per level.
pub fn landing_page(
  stats: LegislationStats,
  template_count: Int,
  level_counts: List(#(String, Int)),
) -> Element(Nil) {
  layout.page_layout("PHILSTUBS", [
    html.div([attribute.class("landing-page")], [
      hero_section(stats, template_count),
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
