import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import gleam/result
import philstubs/core/government_level.{
  type GovernmentLevel, County, Federal, Municipal, State,
}
import philstubs/core/legislation.{Legislation}
import philstubs/core/legislation_status
import philstubs/core/legislation_type
import philstubs/core/similarity_types.{
  type AdoptionEvent, type SimilarLegislation, type TemplateMatch, AdoptionEvent,
  SimilarLegislation, TemplateMatch,
}
import sqlight

/// Store a precomputed similarity between two legislation records (both directions).
/// Uses INSERT OR REPLACE to be idempotent.
pub fn store_similarity(
  connection: sqlight.Connection,
  source_id: String,
  target_id: String,
  similarity_score: Float,
  title_score: Float,
  body_score: Float,
  topic_score: Float,
) -> Result(Nil, sqlight.Error) {
  let forward_id = source_id <> ":" <> target_id
  let reverse_id = target_id <> ":" <> source_id

  let sql =
    "INSERT OR REPLACE INTO legislation_similarities
      (id, source_legislation_id, target_legislation_id,
       similarity_score, title_score, body_score, topic_score)
     VALUES (?, ?, ?, ?, ?, ?, ?)"

  use _ <- result.try(sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(forward_id),
      sqlight.text(source_id),
      sqlight.text(target_id),
      sqlight.float(similarity_score),
      sqlight.float(title_score),
      sqlight.float(body_score),
      sqlight.float(topic_score),
    ],
    expecting: decode.success(Nil),
  ))

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(reverse_id),
      sqlight.text(target_id),
      sqlight.text(source_id),
      sqlight.float(similarity_score),
      sqlight.float(title_score),
      sqlight.float(body_score),
      sqlight.float(topic_score),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Find legislation similar to the given ID, ordered by score descending.
pub fn find_similar(
  connection: sqlight.Connection,
  legislation_id: String,
  min_score: Float,
  max_results: Int,
) -> Result(List(SimilarLegislation), sqlight.Error) {
  let sql =
    "SELECT
      l.id, l.title, l.summary, l.body,
      l.government_level, l.level_state_code, l.level_county_name,
      l.level_municipality_name,
      l.legislation_type, l.status, l.introduced_date,
      l.source_url, l.source_identifier, l.sponsors, l.topics,
      s.similarity_score, s.title_score, s.body_score, s.topic_score
    FROM legislation_similarities s
    JOIN legislation l ON l.id = s.target_legislation_id
    WHERE s.source_legislation_id = ? AND s.similarity_score >= ?
    ORDER BY s.similarity_score DESC
    LIMIT ?"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(legislation_id),
      sqlight.float(min_score),
      sqlight.int(max_results),
    ],
    expecting: similar_legislation_decoder(),
  )
}

/// Store a template-to-legislation match.
pub fn store_template_match(
  connection: sqlight.Connection,
  template_id: String,
  legislation_id: String,
  similarity_score: Float,
  title_score: Float,
  body_score: Float,
  topic_score: Float,
) -> Result(Nil, sqlight.Error) {
  let match_id = template_id <> ":" <> legislation_id

  let sql =
    "INSERT OR REPLACE INTO template_legislation_matches
      (id, template_id, legislation_id,
       similarity_score, title_score, body_score, topic_score)
     VALUES (?, ?, ?, ?, ?, ?, ?)"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(match_id),
      sqlight.text(template_id),
      sqlight.text(legislation_id),
      sqlight.float(similarity_score),
      sqlight.float(title_score),
      sqlight.float(body_score),
      sqlight.float(topic_score),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Find legislation matching a template, ordered by score descending.
pub fn find_template_matches(
  connection: sqlight.Connection,
  template_id: String,
  min_score: Float,
  max_results: Int,
) -> Result(List(TemplateMatch), sqlight.Error) {
  let sql =
    "SELECT
      l.id, l.title, l.summary, l.body,
      l.government_level, l.level_state_code, l.level_county_name,
      l.level_municipality_name,
      l.legislation_type, l.status, l.introduced_date,
      l.source_url, l.source_identifier, l.sponsors, l.topics,
      m.similarity_score, m.title_score, m.body_score, m.topic_score
    FROM template_legislation_matches m
    JOIN legislation l ON l.id = m.legislation_id
    WHERE m.template_id = ? AND m.similarity_score >= ?
    ORDER BY m.similarity_score DESC
    LIMIT ?"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(template_id),
      sqlight.float(min_score),
      sqlight.int(max_results),
    ],
    expecting: template_match_decoder(),
  )
}

