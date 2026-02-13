import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import philstubs/core/government_level.{Federal, Municipal, State}
import philstubs/core/legislation_template.{
  type LegislationTemplate, LegislationTemplate,
}
import philstubs/core/legislation_type
import philstubs/data/database
import philstubs/data/template_repo
import philstubs/data/test_helpers

fn sample_housing_template() -> LegislationTemplate {
  LegislationTemplate(
    id: legislation_template.template_id("test-tmpl-001"),
    title: "Model Affordable Housing Ordinance",
    description: "A template for municipalities to adopt inclusionary zoning",
    body: "WHEREAS the [Municipality] recognizes the need for affordable housing...",
    suggested_level: Municipal("", ""),
    suggested_type: legislation_type.Ordinance,
    author: "Housing Policy Institute",
    topics: ["housing", "zoning", "affordable housing"],
    created_at: "2024-06-01T12:00:00Z",
    download_count: 42,
    owner_user_id: None,
  )
}

fn sample_transparency_template() -> LegislationTemplate {
  LegislationTemplate(
    id: legislation_template.template_id("test-tmpl-002"),
    title: "Government Transparency Act Template",
    description: "A model bill for open data publication requirements",
    body: "AN ACT to promote transparency and open government data...",
    suggested_level: State(""),
    suggested_type: legislation_type.Bill,
    author: "Open Government Coalition",
    topics: ["transparency", "open data", "government accountability"],
    created_at: "2024-04-15T09:30:00Z",
    download_count: 87,
    owner_user_id: None,
  )
}

pub fn insert_and_get_by_id_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let template = sample_housing_template()
  let assert Ok(Nil) = template_repo.insert(connection, template)

  let assert Ok(Some(retrieved)) =
    template_repo.get_by_id(connection, "test-tmpl-001")

  legislation_template.template_id_to_string(retrieved.id)
  |> should.equal("test-tmpl-001")
  retrieved.title |> should.equal("Model Affordable Housing Ordinance")
  retrieved.description
  |> should.equal("A template for municipalities to adopt inclusionary zoning")
  retrieved.suggested_level |> should.equal(Municipal("", ""))
  retrieved.suggested_type |> should.equal(legislation_type.Ordinance)
  retrieved.author |> should.equal("Housing Policy Institute")
  retrieved.topics
  |> should.equal(["housing", "zoning", "affordable housing"])
  retrieved.created_at |> should.equal("2024-06-01T12:00:00Z")
  retrieved.download_count |> should.equal(42)
}

pub fn get_by_id_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let result = template_repo.get_by_id(connection, "nonexistent-id")
  result |> should.equal(Ok(None))
}

pub fn list_all_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())
  let assert Ok(Nil) =
    template_repo.insert(connection, sample_transparency_template())

  let assert Ok(templates) = template_repo.list_all(connection)
  templates |> list.length |> should.equal(2)
}

pub fn update_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let template = sample_housing_template()
  let assert Ok(Nil) = template_repo.insert(connection, template)

  let updated_template =
    LegislationTemplate(
      ..template,
      title: "Updated Housing Template",
      description: "Revised inclusionary zoning requirements",
      topics: ["housing", "zoning", "affordable housing", "equity"],
    )
  let assert Ok(Nil) = template_repo.update(connection, updated_template)

  let assert Ok(Some(retrieved)) =
    template_repo.get_by_id(connection, "test-tmpl-001")
  retrieved.title |> should.equal("Updated Housing Template")
  retrieved.description
  |> should.equal("Revised inclusionary zoning requirements")
  retrieved.topics
  |> should.equal(["housing", "zoning", "affordable housing", "equity"])
}

pub fn delete_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())
  let assert Ok(Some(_)) = template_repo.get_by_id(connection, "test-tmpl-001")

  let assert Ok(Nil) = template_repo.delete(connection, "test-tmpl-001")
  let result = template_repo.get_by_id(connection, "test-tmpl-001")
  result |> should.equal(Ok(None))
}

pub fn search_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) =
    template_repo.insert(connection, sample_housing_template())
  let assert Ok(Nil) =
    template_repo.insert(connection, sample_transparency_template())

  // Search for "housing" — should match only the housing template
  let assert Ok(results) = template_repo.search(connection, "housing")
  results |> list.length |> should.equal(1)
  let assert [matched_template] = results
  legislation_template.template_id_to_string(matched_template.id)
  |> should.equal("test-tmpl-001")

  // Search for "transparency" — should match only the transparency template
  let assert Ok(transparency_results) =
    template_repo.search(connection, "transparency")
  transparency_results |> list.length |> should.equal(1)
  let assert [transparency_match] = transparency_results
  legislation_template.template_id_to_string(transparency_match.id)
  |> should.equal("test-tmpl-002")
}

pub fn increment_download_count_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let template = sample_housing_template()
  let assert Ok(Nil) = template_repo.insert(connection, template)

  // Initial count is 42
  let assert Ok(Some(before)) =
    template_repo.get_by_id(connection, "test-tmpl-001")
  before.download_count |> should.equal(42)

  // Increment
  let assert Ok(Nil) =
    template_repo.increment_download_count(connection, "test-tmpl-001")

  let assert Ok(Some(after)) =
    template_repo.get_by_id(connection, "test-tmpl-001")
  after.download_count |> should.equal(43)
}

pub fn insert_with_federal_suggested_level_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let federal_template =
    LegislationTemplate(
      id: legislation_template.template_id("test-tmpl-fed"),
      title: "Federal Oversight Template",
      description: "A model for federal oversight legislation",
      body: "AN ACT to establish oversight...",
      suggested_level: Federal,
      suggested_type: legislation_type.Bill,
      author: "Policy Research Center",
      topics: ["oversight", "federal"],
      created_at: "2024-09-01T10:00:00Z",
      download_count: 0,
      owner_user_id: None,
    )

  let assert Ok(Nil) = template_repo.insert(connection, federal_template)
  let assert Ok(Some(retrieved)) =
    template_repo.get_by_id(connection, "test-tmpl-fed")
  retrieved.suggested_level |> should.equal(Federal)
}
