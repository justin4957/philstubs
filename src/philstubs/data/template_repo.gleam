import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import philstubs/core/government_level.{
  type GovernmentLevel, County, Federal, Municipal, State,
}
import philstubs/core/legislation_template.{
  type LegislationTemplate, LegislationTemplate,
}
import philstubs/core/legislation_type.{type LegislationType}
import sqlight

/// Insert a template record into the database.
pub fn insert(
  connection: sqlight.Connection,
  template: LegislationTemplate,
) -> Result(Nil, sqlight.Error) {
  let #(level_str, state_code, county_name, municipality_name) =
    government_level_to_columns(template.suggested_level)

  let sql =
    "INSERT INTO legislation_templates (
      id, title, description, body,
      suggested_level, suggested_level_state_code,
      suggested_level_county_name, suggested_level_municipality_name,
      suggested_type, author, topics, download_count, created_at,
      owner_user_id
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(legislation_template.template_id_to_string(template.id)),
      sqlight.text(template.title),
      sqlight.text(template.description),
      sqlight.text(template.body),
      sqlight.text(level_str),
      sqlight.nullable(sqlight.text, state_code),
      sqlight.nullable(sqlight.text, county_name),
      sqlight.nullable(sqlight.text, municipality_name),
      sqlight.text(legislation_type_to_db_string(template.suggested_type)),
      sqlight.text(template.author),
      sqlight.text(list_to_json_text(template.topics)),
      sqlight.int(template.download_count),
      sqlight.text(template.created_at),
      sqlight.nullable(sqlight.text, template.owner_user_id),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Retrieve a template by its ID.
pub fn get_by_id(
  connection: sqlight.Connection,
  template_id: String,
) -> Result(Option(LegislationTemplate), sqlight.Error) {
  let sql =
    "SELECT
    id, title, description, body,
    suggested_level, suggested_level_state_code,
    suggested_level_county_name, suggested_level_municipality_name,
    suggested_type, author, topics, download_count, created_at,
    owner_user_id
    FROM legislation_templates WHERE id = ?"

  use rows <- result.try(sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(template_id)],
    expecting: template_row_decoder(),
  ))

  case rows {
    [template, ..] -> Ok(Some(template))
    [] -> Ok(None)
  }
}

/// List all templates.
pub fn list_all(
  connection: sqlight.Connection,
) -> Result(List(LegislationTemplate), sqlight.Error) {
  let sql =
    "SELECT
    id, title, description, body,
    suggested_level, suggested_level_state_code,
    suggested_level_county_name, suggested_level_municipality_name,
    suggested_type, author, topics, download_count, created_at,
    owner_user_id
    FROM legislation_templates ORDER BY created_at DESC"

  sqlight.query(
    sql,
    on: connection,
    with: [],
    expecting: template_row_decoder(),
  )
}

/// Update a template record. All fields are overwritten.
pub fn update(
  connection: sqlight.Connection,
  template: LegislationTemplate,
) -> Result(Nil, sqlight.Error) {
  let #(level_str, state_code, county_name, municipality_name) =
    government_level_to_columns(template.suggested_level)

  let sql =
    "UPDATE legislation_templates SET
      title = ?, description = ?, body = ?,
      suggested_level = ?, suggested_level_state_code = ?,
      suggested_level_county_name = ?, suggested_level_municipality_name = ?,
      suggested_type = ?, author = ?, topics = ?,
      download_count = ?, created_at = ?,
      owner_user_id = ?,
      updated_at = datetime('now')
    WHERE id = ?"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(template.title),
      sqlight.text(template.description),
      sqlight.text(template.body),
      sqlight.text(level_str),
      sqlight.nullable(sqlight.text, state_code),
      sqlight.nullable(sqlight.text, county_name),
      sqlight.nullable(sqlight.text, municipality_name),
      sqlight.text(legislation_type_to_db_string(template.suggested_type)),
      sqlight.text(template.author),
      sqlight.text(list_to_json_text(template.topics)),
      sqlight.int(template.download_count),
      sqlight.text(template.created_at),
      sqlight.nullable(sqlight.text, template.owner_user_id),
      sqlight.text(legislation_template.template_id_to_string(template.id)),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Delete a template by its ID.
pub fn delete(
  connection: sqlight.Connection,
  template_id: String,
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "DELETE FROM legislation_templates WHERE id = ?",
    on: connection,
    with: [sqlight.text(template_id)],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// List all templates owned by a specific user.
pub fn list_by_owner(
  connection: sqlight.Connection,
  owner_id: String,
) -> Result(List(LegislationTemplate), sqlight.Error) {
  let sql =
    "SELECT
    id, title, description, body,
    suggested_level, suggested_level_state_code,
    suggested_level_county_name, suggested_level_municipality_name,
    suggested_type, author, topics, download_count, created_at,
    owner_user_id
    FROM legislation_templates WHERE owner_user_id = ? ORDER BY created_at DESC"

  sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(owner_id)],
    expecting: template_row_decoder(),
  )
}

