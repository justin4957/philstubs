import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/core/ingestion_job.{
  type IngestionJob, type SourceStatus, Completed, Failed, Pending, Running,
}
import philstubs/ingestion/scheduler_actor.{type SchedulerStatus}
import philstubs/ui/layout

/// Render the admin ingestion dashboard page.
pub fn ingestion_dashboard_page(
  scheduler_status: Option(SchedulerStatus),
  recent_jobs: List(IngestionJob),
) -> Element(Nil) {
  layout.page_layout("Ingestion Dashboard — PHILSTUBS", [
    html.div([attribute.class("ingestion-dashboard")], [
      html.h1([], [html.text("Ingestion Dashboard")]),
      render_scheduler_status(scheduler_status),
      render_schedule_config(scheduler_status),
      render_recent_jobs_table(recent_jobs),
    ]),
  ])
}

fn render_scheduler_status(
  scheduler_status: Option(SchedulerStatus),
) -> Element(Nil) {
  case scheduler_status {
    None ->
      html.div([attribute.class("dashboard-alert")], [
        html.p([], [html.text("Scheduler is not running")]),
      ])
    Some(status) ->
      html.div([attribute.class("dashboard-section")], [
        html.h2([], [html.text("Source Status")]),
        html.div(
          [attribute.class("source-cards")],
          list.map(status.source_statuses, render_source_card),
        ),
      ])
  }
}

fn render_source_card(source_status: SourceStatus) -> Element(Nil) {
  let source_name = ingestion_job.source_to_string(source_status.source)

  let status_class = case source_status.last_run_status {
    Some(Completed) -> "status-completed"
    Some(Failed) -> "status-failed"
    Some(Running) -> "status-running"
    Some(Pending) -> "status-pending"
    None -> "status-none"
  }

  let status_label = case source_status.last_run_status {
    Some(job_status) -> ingestion_job.status_to_string(job_status)
    None -> "never run"
  }

  let last_run_text = case source_status.last_successful_run {
    Some(timestamp) -> timestamp
    None -> "Never"
  }

  html.div([attribute.class("source-card")], [
    html.div([attribute.class("source-card-header")], [
      html.h3([], [html.text(source_name)]),
      html.span([attribute.class("source-status-badge " <> status_class)], [
        html.text(status_label),
      ]),
    ]),
    html.div([attribute.class("source-card-body")], [
      html.div([attribute.class("source-card-stat")], [
        html.span([attribute.class("stat-label")], [
          html.text("Last Success"),
        ]),
        html.span([attribute.class("stat-value")], [
          html.text(last_run_text),
        ]),
      ]),
      html.div([attribute.class("source-card-stat")], [
        html.span([attribute.class("stat-label")], [
          html.text("Total Records"),
        ]),
        html.span([attribute.class("stat-value")], [
          html.text(int.to_string(source_status.total_records)),
        ]),
      ]),
      html.div([attribute.class("source-card-stat")], [
        html.span([attribute.class("stat-label")], [
          html.text("Consecutive Failures"),
        ]),
        html.span([attribute.class("stat-value")], [
          html.text(int.to_string(source_status.consecutive_failures)),
        ]),
      ]),
    ]),
    html.div([attribute.class("source-card-actions")], [
      html.form(
        [
          attribute.method("post"),
          attribute.action("/api/ingestion/trigger?source=" <> source_name),
        ],
        [
          html.button(
            [attribute.type_("submit"), attribute.class("btn btn-secondary")],
            [html.text("Trigger Now")],
          ),
        ],
      ),
    ]),
  ])
}

fn render_schedule_config(
  scheduler_status: Option(SchedulerStatus),
) -> Element(Nil) {
  case scheduler_status {
    None -> element.none()
    Some(status) ->
      html.div([attribute.class("dashboard-section")], [
        html.h2([], [html.text("Schedule Configuration")]),
        html.div([attribute.class("schedule-config")], [
          html.div([attribute.class("config-item")], [
            html.span([attribute.class("config-label")], [
              html.text("Federal"),
            ]),
            html.span([attribute.class("config-value")], [
              html.text(
                "Every "
                <> int.to_string(status.schedule_config.federal_interval_hours)
                <> " hours",
              ),
            ]),
          ]),
          html.div([attribute.class("config-item")], [
            html.span([attribute.class("config-label")], [
              html.text("State"),
            ]),
            html.span([attribute.class("config-value")], [
              html.text(
                "Every "
                <> int.to_string(status.schedule_config.state_interval_hours)
                <> " hours",
              ),
            ]),
          ]),
          html.div([attribute.class("config-item")], [
            html.span([attribute.class("config-label")], [
              html.text("Local"),
            ]),
            html.span([attribute.class("config-value")], [
              html.text(
                "Every "
                <> int.to_string(status.schedule_config.local_interval_hours)
                <> " hours",
              ),
            ]),
          ]),
        ]),
      ])
  }
}

fn render_recent_jobs_table(recent_jobs: List(IngestionJob)) -> Element(Nil) {
  html.div([attribute.class("dashboard-section")], [
    html.h2([], [html.text("Recent Jobs")]),
    case recent_jobs {
      [] ->
        html.p([attribute.class("empty-state")], [
          html.text("No ingestion jobs recorded yet"),
        ])
      _ ->
        html.table([attribute.class("jobs-table")], [
          html.thead([], [
            html.tr([], [
              html.th([], [html.text("Source")]),
              html.th([], [html.text("Status")]),
              html.th([], [html.text("Started")]),
              html.th([], [html.text("Duration")]),
              html.th([], [html.text("Fetched")]),
              html.th([], [html.text("Stored")]),
              html.th([], [html.text("Error")]),
            ]),
          ]),
          html.tbody([], list.map(recent_jobs, render_job_row)),
        ])
    },
  ])
}

fn render_job_row(job: IngestionJob) -> Element(Nil) {
  let status_class = case job.status {
    Completed -> "status-completed"
    Failed -> "status-failed"
    Running -> "status-running"
    Pending -> "status-pending"
  }

  let started_text = case job.started_at {
    Some(timestamp) -> timestamp
    None -> "—"
  }

  let duration_text = case job.duration_seconds > 0 {
    True -> int.to_string(job.duration_seconds) <> "s"
    False -> "—"
  }

  let error_text = case job.error_message {
    Some(message) -> message
    None -> "—"
  }

  html.tr([], [
    html.td([], [
      html.text(ingestion_job.source_to_string(job.source)),
    ]),
    html.td([], [
      html.span([attribute.class("source-status-badge " <> status_class)], [
        html.text(ingestion_job.status_to_string(job.status)),
      ]),
    ]),
    html.td([], [html.text(started_text)]),
    html.td([], [html.text(duration_text)]),
    html.td([], [html.text(int.to_string(job.records_fetched))]),
    html.td([], [html.text(int.to_string(job.records_stored))]),
    html.td([attribute.class("error-cell")], [html.text(error_text)]),
  ])
}
