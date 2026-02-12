import gleam/dynamic/decode
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import sqlight

/// Represents the progress of an ingestion run for a specific congress/bill_type.
pub type IngestionState {
  IngestionState(
    id: String,
    source: String,
    congress_number: Int,
    bill_type: String,
    last_offset: Int,
    last_update_date: Option(String),
    total_bills_fetched: Int,
    status: String,
    started_at: Option(String),
    completed_at: Option(String),
    error_message: Option(String),
  )
}

/// Build a deterministic ID for an ingestion state record.
pub fn build_ingestion_id(congress_number: Int, bill_type: String) -> String {
  "congress_gov-" <> int.to_string(congress_number) <> "-" <> bill_type
}

/// Insert or replace an ingestion state record.
pub fn upsert(
  connection: sqlight.Connection,
  state: IngestionState,
) -> Result(Nil, sqlight.Error) {
  let sql =
    "INSERT OR REPLACE INTO ingestion_state (
      id, source, congress_number, bill_type,
      last_offset, last_update_date, total_bills_fetched,
      status, started_at, completed_at, error_message,
      updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(state.id),
      sqlight.text(state.source),
      sqlight.int(state.congress_number),
      sqlight.text(state.bill_type),
      sqlight.int(state.last_offset),
      sqlight.nullable(sqlight.text, state.last_update_date),
      sqlight.int(state.total_bills_fetched),
      sqlight.text(state.status),
      sqlight.nullable(sqlight.text, state.started_at),
      sqlight.nullable(sqlight.text, state.completed_at),
      sqlight.nullable(sqlight.text, state.error_message),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Retrieve an ingestion state by congress number and bill type.
pub fn get_by_congress_and_type(
  connection: sqlight.Connection,
  congress_number: Int,
  bill_type: String,
) -> Result(Option(IngestionState), sqlight.Error) {
  let sql =
    "SELECT id, source, congress_number, bill_type,
      last_offset, last_update_date, total_bills_fetched,
      status, started_at, completed_at, error_message
    FROM ingestion_state
    WHERE congress_number = ? AND bill_type = ?"

  use rows <- result.try(sqlight.query(
    sql,
    on: connection,
    with: [sqlight.int(congress_number), sqlight.text(bill_type)],
    expecting: ingestion_state_row_decoder(),
  ))

  case rows {
    [record, ..] -> Ok(Some(record))
    [] -> Ok(None)
  }
}

/// Update the progress of an ingestion run.
pub fn update_progress(
  connection: sqlight.Connection,
  ingestion_id: String,
  new_offset: Int,
  additional_bills: Int,
) -> Result(Nil, sqlight.Error) {
  let sql =
    "UPDATE ingestion_state SET
      last_offset = ?,
      total_bills_fetched = total_bills_fetched + ?,
      updated_at = datetime('now')
    WHERE id = ?"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.int(new_offset),
      sqlight.int(additional_bills),
      sqlight.text(ingestion_id),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Mark an ingestion run as completed.
pub fn mark_completed(
  connection: sqlight.Connection,
  ingestion_id: String,
) -> Result(Nil, sqlight.Error) {
  let sql =
    "UPDATE ingestion_state SET
      status = 'completed',
      completed_at = datetime('now'),
      updated_at = datetime('now')
    WHERE id = ?"

  sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(ingestion_id)],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Mark an ingestion run as failed with an error message.
pub fn mark_failed(
  connection: sqlight.Connection,
  ingestion_id: String,
  error_message: String,
) -> Result(Nil, sqlight.Error) {
  let sql =
    "UPDATE ingestion_state SET
      status = 'failed',
      error_message = ?,
      updated_at = datetime('now')
    WHERE id = ?"

  sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(error_message), sqlight.text(ingestion_id)],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

// --- Row decoder ---

fn ingestion_state_row_decoder() -> decode.Decoder(IngestionState) {
  use id <- decode.field(0, decode.string)
  use source <- decode.field(1, decode.string)
  use congress_number <- decode.field(2, decode.int)
  use bill_type <- decode.field(3, decode.string)
  use last_offset <- decode.field(4, decode.int)
  use last_update_date <- decode.field(5, decode.optional(decode.string))
  use total_bills_fetched <- decode.field(6, decode.int)
  use status <- decode.field(7, decode.string)
  use started_at <- decode.field(8, decode.optional(decode.string))
  use completed_at <- decode.field(9, decode.optional(decode.string))
  use error_message <- decode.field(10, decode.optional(decode.string))
  decode.success(IngestionState(
    id:,
    source:,
    congress_number:,
    bill_type:,
    last_offset:,
    last_update_date:,
    total_bills_fetched:,
    status:,
    started_at:,
    completed_at:,
    error_message:,
  ))
}
