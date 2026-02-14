import envoy
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option.{None}
import gleam/result
import mist
import philstubs/data/database
import philstubs/data/legislation_repo
import philstubs/data/seed
import philstubs/web/context.{Context}
import philstubs/web/router
import wisp
import wisp/wisp_mist

const default_port = 8000

pub fn main() {
  wisp.configure_logger()

  let secret_key_base = wisp.random_string(64)
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

  let application_context =
    Context(
      static_directory: static_directory,
      db_connection: connection,
      current_user: None,
      github_client_id: github_client_id,
      github_client_secret: github_client_secret,
    )

  let request_handler = router.handle_request(_, application_context)

  let assert Ok(_) =
    wisp_mist.handler(request_handler, secret_key_base)
    |> mist.new
    |> mist.port(default_port)
    |> mist.start

  io.println(
    "PHILSTUBS server started on http://localhost:"
    <> int.to_string(default_port),
  )

  process.sleep_forever()
}

fn static_directory() -> String {
  let assert Ok(priv_directory) = wisp.priv_directory("philstubs")
  priv_directory <> "/static"
}
