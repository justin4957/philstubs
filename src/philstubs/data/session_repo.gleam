import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import philstubs/core/user.{type User, User}
import sqlight
import wisp

/// Session duration in seconds (7 days).
const session_max_age_seconds = 604_800

/// Create a new session for a user. Returns the session token string.
pub fn create_session(
  connection: sqlight.Connection,
  user_id_str: String,
) -> Result(String, sqlight.Error) {
  let session_token = wisp.random_string(64)

  let sql =
    "INSERT INTO sessions (token, user_id, expires_at)
     VALUES (?, ?, datetime('now', '+' || ? || ' seconds'))"

  use _ <- result.try(sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(session_token),
      sqlight.text(user_id_str),
      sqlight.int(session_max_age_seconds),
    ],
    expecting: decode.success(Nil),
  ))

  Ok(session_token)
}

/// Look up a session token and return the associated user if the session
/// is valid (exists and not expired).
pub fn get_user_by_session(
  connection: sqlight.Connection,
  session_token: String,
) -> Result(Option(User), sqlight.Error) {
  let sql =
    "SELECT u.id, u.github_id, u.username, u.display_name, u.avatar_url, u.created_at
     FROM sessions s
     JOIN users u ON u.id = s.user_id
     WHERE s.token = ? AND s.expires_at > datetime('now')"

  use rows <- result.try(sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(session_token)],
    expecting: user_row_decoder(),
  ))

  case rows {
    [found_user, ..] -> Ok(Some(found_user))
    [] -> Ok(None)
  }
}

/// Delete a specific session (used for logout).
pub fn delete_session(
  connection: sqlight.Connection,
  session_token: String,
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "DELETE FROM sessions WHERE token = ?",
    on: connection,
    with: [sqlight.text(session_token)],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Delete all expired sessions (cleanup).
pub fn delete_expired_sessions(
  connection: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "DELETE FROM sessions WHERE expires_at <= datetime('now')",
    on: connection,
    with: [],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Return the session max age in seconds (for cookie max_age).
pub fn max_age_seconds() -> Int {
  session_max_age_seconds
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
