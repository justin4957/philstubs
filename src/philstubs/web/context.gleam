import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import philstubs/core/user.{type User}
import philstubs/ingestion/scheduler_actor.{type SchedulerMessage}
import sqlight

/// Application context carried through the request handling pipeline.
/// Holds resources and configuration that handlers need access to.
pub type Context {
  Context(
    static_directory: String,
    db_connection: sqlight.Connection,
    current_user: Option(User),
    github_client_id: String,
    github_client_secret: String,
    scheduler: Option(Subject(SchedulerMessage)),
  )
}
