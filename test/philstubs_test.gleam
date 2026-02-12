import gleam/string
import gleeunit
import gleeunit/should
import lustre/element
import philstubs/core/types
import philstubs/ui/pages

pub fn main() {
  gleeunit.main()
}

pub fn government_level_to_string_test() {
  types.government_level_to_string(types.Federal)
  |> should.equal("Federal")

  types.government_level_to_string(types.State)
  |> should.equal("State")

  types.government_level_to_string(types.County)
  |> should.equal("County")

  types.government_level_to_string(types.Municipal)
  |> should.equal("Municipal")
}

pub fn landing_page_renders_test() {
  let rendered_html =
    pages.landing_page()
    |> element.to_document_string

  string.contains(rendered_html, "PHILSTUBS")
  |> should.be_true

  string.contains(rendered_html, "People Hardly Inspect Legislation")
  |> should.be_true

  string.contains(rendered_html, "Federal")
  |> should.be_true
}
