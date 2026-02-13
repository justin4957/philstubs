import gleam/erlang/process
import gleam/int
import gleam/io
import mist
import philstubs/data/database
import philstubs/web/context.{Context}
import philstubs/web/router
import wisp
import wisp/wisp_mist

const default_port = 8000

pub fn main() {
  wisp.configure_logger()

  let secret_key_base = wisp.random_string(64)
  let static_directory = static_directory()

  use connection <- database.with_connection()
  let assert Ok(_) = database.initialize(connection)

  let application_context =
    Context(static_directory: static_directory, db_connection: connection)

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