/// Full-text search across templates using FTS5.
pub fn search(
  connection: sqlight.Connection,
  query_text: String,
) -> Result(List(LegislationTemplate), sqlight.Error) {
  let sql =
    "SELECT
      t.id, t.title, t.description, t.body,
      t.suggested_level, t.suggested_level_state_code,
      t.suggested_level_county_name, t.suggested_level_municipality_name,
      t.suggested_type, t.author, t.topics, t.download_count, t.created_at,
      t.owner_user_id
    FROM templates_fts fts
    JOIN legislation_templates t ON t.rowid = fts.rowid
    WHERE templates_fts MATCH ?
    ORDER BY rank"

  sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(query_text)],
    expecting: template_row_decoder(),
  )
}

/// Count all templates in the database.
pub fn count_all(connection: sqlight.Connection) -> Result(Int, sqlight.Error) {
  let count_decoder = {
    use count <- decode.field(0, decode.int)
    decode.success(count)
  }

  use rows <- result.try(sqlight.query(
    "SELECT COUNT(*) FROM legislation_templates",
    on: connection,
    with: [],
    expecting: count_decoder,
  ))

  case rows {
    [count, ..] -> Ok(count)
    [] -> Ok(0)
  }
}

/// Increment the download count for a template.
pub fn increment_download_count(
  connection: sqlight.Connection,
  template_id: String,
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "UPDATE legislation_templates
     SET download_count = download_count + 1, updated_at = datetime('now')
     WHERE id = ?",
    on: connection,
    with: [sqlight.text(template_id)],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

// --- Row decoder ---

fn template_row_decoder() -> decode.Decoder(LegislationTemplate) {
  use id_str <- decode.field(0, decode.string)
  use title <- decode.field(1, decode.string)
  use description <- decode.field(2, decode.string)
  use body <- decode.field(3, decode.string)
  use level_str <- decode.field(4, decode.string)
  use state_code <- decode.field(5, decode.optional(decode.string))
  use county_name <- decode.field(6, decode.optional(decode.string))
  use municipality_name <- decode.field(7, decode.optional(decode.string))
  use suggested_type_str <- decode.field(8, decode.string)
  use author <- decode.field(9, decode.string)
  use topics_json <- decode.field(10, decode.string)
  use download_count <- decode.field(11, decode.int)
  use created_at <- decode.field(12, decode.string)
  use owner_user_id <- decode.field(13, decode.optional(decode.string))

  let suggested_level =
    government_level_from_columns(
      level_str,
      state_code,
      county_name,
      municipality_name,
    )
  let suggested_type = legislation_type_from_db_string(suggested_type_str)

  decode.success(LegislationTemplate(
    id: legislation_template.template_id(id_str),
    title:,
    description:,
    body:,
    suggested_level:,
    suggested_type:,
    author:,
    topics: json_text_to_list(topics_json),
    created_at:,
    download_count:,
    owner_user_id:,
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
