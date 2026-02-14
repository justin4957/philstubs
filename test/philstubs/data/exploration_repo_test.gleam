import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import philstubs/core/saved_exploration.{SavedExploration}
import philstubs/data/database
import philstubs/data/exploration_repo
import philstubs/data/test_helpers

fn sample_exploration() -> saved_exploration.SavedExploration {
  SavedExploration(
    id: saved_exploration.exploration_id("expl-test-001"),
    user_id: Some("user-1"),
    title: "Healthcare Network",
    description: "Exploring healthcare legislation connections",
    graph_state: "{\"nodes\":[],\"edges\":[]}",
    created_at: "",
    updated_at: "",
    is_public: False,
  )
}

fn sample_public_exploration() -> saved_exploration.SavedExploration {
  SavedExploration(
    id: saved_exploration.exploration_id("expl-test-002"),
    user_id: Some("user-2"),
    title: "Public Housing Graph",
    description: "Shared housing legislation map",
    graph_state: "{\"nodes\":[{\"id\":\"leg-1\"}],\"edges\":[]}",
    created_at: "",
    updated_at: "",
    is_public: True,
  )
}

pub fn insert_and_get_by_id_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let exploration = sample_exploration()
  let assert Ok(Nil) = exploration_repo.insert(connection, exploration)

  let assert Ok(Some(retrieved)) =
    exploration_repo.get_by_id(connection, "expl-test-001")

  saved_exploration.exploration_id_to_string(retrieved.id)
  |> should.equal("expl-test-001")
  retrieved.user_id |> should.equal(Some("user-1"))
  retrieved.title |> should.equal("Healthcare Network")
  retrieved.description
  |> should.equal("Exploring healthcare legislation connections")
  retrieved.graph_state |> should.equal("{\"nodes\":[],\"edges\":[]}")
  retrieved.is_public |> should.equal(False)
}

pub fn get_by_id_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let result = exploration_repo.get_by_id(connection, "nonexistent-id")
  result |> should.equal(Ok(None))
}

pub fn list_by_user_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) = exploration_repo.insert(connection, sample_exploration())
  let assert Ok(Nil) =
    exploration_repo.insert(connection, sample_public_exploration())

  // user-1 has 1 exploration
  let assert Ok(user_explorations) =
    exploration_repo.list_by_user(connection, "user-1")
  user_explorations |> list.length |> should.equal(1)

  // user-2 has 1 exploration
  let assert Ok(user2_explorations) =
    exploration_repo.list_by_user(connection, "user-2")
  user2_explorations |> list.length |> should.equal(1)

  // user-3 has 0 explorations
  let assert Ok(empty_list) =
    exploration_repo.list_by_user(connection, "user-3")
  empty_list |> list.length |> should.equal(0)
}

pub fn list_public_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) = exploration_repo.insert(connection, sample_exploration())
  let assert Ok(Nil) =
    exploration_repo.insert(connection, sample_public_exploration())

  let assert Ok(public_explorations) = exploration_repo.list_public(connection)
  // Only the public one should appear
  public_explorations |> list.length |> should.equal(1)
  let assert [public_item] = public_explorations
  saved_exploration.exploration_id_to_string(public_item.id)
  |> should.equal("expl-test-002")
}

pub fn update_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let exploration = sample_exploration()
  let assert Ok(Nil) = exploration_repo.insert(connection, exploration)

  let updated_exploration =
    SavedExploration(
      ..exploration,
      title: "Updated Network",
      description: "Revised description",
      graph_state: "{\"nodes\":[{\"id\":\"new\"}],\"edges\":[]}",
      is_public: True,
    )
  let assert Ok(Nil) = exploration_repo.update(connection, updated_exploration)

  let assert Ok(Some(retrieved)) =
    exploration_repo.get_by_id(connection, "expl-test-001")
  retrieved.title |> should.equal("Updated Network")
  retrieved.description |> should.equal("Revised description")
  retrieved.graph_state
  |> should.equal("{\"nodes\":[{\"id\":\"new\"}],\"edges\":[]}")
  retrieved.is_public |> should.equal(True)
}

pub fn delete_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) = exploration_repo.insert(connection, sample_exploration())
  let assert Ok(Some(_)) =
    exploration_repo.get_by_id(connection, "expl-test-001")

  let assert Ok(Nil) = exploration_repo.delete(connection, "expl-test-001")
  let result = exploration_repo.get_by_id(connection, "expl-test-001")
  result |> should.equal(Ok(None))
}
