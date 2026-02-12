import philstubs/data/migration
import sqlight

/// The default database path for local development.
const default_database_path = "philstubs_dev.sqlite"

/// Execute a function with a database connection. The connection is
/// automatically closed when the function completes.
///
/// Usage:
///   use connection <- database.with_connection()
///   sqlight.exec("SELECT 1", on: connection)
pub fn with_connection(next: fn(sqlight.Connection) -> result) -> result {
  sqlight.with_connection(default_database_path, next)
}

/// Execute a function with a connection to a specific database path.
/// Useful for testing with in-memory databases.
///
/// Usage:
///   use connection <- database.with_named_connection(":memory:")
///   sqlight.exec("CREATE TABLE ...", on: connection)
pub fn with_named_connection(
  database_path: String,
  next: fn(sqlight.Connection) -> result,
) -> result {
  sqlight.with_connection(database_path, next)
}

/// Initialize the database by running all pending migrations.
/// Should be called once at application startup.
pub fn initialize(
  connection: sqlight.Connection,
) -> Result(List(String), sqlight.Error) {
  migration.run_migrations(connection)
}
