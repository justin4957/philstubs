import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import philstubs/core/user
import philstubs/data/database
import philstubs/data/session_repo
import philstubs/data/test_helpers
import philstubs/data/user_repo

fn create_test_user(connection) {
  let assert Ok(test_user) =
    user_repo.upsert_from_github(
      connection,
      42_000,
      "sessiontester",
      "Session Tester",
      "",
    )
  test_user
}

pub fn create_session_returns_token_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let test_user = create_test_user(connection)
  let user_id_str = user.user_id_to_string(test_user.id)

  let result = session_repo.create_session(connection, user_id_str)

  result |> should.be_ok
  let assert Ok(session_token) = result
  // Token should be a non-empty string
  string.length(session_token) |> should.not_equal(0)
}

pub fn get_user_by_session_valid_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let test_user = create_test_user(connection)
  let user_id_str = user.user_id_to_string(test_user.id)

  let assert Ok(session_token) =
    session_repo.create_session(connection, user_id_str)

  let result = session_repo.get_user_by_session(connection, session_token)

  result |> should.be_ok
  let assert Ok(Some(found_user)) = result
  found_user.username |> should.equal("sessiontester")
  found_user.github_id |> should.equal(42_000)
}

pub fn get_user_by_session_invalid_token_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let result = session_repo.get_user_by_session(connection, "nonexistent-token")

  result |> should.be_ok
  let assert Ok(None) = result
}

pub fn delete_session_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let test_user = create_test_user(connection)
  let user_id_str = user.user_id_to_string(test_user.id)

  let assert Ok(session_token) =
    session_repo.create_session(connection, user_id_str)

  // Session should be valid initially
  let assert Ok(Some(_)) =
    session_repo.get_user_by_session(connection, session_token)

  // Delete the session
  let delete_result = session_repo.delete_session(connection, session_token)
  delete_result |> should.be_ok

  // Session should no longer be valid
  let assert Ok(None) =
    session_repo.get_user_by_session(connection, session_token)
}

pub fn delete_expired_sessions_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  // delete_expired_sessions should succeed even with no sessions
  let result = session_repo.delete_expired_sessions(connection)
  result |> should.be_ok
}

pub fn max_age_seconds_test() {
  // Session max age should be 7 days
  session_repo.max_age_seconds() |> should.equal(604_800)
}
