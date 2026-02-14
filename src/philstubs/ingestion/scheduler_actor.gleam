import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import philstubs/core/ingestion_job.{
  type IngestionSource, type ScheduleConfig, type SourceStatus, IngestionJob,
  SourceStatus,
}
import philstubs/data/database
import philstubs/data/ingestion_job_repo
import philstubs/ingestion/ingestion_runner.{type RunError, type RunResult}
import sqlight

/// Tick interval for the scheduler check loop (60 seconds).
const tick_interval_ms = 60_000

/// Initial delay before the first tick (5 seconds).
const initial_tick_delay_ms = 5000

/// Messages the scheduler actor can receive.
pub type SchedulerMessage {
  /// Self-scheduled timer tick to check if any source needs running.
  Tick
  /// Manually trigger a specific source, reply with result.
  TriggerSource(source: IngestionSource, reply_to: Subject(TriggerResult))
  /// Query current scheduler status.
  GetStatus(reply_to: Subject(SchedulerStatus))
  /// Graceful shutdown.
  Shutdown
}

/// Result of a manual trigger request.
pub type TriggerResult {
  TriggerAccepted(job_id: String)
  TriggerRejected(reason: String)
}

/// Full scheduler status for monitoring.
pub type SchedulerStatus {
  SchedulerStatus(
    source_statuses: List(SourceStatus),
    schedule_config: ScheduleConfig,
    is_running: Bool,
  )
}

/// Internal actor state.
pub type SchedulerState {
  SchedulerState(
    schedule_config: ScheduleConfig,
    self_subject: Subject(SchedulerMessage),
    current_source: Option(IngestionSource),
    last_run_times: Dict(String, Int),
    retry_counts: Dict(String, Int),
    runner_fn: fn(sqlight.Connection, IngestionSource) ->
      Result(RunResult, RunError),
  )
}

/// Start the scheduler actor. Returns a subject for sending messages.
pub fn start(
  schedule_config: ScheduleConfig,
  runner_fn: fn(sqlight.Connection, IngestionSource) ->
    Result(RunResult, RunError),
) -> actor.StartResult(Subject(SchedulerMessage)) {
  actor.new_with_initialiser(10_000, fn(self_subject) {
    let initial_state =
      SchedulerState(
        schedule_config:,
        self_subject:,
        current_source: None,
        last_run_times: dict.new(),
        retry_counts: dict.new(),
        runner_fn:,
      )

    // Schedule the first tick
    let _ = process.send_after(self_subject, initial_tick_delay_ms, Tick)

    io.println("[scheduler] Ingestion scheduler started")

    actor.initialised(initial_state)
    |> actor.returning(self_subject)
    |> Ok
  })
  |> actor.on_message(handle_message)
  |> actor.start
}

/// Convenience: trigger a source and wait for the result.
pub fn trigger(
  subject: Subject(SchedulerMessage),
  source: IngestionSource,
) -> TriggerResult {
  actor.call(subject, 300_000, fn(reply_to) {
    TriggerSource(source:, reply_to:)
  })
}

/// Convenience: get the current scheduler status.
pub fn get_status(subject: Subject(SchedulerMessage)) -> SchedulerStatus {
  actor.call(subject, 5000, GetStatus)
}

// --- Message handler ---

fn handle_message(
  actor_state: SchedulerState,
  message: SchedulerMessage,
) -> actor.Next(SchedulerState, SchedulerMessage) {
  case message {
    Tick -> handle_tick(actor_state)
    TriggerSource(source:, reply_to:) ->
      handle_trigger_source(actor_state, source, reply_to)
    GetStatus(reply_to:) -> handle_get_status(actor_state, reply_to)
    Shutdown -> actor.stop()
  }
}

