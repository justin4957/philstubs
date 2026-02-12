import gleam/option.{None, Some}
import gleam/result
import philstubs/core/government_level.{County, Federal, Municipal, State}
import philstubs/core/legislation.{Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_template.{LegislationTemplate}
import philstubs/core/legislation_type
import philstubs/data/legislation_repo
import philstubs/data/template_repo
import sqlight

/// Insert sample legislation and template records for development and demos.
pub fn seed(connection: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(seed_legislation(connection))
  seed_templates(connection)
}

fn seed_legislation(
  connection: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  let records = [
    Legislation(
      id: legislation.legislation_id("fed-clean-air-001"),
      title: "Clean Air Standards Act of 2024",
      summary: "Establishes updated air quality standards for industrial emissions nationwide",
      body: "Section 1. Short Title.\nThis Act may be cited as the Clean Air Standards Act of 2024.\n\nSection 2. Purpose.\nTo establish comprehensive air quality standards...",
      level: Federal,
      legislation_type: legislation_type.Bill,
      status: legislation_status.InCommittee,
      introduced_date: "2024-03-15",
      source_url: Some("https://congress.gov/bill/118th/hr1234"),
      source_identifier: "H.R. 1234",
      sponsors: ["Rep. Smith", "Rep. Jones", "Sen. Williams"],
      topics: ["environment", "air quality", "regulation", "emissions"],
    ),
    Legislation(
      id: legislation.legislation_id("state-ca-housing-001"),
      title: "California Affordable Housing Incentive Act",
      summary: "Provides tax incentives for developers building affordable housing units",
      body: "THE PEOPLE OF THE STATE OF CALIFORNIA DO ENACT AS FOLLOWS:\n\nSECTION 1. This act shall be known as the Affordable Housing Incentive Act.\n\nSECTION 2. Tax Credit Program...",
      level: State("CA"),
      legislation_type: legislation_type.Bill,
      status: legislation_status.PassedChamber,
      introduced_date: "2024-01-20",
      source_url: Some("https://leginfo.legislature.ca.gov/sb-456"),
      source_identifier: "SB 456",
      sponsors: ["Sen. Garcia", "Asm. Chen"],
      topics: ["housing", "affordable housing", "tax incentives"],
    ),
    Legislation(
      id: legislation.legislation_id("county-cook-noise-001"),
      title: "Cook County Noise Control Ordinance Amendment",
      summary: "Amends noise restrictions for residential zones after 10 PM",
      body: "BE IT ORDAINED by the Cook County Board of Commissioners:\n\nSection 1. Amendment to Chapter 42.\nThe existing noise ordinance is hereby amended...",
      level: County("IL", "Cook"),
      legislation_type: legislation_type.Ordinance,
      status: legislation_status.Enacted,
      introduced_date: "2024-06-01",
      source_url: None,
      source_identifier: "Ord. 2024-15",
      sponsors: ["Commissioner Davis", "Commissioner Park"],
      topics: ["noise", "zoning", "residential"],
    ),
    Legislation(
      id: legislation.legislation_id("muni-austin-transport-001"),
      title: "Austin Public Transit Expansion Resolution",
      summary: "Directs the city to study expansion of bus rapid transit corridors",
      body: "RESOLUTION NO. 20240801-042\n\nWHEREAS, the City of Austin recognizes the need for expanded public transportation...",
      level: Municipal("TX", "Austin"),
      legislation_type: legislation_type.Resolution,
      status: legislation_status.Introduced,
      introduced_date: "2024-08-01",
      source_url: Some("https://austin.gov/resolutions/20240801-042"),
      source_identifier: "Res. 20240801-042",
      sponsors: ["Council Member Rivera"],
      topics: ["transportation", "public transit", "urban planning"],
    ),
  ]

  list_try_each(records, fn(record) {
    legislation_repo.insert(connection, record)
  })
}

fn seed_templates(connection: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  let templates = [
    LegislationTemplate(
      id: legislation_template.template_id("tmpl-housing-001"),
      title: "Model Affordable Housing Ordinance",
      description: "A template ordinance for municipalities to adopt inclusionary zoning requirements and affordable housing mandates",
      body: "WHEREAS the [Municipality] recognizes the need for affordable housing;\n\nWHEREAS current housing costs exceed 30% of median household income;\n\nBE IT ORDAINED:\n\nSection 1. Definitions.\n[Affordable Housing Unit] means a dwelling unit...\n\nSection 2. Requirements.\nAll residential developments of [10] or more units shall include...",
      suggested_level: Municipal("", ""),
      suggested_type: legislation_type.Ordinance,
      author: "Housing Policy Institute",
      topics: ["housing", "zoning", "affordable housing", "inclusionary zoning"],
      created_at: "2024-06-01T12:00:00Z",
      download_count: 42,
    ),
    LegislationTemplate(
      id: legislation_template.template_id("tmpl-transparency-001"),
      title: "Government Transparency and Open Data Act Template",
      description: "A model bill for state legislatures to require open data publication and government transparency reporting",
      body: "AN ACT to promote transparency and open government data.\n\nSection 1. Short Title.\nThis Act may be cited as the [State] Transparency and Open Data Act.\n\nSection 2. Definitions.\n(a) \"Public data\" means any data collected or maintained by a state agency...\n\nSection 3. Open Data Portal.\nThe [Chief Data Officer] shall establish and maintain...",
      suggested_level: State(""),
      suggested_type: legislation_type.Bill,
      author: "Open Government Coalition",
      topics: [
        "transparency", "open data", "government accountability", "technology",
      ],
      created_at: "2024-04-15T09:30:00Z",
      download_count: 87,
    ),
  ]

  list_try_each(templates, fn(template) {
    template_repo.insert(connection, template)
  })
}

fn list_try_each(
  items: List(a),
  operation: fn(a) -> Result(Nil, e),
) -> Result(Nil, e) {
  case items {
    [] -> Ok(Nil)
    [first, ..rest] -> {
      use _ <- result.try(operation(first))
      list_try_each(rest, operation)
    }
  }
}
