import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import philstubs/core/user.{type User, User}
import sqlight

/// Upsert a user from GitHub OAuth data. Creates the user if they don't exist,
/// or updates their profile fields if they do (matched by github_id).
pub fn upsert_from_github(
  connection: sqlight.Connection,
  github_id: Int,
  username: String,
  display_name: String,
  avatar_url: String,
) -> Result(User, sqlight.Error) {
  let user_id_str = "github-" <> username

  let sql =
    "INSERT INTO users (id, github_id, username, display_name, avatar_url)
     VALUES (?, ?, ?, ?, ?)
     ON CONFLICT(github_id) DO UPDATE SET
       username = excluded.username,
       display_name = excluded.display_name,
       avatar_url = excluded.avatar_url,
       updated_at = datetime('now')
     RETURNING id, github_id, username, display_name, avatar_url, created_at"

  use rows <- result.try(sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(user_id_str),
      sqlight.int(github_id),
      sqlight.text(username),
      sqlight.text(display_name),
      sqlight.text(avatar_url),
    ],
    expecting: user_row_decoder(),
  ))

  case rows {
    [returned_user, ..] -> Ok(returned_user)
    [] ->
      Error(sqlight.SqlightError(
        sqlight.GenericError,
        "No user returned from upsert",
        -1,
      ))
  }
}

/// Retrieve a user by their internal ID.
pub fn get_by_id(
  connection: sqlight.Connection,
  user_id_str: String,
) -> Result(Option(User), sqlight.Error) {
  let sql =
    "SELECT id, github_id, username, display_name, avatar_url, created_at
     FROM users WHERE id = ?"

  use rows <- result.try(sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(user_id_str)],
    expecting: user_row_decoder(),
  ))

  case rows {
    [found_user, ..] -> Ok(Some(found_user))
    [] -> Ok(None)
  }
}

/// Retrieve a user by their GitHub ID.
pub fn get_by_github_id(
  connection: sqlight.Connection,
  github_id: Int,
) -> Result(Option(User), sqlight.Error) {
  let sql =
    "SELECT id, github_id, username, display_name, avatar_url, created_at
     FROM users WHERE github_id = ?"

  use rows <- result.try(sqlight.query(
    sql,
    on: connection,
    with: [sqlight.int(github_id)],
    expecting: user_row_decoder(),
  ))

  case rows {
    [found_user, ..] -> Ok(Some(found_user))
    [] -> Ok(None)
  }
}

// --- Row decoder ---

fn user_row_decoder() -> decode.Decoder(User) {
  use id_str <- decode.field(0, decode.string)
  use github_id <- decode.field(1, decode.int)
  use username <- decode.field(2, decode.string)
  use display_name <- decode.field(3, decode.string)
  use avatar_url <- decode.field(4, decode.string)
  use created_at <- decode.field(5, decode.string)
  decode.success(User(
    id: user.user_id(id_str),
    github_id:,
    username:,
    display_name:,
    avatar_url:,
    created_at:,
  ))
}