fn handle_tick(
  actor_state: SchedulerState,
) -> actor.Next(SchedulerState, SchedulerMessage) {
  let current_time = system_time_seconds()
  let sources_to_run =
    ingestion_job.all_sources()
    |> list.filter(fn(source) {
      should_run_source(actor_state, source, current_time)
    })

  let updated_state =
    list.fold(sources_to_run, actor_state, fn(fold_state, source) {
      run_source_with_tracking(fold_state, source, current_time)
    })

  // Schedule next tick
  let _ = process.send_after(updated_state.self_subject, tick_interval_ms, Tick)

  actor.continue(updated_state)
}

fn handle_trigger_source(
  actor_state: SchedulerState,
  source: IngestionSource,
  reply_to: Subject(TriggerResult),
) -> actor.Next(SchedulerState, SchedulerMessage) {
  case actor_state.current_source {
    Some(running_source) -> {
      process.send(
        reply_to,
        TriggerRejected(
          "Scheduler busy running "
          <> ingestion_job.source_to_string(running_source),
        ),
      )
      actor.continue(actor_state)
    }
    None -> {
      let current_time = system_time_seconds()
      let updated_state =
        run_source_with_tracking(actor_state, source, current_time)

      // Find the job ID from the most recent job for this source
      let job_id =
        get_latest_job_id_for_source(ingestion_job.source_to_string(source))
      process.send(reply_to, TriggerAccepted(job_id:))
      actor.continue(updated_state)
    }
  }
}

fn handle_get_status(
  actor_state: SchedulerState,
  reply_to: Subject(SchedulerStatus),
) -> actor.Next(SchedulerState, SchedulerMessage) {
  let source_statuses =
    ingestion_job.all_sources()
    |> list.map(fn(source) { build_source_status(actor_state, source) })

  let scheduler_status =
    SchedulerStatus(
      source_statuses:,
      schedule_config: actor_state.schedule_config,
      is_running: option.is_some(actor_state.current_source),
    )

  process.send(reply_to, scheduler_status)
  actor.continue(actor_state)
}

// --- Core scheduling logic ---

fn should_run_source(
  actor_state: SchedulerState,
  source: IngestionSource,
  current_time: Int,
) -> Bool {
  let source_key = ingestion_job.source_to_string(source)
  let interval_seconds =
    ingestion_job.interval_for_source(actor_state.schedule_config, source)
    * 3600

  // Check if in backoff from consecutive failures
  let consecutive_failures =
    dict.get(actor_state.retry_counts, source_key)
    |> result.unwrap(0)

  case consecutive_failures >= ingestion_job.default_max_retries {
    True -> False
    False -> {
      case dict.get(actor_state.last_run_times, source_key) {
        Error(Nil) -> True
        Ok(last_run_time) -> {
          let elapsed = current_time - last_run_time
          // Apply backoff if there are failures
          let effective_interval = case consecutive_failures > 0 {
            True -> {
              let backoff_seconds =
                ingestion_job.calculate_backoff_ms(consecutive_failures) / 1000
              int.min(interval_seconds, backoff_seconds)
            }
            False -> interval_seconds
          }
          elapsed >= effective_interval
        }
      }
    }
  }
}

fn run_source_with_tracking(
  actor_state: SchedulerState,
  source: IngestionSource,
  current_time: Int,
) -> SchedulerState {
  let source_key = ingestion_job.source_to_string(source)
  let job_id = source_key <> "-" <> int.to_string(current_time)

  io.println(
    "[scheduler] Running ingestion for "
    <> source_key
    <> " (job "
    <> job_id
    <> ")",
  )

  // Update state to indicate we're running
  let running_state =
    SchedulerState(
      ..actor_state,
      current_source: Some(source),
      last_run_times: dict.insert(
        actor_state.last_run_times,
        source_key,
        current_time,
      ),
    )

  // Open a database connection for this job
  let database_path = database.resolve_database_path()
  case sqlight.open(database_path) {
    Ok(connection) -> {
      let result_state =
        execute_job(running_state, connection, source, source_key, job_id)
      let _ = sqlight.close(connection)
      result_state
    }
    Error(_) -> {
      io.println(
        "[scheduler] WARNING: Failed to open database for " <> source_key,
      )
      SchedulerState(..running_state, current_source: None)
    }
  }
}

