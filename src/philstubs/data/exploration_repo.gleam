import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import philstubs/core/saved_exploration.{type SavedExploration, SavedExploration}
import sqlight

/// Insert a saved exploration record into the database.
pub fn insert(
  connection: sqlight.Connection,
  exploration: SavedExploration,
) -> Result(Nil, sqlight.Error) {
  let sql =
    "INSERT INTO saved_explorations (
      id, user_id, title, description, graph_state,
      created_at, updated_at, is_public
    ) VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'), ?)"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(saved_exploration.exploration_id_to_string(exploration.id)),
      sqlight.nullable(sqlight.text, exploration.user_id),
      sqlight.text(exploration.title),
      sqlight.text(exploration.description),
      sqlight.text(exploration.graph_state),
      sqlight.int(bool_to_int(exploration.is_public)),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Retrieve a saved exploration by its ID.
pub fn get_by_id(
  connection: sqlight.Connection,
  exploration_id: String,
) -> Result(Option(SavedExploration), sqlight.Error) {
  let sql =
    "SELECT id, user_id, title, description, graph_state,
      created_at, updated_at, is_public
    FROM saved_explorations WHERE id = ?"

  use rows <- result.try(sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(exploration_id)],
    expecting: exploration_row_decoder(),
  ))

  case rows {
    [exploration, ..] -> Ok(Some(exploration))
    [] -> Ok(None)
  }
}

/// List all explorations owned by a specific user, ordered by most recently updated.
pub fn list_by_user(
  connection: sqlight.Connection,
  user_id: String,
) -> Result(List(SavedExploration), sqlight.Error) {
  let sql =
    "SELECT id, user_id, title, description, graph_state,
      created_at, updated_at, is_public
    FROM saved_explorations WHERE user_id = ? ORDER BY updated_at DESC"

  sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(user_id)],
    expecting: exploration_row_decoder(),
  )
}

/// List all public explorations, ordered by most recently created.
pub fn list_public(
  connection: sqlight.Connection,
) -> Result(List(SavedExploration), sqlight.Error) {
  let sql =
    "SELECT id, user_id, title, description, graph_state,
      created_at, updated_at, is_public
    FROM saved_explorations WHERE is_public = 1 ORDER BY created_at DESC"

  sqlight.query(
    sql,
    on: connection,
    with: [],
    expecting: exploration_row_decoder(),
  )
}

/// Update a saved exploration. Overwrites title, description, graph_state, is_public.
pub fn update(
  connection: sqlight.Connection,
  exploration: SavedExploration,
) -> Result(Nil, sqlight.Error) {
  let sql =
    "UPDATE saved_explorations SET
      title = ?, description = ?, graph_state = ?,
      is_public = ?, updated_at = datetime('now')
    WHERE id = ?"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(exploration.title),
      sqlight.text(exploration.description),
      sqlight.text(exploration.graph_state),
      sqlight.int(bool_to_int(exploration.is_public)),
      sqlight.text(saved_exploration.exploration_id_to_string(exploration.id)),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Delete a saved exploration by its ID.
pub fn delete(
  connection: sqlight.Connection,
  exploration_id: String,
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "DELETE FROM saved_explorations WHERE id = ?",
    on: connection,
    with: [sqlight.text(exploration_id)],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

// --- Row decoder ---

fn exploration_row_decoder() -> decode.Decoder(SavedExploration) {
  use id_str <- decode.field(0, decode.string)
  use user_id <- decode.field(1, decode.optional(decode.string))
  use title <- decode.field(2, decode.string)
  use description <- decode.field(3, decode.string)
  use graph_state <- decode.field(4, decode.string)
  use created_at <- decode.field(5, decode.string)
  use updated_at <- decode.field(6, decode.string)
  use is_public_int <- decode.field(7, decode.int)

  decode.success(SavedExploration(
    id: saved_exploration.exploration_id(id_str),
    user_id:,
    title:,
    description:,
    graph_state:,
    created_at:,
    updated_at:,
    is_public: int_to_bool(is_public_int),
  ))
}

// --- Bool ↔ Int helpers ---

fn bool_to_int(value: Bool) -> Int {
  case value {
    True -> 1
    False -> 0
  }
}

fn int_to_bool(value: Int) -> Bool {
  value != 0
}
