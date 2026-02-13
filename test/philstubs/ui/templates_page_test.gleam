import gleam/string
import gleeunit/should
import lustre/element
import philstubs/core/government_level.{Federal, Municipal}
import philstubs/core/legislation_template.{
  type LegislationTemplate, LegislationTemplate,
}
import philstubs/core/legislation_type
import philstubs/ui/templates_page

fn sample_housing_template() -> LegislationTemplate {
  LegislationTemplate(
    id: legislation_template.template_id("test-tmpl-001"),
    title: "Model Affordable Housing Ordinance",
    description: "A template for municipalities to adopt inclusionary zoning",
    body: "WHEREAS the [Municipality] recognizes the need...",
    suggested_level: Municipal("", ""),
    suggested_type: legislation_type.Ordinance,
    author: "Housing Policy Institute",
    topics: ["housing", "zoning"],
    created_at: "2024-06-01T12:00:00Z",
    download_count: 42,
  )
}

fn sample_transparency_template() -> LegislationTemplate {
  LegislationTemplate(
    id: legislation_template.template_id("test-tmpl-002"),
    title: "Government Transparency Act Template",
    description: "A model bill for open data",
    body: "AN ACT to promote transparency...",
    suggested_level: Federal,
    suggested_type: legislation_type.Bill,
    author: "Open Government Coalition",
    topics: ["transparency"],
    created_at: "2024-04-15T09:30:00Z",
    download_count: 87,
  )
}

fn sample_alphabetical_template() -> LegislationTemplate {
  LegislationTemplate(
    id: legislation_template.template_id("test-tmpl-003"),
    title: "Anti-Corruption Standards Template",
    description: "Standards for preventing corruption",
    body: "SECTION 1. Anti-corruption standards...",
    suggested_level: Federal,
    suggested_type: legislation_type.Bill,
    author: "Ethics Board",
    topics: ["ethics"],
    created_at: "2024-08-01T10:00:00Z",
    download_count: 10,
  )
}

// --- Sort tests ---

pub fn sort_templates_newest_first_test() {
  let templates = [
    sample_housing_template(),
    sample_transparency_template(),
    sample_alphabetical_template(),
  ]

  let sorted = templates_page.sort_templates(templates, templates_page.Newest)

  let assert [first, second, third] = sorted
  first.created_at |> should.equal("2024-08-01T10:00:00Z")
  second.created_at |> should.equal("2024-06-01T12:00:00Z")
  third.created_at |> should.equal("2024-04-15T09:30:00Z")
}

pub fn sort_templates_most_downloaded_test() {
  let templates = [
    sample_housing_template(),
    sample_transparency_template(),
    sample_alphabetical_template(),
  ]

  let sorted =
    templates_page.sort_templates(templates, templates_page.MostDownloaded)

  let assert [first, second, third] = sorted
  first.download_count |> should.equal(87)
  second.download_count |> should.equal(42)
  third.download_count |> should.equal(10)
}

pub fn sort_templates_alphabetical_test() {
  let templates = [
    sample_housing_template(),
    sample_transparency_template(),
    sample_alphabetical_template(),
  ]

  let sorted =
    templates_page.sort_templates(templates, templates_page.Alphabetical)

  let assert [first, second, third] = sorted
  first.title |> should.equal("Anti-Corruption Standards Template")
  second.title |> should.equal("Government Transparency Act Template")
  third.title |> should.equal("Model Affordable Housing Ordinance")
}

// --- Sort order parsing tests ---

pub fn sort_order_from_string_newest_test() {
  templates_page.sort_order_from_string("newest")
  |> should.equal(templates_page.Newest)
}

pub fn sort_order_from_string_downloads_test() {
  templates_page.sort_order_from_string("downloads")
  |> should.equal(templates_page.MostDownloaded)
}

pub fn sort_order_from_string_title_test() {
  templates_page.sort_order_from_string("title")
  |> should.equal(templates_page.Alphabetical)
}

pub fn sort_order_from_string_unknown_defaults_newest_test() {
  templates_page.sort_order_from_string("unknown")
  |> should.equal(templates_page.Newest)
}

// --- Rendering tests ---

pub fn templates_page_renders_empty_state_test() {
  let rendered =
    templates_page.templates_page([], templates_page.Newest)
    |> element.to_document_string

  rendered |> string.contains("Legislation Templates") |> should.be_true
  rendered |> string.contains("No templates yet") |> should.be_true
  rendered |> string.contains("Upload Template") |> should.be_true
}

pub fn templates_page_renders_template_cards_test() {
  let templates = [sample_housing_template(), sample_transparency_template()]

  let rendered =
    templates_page.templates_page(templates, templates_page.Newest)
    |> element.to_document_string

  rendered
  |> string.contains("Model Affordable Housing Ordinance")
  |> should.be_true
  rendered
  |> string.contains("Government Transparency Act Template")
  |> should.be_true
  rendered |> string.contains("Housing Policy Institute") |> should.be_true
  rendered |> string.contains("42 downloads") |> should.be_true
  rendered |> string.contains("87 downloads") |> should.be_true
}

pub fn templates_page_renders_sort_links_test() {
  let rendered =
    templates_page.templates_page([], templates_page.Newest)
    |> element.to_document_string

  rendered |> string.contains("Sort by:") |> should.be_true
  rendered |> string.contains("Newest") |> should.be_true
  rendered |> string.contains("Most Downloaded") |> should.be_true
  rendered |> string.contains("Title") |> should.be_true
}
