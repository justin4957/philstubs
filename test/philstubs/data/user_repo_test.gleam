import gleam/option.{None, Some}
import gleeunit/should
import philstubs/core/user
import philstubs/data/database
import philstubs/data/test_helpers
import philstubs/data/user_repo

pub fn upsert_creates_new_user_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let result =
    user_repo.upsert_from_github(
      connection,
      42_000,
      "octocat",
      "The Octocat",
      "https://avatars.example.com/octocat.png",
    )

  result |> should.be_ok
  let assert Ok(created_user) = result
  created_user.github_id |> should.equal(42_000)
  created_user.username |> should.equal("octocat")
  created_user.display_name |> should.equal("The Octocat")
  created_user.avatar_url
  |> should.equal("https://avatars.example.com/octocat.png")
  user.user_id_to_string(created_user.id) |> should.equal("github-octocat")
}

pub fn upsert_updates_existing_user_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  // Create the user first
  let assert Ok(original_user) =
    user_repo.upsert_from_github(connection, 42_000, "octocat", "Old Name", "")

  // Upsert again with updated fields
  let assert Ok(updated_user) =
    user_repo.upsert_from_github(
      connection,
      42_000,
      "octocat-new",
      "New Name",
      "https://new-avatar.example.com",
    )

  // ID should remain the same (based on original username)
  user.user_id_to_string(updated_user.id)
  |> should.equal(user.user_id_to_string(original_user.id))
  // Fields should be updated
  updated_user.username |> should.equal("octocat-new")
  updated_user.display_name |> should.equal("New Name")
  updated_user.avatar_url |> should.equal("https://new-avatar.example.com")
}

pub fn get_by_id_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(created_user) =
    user_repo.upsert_from_github(connection, 42_000, "octocat", "Octocat", "")

  let user_id_str = user.user_id_to_string(created_user.id)
  let result = user_repo.get_by_id(connection, user_id_str)

  result |> should.be_ok
  let assert Ok(Some(found_user)) = result
  found_user.username |> should.equal("octocat")
}

pub fn get_by_id_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let result = user_repo.get_by_id(connection, "nonexistent-id")

  result |> should.be_ok
  let assert Ok(None) = result
}

pub fn get_by_github_id_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(_) =
    user_repo.upsert_from_github(connection, 42_000, "octocat", "Octocat", "")

  let result = user_repo.get_by_github_id(connection, 42_000)

  result |> should.be_ok
  let assert Ok(Some(found_user)) = result
  found_user.username |> should.equal("octocat")
  found_user.github_id |> should.equal(42_000)
}

pub fn get_by_github_id_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let result = user_repo.get_by_github_id(connection, 99_999)

  result |> should.be_ok
  let assert Ok(None) = result
}
