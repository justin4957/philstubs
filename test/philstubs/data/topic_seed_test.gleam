import gleeunit/should
import philstubs/data/database
import philstubs/data/test_helpers
import philstubs/data/topic_seed

pub fn seed_topic_taxonomy_creates_topics_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(topic_count) = topic_seed.seed_topic_taxonomy(connection)

  // 9 parent topics + 27 children = 36 total
  topic_count |> should.equal(36)
}

pub fn seed_topic_taxonomy_idempotent_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(first_count) = topic_seed.seed_topic_taxonomy(connection)
  let assert Ok(second_count) = topic_seed.seed_topic_taxonomy(connection)

  // Both should return the same count since INSERT OR IGNORE is used
  first_count |> should.equal(36)
  second_count |> should.equal(36)
}
