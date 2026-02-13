import gleam/string
import gleeunit
import gleeunit/should
import lustre/element
import philstubs/data/stats_repo
import philstubs/ui/pages

pub fn main() {
  gleeunit.main()
}

pub fn landing_page_renders_test() {
  let stats =
    stats_repo.LegislationStats(
      total: 42,
      by_level: [
        #("federal", 10),
        #("state", 20),
        #("county", 8),
        #("municipal", 4),
      ],
      by_type: [],
      by_status: [],
    )
  let template_count = 7
  let level_counts = [
    #("federal", 10),
    #("state", 20),
    #("county", 8),
    #("municipal", 4),
  ]

  let rendered_html =
    pages.landing_page(stats, template_count, level_counts)
    |> element.to_document_string

  string.contains(rendered_html, "PHILSTUBS")
  |> should.be_true

  string.contains(rendered_html, "People Hardly Inspect Legislation")
  |> should.be_true

  string.contains(rendered_html, "Federal")
  |> should.be_true
}

pub fn landing_page_shows_stats_test() {
  let stats =
    stats_repo.LegislationStats(
      total: 150,
      by_level: [#("federal", 50), #("state", 100)],
      by_type: [],
      by_status: [],
    )

  let rendered_html =
    pages.landing_page(stats, 12, [#("federal", 50), #("state", 100)])
    |> element.to_document_string

  // Verify stats are rendered
  string.contains(rendered_html, "150")
  |> should.be_true

  string.contains(rendered_html, "12")
  |> should.be_true

  string.contains(rendered_html, "Legislation")
  |> should.be_true

  string.contains(rendered_html, "Templates")
  |> should.be_true
}

pub fn landing_page_shows_search_bar_test() {
  let stats =
    stats_repo.LegislationStats(
      total: 0,
      by_level: [],
      by_type: [],
      by_status: [],
    )

  let rendered_html =
    pages.landing_page(stats, 0, [])
    |> element.to_document_string

  string.contains(rendered_html, "search")
  |> should.be_true

  string.contains(rendered_html, "/search")
  |> should.be_true
}

pub fn landing_page_shows_how_it_works_test() {
  let stats =
    stats_repo.LegislationStats(
      total: 0,
      by_level: [],
      by_type: [],
      by_status: [],
    )

  let rendered_html =
    pages.landing_page(stats, 0, [])
    |> element.to_document_string

  string.contains(rendered_html, "How It Works")
  |> should.be_true

  string.contains(rendered_html, "Browse")
  |> should.be_true

  string.contains(rendered_html, "Search")
  |> should.be_true

  string.contains(rendered_html, "Templates")
  |> should.be_true
}

pub fn landing_page_shows_level_counts_test() {
  let stats =
    stats_repo.LegislationStats(
      total: 100,
      by_level: [],
      by_type: [],
      by_status: [],
    )
  let level_counts = [
    #("federal", 25),
    #("state", 50),
    #("county", 15),
    #("municipal", 10),
  ]

  let rendered_html =
    pages.landing_page(stats, 5, level_counts)
    |> element.to_document_string

  string.contains(rendered_html, "25")
  |> should.be_true

  string.contains(rendered_html, "50")
  |> should.be_true

  string.contains(rendered_html, "Government Levels")
  |> should.be_true
}

pub fn landing_page_shows_cta_test() {
  let stats =
    stats_repo.LegislationStats(
      total: 0,
      by_level: [],
      by_type: [],
      by_status: [],
    )

  let rendered_html =
    pages.landing_page(stats, 0, [])
    |> element.to_document_string

  string.contains(rendered_html, "Start Exploring")
  |> should.be_true
}

pub fn landing_page_empty_data_test() {
  let stats =
    stats_repo.LegislationStats(
      total: 0,
      by_level: [],
      by_type: [],
      by_status: [],
    )

  let rendered_html =
    pages.landing_page(stats, 0, [])
    |> element.to_document_string

  // Should still render without errors
  string.contains(rendered_html, "PHILSTUBS")
  |> should.be_true

  // Stats should show 0
  string.contains(rendered_html, "0")
  |> should.be_true
}