fn execute_job(
  actor_state: SchedulerState,
  connection: sqlight.Connection,
  source: IngestionSource,
  source_key: String,
  job_id: String,
) -> SchedulerState {
  let retry_count =
    dict.get(actor_state.retry_counts, source_key)
    |> result.unwrap(0)

  let pending_job =
    IngestionJob(
      id: job_id,
      source:,
      status: ingestion_job.Pending,
      started_at: None,
      completed_at: None,
      duration_seconds: 0,
      records_fetched: 0,
      records_stored: 0,
      error_message: None,
      retry_count:,
      created_at: "",
    )

  let _ = ingestion_job_repo.insert(connection, pending_job)
  let _ = ingestion_job_repo.mark_running(connection, job_id)

  let start_time = system_time_seconds()
  let run_result = actor_state.runner_fn(connection, source)
  let end_time = system_time_seconds()
  let duration_seconds = end_time - start_time

  case run_result {
    Ok(run_outcome) -> {
      let _ =
        ingestion_job_repo.mark_completed(
          connection,
          job_id,
          run_outcome.records_fetched,
          run_outcome.records_stored,
          duration_seconds,
        )
      io.println(
        "[scheduler] Completed "
        <> source_key
        <> ": fetched="
        <> int.to_string(run_outcome.records_fetched)
        <> " stored="
        <> int.to_string(run_outcome.records_stored),
      )
      SchedulerState(
        ..actor_state,
        current_source: None,
        retry_counts: dict.insert(actor_state.retry_counts, source_key, 0),
      )
    }
    Error(run_error) -> {
      let error_message = run_error_to_string(run_error)
      let _ =
        ingestion_job_repo.mark_failed(
          connection,
          job_id,
          error_message,
          duration_seconds,
        )
      let new_retry_count = retry_count + 1
      io.println(
        "[scheduler] Failed "
        <> source_key
        <> " (retry "
        <> int.to_string(new_retry_count)
        <> "): "
        <> error_message,
      )
      SchedulerState(
        ..actor_state,
        current_source: None,
        retry_counts: dict.insert(
          actor_state.retry_counts,
          source_key,
          new_retry_count,
        ),
      )
    }
  }
}

fn build_source_status(
  actor_state: SchedulerState,
  source: IngestionSource,
) -> SourceStatus {
  let source_key = ingestion_job.source_to_string(source)
  let consecutive_failures =
    dict.get(actor_state.retry_counts, source_key)
    |> result.unwrap(0)

  SourceStatus(
    source:,
    last_successful_run: None,
    last_run_status: None,
    total_records: 0,
    consecutive_failures:,
    next_scheduled_run: None,
  )
}

fn get_latest_job_id_for_source(source_string: String) -> String {
  let database_path = database.resolve_database_path()
  case sqlight.open(database_path) {
    Ok(connection) -> {
      let job_id = case
        ingestion_job_repo.get_latest_by_source(connection, source_string)
      {
        Ok(Some(job)) -> job.id
        _ -> "unknown"
      }
      let _ = sqlight.close(connection)
      job_id
    }
    Error(_) -> "unknown"
  }
}

fn run_error_to_string(error: RunError) -> String {
  case error {
    ingestion_runner.FederalError(message) -> "Federal: " <> message
    ingestion_runner.StateError(message) -> "State: " <> message
    ingestion_runner.LocalError(message) -> "Local: " <> message
    ingestion_runner.ConfigError(message) -> "Config: " <> message
  }
}

// --- Erlang FFI for timestamps ---

@external(erlang, "philstubs_erlang_ffi", "system_time_seconds")
fn system_time_seconds() -> Int
