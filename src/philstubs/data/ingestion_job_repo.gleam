import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import philstubs/core/ingestion_job.{type IngestionJob, IngestionJob}
import sqlight

/// Insert a new ingestion job record.
pub fn insert(
  connection: sqlight.Connection,
  job: IngestionJob,
) -> Result(Nil, sqlight.Error) {
  let sql =
    "INSERT INTO ingestion_jobs (
      id, source, status, started_at, completed_at,
      duration_seconds, records_fetched, records_stored,
      error_message, retry_count, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(job.id),
      sqlight.text(ingestion_job.source_to_string(job.source)),
      sqlight.text(ingestion_job.status_to_string(job.status)),
      sqlight.nullable(sqlight.text, job.started_at),
      sqlight.nullable(sqlight.text, job.completed_at),
      sqlight.int(job.duration_seconds),
      sqlight.int(job.records_fetched),
      sqlight.int(job.records_stored),
      sqlight.nullable(sqlight.text, job.error_message),
      sqlight.int(job.retry_count),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Mark a job as running with started_at set to now.
pub fn mark_running(
  connection: sqlight.Connection,
  job_id: String,
) -> Result(Nil, sqlight.Error) {
  let sql =
    "UPDATE ingestion_jobs SET
      status = 'running',
      started_at = datetime('now')
    WHERE id = ?"

  sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(job_id)],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Mark a job as completed with final counts.
pub fn mark_completed(
  connection: sqlight.Connection,
  job_id: String,
  records_fetched: Int,
  records_stored: Int,
  duration_seconds: Int,
) -> Result(Nil, sqlight.Error) {
  let sql =
    "UPDATE ingestion_jobs SET
      status = 'completed',
      completed_at = datetime('now'),
      records_fetched = ?,
      records_stored = ?,
      duration_seconds = ?
    WHERE id = ?"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.int(records_fetched),
      sqlight.int(records_stored),
      sqlight.int(duration_seconds),
      sqlight.text(job_id),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Mark a job as failed with an error message.
pub fn mark_failed(
  connection: sqlight.Connection,
  job_id: String,
  error_message: String,
  duration_seconds: Int,
) -> Result(Nil, sqlight.Error) {
  let sql =
    "UPDATE ingestion_jobs SET
      status = 'failed',
      completed_at = datetime('now'),
      error_message = ?,
      duration_seconds = ?
    WHERE id = ?"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(error_message),
      sqlight.int(duration_seconds),
      sqlight.text(job_id),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Look up a single job by ID.
pub fn get_by_id(
  connection: sqlight.Connection,
  job_id: String,
) -> Result(Option(IngestionJob), sqlight.Error) {
  let sql =
    "SELECT id, source, status, started_at, completed_at,
      duration_seconds, records_fetched, records_stored,
      error_message, retry_count, created_at
    FROM ingestion_jobs
    WHERE id = ?"

  use rows <- result.try(sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(job_id)],
    expecting: ingestion_job_row_decoder(),
  ))

  case rows {
    [job, ..] -> Ok(Some(job))
    [] -> Ok(None)
  }
}

/// List recent jobs ordered by created_at descending.
pub fn list_recent(
  connection: sqlight.Connection,
  limit: Int,
) -> Result(List(IngestionJob), sqlight.Error) {
  let sql =
    "SELECT id, source, status, started_at, completed_at,
      duration_seconds, records_fetched, records_stored,
      error_message, retry_count, created_at
    FROM ingestion_jobs
    ORDER BY created_at DESC
    LIMIT ?"

  sqlight.query(
    sql,
    on: connection,
    with: [sqlight.int(limit)],
    expecting: ingestion_job_row_decoder(),
  )
}

/// List recent jobs for a specific source.
pub fn list_by_source(
  connection: sqlight.Connection,
  source_string: String,
  limit: Int,
) -> Result(List(IngestionJob), sqlight.Error) {
  let sql =
    "SELECT id, source, status, started_at, completed_at,
      duration_seconds, records_fetched, records_stored,
      error_message, retry_count, created_at
    FROM ingestion_jobs
    WHERE source = ?
    ORDER BY created_at DESC
    LIMIT ?"

  sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(source_string), sqlight.int(limit)],
    expecting: ingestion_job_row_decoder(),
  )
}

/// Get the most recent job for a specific source.
pub fn get_latest_by_source(
  connection: sqlight.Connection,
  source_string: String,
) -> Result(Option(IngestionJob), sqlight.Error) {
  use jobs <- result.try(list_by_source(connection, source_string, 1))
  case jobs {
    [job, ..] -> Ok(Some(job))
    [] -> Ok(None)
  }
}

/// Count consecutive failures for a source (trailing failures before any success).
/// Counts recent 'failed' jobs from newest to oldest, stopping at the first
/// non-failed job.
pub fn count_consecutive_failures(
  connection: sqlight.Connection,
  source_string: String,
) -> Result(Int, sqlight.Error) {
  // Get statuses of recent jobs ordered newest first
  let sql =
    "SELECT status FROM ingestion_jobs
     WHERE source = ?
     ORDER BY rowid DESC
     LIMIT 100"

  use rows <- result.try(
    sqlight.query(
      sql,
      on: connection,
      with: [sqlight.text(source_string)],
      expecting: {
        use status <- decode.field(0, decode.string)
        decode.success(status)
      },
    ),
  )

  Ok(count_leading_failures(rows, 0))
}

fn count_leading_failures(
  status_list: List(String),
  accumulated_count: Int,
) -> Int {
  case status_list {
    [] -> accumulated_count
    ["failed", ..rest] -> count_leading_failures(rest, accumulated_count + 1)
    _ -> accumulated_count
  }
}

// --- Row decoder ---

fn ingestion_job_row_decoder() -> decode.Decoder(IngestionJob) {
  use id <- decode.field(0, decode.string)
  use source_string <- decode.field(1, decode.string)
  use status_string <- decode.field(2, decode.string)
  use started_at <- decode.field(3, decode.optional(decode.string))
  use completed_at <- decode.field(4, decode.optional(decode.string))
  use duration_seconds <- decode.field(5, decode.int)
  use records_fetched <- decode.field(6, decode.int)
  use records_stored <- decode.field(7, decode.int)
  use error_message <- decode.field(8, decode.optional(decode.string))
  use retry_count <- decode.field(9, decode.int)
  use created_at <- decode.field(10, decode.string)
  let source = case ingestion_job.source_from_string(source_string) {
    Ok(parsed_source) -> parsed_source
    Error(Nil) -> ingestion_job.Federal
  }
  let status = case ingestion_job.status_from_string(status_string) {
    Ok(parsed_status) -> parsed_status
    Error(Nil) -> ingestion_job.Pending
  }
  decode.success(IngestionJob(
    id:,
    source:,
    status:,
    started_at:,
    completed_at:,
    duration_seconds:,
    records_fetched:,
    records_stored:,
    error_message:,
    retry_count:,
    created_at:,
  ))
}
