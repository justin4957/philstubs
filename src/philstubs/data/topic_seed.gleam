import gleam/dynamic/decode
import gleam/list
import gleam/result
import sqlight

/// Seed the topic taxonomy with parent topics, child topics, and keywords.
/// Uses INSERT OR IGNORE for idempotent seeding — safe to call on every startup.
/// Returns the count of newly inserted topics.
pub fn seed_topic_taxonomy(
  connection: sqlight.Connection,
) -> Result(Int, sqlight.Error) {
  let topic_definitions = all_topic_definitions()

  use _ <- result.try(insert_topics(connection, topic_definitions))
  use _ <- result.try(insert_keywords(connection, keyword_definitions()))

  count_topics(connection)
}

/// A topic definition for seeding: id, name, slug, description, parent_id, display_order.
type TopicDefinition {
  TopicDefinition(
    id: String,
    name: String,
    slug: String,
    description: String,
    parent_id: String,
    display_order: Int,
  )
}

/// A keyword definition for seeding: topic_id, keyword.
type KeywordDefinition {
  KeywordDefinition(topic_id: String, keyword: String)
}

fn all_topic_definitions() -> List(TopicDefinition) {
  list.flatten([
    parent_topics(),
    civil_rights_children(),
    economy_children(),
    education_children(),
    environment_children(),
    healthcare_children(),
    housing_children(),
    public_safety_children(),
    technology_children(),
    transportation_children(),
  ])
}

fn parent_topics() -> List(TopicDefinition) {
  [
    TopicDefinition(
      "civil-rights",
      "Civil Rights",
      "civil-rights",
      "Legislation relating to civil rights, equality, and justice",
      "",
      1,
    ),
    TopicDefinition(
      "economy",
      "Economy",
      "economy",
      "Economic policy, taxation, and labor legislation",
      "",
      2,
    ),
    TopicDefinition(
      "education",
      "Education",
      "education",
      "Education policy from K-12 through higher education",
      "",
      3,
    ),
    TopicDefinition(
      "environment",
      "Environment",
      "environment",
      "Environmental protection, climate, and land use",
      "",
      4,
    ),
    TopicDefinition(
      "healthcare",
      "Healthcare",
      "healthcare",
      "Health insurance, public health, and medical policy",
      "",
      5,
    ),
    TopicDefinition(
      "housing",
      "Housing",
      "housing",
      "Housing policy, zoning, and tenant protections",
      "",
      6,
    ),
    TopicDefinition(
      "public-safety",
      "Public Safety",
      "public-safety",
      "Policing, firearms, and emergency services",
      "",
      7,
    ),
    TopicDefinition(
      "technology",
      "Technology",
      "technology",
      "Technology regulation, privacy, and digital infrastructure",
      "",
      8,
    ),
    TopicDefinition(
      "transportation",
      "Transportation",
      "transportation",
      "Infrastructure, public transit, and traffic safety",
      "",
      9,
    ),
  ]
}

fn civil_rights_children() -> List(TopicDefinition) {
  [
    TopicDefinition(
      "voting-rights",
      "Voting Rights",
      "voting-rights",
      "Voter access, registration, and election integrity",
      "civil-rights",
      1,
    ),
    TopicDefinition(
      "anti-discrimination",
      "Anti-Discrimination",
      "anti-discrimination",
      "Protections against discrimination in employment, housing, and services",
      "civil-rights",
      2,
    ),
    TopicDefinition(
      "criminal-justice-reform",
      "Criminal Justice Reform",
      "criminal-justice-reform",
      "Sentencing reform, bail, and incarceration policy",
      "civil-rights",
      3,
    ),
  ]
}

fn economy_children() -> List(TopicDefinition) {
  [
    TopicDefinition(
      "taxation",
      "Taxation",
      "taxation",
      "Tax policy, credits, and revenue measures",
      "economy",
      1,
    ),
    TopicDefinition(
      "labor-employment",
      "Labor & Employment",
      "labor-employment",
      "Wages, worker protections, and employment law",
      "economy",
      2,
    ),
    TopicDefinition(
      "small-business",
      "Small Business",
      "small-business",
      "Small business support, grants, and regulations",
      "economy",
      3,
    ),
  ]
}

fn education_children() -> List(TopicDefinition) {
  [
    TopicDefinition(
      "k-12",
      "K-12 Education",
      "k-12",
      "Primary and secondary education policy",
      "education",
      1,
    ),
    TopicDefinition(
      "higher-education",
      "Higher Education",
      "higher-education",
      "College, university, and vocational training policy",
      "education",
      2,
    ),
    TopicDefinition(
      "school-funding",
      "School Funding",
      "school-funding",
      "Education budgets, per-pupil funding, and grants",
      "education",
      3,
    ),
  ]
}

fn environment_children() -> List(TopicDefinition) {
  [
    TopicDefinition(
      "climate",
      "Climate",
      "climate",
      "Climate change mitigation and adaptation",
      "environment",
      1,
    ),
    TopicDefinition(
      "clean-water",
      "Clean Water",
      "clean-water",
      "Water quality, treatment, and access",
      "environment",
      2,
    ),
    TopicDefinition(
      "land-use",
      "Land Use",
      "land-use",
      "Land conservation, development, and planning",
      "environment",
      3,
    ),
  ]
}

