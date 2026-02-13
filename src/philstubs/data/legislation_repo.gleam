import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import philstubs/core/government_level.{
  type GovernmentLevel, County, Federal, Municipal, State,
}
import philstubs/core/legislation.{type Legislation, Legislation}
import philstubs/core/legislation_status.{type LegislationStatus}
import philstubs/core/legislation_type.{type LegislationType}
import sqlight

/// Insert a legislation record into the database.
pub fn insert(
  connection: sqlight.Connection,
  record: Legislation,
) -> Result(Nil, sqlight.Error) {
  let #(level_str, state_code, county_name, municipality_name) =
    government_level_to_columns(record.level)

  let sql =
    "INSERT INTO legislation (
      id, title, summary, body,
      government_level, level_state_code, level_county_name, level_municipality_name,
      legislation_type, status, introduced_date,
      source_url, source_identifier, sponsors, topics
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(legislation.legislation_id_to_string(record.id)),
      sqlight.text(record.title),
      sqlight.text(record.summary),
      sqlight.text(record.body),
      sqlight.text(level_str),
      sqlight.nullable(sqlight.text, state_code),
      sqlight.nullable(sqlight.text, county_name),
      sqlight.nullable(sqlight.text, municipality_name),
      sqlight.text(legislation_type_to_db_string(record.legislation_type)),
      sqlight.text(legislation_status_to_db_string(record.status)),
      sqlight.text(record.introduced_date),
      sqlight.nullable(sqlight.text, record.source_url),
      sqlight.text(record.source_identifier),
      sqlight.text(list_to_json_text(record.sponsors)),
      sqlight.text(list_to_json_text(record.topics)),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Retrieve a legislation record by its ID.
pub fn get_by_id(
  connection: sqlight.Connection,
  legislation_id: String,
) -> Result(Option(Legislation), sqlight.Error) {
  let sql =
    "SELECT
    id, title, summary, body,
    government_level, level_state_code, level_county_name, level_municipality_name,
    legislation_type, status, introduced_date,
    source_url, source_identifier, sponsors, topics
    FROM legislation WHERE id = ?"

  use rows <- result.try(sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(legislation_id)],
    expecting: legislation_row_decoder(),
  ))

  case rows {
    [record, ..] -> Ok(Some(record))
    [] -> Ok(None)
  }
}

/// List all legislation records.
pub fn list_all(
  connection: sqlight.Connection,
) -> Result(List(Legislation), sqlight.Error) {
  let sql =
    "SELECT
    id, title, summary, body,
    government_level, level_state_code, level_county_name, level_municipality_name,
    legislation_type, status, introduced_date,
    source_url, source_identifier, sponsors, topics
    FROM legislation ORDER BY created_at DESC"

  sqlight.query(
    sql,
    on: connection,
    with: [],
    expecting: legislation_row_decoder(),
  )
}

/// Update a legislation record. All fields are overwritten.
pub fn update(
  connection: sqlight.Connection,
  record: Legislation,
) -> Result(Nil, sqlight.Error) {
  let #(level_str, state_code, county_name, municipality_name) =
    government_level_to_columns(record.level)

  let sql =
    "UPDATE legislation SET
      title = ?, summary = ?, body = ?,
      government_level = ?, level_state_code = ?,
      level_county_name = ?, level_municipality_name = ?,
      legislation_type = ?, status = ?, introduced_date = ?,
      source_url = ?, source_identifier = ?, sponsors = ?, topics = ?,
      updated_at = datetime('now')
    WHERE id = ?"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(record.title),
      sqlight.text(record.summary),
      sqlight.text(record.body),
      sqlight.text(level_str),
      sqlight.nullable(sqlight.text, state_code),
      sqlight.nullable(sqlight.text, county_name),
      sqlight.nullable(sqlight.text, municipality_name),
      sqlight.text(legislation_type_to_db_string(record.legislation_type)),
      sqlight.text(legislation_status_to_db_string(record.status)),
      sqlight.text(record.introduced_date),
      sqlight.nullable(sqlight.text, record.source_url),
      sqlight.text(record.source_identifier),
      sqlight.text(list_to_json_text(record.sponsors)),
      sqlight.text(list_to_json_text(record.topics)),
      sqlight.text(legislation.legislation_id_to_string(record.id)),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Delete a legislation record by its ID.
pub fn delete(
  connection: sqlight.Connection,
  legislation_id: String,
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "DELETE FROM legislation WHERE id = ?",
    on: connection,
    with: [sqlight.text(legislation_id)],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Full-text search across legislation using FTS5.
pub fn search(
  connection: sqlight.Connection,
  query_text: String,
) -> Result(List(Legislation), sqlight.Error) {
  let sql =
    "SELECT
      l.id, l.title, l.summary, l.body,
      l.government_level, l.level_state_code, l.level_county_name, l.level_municipality_name,
      l.legislation_type, l.status, l.introduced_date,
      l.source_url, l.source_identifier, l.sponsors, l.topics
    FROM legislation_fts fts
    JOIN legislation l ON l.rowid = fts.rowid
    WHERE legislation_fts MATCH ?
    ORDER BY rank"

  sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(query_text)],
    expecting: legislation_row_decoder(),
  )
}

