import envoy
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option.{None, Some}
import gleam/result
import mist
import philstubs/core/ingestion_job
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/seed
import philstubs/data/topic_seed
import philstubs/ingestion/ingestion_runner
import philstubs/ingestion/scheduler_actor
import philstubs/web/context.{Context}
import philstubs/web/router
import wisp
import wisp/wisp_mist

const default_port = 8000

pub fn main() {
  wisp.configure_logger()

  let secret_key_base = resolve_secret_key_base()
  let application_port = resolve_port()
  let static_directory = static_directory()

  let github_client_id = envoy.get("GITHUB_CLIENT_ID") |> result.unwrap("")
  let github_client_secret =
    envoy.get("GITHUB_CLIENT_SECRET") |> result.unwrap("")

  use connection <- database.with_connection()
  let assert Ok(_) = database.initialize(connection)

  // Seed the database with sample data if it's empty
  let assert Ok(existing_legislation) = legislation_repo.list_all(connection)
  case existing_legislation {
    [] -> {
      let assert Ok(_) = seed.seed(connection)
      io.println("Seeded database with sample legislation and templates")
    }
    _ -> Nil
  }

  // Seed the topic taxonomy (idempotent — safe on every startup)
  case topic_seed.seed_topic_taxonomy(connection) {
    Ok(topic_count) ->
      io.println(
        "Topic taxonomy ready: " <> int.to_string(topic_count) <> " topics",
      )
    Error(_) -> io.println("WARNING: Failed to seed topic taxonomy")
  }

  // Start the ingestion scheduler actor
  let schedule_config = ingestion_job.resolve_schedule_config()
  let scheduler_subject = case
    scheduler_actor.start(schedule_config, ingestion_runner.run_source)
  {
    Ok(started) -> {
      io.println("Ingestion scheduler started successfully")
      Some(started.data)
    }
    Error(_) -> {
      io.println("WARNING: Failed to start ingestion scheduler")
      None
    }
  }

  let application_context =
    Context(
      static_directory: static_directory,
      db_connection: connection,
      current_user: None,
      github_client_id: github_client_id,
      github_client_secret: github_client_secret,
      scheduler: scheduler_subject,
    )

  let request_handler = router.handle_request(_, application_context)

  let assert Ok(_) =
    wisp_mist.handler(request_handler, secret_key_base)
    |> mist.new
    |> mist.port(application_port)
    |> mist.start

  io.println(
    "PHILSTUBS server started on http://localhost:"
    <> int.to_string(application_port),
  )

  process.sleep_forever()
}

/// Resolve the server port from the PORT environment variable,
/// falling back to the default port (8000).
fn resolve_port() -> Int {
  envoy.get("PORT")
  |> result.try(int.parse)
  |> result.unwrap(default_port)
}

/// Resolve the secret key base from the SECRET_KEY_BASE environment variable.
/// If unset, generates a random key and logs a warning.
fn resolve_secret_key_base() -> String {
  case envoy.get("SECRET_KEY_BASE") {
    Ok(key) -> key
    Error(_) -> {
      io.println(
        "WARNING: SECRET_KEY_BASE not set, generating random key. "
        <> "Sessions will not persist across restarts.",
      )
      wisp.random_string(64)
    }
  }
}

fn static_directory() -> String {
  let assert Ok(priv_directory) = wisp.priv_directory("philstubs")
  priv_directory <> "/static"
}
