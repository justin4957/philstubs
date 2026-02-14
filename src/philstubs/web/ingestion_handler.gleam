import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import philstubs/core/ingestion_job
import philstubs/data/ingestion_job_repo
import philstubs/ingestion/scheduler_actor
import philstubs/web/api_error
import philstubs/web/context.{type Context}
import sqlight
import wisp.{type Request, type Response}

/// GET /api/ingestion/status — returns scheduler status as JSON.
pub fn handle_status(request: Request, application_context: Context) -> Response {
  use <- wisp.require_method(request, http.Get)

  case application_context.scheduler {
    None ->
      json.object([
        #("error", json.string("Scheduler not running")),
        #("is_running", json.bool(False)),
      ])
      |> json.to_string
      |> wisp.json_response(503)
    Some(scheduler_subject) -> {
      let status = scheduler_actor.get_status(scheduler_subject)
      json.object([
        #("is_running", json.bool(status.is_running)),
        #(
          "schedule_config",
          json.object([
            #(
              "federal_interval_hours",
              json.int(status.schedule_config.federal_interval_hours),
            ),
            #(
              "state_interval_hours",
              json.int(status.schedule_config.state_interval_hours),
            ),
            #(
              "local_interval_hours",
              json.int(status.schedule_config.local_interval_hours),
            ),
          ]),
        ),
        #(
          "sources",
          json.array(
            status.source_statuses,
            ingestion_job.source_status_to_json,
          ),
        ),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    }
  }
}

/// GET /api/ingestion/jobs — list recent ingestion jobs.
/// Supports ?source=federal&limit=20 query params.
pub fn handle_jobs(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)

  let query_params = wisp.get_query(request)
  let source_filter =
    list.find(query_params, fn(pair) { pair.0 == "source" })
    |> result.map(fn(pair) { pair.1 })
    |> option.from_result

  let limit =
    list.find(query_params, fn(pair) { pair.0 == "limit" })
    |> result.try(fn(pair) { int.parse(pair.1) })
    |> result.unwrap(20)

  let jobs_result = case source_filter {
    Some(source_string) ->
      ingestion_job_repo.list_by_source(db_connection, source_string, limit)
    None -> ingestion_job_repo.list_recent(db_connection, limit)
  }

  case jobs_result {
    Ok(jobs) ->
      json.object([
        #("jobs", json.array(jobs, ingestion_job.job_to_json)),
        #("count", json.int(list.length(jobs))),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    Error(_) -> api_error.internal_error()
  }
}

/// GET /api/ingestion/jobs/:id — single job detail.
pub fn handle_job_detail(
  request: Request,
  job_id: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)

  case ingestion_job_repo.get_by_id(db_connection, job_id) {
    Ok(Some(job)) ->
      job
      |> ingestion_job.job_to_json
      |> json.to_string
      |> wisp.json_response(200)
    Ok(None) -> api_error.not_found("Ingestion job")
    Error(_) -> api_error.internal_error()
  }
}

/// POST /api/ingestion/trigger — manually trigger ingestion.
/// Requires ?source=federal query param.
pub fn handle_trigger(
  request: Request,
  application_context: Context,
) -> Response {
  use <- wisp.require_method(request, http.Post)

  case application_context.scheduler {
    None ->
      api_error.error_response(
        "Scheduler not running",
        api_error.InternalError,
        503,
      )
    Some(scheduler_subject) -> {
      let query_params = wisp.get_query(request)
      let source_param =
        list.find(query_params, fn(pair) { pair.0 == "source" })
        |> result.map(fn(pair) { pair.1 })

      case source_param {
        Error(Nil) ->
          api_error.validation_error("Missing required 'source' parameter")
        Ok(source_string) -> {
          case ingestion_job.source_from_string(source_string) {
            Error(Nil) ->
              api_error.validation_error(
                "Invalid source. Must be one of: federal, state, local",
              )
            Ok(source) -> {
              let trigger_result =
                scheduler_actor.trigger(scheduler_subject, source)
              case trigger_result {
                scheduler_actor.TriggerAccepted(job_id:) ->
                  json.object([
                    #("status", json.string("accepted")),
                    #("job_id", json.string(job_id)),
                    #("source", json.string(source_string)),
                  ])
                  |> json.to_string
                  |> wisp.json_response(202)
                scheduler_actor.TriggerRejected(reason:) ->
                  json.object([
                    #("status", json.string("rejected")),
                    #("reason", json.string(reason)),
                  ])
                  |> json.to_string
                  |> wisp.json_response(409)
              }
            }
          }
        }
      }
    }
  }
}
