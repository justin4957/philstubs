# PHILSTUBS Testing Guide

## Running Tests

```sh
gleam test
```

## Test Structure

Tests live in `test/` and follow the gleeunit convention:
- Test files are named `*_test.gleam`
- Test functions are named `*_test`
- Use `gleeunit/should` for assertions

## Current Tests

### UI Tests (`test/philstubs_test.gleam`)

1. **`landing_page_renders_test`** — Verifies the Lustre landing page renders
   to an HTML string containing expected content (title, tagline, government levels).

### Domain Type Tests (`test/philstubs/core/domain_types_test.gleam`)

**GovernmentLevel** (8 tests):
- `to_string` for all 4 variants (Federal, State, County, Municipal)
- `jurisdiction_label` with jurisdiction data (e.g., "State (CA)", "County (Cook, IL)")
- JSON round-trip for all 4 variants including jurisdiction data

**LegislationType** (2 tests):
- `to_string` for all 7 variants
- JSON round-trip for all 7 variants

**LegislationStatus** (2 tests):
- `to_string` for all 7 variants
- JSON round-trip for all 7 variants

**Opaque IDs** (4 tests):
- LegislationId creation and string extraction
- LegislationId JSON round-trip
- TemplateId creation and string extraction
- TemplateId JSON round-trip

**Full Record Types** (3 tests):
- Legislation JSON round-trip with all fields including Option(Some)
- Legislation JSON round-trip with Option(None) source_url
- LegislationTemplate JSON round-trip with all fields

### Migration Tests (`test/philstubs/data/migration_test.gleam`)

**Migration Runner** (2 tests):
- `run_migrations_fresh_database_test` — Runs migrations on empty `:memory:` DB, verifies tables exist
- `run_migrations_idempotent_test` — Runs migrations twice, verifies second run applies zero changes

### Legislation Repository Tests (`test/philstubs/data/legislation_repo_test.gleam`)

**CRUD Operations** (7 tests):
- `insert_and_get_by_id_test` — Insert a record and retrieve it, verify all fields round-trip
- `get_by_id_not_found_test` — Query for nonexistent ID returns `Ok(None)`
- `list_all_test` — Insert multiple records, verify list returns correct count
- `update_test` — Insert, update fields (title, status, topics), verify changes persisted
- `delete_test` — Insert, delete, verify record is gone
- `insert_with_none_source_url_test` — Verify nullable `source_url` stored/retrieved as `None`
- `insert_with_county_level_test` — Verify County government level with state_code + county_name

**Full-Text Search** (1 test):
- `search_test` — Insert records with distinct terms, FTS5 search returns correct matches

### Template Repository Tests (`test/philstubs/data/template_repo_test.gleam`)

**CRUD Operations** (6 tests):
- `insert_and_get_by_id_test` — Insert template and retrieve, verify all fields
- `get_by_id_not_found_test` — Query for nonexistent ID returns `Ok(None)`
- `list_all_test` — Insert multiple templates, verify list count
- `update_test` — Update title, description, topics, verify changes
- `delete_test` — Insert, delete, verify removed
- `insert_with_federal_suggested_level_test` — Verify Federal level (no jurisdiction columns)

**Full-Text Search** (1 test):
- `search_test` — Insert templates with distinct terms, FTS5 search returns correct matches

**Download Count** (1 test):
- `increment_download_count_test` — Verify count increments from 42 to 43

### Congress.gov Ingestion Tests

#### Congress Types (`test/philstubs/ingestion/congress_types_test.gleam`)

**JSON Decoder Tests** (10 tests):
- `decode_bill_list_response_test` — Decode canned bill list JSON with pagination and latestAction
- `decode_bill_list_item_without_latest_action_test` — Decode bill with missing optional latestAction
- `decode_bill_detail_response_test` — Decode full detail with sponsors, policyArea, latestAction
- `decode_bill_detail_minimal_test` — Decode detail with only required fields, optional fields default
- `decode_latest_action_test` — Decode standalone latest action object
- `decode_sponsor_test` — Decode sponsor with all fields
- `decode_sponsor_minimal_test` — Decode sponsor with only fullName
- `bill_type_to_string_test` — Verify bill type enum to string mapping
- `all_bill_types_test` — Verify all 8 bill types returned
- `default_config_test` — Verify config constructor defaults
- `decode_pagination_without_next_test` — Decode pagination without next URL

#### Bill Mapper (`test/philstubs/ingestion/bill_mapper_test.gleam`)

