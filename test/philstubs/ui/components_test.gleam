import gleam/string
import gleeunit/should
import lustre/element
import philstubs/ui/components

pub fn badge_renders_test() {
  let rendered_html =
    components.badge("level-badge", "Federal")
    |> element.to_string

  string.contains(rendered_html, "badge level-badge")
  |> should.be_true

  string.contains(rendered_html, "Federal")
  |> should.be_true
}

pub fn badge_custom_class_test() {
  let rendered_html =
    components.badge("status-badge", "Enacted")
    |> element.to_string

  string.contains(rendered_html, "badge status-badge")
  |> should.be_true

  string.contains(rendered_html, "Enacted")
  |> should.be_true
}

pub fn metadata_item_renders_test() {
  let rendered_html =
    components.metadata_item("Status", "Introduced")
    |> element.to_string

  string.contains(rendered_html, "metadata-item")
  |> should.be_true

  string.contains(rendered_html, "metadata-label")
  |> should.be_true

  string.contains(rendered_html, "Status")
  |> should.be_true

  string.contains(rendered_html, "Introduced")
  |> should.be_true
}

pub fn topics_section_renders_test() {
  let rendered_html =
    components.topics_section(["environment", "housing"])
    |> element.to_string

  string.contains(rendered_html, "topic-tags")
  |> should.be_true

  string.contains(rendered_html, "environment")
  |> should.be_true

  string.contains(rendered_html, "housing")
  |> should.be_true
}

pub fn topics_section_empty_returns_none_test() {
  let rendered_html =
    components.topics_section([])
    |> element.to_string

  // element.none() renders as empty string
  rendered_html
  |> should.equal("")
}

pub fn stat_card_renders_test() {
  let rendered_html =
    components.stat_card("42", "Legislation")
    |> element.to_string

  string.contains(rendered_html, "stat-card")
  |> should.be_true

  string.contains(rendered_html, "42")
  |> should.be_true

  string.contains(rendered_html, "Legislation")
  |> should.be_true
}

pub fn search_bar_renders_test() {
  let rendered_html =
    components.search_bar("Search legislation...")
    |> element.to_string

  string.contains(rendered_html, "Search legislation...")
  |> should.be_true

  string.contains(rendered_html, "/search")
  |> should.be_true

  string.contains(rendered_html, "search")
  |> should.be_true
}

pub fn search_bar_has_accessible_label_test() {
  let rendered_html =
    components.search_bar("Search...")
    |> element.to_string

  string.contains(rendered_html, "sr-only")
  |> should.be_true

  string.contains(rendered_html, "Search legislation")
  |> should.be_true
}

pub fn stats_row_renders_multiple_test() {
  let rendered_html =
    components.stats_row([#("10", "Bills"), #("5", "Templates")])
    |> element.to_string

  string.contains(rendered_html, "stats-row")
  |> should.be_true

  string.contains(rendered_html, "10")
  |> should.be_true

  string.contains(rendered_html, "Bills")
  |> should.be_true

  string.contains(rendered_html, "5")
  |> should.be_true

  string.contains(rendered_html, "Templates")
  |> should.be_true
}

pub fn action_card_renders_test() {
  let rendered_html =
    components.action_card("Browse", "Explore legislation", "/browse", "1")
    |> element.to_string

  string.contains(rendered_html, "action-card")
  |> should.be_true

  string.contains(rendered_html, "Browse")
  |> should.be_true

  string.contains(rendered_html, "Explore legislation")
  |> should.be_true

  string.contains(rendered_html, "/browse")
  |> should.be_true
}

pub fn level_overview_card_renders_test() {
  let rendered_html =
    components.level_overview_card(
      "Federal",
      25,
      "Congressional bills",
      "/search?level=federal",
    )
    |> element.to_string

  string.contains(rendered_html, "level-overview-card")
  |> should.be_true

  string.contains(rendered_html, "Federal")
  |> should.be_true

  string.contains(rendered_html, "25")
  |> should.be_true

  string.contains(rendered_html, "Congressional bills")
  |> should.be_true
}

pub fn level_overview_card_zero_count_test() {
  let rendered_html =
    components.level_overview_card(
      "County",
      0,
      "County ordinances",
      "/search?level=county",
    )
    |> element.to_string

  string.contains(rendered_html, "0")
  |> should.be_true

  string.contains(rendered_html, "County")
  |> should.be_true
}