/// Get adoption timeline: similar legislation sorted by introduced_date.
pub fn adoption_timeline(
  connection: sqlight.Connection,
  legislation_id: String,
  min_score: Float,
) -> Result(List(AdoptionEvent), sqlight.Error) {
  let sql =
    "SELECT
      l.id, l.title,
      l.government_level, l.level_state_code, l.level_county_name,
      l.level_municipality_name,
      l.introduced_date,
      s.similarity_score
    FROM legislation_similarities s
    JOIN legislation l ON l.id = s.target_legislation_id
    WHERE s.source_legislation_id = ? AND s.similarity_score >= ?
    ORDER BY l.introduced_date ASC"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(legislation_id),
      sqlight.float(min_score),
    ],
    expecting: adoption_event_decoder(),
  )
}

/// Delete all similarities for a given legislation (for recomputation).
pub fn delete_similarities_for(
  connection: sqlight.Connection,
  legislation_id: String,
) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(sqlight.query(
    "DELETE FROM legislation_similarities WHERE source_legislation_id = ?",
    on: connection,
    with: [sqlight.text(legislation_id)],
    expecting: decode.success(Nil),
  ))

  sqlight.query(
    "DELETE FROM legislation_similarities WHERE target_legislation_id = ?",
    on: connection,
    with: [sqlight.text(legislation_id)],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Count total precomputed similarities.
pub fn count_similarities(
  connection: sqlight.Connection,
) -> Result(Int, sqlight.Error) {
  let count_decoder = {
    use count <- decode.field(0, decode.int)
    decode.success(count)
  }

  use rows <- result.try(sqlight.query(
    "SELECT COUNT(*) FROM legislation_similarities",
    on: connection,
    with: [],
    expecting: count_decoder,
  ))

  case rows {
    [count, ..] -> Ok(count)
    [] -> Ok(0)
  }
}

// --- Row decoders ---

fn similar_legislation_decoder() -> decode.Decoder(SimilarLegislation) {
  use id_str <- decode.field(0, decode.string)
  use title <- decode.field(1, decode.string)
  use summary <- decode.field(2, decode.string)
  use body <- decode.field(3, decode.string)
  use level_str <- decode.field(4, decode.string)
  use state_code <- decode.field(5, decode.optional(decode.string))
  use county_name <- decode.field(6, decode.optional(decode.string))
  use municipality_name <- decode.field(7, decode.optional(decode.string))
  use leg_type_str <- decode.field(8, decode.string)
  use status_str <- decode.field(9, decode.string)
  use introduced_date <- decode.field(10, decode.string)
  use source_url <- decode.field(11, decode.optional(decode.string))
  use source_identifier <- decode.field(12, decode.string)
  use sponsors_json <- decode.field(13, decode.string)
  use topics_json <- decode.field(14, decode.string)
  use similarity_score <- decode.field(15, decode.float)
  use title_score <- decode.field(16, decode.float)
  use body_score <- decode.field(17, decode.float)
  use topic_score <- decode.field(18, decode.float)

  let level =
    government_level_from_columns(
      level_str,
      state_code,
      county_name,
      municipality_name,
    )

  decode.success(SimilarLegislation(
    legislation: Legislation(
      id: legislation.legislation_id(id_str),
      title:,
      summary:,
      body:,
      level:,
      legislation_type: legislation_type_from_db_string(leg_type_str),
      status: legislation_status_from_db_string(status_str),
      introduced_date:,
      source_url:,
      source_identifier:,
      sponsors: json_text_to_list(sponsors_json),
      topics: json_text_to_list(topics_json),
    ),
    similarity_score:,
    title_score:,
    body_score:,
    topic_score:,
  ))
}

fn template_match_decoder() -> decode.Decoder(TemplateMatch) {
  use id_str <- decode.field(0, decode.string)
  use title <- decode.field(1, decode.string)
  use summary <- decode.field(2, decode.string)
  use body <- decode.field(3, decode.string)
  use level_str <- decode.field(4, decode.string)
  use state_code <- decode.field(5, decode.optional(decode.string))
  use county_name <- decode.field(6, decode.optional(decode.string))
  use municipality_name <- decode.field(7, decode.optional(decode.string))
  use leg_type_str <- decode.field(8, decode.string)
  use status_str <- decode.field(9, decode.string)
  use introduced_date <- decode.field(10, decode.string)
  use source_url <- decode.field(11, decode.optional(decode.string))
  use source_identifier <- decode.field(12, decode.string)
  use sponsors_json <- decode.field(13, decode.string)
  use topics_json <- decode.field(14, decode.string)
  use similarity_score <- decode.field(15, decode.float)
  use title_score <- decode.field(16, decode.float)
  use body_score <- decode.field(17, decode.float)
  use topic_score <- decode.field(18, decode.float)

  let level =
    government_level_from_columns(
      level_str,
      state_code,
      county_name,
      municipality_name,
    )

  decode.success(TemplateMatch(
    legislation: Legislation(
      id: legislation.legislation_id(id_str),
      title:,
      summary:,
      body:,
      level:,
      legislation_type: legislation_type_from_db_string(leg_type_str),
      status: legislation_status_from_db_string(status_str),
      introduced_date:,
      source_url:,
      source_identifier:,
      sponsors: json_text_to_list(sponsors_json),
      topics: json_text_to_list(topics_json),
    ),
    similarity_score:,
    title_score:,
    body_score:,
    topic_score:,
  ))
}

fn adoption_event_decoder() -> decode.Decoder(AdoptionEvent) {
  use id_str <- decode.field(0, decode.string)
  use title <- decode.field(1, decode.string)
  use level_str <- decode.field(2, decode.string)
  use state_code <- decode.field(3, decode.optional(decode.string))
  use county_name <- decode.field(4, decode.optional(decode.string))
  use municipality_name <- decode.field(5, decode.optional(decode.string))
  use introduced_date <- decode.field(6, decode.string)
  use similarity_score <- decode.field(7, decode.float)

  let level =
    government_level_from_columns(
      level_str,
      state_code,
      county_name,
      municipality_name,
    )

  decode.success(AdoptionEvent(
    legislation_id: id_str,
    title:,
    level:,
    introduced_date:,
    similarity_score:,
  ))
}

// --- Shared helpers (duplicated from legislation_repo to avoid coupling) ---

fn government_level_from_columns(
  level_str: String,
  state_code: Option(String),
  county_name: Option(String),
  municipality_name: Option(String),
) -> GovernmentLevel {
  case level_str {
    "state" -> State(state_code: option.unwrap(state_code, ""))
    "county" ->
      County(
        state_code: option.unwrap(state_code, ""),
        county_name: option.unwrap(county_name, ""),
      )
    "municipal" ->
      Municipal(
        state_code: option.unwrap(state_code, ""),
        municipality_name: option.unwrap(municipality_name, ""),
      )
    _ -> Federal
  }
}

fn legislation_type_from_db_string(
  value: String,
) -> legislation_type.LegislationType {
  case value {
    "bill" -> legislation_type.Bill
    "resolution" -> legislation_type.Resolution
    "ordinance" -> legislation_type.Ordinance
    "bylaw" -> legislation_type.Bylaw
    "amendment" -> legislation_type.Amendment
    "regulation" -> legislation_type.Regulation
    "executive_order" -> legislation_type.ExecutiveOrder
    _ -> legislation_type.Bill
  }
}

fn legislation_status_from_db_string(
  value: String,
) -> legislation_status.LegislationStatus {
  case value {
    "introduced" -> legislation_status.Introduced
    "in_committee" -> legislation_status.InCommittee
    "passed_chamber" -> legislation_status.PassedChamber
    "enacted" -> legislation_status.Enacted
    "vetoed" -> legislation_status.Vetoed
    "expired" -> legislation_status.Expired
    "withdrawn" -> legislation_status.Withdrawn
    _ -> legislation_status.Introduced
  }
}

fn json_text_to_list(json_text: String) -> List(String) {
  case json.parse(json_text, decode.list(decode.string)) {
    Ok(items) -> items
    Error(_) -> []
  }
}
