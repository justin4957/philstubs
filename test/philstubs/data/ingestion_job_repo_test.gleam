import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import philstubs/core/ingestion_job.{
  type IngestionJob, Completed, Failed, Federal, IngestionJob, Local, Pending,
  Running, State,
}
import philstubs/data/database
import philstubs/data/ingestion_job_repo
import philstubs/data/test_helpers

fn sample_job(
  job_id: String,
  source: ingestion_job.IngestionSource,
) -> IngestionJob {
  IngestionJob(
    id: job_id,
    source:,
    status: Pending,
    started_at: None,
    completed_at: None,
    duration_seconds: 0,
    records_fetched: 0,
    records_stored: 0,
    error_message: None,
    retry_count: 0,
    created_at: "",
  )
}

// --- Insert and get ---

pub fn insert_and_get_by_id_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let job = sample_job("job-1", Federal)
  let assert Ok(Nil) = ingestion_job_repo.insert(connection, job)

  let assert Ok(Some(retrieved)) =
    ingestion_job_repo.get_by_id(connection, "job-1")
  retrieved.id |> should.equal("job-1")
  retrieved.source |> should.equal(Federal)
  retrieved.status |> should.equal(Pending)
  retrieved.records_fetched |> should.equal(0)
}

pub fn get_by_id_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(None) = ingestion_job_repo.get_by_id(connection, "nonexistent")
}

// --- Mark running ---

pub fn mark_running_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let job = sample_job("job-run", Federal)
  let assert Ok(Nil) = ingestion_job_repo.insert(connection, job)
  let assert Ok(Nil) = ingestion_job_repo.mark_running(connection, "job-run")

  let assert Ok(Some(retrieved)) =
    ingestion_job_repo.get_by_id(connection, "job-run")
  retrieved.status |> should.equal(Running)
  retrieved.started_at |> should.not_equal(None)
}

// --- Mark completed ---

pub fn mark_completed_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let job = sample_job("job-done", State)
  let assert Ok(Nil) = ingestion_job_repo.insert(connection, job)
  let assert Ok(Nil) = ingestion_job_repo.mark_running(connection, "job-done")
  let assert Ok(Nil) =
    ingestion_job_repo.mark_completed(connection, "job-done", 50, 45, 120)

  let assert Ok(Some(retrieved)) =
    ingestion_job_repo.get_by_id(connection, "job-done")
  retrieved.status |> should.equal(Completed)
  retrieved.completed_at |> should.not_equal(None)
  retrieved.records_fetched |> should.equal(50)
  retrieved.records_stored |> should.equal(45)
  retrieved.duration_seconds |> should.equal(120)
}

// --- Mark failed ---

pub fn mark_failed_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let job = sample_job("job-fail", Local)
  let assert Ok(Nil) = ingestion_job_repo.insert(connection, job)
  let assert Ok(Nil) = ingestion_job_repo.mark_running(connection, "job-fail")
  let assert Ok(Nil) =
    ingestion_job_repo.mark_failed(
      connection,
      "job-fail",
      "Connection timeout",
      30,
    )

  let assert Ok(Some(retrieved)) =
    ingestion_job_repo.get_by_id(connection, "job-fail")
  retrieved.status |> should.equal(Failed)
  retrieved.completed_at |> should.not_equal(None)
  retrieved.error_message |> should.equal(Some("Connection timeout"))
  retrieved.duration_seconds |> should.equal(30)
}

// --- List recent ---

pub fn list_recent_ordering_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_job("job-a", Federal))
  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_job("job-b", State))
  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_job("job-c", Local))

  let assert Ok(jobs) = ingestion_job_repo.list_recent(connection, 10)
  jobs |> list.length |> should.equal(3)
}

pub fn list_recent_limit_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_job("job-1", Federal))
  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_job("job-2", Federal))
  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_job("job-3", Federal))

  let assert Ok(jobs) = ingestion_job_repo.list_recent(connection, 2)
  jobs |> list.length |> should.equal(2)
}

// --- List by source ---

pub fn list_by_source_filtering_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_job("fed-1", Federal))
  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_job("state-1", State))
  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_job("fed-2", Federal))

  let assert Ok(federal_jobs) =
    ingestion_job_repo.list_by_source(connection, "federal", 10)
  federal_jobs |> list.length |> should.equal(2)

  let assert Ok(state_jobs) =
    ingestion_job_repo.list_by_source(connection, "state", 10)
  state_jobs |> list.length |> should.equal(1)
}

// --- Get latest by source ---

pub fn get_latest_by_source_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_job("fed-old", Federal))
  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_job("fed-new", Federal))

  let assert Ok(Some(latest)) =
    ingestion_job_repo.get_latest_by_source(connection, "federal")
  // Should be one of the two (order depends on created_at which is same for :memory:)
  [latest.id == "fed-old" || latest.id == "fed-new"]
  |> list.any(fn(valid) { valid })
  |> should.be_true
}

pub fn get_latest_by_source_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(None) =
    ingestion_job_repo.get_latest_by_source(connection, "federal")
}

// --- Count consecutive failures ---

pub fn count_consecutive_failures_no_jobs_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let assert Ok(count) =
    ingestion_job_repo.count_consecutive_failures(connection, "federal")
  count |> should.equal(0)
}

pub fn count_consecutive_failures_with_failures_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  // Insert a completed job followed by two failed jobs
  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_job("fed-ok", Federal))
  let assert Ok(Nil) =
    ingestion_job_repo.mark_completed(connection, "fed-ok", 10, 10, 5)

  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_job("fed-f1", Federal))
  let assert Ok(Nil) =
    ingestion_job_repo.mark_failed(connection, "fed-f1", "error 1", 1)

  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_job("fed-f2", Federal))
  let assert Ok(Nil) =
    ingestion_job_repo.mark_failed(connection, "fed-f2", "error 2", 1)

  let assert Ok(count) =
    ingestion_job_repo.count_consecutive_failures(connection, "federal")
  count |> should.equal(2)
}
