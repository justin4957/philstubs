import gleam/option.{None, Some}
import gleeunit/should
import philstubs/data/database
import philstubs/data/test_helpers
import philstubs/ingestion/ingestion_state_repo.{
  type IngestionState, IngestionState,
}

fn sample_ingestion_state() -> IngestionState {
  IngestionState(
    id: "congress_gov-118-hr",
    source: "congress_gov",
    congress_number: 118,
    bill_type: "hr",
    last_offset: 0,
    last_update_date: None,
    total_bills_fetched: 0,
    status: "pending",
    started_at: None,
    completed_at: None,
    error_message: None,
  )
}

pub fn upsert_and_get_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let state = sample_ingestion_state()
  let assert Ok(Nil) = ingestion_state_repo.upsert(connection, state)

  let assert Ok(Some(retrieved)) =
    ingestion_state_repo.get_by_congress_and_type(connection, 118, "hr")

  retrieved.id |> should.equal("congress_gov-118-hr")
  retrieved.source |> should.equal("congress_gov")
  retrieved.congress_number |> should.equal(118)
  retrieved.bill_type |> should.equal("hr")
  retrieved.last_offset |> should.equal(0)
  retrieved.total_bills_fetched |> should.equal(0)
  retrieved.status |> should.equal("pending")
}

pub fn get_not_found_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let result =
    ingestion_state_repo.get_by_congress_and_type(connection, 118, "hr")
  result |> should.equal(Ok(None))
}

pub fn upsert_replaces_existing_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let state = sample_ingestion_state()
  let assert Ok(Nil) = ingestion_state_repo.upsert(connection, state)

  // Update with new values
  let updated_state =
    IngestionState(..state, last_offset: 100, status: "in_progress")
  let assert Ok(Nil) = ingestion_state_repo.upsert(connection, updated_state)

  let assert Ok(Some(retrieved)) =
    ingestion_state_repo.get_by_congress_and_type(connection, 118, "hr")
  retrieved.last_offset |> should.equal(100)
  retrieved.status |> should.equal("in_progress")
}

pub fn update_progress_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let state = sample_ingestion_state()
  let assert Ok(Nil) = ingestion_state_repo.upsert(connection, state)

  // Update progress: offset to 20, fetched 20 more bills
  let assert Ok(Nil) =
    ingestion_state_repo.update_progress(
      connection,
      "congress_gov-118-hr",
      20,
      20,
    )

  let assert Ok(Some(retrieved)) =
    ingestion_state_repo.get_by_congress_and_type(connection, 118, "hr")
  retrieved.last_offset |> should.equal(20)
  retrieved.total_bills_fetched |> should.equal(20)

  // Update progress again: offset to 40, fetched 15 more
  let assert Ok(Nil) =
    ingestion_state_repo.update_progress(
      connection,
      "congress_gov-118-hr",
      40,
      15,
    )

  let assert Ok(Some(retrieved_again)) =
    ingestion_state_repo.get_by_congress_and_type(connection, 118, "hr")
  retrieved_again.last_offset |> should.equal(40)
  retrieved_again.total_bills_fetched |> should.equal(35)
}

pub fn mark_completed_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let state = IngestionState(..sample_ingestion_state(), status: "in_progress")
  let assert Ok(Nil) = ingestion_state_repo.upsert(connection, state)

  let assert Ok(Nil) =
    ingestion_state_repo.mark_completed(connection, "congress_gov-118-hr")

  let assert Ok(Some(retrieved)) =
    ingestion_state_repo.get_by_congress_and_type(connection, 118, "hr")
  retrieved.status |> should.equal("completed")
}

pub fn mark_failed_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  let state = IngestionState(..sample_ingestion_state(), status: "in_progress")
  let assert Ok(Nil) = ingestion_state_repo.upsert(connection, state)

  let assert Ok(Nil) =
    ingestion_state_repo.mark_failed(
      connection,
      "congress_gov-118-hr",
      "Rate limit exceeded",
    )

  let assert Ok(Some(retrieved)) =
    ingestion_state_repo.get_by_congress_and_type(connection, 118, "hr")
  retrieved.status |> should.equal("failed")
  retrieved.error_message |> should.equal(Some("Rate limit exceeded"))
}

pub fn build_ingestion_id_test() {
  ingestion_state_repo.build_ingestion_id(118, "hr")
  |> should.equal("congress_gov-118-hr")

  ingestion_state_repo.build_ingestion_id(117, "sjres")
  |> should.equal("congress_gov-117-sjres")
}