fn healthcare_children() -> List(TopicDefinition) {
  [
    TopicDefinition(
      "insurance",
      "Insurance",
      "insurance",
      "Health insurance coverage, mandates, and marketplaces",
      "healthcare",
      1,
    ),
    TopicDefinition(
      "public-health",
      "Public Health",
      "public-health",
      "Disease prevention, vaccination, and community health",
      "healthcare",
      2,
    ),
    TopicDefinition(
      "mental-health",
      "Mental Health",
      "mental-health",
      "Mental health services, funding, and parity",
      "healthcare",
      3,
    ),
  ]
}

fn housing_children() -> List(TopicDefinition) {
  [
    TopicDefinition(
      "zoning",
      "Zoning",
      "zoning",
      "Zoning regulations, land use permits, and density",
      "housing",
      1,
    ),
    TopicDefinition(
      "affordable-housing",
      "Affordable Housing",
      "affordable-housing",
      "Affordable housing programs, subsidies, and development",
      "housing",
      2,
    ),
    TopicDefinition(
      "tenant-rights",
      "Tenant Rights",
      "tenant-rights",
      "Renter protections, eviction rules, and lease regulations",
      "housing",
      3,
    ),
  ]
}

fn public_safety_children() -> List(TopicDefinition) {
  [
    TopicDefinition(
      "policing",
      "Policing",
      "policing",
      "Law enforcement practices, accountability, and reform",
      "public-safety",
      1,
    ),
    TopicDefinition(
      "firearms",
      "Firearms",
      "firearms",
      "Gun regulations, permits, and safety measures",
      "public-safety",
      2,
    ),
    TopicDefinition(
      "emergency-services",
      "Emergency Services",
      "emergency-services",
      "Fire, EMS, and emergency management",
      "public-safety",
      3,
    ),
  ]
}

fn technology_children() -> List(TopicDefinition) {
  [
    TopicDefinition(
      "privacy",
      "Privacy",
      "privacy",
      "Data privacy, surveillance, and personal information protections",
      "technology",
      1,
    ),
    TopicDefinition(
      "ai-regulation",
      "AI Regulation",
      "ai-regulation",
      "Artificial intelligence oversight and governance",
      "technology",
      2,
    ),
    TopicDefinition(
      "broadband",
      "Broadband",
      "broadband",
      "Internet access, broadband deployment, and digital equity",
      "technology",
      3,
    ),
  ]
}

fn transportation_children() -> List(TopicDefinition) {
  [
    TopicDefinition(
      "infrastructure",
      "Infrastructure",
      "infrastructure",
      "Roads, bridges, and public works",
      "transportation",
      1,
    ),
    TopicDefinition(
      "public-transit",
      "Public Transit",
      "public-transit",
      "Bus, rail, and other mass transit systems",
      "transportation",
      2,
    ),
    TopicDefinition(
      "traffic-safety",
      "Traffic Safety",
      "traffic-safety",
      "Speed limits, DUI, and road safety regulations",
      "transportation",
      3,
    ),
  ]
}

