import gleam/dynamic/decode
import gleam/list
import gleeunit/should
import philstubs/data/database
import philstubs/data/migration
import philstubs/data/test_helpers
import sqlight

pub fn run_migrations_fresh_database_test() {
  use connection <- database.with_named_connection(":memory:")

  let result = test_helpers.setup_test_db(connection)
  result |> should.be_ok

  let assert Ok(applied_versions) = result
  applied_versions |> list.length |> should.equal(4)
  applied_versions |> should.equal(["001", "002", "003", "005"])

  // Verify legislation table exists
  let table_check =
    sqlight.query(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='legislation'",
      on: connection,
      with: [],
      expecting: {
        use name <- decode.field(0, decode.string)
        decode.success(name)
      },
    )
  let assert Ok(tables) = table_check
  tables |> should.equal(["legislation"])

  // Verify legislation_templates table exists
  let template_table_check =
    sqlight.query(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='legislation_templates'",
      on: connection,
      with: [],
      expecting: {
        use name <- decode.field(0, decode.string)
        decode.success(name)
      },
    )
  let assert Ok(template_tables) = template_table_check
  template_tables |> should.equal(["legislation_templates"])
}

pub fn run_migrations_idempotent_test() {
  use connection <- database.with_named_connection(":memory:")

  // Run migrations twice
  let first_run = test_helpers.setup_test_db(connection)
  first_run |> should.be_ok
  let assert Ok(first_applied) = first_run

  let second_run =
    migration.run_migrations_from_sql(connection, test_helpers.all_migrations())
  second_run |> should.be_ok
  let assert Ok(second_applied) = second_run

  // First run applies all four, second run applies none
  first_applied |> list.length |> should.equal(4)
  second_applied |> list.length |> should.equal(0)
}