/// Find legislation related to the given record by matching topics via FTS5.
/// Excludes the legislation itself and limits to a small set of results.
pub fn find_related(
  connection: sqlight.Connection,
  legislation_id: String,
  topics: List(String),
  max_results: Int,
) -> Result(List(Legislation), sqlight.Error) {
  case topics {
    [] -> Ok([])
    topic_list -> {
      let query_text = string.join(topic_list, " OR ")
      let sql =
        "SELECT
          l.id, l.title, l.summary, l.body,
          l.government_level, l.level_state_code, l.level_county_name, l.level_municipality_name,
          l.legislation_type, l.status, l.introduced_date,
          l.source_url, l.source_identifier, l.sponsors, l.topics
        FROM legislation_fts fts
        JOIN legislation l ON l.rowid = fts.rowid
        WHERE legislation_fts MATCH ? AND l.id != ?
        ORDER BY rank
        LIMIT ?"

      sqlight.query(
        sql,
        on: connection,
        with: [
          sqlight.text(query_text),
          sqlight.text(legislation_id),
          sqlight.int(max_results),
        ],
        expecting: legislation_row_decoder(),
      )
    }
  }
}

// --- Row decoder ---

fn legislation_row_decoder() -> decode.Decoder(Legislation) {
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

  let level =
    government_level_from_columns(
      level_str,
      state_code,
      county_name,
      municipality_name,
    )
  let leg_type = legislation_type_from_db_string(leg_type_str)
  let status = legislation_status_from_db_string(status_str)

  decode.success(Legislation(
    id: legislation.legislation_id(id_str),
    title:,
    summary:,
    body:,
    level:,
    legislation_type: leg_type,
    status:,
    introduced_date:,
    source_url:,
    source_identifier:,
    sponsors: json_text_to_list(sponsors_json),
    topics: json_text_to_list(topics_json),
  ))
}

// --- GovernmentLevel ↔ DB columns ---

fn government_level_to_columns(
  level: GovernmentLevel,
) -> #(String, Option(String), Option(String), Option(String)) {
  case level {
    Federal -> #("federal", None, None, None)
    State(state_code:) -> #("state", Some(state_code), None, None)
    County(state_code:, county_name:) -> #(
      "county",
      Some(state_code),
      Some(county_name),
      None,
    )
    Municipal(state_code:, municipality_name:) -> #(
      "municipal",
      Some(state_code),
      None,
      Some(municipality_name),
    )
  }
}

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
    // Default to Federal for "federal" and any unknown value
    _ -> Federal
  }
}

// --- LegislationType ↔ DB string ---

fn legislation_type_to_db_string(leg_type: LegislationType) -> String {
  case leg_type {
    legislation_type.Bill -> "bill"
    legislation_type.Resolution -> "resolution"
    legislation_type.Ordinance -> "ordinance"
    legislation_type.Bylaw -> "bylaw"
    legislation_type.Amendment -> "amendment"
    legislation_type.Regulation -> "regulation"
    legislation_type.ExecutiveOrder -> "executive_order"
  }
}

fn legislation_type_from_db_string(value: String) -> LegislationType {
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

// --- LegislationStatus ↔ DB string ---

fn legislation_status_to_db_string(status: LegislationStatus) -> String {
  case status {
    legislation_status.Introduced -> "introduced"
    legislation_status.InCommittee -> "in_committee"
    legislation_status.PassedChamber -> "passed_chamber"
    legislation_status.Enacted -> "enacted"
    legislation_status.Vetoed -> "vetoed"
    legislation_status.Expired -> "expired"
    legislation_status.Withdrawn -> "withdrawn"
  }
}

fn legislation_status_from_db_string(value: String) -> LegislationStatus {
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

// --- JSON list helpers ---

fn list_to_json_text(items: List(String)) -> String {
  json.array(items, json.string)
  |> json.to_string
}

fn json_text_to_list(json_text: String) -> List(String) {
  case json.parse(json_text, decode.list(decode.string)) {
    Ok(items) -> items
    Error(_) -> []
  }
}
