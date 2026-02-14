import envoy
import gleam/int
import gleam/json.{type Json}
import gleam/option.{type Option}
import gleam/result

/// Which ingestion pipeline to run.
pub type IngestionSource {
  Federal
  State
  Local
}

/// Job lifecycle status.
pub type JobStatus {
  Pending
  Running
  Completed
  Failed
}

/// A single ingestion job execution record.
pub type IngestionJob {
  IngestionJob(
    id: String,
    source: IngestionSource,
    status: JobStatus,
    started_at: Option(String),
    completed_at: Option(String),
    duration_seconds: Int,
    records_fetched: Int,
    records_stored: Int,
    error_message: Option(String),
    retry_count: Int,
    created_at: String,
  )
}

/// Per-source summary for monitoring display.
pub type SourceStatus {
  SourceStatus(
    source: IngestionSource,
    last_successful_run: Option(String),
    last_run_status: Option(JobStatus),
    total_records: Int,
    consecutive_failures: Int,
    next_scheduled_run: Option(String),
  )
}

/// Configurable ingestion schedule intervals in hours.
pub type ScheduleConfig {
  ScheduleConfig(
    federal_interval_hours: Int,
    state_interval_hours: Int,
    local_interval_hours: Int,
  )
}

// --- Source conversions ---

/// Convert an ingestion source to its string representation.
pub fn source_to_string(source: IngestionSource) -> String {
  case source {
    Federal -> "federal"
    State -> "state"
    Local -> "local"
  }
}

/// Parse a string into an ingestion source.
pub fn source_from_string(source_string: String) -> Result(IngestionSource, Nil) {
  case source_string {
    "federal" -> Ok(Federal)
    "state" -> Ok(State)
    "local" -> Ok(Local)
    _ -> Error(Nil)
  }
}

// --- Status conversions ---

/// Convert a job status to its string representation.
pub fn status_to_string(status: JobStatus) -> String {
  case status {
    Pending -> "pending"
    Running -> "running"
    Completed -> "completed"
    Failed -> "failed"
  }
}

/// Parse a string into a job status.
pub fn status_from_string(status_string: String) -> Result(JobStatus, Nil) {
  case status_string {
    "pending" -> Ok(Pending)
    "running" -> Ok(Running)
    "completed" -> Ok(Completed)
    "failed" -> Ok(Failed)
    _ -> Error(Nil)
  }
}

// --- Schedule config ---

/// Default schedule intervals: federal every 24h, state/local every 168h (weekly).
pub fn default_schedule_config() -> ScheduleConfig {
  ScheduleConfig(
    federal_interval_hours: 24,
    state_interval_hours: 168,
    local_interval_hours: 168,
  )
}

/// Resolve schedule config from environment variables, falling back to defaults.
/// Reads INGESTION_FEDERAL_INTERVAL_HOURS, INGESTION_STATE_INTERVAL_HOURS,
/// and INGESTION_LOCAL_INTERVAL_HOURS.
pub fn resolve_schedule_config() -> ScheduleConfig {
  let defaults = default_schedule_config()
  ScheduleConfig(
    federal_interval_hours: resolve_interval_env(
      "INGESTION_FEDERAL_INTERVAL_HOURS",
      defaults.federal_interval_hours,
    ),
    state_interval_hours: resolve_interval_env(
      "INGESTION_STATE_INTERVAL_HOURS",
      defaults.state_interval_hours,
    ),
    local_interval_hours: resolve_interval_env(
      "INGESTION_LOCAL_INTERVAL_HOURS",
      defaults.local_interval_hours,
    ),
  )
}

fn resolve_interval_env(env_var_name: String, default_value: Int) -> Int {
  envoy.get(env_var_name)
  |> result.try(int.parse)
  |> result.unwrap(default_value)
}

// --- Backoff and retry ---

/// Calculate exponential backoff in milliseconds for retry attempts.
/// Uses 30s base with exponential growth, capped at 1 hour.
pub fn calculate_backoff_ms(retry_count: Int) -> Int {
  let base_ms = 30_000
  let max_ms = 3_600_000
  let backoff = base_ms * power_of_two(retry_count)
  int.min(backoff, max_ms)
}

fn power_of_two(exponent: Int) -> Int {
  case exponent <= 0 {
    True -> 1
    False -> 2 * power_of_two(exponent - 1)
  }
}

/// Determine whether a failed job should be retried.
pub fn should_retry(retry_count: Int, max_retries: Int) -> Bool {
  retry_count < max_retries
}

/// Default maximum number of consecutive retries per source.
pub const default_max_retries = 3

// --- JSON encoding ---

/// Encode an ingestion job as JSON.
pub fn job_to_json(job: IngestionJob) -> Json {
  json.object([
    #("id", json.string(job.id)),
    #("source", json.string(source_to_string(job.source))),
    #("status", json.string(status_to_string(job.status))),
    #("started_at", json.nullable(job.started_at, json.string)),
    #("completed_at", json.nullable(job.completed_at, json.string)),
    #("duration_seconds", json.int(job.duration_seconds)),
    #("records_fetched", json.int(job.records_fetched)),
    #("records_stored", json.int(job.records_stored)),
    #("error_message", json.nullable(job.error_message, json.string)),
    #("retry_count", json.int(job.retry_count)),
    #("created_at", json.string(job.created_at)),
  ])
}

/// Encode a source status summary as JSON.
pub fn source_status_to_json(source_status: SourceStatus) -> Json {
  json.object([
    #("source", json.string(source_to_string(source_status.source))),
    #(
      "last_successful_run",
      json.nullable(source_status.last_successful_run, json.string),
    ),
    #(
      "last_run_status",
      json.nullable(
        option.map(source_status.last_run_status, status_to_string),
        json.string,
      ),
    ),
    #("total_records", json.int(source_status.total_records)),
    #("consecutive_failures", json.int(source_status.consecutive_failures)),
    #(
      "next_scheduled_run",
      json.nullable(source_status.next_scheduled_run, json.string),
    ),
  ])
}

/// All ingestion sources in scheduling priority order.
pub fn all_sources() -> List(IngestionSource) {
  [Federal, State, Local]
}

/// Get the schedule interval in hours for a given source.
pub fn interval_for_source(
  config: ScheduleConfig,
  source: IngestionSource,
) -> Int {
  case source {
    Federal -> config.federal_interval_hours
    State -> config.state_interval_hours
    Local -> config.local_interval_hours
  }
}