**Pure Mapping Tests** (18 tests):
- `build_legislation_id_test` / `build_legislation_id_senate_test` — Deterministic ID construction
- `map_bill_type_*_test` (5 tests) — HR/S → Bill, HJRES/SCONRES → Resolution, unknown → Bill
- `infer_status_*_test` (7 tests) — Status inference from action text: None → Introduced, "became public law" → Enacted, "vetoed" → Vetoed, "passed house/senate" → PassedChamber, "referred to"/"committee" → InCommittee, fallback → Introduced
- `build_source_identifier_*_test` (4 tests) — H.R., S., H.J.Res., S.Con.Res. formatting
- `build_source_url_*_test` (2 tests) — Congress.gov URL construction for house/senate
- `map_list_item_to_legislation_test` — Full mapping from list item to domain type
- `map_detail_to_legislation_test` — Full mapping from detail to domain type with sponsors/topics
- `map_detail_to_legislation_no_policy_area_test` — Mapping with empty optional fields
- `map_list_item_resolution_type_test` — HJRES maps to Resolution type

#### Ingestion State Repository (`test/philstubs/ingestion/ingestion_state_repo_test.gleam`)

**Database CRUD Tests** (7 tests):
- `upsert_and_get_test` — Insert state and retrieve by congress/type
- `get_not_found_test` — Query for nonexistent state returns `Ok(None)`
- `upsert_replaces_existing_test` — Upsert overwrites previous record
- `update_progress_test` — Increment offset and total_bills_fetched across multiple calls
- `mark_completed_test` — Status transitions to "completed"
- `mark_failed_test` — Status transitions to "failed" with error message
- `build_ingestion_id_test` — Verify deterministic ID construction

#### Congress Ingestion Integration (`test/philstubs/ingestion/congress_ingestion_test.gleam`)

**Mock HTTP Tests** (4 tests):
- `ingest_bills_with_mock_test` — Full pipeline with mock dispatcher: fetch → map → store → verify DB records
- `ingest_bills_updates_ingestion_state_test` — Verify ingestion state tracking through pipeline
- `ingest_bills_idempotent_test` — Run ingestion twice, verify no duplicates (update existing records)
- `ingest_bills_handles_server_error_test` — Verify error handling marks ingestion state as failed

**Live API Test** (1 test, gated on CONGRESS_API_KEY):
- `live_api_smoke_test` — Fetches real bills from Congress.gov API, stores in memory DB, verifies structure

### Ingestion Testing Pattern

Ingestion tests use **function injection** for HTTP testability:

```gleam
import gleam/http/response.{type Response, Response}

fn mock_dispatcher() -> congress_api_client.HttpDispatcher {
  fn(_req: request.Request(String)) -> Result(Response(String), String) {
    Ok(Response(status: 200, headers: [], body: canned_json))
  }
}

pub fn ingest_with_mock_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let config = congress_types.default_config("test-key", 118)

  let assert Ok(result) =
    congress_ingestion.ingest_bills(connection, config, congress_types.Hr, mock_dispatcher())
  result.bills_stored |> should.equal(2)
}
```

Key patterns:
- Mock dispatchers return canned JSON responses for deterministic testing
- Error dispatchers simulate API failures (500s, timeouts)
- Live tests gated on `CONGRESS_API_KEY` env var — skip gracefully when unavailable
- All database tests use fresh `:memory:` SQLite with `test_helpers.setup_test_db`

## Testing Strategy

- **Pure function tests**: Test domain logic in `core/` with direct assertions
- **Rendering tests**: Test UI components by rendering to string and checking content
- **Database tests**: Use `:memory:` SQLite databases via `database.with_named_connection`
- **HTTP tests**: Use `wisp/testing` module for request/response testing

### Data Layer Testing Pattern

Database integration tests use in-memory SQLite with inline migration SQL:

```gleam
import philstubs/data/database
import philstubs/data/test_helpers

pub fn my_data_test() {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)

  // Test CRUD operations against the in-memory database
  let assert Ok(Nil) = legislation_repo.insert(connection, sample_record)
  let assert Ok(Some(retrieved)) = legislation_repo.get_by_id(connection, "id")
  retrieved.title |> should.equal("Expected Title")
}
```

Key conventions:
- `test_helpers.setup_test_db(connection)` runs all migrations via inline SQL
- Each test gets a fresh `:memory:` database — no shared state between tests
- `run_migrations_from_sql` avoids dependency on filesystem `priv/` directory in tests
- FTS5 search tests verify triggers keep the search index in sync with source tables

## Manual Verification

Start the server and test endpoints:

```sh
gleam run

# In another terminal:
curl -v http://localhost:8000/health    # Expect: 200 OK
curl http://localhost:8000/             # Expect: HTML with "PHILSTUBS"
curl http://localhost:8000/nonexistent  # Expect: 404
```

## Adding New Tests

For domain logic, create domain-specific test files:
```
test/philstubs/core/domain_types_test.gleam  (exists)
test/philstubs/web/router_test.gleam
```

For HTTP endpoint tests, use wisp testing utilities:
```gleam
import wisp/testing

pub fn health_check_test() {
  let request = testing.get("/health", [])
  let response = router.handle_request(request, test_context())
  response.status |> should.equal(200)
}
```
