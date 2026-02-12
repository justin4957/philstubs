import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
import simplifile
import sqlight
import wisp

/// Run all pending migrations from the priv/migrations/ directory.
/// Returns the list of migration versions that were applied.
pub fn run_migrations(
  connection: sqlight.Connection,
) -> Result(List(String), sqlight.Error) {
  use _ <- result.try(ensure_schema_migrations_table(connection))
  use applied <- result.try(get_applied_migrations(connection))
  use migration_files <- result.try(
    read_migration_files()
    |> result.map_error(fn(_file_error) {
      sqlight.SqlightError(
        sqlight.GenericError,
        "Failed to read migration files",
        -1,
      )
    }),
  )

  let pending_migrations =
    migration_files
    |> list.filter(fn(migration) { !list.contains(applied, migration.version) })
    |> list.sort(fn(migration_a, migration_b) {
      string.compare(migration_a.version, migration_b.version)
    })

  apply_pending_migrations(connection, pending_migrations, [])
}

/// Run migrations using inline SQL strings instead of reading from files.
/// Useful for testing where priv/ directory may not be available.
pub fn run_migrations_from_sql(
  connection: sqlight.Connection,
  migrations: List(#(String, String)),
) -> Result(List(String), sqlight.Error) {
  use _ <- result.try(ensure_schema_migrations_table(connection))
  use applied <- result.try(get_applied_migrations(connection))

  let pending_migrations =
    migrations
    |> list.filter_map(fn(migration_pair) {
      let #(version, sql_content) = migration_pair
      case list.contains(applied, version) {
        True -> Error(Nil)
        False -> Ok(MigrationFile(version:, sql: sql_content))
      }
    })
    |> list.sort(fn(migration_a, migration_b) {
      string.compare(migration_a.version, migration_b.version)
    })

  apply_pending_migrations(connection, pending_migrations, [])
}

type MigrationFile {
  MigrationFile(version: String, sql: String)
}

fn ensure_schema_migrations_table(
  connection: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  sqlight.exec(
    "CREATE TABLE IF NOT EXISTS schema_migrations (
      version TEXT PRIMARY KEY,
      applied_at TEXT NOT NULL DEFAULT (datetime('now'))
    )",
    on: connection,
  )
}

fn get_applied_migrations(
  connection: sqlight.Connection,
) -> Result(List(String), sqlight.Error) {
  let version_decoder = {
    use version <- decode.field(0, decode.string)
    decode.success(version)
  }
  sqlight.query(
    "SELECT version FROM schema_migrations ORDER BY version",
    on: connection,
    with: [],
    expecting: version_decoder,
  )
}

fn read_migration_files() -> Result(List(MigrationFile), simplifile.FileError) {
  let migrations_dir = migrations_directory()
  use file_names <- result.try(simplifile.read_directory(migrations_dir))

  let sql_files =
    file_names
    |> list.filter(fn(file_name) { string.ends_with(file_name, ".sql") })
    |> list.sort(string.compare)

  list.try_map(sql_files, fn(file_name) {
    let file_path = migrations_dir <> "/" <> file_name
    use sql_content <- result.try(simplifile.read(file_path))
    let version = extract_version(file_name)
    Ok(MigrationFile(version:, sql: sql_content))
  })
}

fn migrations_directory() -> String {
  let assert Ok(priv_dir) = wisp.priv_directory("philstubs")
  priv_dir <> "/migrations"
}

fn extract_version(file_name: String) -> String {
  case string.split(file_name, "_") {
    [version, ..] -> version
    _ -> file_name
  }
}

fn apply_pending_migrations(
  connection: sqlight.Connection,
  pending_migrations: List(MigrationFile),
  applied_versions: List(String),
) -> Result(List(String), sqlight.Error) {
  case pending_migrations {
    [] -> Ok(list.reverse(applied_versions))
    [migration, ..remaining_migrations] -> {
      use _ <- result.try(sqlight.exec(migration.sql, on: connection))
      use _ <- result.try(record_migration(connection, migration.version))
      apply_pending_migrations(connection, remaining_migrations, [
        migration.version,
        ..applied_versions
      ])
    }
  }
}

fn record_migration(
  connection: sqlight.Connection,
  version: String,
) -> Result(Nil, sqlight.Error) {
  let insert_sql =
    "INSERT INTO schema_migrations (version) VALUES ('" <> version <> "')"
  sqlight.exec(insert_sql, on: connection)
}
