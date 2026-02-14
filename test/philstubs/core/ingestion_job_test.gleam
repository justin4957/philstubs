import gleam/json
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import philstubs/core/ingestion_job.{
  Completed, Failed, Federal, IngestionJob, Local, Pending, Running,
  ScheduleConfig, SourceStatus, State,
}

// --- Source string conversions ---

pub fn source_to_string_federal_test() {
  ingestion_job.source_to_string(Federal)
  |> should.equal("federal")
}

pub fn source_to_string_state_test() {
  ingestion_job.source_to_string(State)
  |> should.equal("state")
}

pub fn source_to_string_local_test() {
  ingestion_job.source_to_string(Local)
  |> should.equal("local")
}

pub fn source_from_string_roundtrip_test() {
  ingestion_job.source_from_string("federal")
  |> should.equal(Ok(Federal))
  ingestion_job.source_from_string("state")
  |> should.equal(Ok(State))
  ingestion_job.source_from_string("local")
  |> should.equal(Ok(Local))
}

pub fn source_from_string_invalid_test() {
  ingestion_job.source_from_string("unknown")
  |> should.equal(Error(Nil))
}

// --- Status string conversions ---

pub fn status_to_string_all_test() {
  ingestion_job.status_to_string(Pending)
  |> should.equal("pending")
  ingestion_job.status_to_string(Running)
  |> should.equal("running")
  ingestion_job.status_to_string(Completed)
  |> should.equal("completed")
  ingestion_job.status_to_string(Failed)
  |> should.equal("failed")
}

pub fn status_from_string_roundtrip_test() {
  ingestion_job.status_from_string("pending")
  |> should.equal(Ok(Pending))
  ingestion_job.status_from_string("running")
  |> should.equal(Ok(Running))
  ingestion_job.status_from_string("completed")
  |> should.equal(Ok(Completed))
  ingestion_job.status_from_string("failed")
  |> should.equal(Ok(Failed))
}

pub fn status_from_string_invalid_test() {
  ingestion_job.status_from_string("invalid")
  |> should.equal(Error(Nil))
}

// --- Default schedule config ---

pub fn default_schedule_config_test() {
  let config = ingestion_job.default_schedule_config()
  config.federal_interval_hours |> should.equal(24)
  config.state_interval_hours |> should.equal(168)
  config.local_interval_hours |> should.equal(168)
}

// --- Backoff calculation ---

pub fn calculate_backoff_zero_retries_test() {
  ingestion_job.calculate_backoff_ms(0)
  |> should.equal(30_000)
}

pub fn calculate_backoff_one_retry_test() {
  ingestion_job.calculate_backoff_ms(1)
  |> should.equal(60_000)
}

pub fn calculate_backoff_two_retries_test() {
  ingestion_job.calculate_backoff_ms(2)
  |> should.equal(120_000)
}

pub fn calculate_backoff_capped_test() {
  // Very high retry count should cap at 1 hour (3,600,000 ms)
  ingestion_job.calculate_backoff_ms(20)
  |> should.equal(3_600_000)
}

// --- Should retry ---

pub fn should_retry_under_max_test() {
  ingestion_job.should_retry(0, 3)
  |> should.be_true
  ingestion_job.should_retry(2, 3)
  |> should.be_true
}

pub fn should_retry_at_max_test() {
  ingestion_job.should_retry(3, 3)
  |> should.be_false
}

pub fn should_retry_over_max_test() {
  ingestion_job.should_retry(5, 3)
  |> should.be_false
}

// --- JSON encoding ---

pub fn job_to_json_test() {
  let job =
    IngestionJob(
      id: "federal-123",
      source: Federal,
      status: Completed,
      started_at: Some("2025-01-01T00:00:00"),
      completed_at: Some("2025-01-01T01:00:00"),
      duration_seconds: 3600,
      records_fetched: 100,
      records_stored: 95,
      error_message: None,
      retry_count: 0,
      created_at: "2025-01-01T00:00:00",
    )

  let json_string =
    job
    |> ingestion_job.job_to_json
    |> json.to_string

  json_string |> string.contains("\"federal\"") |> should.be_true
  json_string |> string.contains("\"completed\"") |> should.be_true
  json_string |> string.contains("\"federal-123\"") |> should.be_true
  json_string |> string.contains("\"records_fetched\":100") |> should.be_true
}

pub fn source_status_to_json_test() {
  let status =
    SourceStatus(
      source: State,
      last_successful_run: Some("2025-01-01T00:00:00"),
      last_run_status: Some(Completed),
      total_records: 500,
      consecutive_failures: 0,
      next_scheduled_run: None,
    )

  let json_string =
    status
    |> ingestion_job.source_status_to_json
    |> json.to_string

  json_string |> string.contains("\"state\"") |> should.be_true
  json_string |> string.contains("\"completed\"") |> should.be_true
  json_string |> string.contains("\"total_records\":500") |> should.be_true
}

// --- All sources ---

pub fn all_sources_test() {
  let sources = ingestion_job.all_sources()
  sources |> should.equal([Federal, State, Local])
}

// --- Interval for source ---

pub fn interval_for_source_test() {
  let config =
    ScheduleConfig(
      federal_interval_hours: 12,
      state_interval_hours: 48,
      local_interval_hours: 72,
    )

  ingestion_job.interval_for_source(config, Federal)
  |> should.equal(12)
  ingestion_job.interval_for_source(config, State)
  |> should.equal(48)
  ingestion_job.interval_for_source(config, Local)
  |> should.equal(72)
}