fn keyword_definitions() -> List(KeywordDefinition) {
  list.flatten([
    // Civil Rights
    keywords_for("civil-rights", [
      "civil rights",
      "discrimination",
      "equal rights",
      "equality",
    ]),
    keywords_for("voting-rights", [
      "voting",
      "voter",
      "election",
      "ballot",
      "franchise",
    ]),
    keywords_for("anti-discrimination", [
      "discrimination",
      "bias",
      "equal opportunity",
      "hate crime",
    ]),
    keywords_for("criminal-justice-reform", [
      "criminal justice",
      "sentencing",
      "bail",
      "incarceration",
      "prison",
    ]),
    // Economy
    keywords_for("economy", ["economy", "fiscal", "economic"]),
    keywords_for("taxation", ["tax", "taxation", "revenue", "levy", "deduction"]),
    keywords_for("labor-employment", [
      "wages",
      "employment",
      "labor",
      "worker",
      "minimum wage",
      "overtime",
    ]),
    keywords_for("small-business", ["small business", "entrepreneur", "startup"]),
    // Education
    keywords_for("education", [
      "education",
      "school",
      "student",
      "university",
      "academic",
    ]),
    keywords_for("k-12", [
      "k-12",
      "elementary",
      "middle school",
      "high school",
      "secondary education",
    ]),
    keywords_for("higher-education", [
      "college",
      "university",
      "tuition",
      "student loan",
    ]),
    keywords_for("school-funding", [
      "school funding",
      "per-pupil",
      "education budget",
    ]),
    // Environment
    keywords_for("environment", [
      "environment",
      "pollution",
      "conservation",
      "ecological",
    ]),
    keywords_for("climate", [
      "climate",
      "emissions",
      "carbon",
      "greenhouse",
      "renewable energy",
    ]),
    keywords_for("clean-water", [
      "water quality",
      "clean water",
      "drinking water",
      "wastewater",
    ]),
    keywords_for("land-use", [
      "land use",
      "conservation",
      "development",
      "wetlands",
    ]),
    // Healthcare
    keywords_for("healthcare", ["health", "medical", "hospital", "healthcare"]),
    keywords_for("insurance", [
      "health insurance",
      "coverage",
      "medicaid",
      "medicare",
      "premium",
    ]),
    keywords_for("public-health", [
      "public health",
      "disease",
      "vaccination",
      "epidemic",
    ]),
    keywords_for("mental-health", [
      "mental health",
      "behavioral health",
      "counseling",
      "psychiatric",
    ]),
    // Housing
    keywords_for("housing", ["housing", "rent", "affordable", "shelter"]),
    keywords_for("zoning", ["zoning", "land use permit", "density", "setback"]),
    keywords_for("affordable-housing", [
      "affordable housing",
      "low-income housing",
      "housing subsidy",
      "section 8",
    ]),
    keywords_for("tenant-rights", [
      "tenant",
      "renter",
      "eviction",
      "lease",
      "landlord",
    ]),
    // Public Safety
    keywords_for("public-safety", ["safety", "public safety"]),
    keywords_for("policing", [
      "police",
      "law enforcement",
      "officer",
      "body camera",
    ]),
    keywords_for("firearms", [
      "firearm",
      "gun",
      "weapon",
      "ammunition",
      "concealed carry",
    ]),
    keywords_for("emergency-services", [
      "emergency",
      "fire department",
      "ems",
      "disaster",
      "911",
    ]),
    // Technology
    keywords_for("technology", ["technology", "digital", "cyber"]),
    keywords_for("privacy", [
      "privacy",
      "data protection",
      "surveillance",
      "personal data",
    ]),
    keywords_for("ai-regulation", [
      "artificial intelligence",
      "ai",
      "machine learning",
      "algorithm",
    ]),
    keywords_for("broadband", [
      "broadband",
      "internet access",
      "fiber optic",
      "connectivity",
    ]),
    // Transportation
    keywords_for("transportation", ["transport", "transit", "traffic"]),
    keywords_for("infrastructure", [
      "infrastructure",
      "bridge",
      "road",
      "highway",
      "public works",
    ]),
    keywords_for("public-transit", [
      "public transit",
      "bus",
      "rail",
      "subway",
      "metro",
    ]),
    keywords_for("traffic-safety", [
      "traffic safety",
      "speed limit",
      "dui",
      "road safety",
    ]),
  ])
}

fn keywords_for(
  target_topic_id: String,
  keyword_list: List(String),
) -> List(KeywordDefinition) {
  list.map(keyword_list, fn(keyword) {
    KeywordDefinition(topic_id: target_topic_id, keyword: keyword)
  })
}

fn insert_topics(
  connection: sqlight.Connection,
  definitions: List(TopicDefinition),
) -> Result(Nil, sqlight.Error) {
  list.try_each(definitions, fn(definition) {
    let parent_id_param = case definition.parent_id {
      "" -> sqlight.null()
      parent_value -> sqlight.text(parent_value)
    }

    sqlight.query(
      "INSERT OR IGNORE INTO topics (id, name, slug, description, parent_id, display_order)
       VALUES (?, ?, ?, ?, ?, ?)",
      on: connection,
      with: [
        sqlight.text(definition.id),
        sqlight.text(definition.name),
        sqlight.text(definition.slug),
        sqlight.text(definition.description),
        parent_id_param,
        sqlight.int(definition.display_order),
      ],
      expecting: decode.success(Nil),
    )
    |> result.replace(Nil)
  })
}

fn insert_keywords(
  connection: sqlight.Connection,
  definitions: List(KeywordDefinition),
) -> Result(Nil, sqlight.Error) {
  // First check if keywords already exist to avoid duplicates
  use existing_count <- result.try(
    sqlight.query(
      "SELECT COUNT(*) FROM topic_keywords",
      on: connection,
      with: [],
      expecting: {
        use count <- decode.field(0, decode.int)
        decode.success(count)
      },
    ),
  )

  case existing_count {
    [0] -> {
      list.try_each(definitions, fn(definition) {
        sqlight.query(
          "INSERT INTO topic_keywords (topic_id, keyword) VALUES (?, ?)",
          on: connection,
          with: [
            sqlight.text(definition.topic_id),
            sqlight.text(definition.keyword),
          ],
          expecting: decode.success(Nil),
        )
        |> result.replace(Nil)
      })
    }
    _ -> Ok(Nil)
  }
}

fn count_topics(connection: sqlight.Connection) -> Result(Int, sqlight.Error) {
  use rows <- result.try(
    sqlight.query(
      "SELECT COUNT(*) FROM topics",
      on: connection,
      with: [],
      expecting: {
        use count <- decode.field(0, decode.int)
        decode.success(count)
      },
    ),
  )
  case rows {
    [count] -> Ok(count)
    _ -> Ok(0)
  }
}
