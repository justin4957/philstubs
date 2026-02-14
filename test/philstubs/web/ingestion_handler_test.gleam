import gleam/http
import gleam/option.{None}
import gleam/string
import gleeunit/should
import philstubs/core/ingestion_job.{
  type IngestionJob, Federal, IngestionJob, Pending,
}
import philstubs/data/database
import philstubs/data/ingestion_job_repo
import philstubs/data/test_helpers
import philstubs/web/context.{Context}
import philstubs/web/router
import sqlight
import wisp/simulate

fn test_context(db_connection: sqlight.Connection) -> context.Context {
  Context(
    static_directory: "",
    db_connection:,
    current_user: None,
    github_client_id: "",
    github_client_secret: "",
    scheduler: None,
  )
}

fn sample_ingestion_job(job_id: String) -> IngestionJob {
  IngestionJob(
    id: job_id,
    source: Federal,
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

// --- GET /api/ingestion/status (no scheduler) ---

pub fn ingestion_status_no_scheduler_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/ingestion/status")
    |> router.handle_request(context)

  response.status |> should.equal(503)
  let body = simulate.read_body(response)
  body |> string.contains("Scheduler not running") |> should.be_true
  body |> string.contains("\"is_running\":false") |> should.be_true
}

// --- GET /api/ingestion/jobs ---

pub fn ingestion_jobs_empty_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/ingestion/jobs")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"jobs\"") |> should.be_true
  body |> string.contains("\"count\":0") |> should.be_true
}

pub fn ingestion_jobs_with_data_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_ingestion_job("job-1"))
  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_ingestion_job("job-2"))

  let response =
    simulate.request(http.Get, "/api/ingestion/jobs")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"count\":2") |> should.be_true
  body |> string.contains("job-1") |> should.be_true
  body |> string.contains("job-2") |> should.be_true
}

pub fn ingestion_jobs_with_source_filter_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_ingestion_job("fed-job"))
  let assert Ok(Nil) =
    ingestion_job_repo.insert(
      connection,
      IngestionJob(
        ..sample_ingestion_job("state-job"),
        source: ingestion_job.State,
      ),
    )

  let response =
    simulate.request(http.Get, "/api/ingestion/jobs?source=federal")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"count\":1") |> should.be_true
  body |> string.contains("fed-job") |> should.be_true
  body |> string.contains("state-job") |> should.be_false
}

pub fn ingestion_jobs_with_limit_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_ingestion_job("job-a"))
  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_ingestion_job("job-b"))
  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_ingestion_job("job-c"))

  let response =
    simulate.request(http.Get, "/api/ingestion/jobs?limit=2")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("\"count\":2") |> should.be_true
}

// --- GET /api/ingestion/jobs/:id ---

pub fn ingestion_job_detail_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_ingestion_job("detail-job"))

  let response =
    simulate.request(http.Get, "/api/ingestion/jobs/detail-job")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("detail-job") |> should.be_true
  body |> string.contains("\"federal\"") |> should.be_true
  body |> string.contains("\"pending\"") |> should.be_true
}

pub fn ingestion_job_detail_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/ingestion/jobs/nonexistent")
    |> router.handle_request(context)

  response.status |> should.equal(404)
  let body = simulate.read_body(response)
  body |> string.contains("NOT_FOUND") |> should.be_true
}

// --- POST /api/ingestion/trigger (no scheduler) ---

pub fn ingestion_trigger_no_scheduler_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Post, "/api/ingestion/trigger?source=federal")
    |> router.handle_request(context)

  response.status |> should.equal(503)
  let body = simulate.read_body(response)
  body |> string.contains("Scheduler not running") |> should.be_true
}

// --- GET /admin/ingestion (dashboard) ---

pub fn ingestion_dashboard_renders_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/admin/ingestion")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  body |> string.contains("Ingestion Dashboard") |> should.be_true
  body |> string.contains("Recent Jobs") |> should.be_true
}

pub fn ingestion_dashboard_shows_jobs_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let assert Ok(Nil) =
    ingestion_job_repo.insert(connection, sample_ingestion_job("dash-job"))
  let assert Ok(Nil) = ingestion_job_repo.mark_running(connection, "dash-job")

  let response =
    simulate.request(http.Get, "/admin/ingestion")
    |> router.handle_request(context)

  response.status |> should.equal(200)
  let body = simulate.read_body(response)
  // Dashboard renders job rows with source name and status, not job ID
  body |> string.contains("federal") |> should.be_true
  body |> string.contains("running") |> should.be_true
}

// --- Method not allowed ---

pub fn ingestion_jobs_post_not_allowed_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Post, "/api/ingestion/jobs")
    |> router.handle_request(context)

  response.status |> should.equal(405)
}

pub fn ingestion_trigger_get_not_allowed_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let context = test_context(connection)

  let response =
    simulate.request(http.Get, "/api/ingestion/trigger?source=federal")
    |> router.handle_request(context)

  response.status |> should.equal(405)
}
