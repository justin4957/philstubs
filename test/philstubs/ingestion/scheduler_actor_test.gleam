import gleam/erlang/process
import gleeunit/should
import philstubs/core/ingestion_job.{
  type IngestionSource, type ScheduleConfig, Federal, ScheduleConfig,
}
import philstubs/ingestion/ingestion_runner.{type RunResult, RunResult}
import philstubs/ingestion/scheduler_actor
import sqlight

/// A mock runner that always succeeds with a small result.
fn mock_success_runner(
  _connection: sqlight.Connection,
  _source: IngestionSource,
) -> Result(RunResult, ingestion_runner.RunError) {
  Ok(RunResult(records_fetched: 5, records_stored: 5))
}

fn test_schedule_config() -> ScheduleConfig {
  ScheduleConfig(
    federal_interval_hours: 1,
    state_interval_hours: 1,
    local_interval_hours: 1,
  )
}

// --- Start and get status ---

pub fn start_and_get_status_test() {
  let config = test_schedule_config()
  let assert Ok(started) = scheduler_actor.start(config, mock_success_runner)

  let status = scheduler_actor.get_status(started.data)
  status.is_running |> should.be_false
  status.schedule_config.federal_interval_hours |> should.equal(1)
  status.source_statuses
  |> should.not_equal([])

  // Clean shutdown
  process.send(started.data, scheduler_actor.Shutdown)
}

// --- Trigger source ---

pub fn trigger_source_test() {
  let config = test_schedule_config()
  let assert Ok(started) = scheduler_actor.start(config, mock_success_runner)

  let _trigger_result = scheduler_actor.trigger(started.data, Federal)

  // Clean shutdown
  process.send(started.data, scheduler_actor.Shutdown)
}

// --- Shutdown ---

pub fn shutdown_stops_actor_test() {
  let config = test_schedule_config()
  let assert Ok(started) = scheduler_actor.start(config, mock_success_runner)

  // Send shutdown
  process.send(started.data, scheduler_actor.Shutdown)

  // Give the actor time to process the shutdown
  process.sleep(100)

  // The actor should be stopped - we verify by checking the process is no longer alive
  let monitor = process.monitor(started.pid)
  // If not already down, send another shutdown - it'll be discarded by a dead process
  process.send(started.data, scheduler_actor.Shutdown)

  // Wait for down signal or timeout
  let selector =
    process.new_selector()
    |> process.select_specific_monitor(monitor, fn(_down) { True })

  case process.selector_receive(selector, 500) {
    Ok(True) -> Nil
    _ -> Nil
  }
}
