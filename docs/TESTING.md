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

### Search Query Tests (`test/philstubs/search/search_query_test.gleam`)

**Query Builder** (10 tests):
- `default_query_test` — Verify default values (None text, page 1, per_page 20, Relevance sort)
- `from_query_params_with_text_test` — Parse `q=healthcare` into text field
- `from_query_params_with_filters_test` — Parse level, type, status, state_code filters
- `from_query_params_with_pagination_test` — Parse page and per_page values
- `from_query_params_clamps_values_test` — Page minimum 1, per_page max 100, invalid falls back to default
- `to_query_params_roundtrip_test` — Serialize and parse back preserves values
- `has_filters_test` — True when any filter set, false for default and text-only queries
- `from_query_params_with_sort_test` — Parse sort=date, sort=title, unknown defaults to Relevance
- `offset_calculation_test` — Verify (page-1) * per_page offset calculation
- `from_query_params_empty_values_ignored_test` — Empty strings treated as None
- `to_query_params_omits_defaults_test` — Default query produces empty params list

### Search Repository Tests (`test/philstubs/search/search_repo_test.gleam`)

**FTS5 Search + Faceted Filtering** (12 tests):
- `search_by_text_test` — FTS5 text search returns matching results
- `search_by_text_with_ranking_test` — Better matches ranked correctly
- `search_with_level_filter_test` — Filter by government_level returns only matching level
- `search_with_type_filter_test` — Filter by legislation_type returns only matching type
- `search_with_status_filter_test` — Filter by status returns only matching status
- `search_with_date_range_test` — Filter by introduced_date range (date_from/date_to)
- `search_with_combined_filters_test` — Multiple filters applied simultaneously
- `search_pagination_test` — Verify LIMIT/OFFSET, total_count, and total_pages
- `search_no_text_browse_test` — Filter-only search without text query returns all records
- `search_empty_results_test` — No matches returns empty results with count 0
- `search_text_with_filter_test` — Text search combined with faceted filter
- `search_snippet_contains_text_test` — FTS5 snippet() produces `<mark>` highlighted excerpts

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

### Template Handler Tests (`test/philstubs/web/template_handler_test.gleam`)

**Template Listing** (3 tests):
- `templates_list_empty_test` — Empty listing shows "No templates yet" message
- `templates_list_with_items_test` — Listing renders all template titles
- `templates_list_sorted_by_downloads_test` — Sort=downloads orders by download count

**Template Upload Form** (1 test):
- `template_new_form_test` — GET /templates/new renders upload form with fields

**Template Creation** (5 tests):
- `template_create_success_test` — POST /templates creates template and redirects
- `template_create_missing_title_test` — Returns 400 with "Title is required" error
- `template_create_missing_body_test` — Returns 400 with "Template body is required" error
- `template_create_missing_author_test` — Returns 400 with "Author is required" error
- `template_create_sanitizes_xss_test` — Verifies XSS script tags are sanitized in stored data

**Template Detail** (2 tests):
- `template_detail_test` — GET /templates/:id renders full template with metadata and download buttons
- `template_detail_not_found_test` — Returns 404 for nonexistent template

**Template Download** (4 tests):
- `template_download_plain_text_test` — Downloads as text/plain with content-disposition header
- `template_download_markdown_test` — Downloads as text/markdown with proper formatting
- `template_download_increments_count_test` — Download increments counter from 42 to 43
- `template_download_not_found_test` — Returns 404 for nonexistent template

**Template Deletion** (2 tests):
- `template_delete_test` — POST /templates/:id deletes template and redirects to listing
- `template_delete_not_found_test` — Returns 404 for nonexistent template

**JSON API** (3 tests):
- `api_templates_list_test` — GET /api/templates returns JSON array with content-type header
- `api_template_detail_test` — GET /api/templates/:id returns JSON object
- `api_template_not_found_test` — Returns 404 for nonexistent template

### Templates Page UI Tests (`test/philstubs/ui/templates_page_test.gleam`)

**Sort Logic** (3 tests):
- `sort_templates_newest_first_test` — Sorts by created_at descending
- `sort_templates_most_downloaded_test` — Sorts by download_count descending
- `sort_templates_alphabetical_test` — Sorts by title ascending

**Sort Order Parsing** (4 tests):
- `sort_order_from_string_newest_test` — Parses "newest" to Newest
- `sort_order_from_string_downloads_test` — Parses "downloads" to MostDownloaded
- `sort_order_from_string_title_test` — Parses "title" to Alphabetical
- `sort_order_from_string_unknown_defaults_newest_test` — Unknown value defaults to Newest

**Rendering** (3 tests):
- `templates_page_renders_empty_state_test` — Empty list shows "No templates yet" message
- `templates_page_renders_template_cards_test` — Renders template titles, authors, download counts
- `templates_page_renders_sort_links_test` — Renders sort control links

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

**Congress.gov CRUD Tests** (7 tests):
- `upsert_and_get_test` — Insert state and retrieve by congress/type, verify Optional fields
- `get_not_found_test` — Query for nonexistent state returns `Ok(None)`
- `upsert_replaces_existing_test` — Upsert overwrites previous record
- `update_progress_test` — Increment offset and total_bills_fetched across multiple calls
- `mark_completed_test` — Status transitions to "completed"
- `mark_failed_test` — Status transitions to "failed" with error message
- `build_ingestion_id_test` — Verify deterministic ID construction

**Open States CRUD Tests** (4 tests):
- `state_upsert_and_get_by_jurisdiction_test` — Insert state ingestion record and retrieve by jurisdiction/session
- `state_get_not_found_test` — Query for nonexistent jurisdiction/session returns `Ok(None)`
- `update_page_progress_test` — Increment last_page and total_bills_fetched across multiple calls
- `build_state_ingestion_id_test` — Verify deterministic state ingestion ID construction

#### Congress Ingestion Integration (`test/philstubs/ingestion/congress_ingestion_test.gleam`)

**Mock HTTP Tests** (4 tests):
- `ingest_bills_with_mock_test` — Full pipeline with mock dispatcher: fetch → map → store → verify DB records
- `ingest_bills_updates_ingestion_state_test` — Verify ingestion state tracking through pipeline
- `ingest_bills_idempotent_test` — Run ingestion twice, verify no duplicates (update existing records)
- `ingest_bills_handles_server_error_test` — Verify error handling marks ingestion state as failed

**Live API Test** (1 test, gated on CONGRESS_API_KEY):
- `live_api_smoke_test` — Fetches real bills from Congress.gov API, stores in memory DB, verifies structure

### Open States Ingestion Tests

#### Open States Types (`test/philstubs/ingestion/openstates_types_test.gleam`)

**JSON Decoder Tests** (14 tests):
- `decode_jurisdiction_test` — Decode jurisdiction with id, name, classification
- `decode_person_test` — Decode person with name and party
- `decode_person_minimal_test` — Decode person with only name (no party)
- `decode_sponsorship_test` — Decode sponsorship with nested person
- `decode_sponsorship_without_person_test` — Decode sponsorship without person
- `decode_abstract_test` — Decode abstract with text and note
- `decode_abstract_without_note_test` — Decode abstract without optional note
- `decode_action_test` — Decode action with description, date, classification
- `decode_action_without_classification_test` — Decode action without classification list
- `decode_pagination_test` — Decode pagination with per_page, page, max_page, total_items
- `decode_bill_test` — Decode full bill with all nested objects
- `decode_bill_minimal_test` — Decode bill with only required fields, optional fields default
- `decode_bill_list_response_test` — Decode bill list response with results and pagination
- `default_config_test` — Verify config constructor defaults

#### State Bill Mapper (`test/philstubs/ingestion/state_bill_mapper_test.gleam`)

**Pure Mapping Tests** (28 tests):
- `build_legislation_id_test` / `build_legislation_id_house_bill_test` — Deterministic ID construction with space/dot removal
- `extract_state_code_*_test` (4 tests) — Extract 2-letter state code from OCD jurisdiction ID (CA, TX, NY, empty)
- `map_classification_*_test` (6 tests) — Bill classification mapping: bill → Bill, resolution/joint/concurrent → Resolution, empty/unknown → Bill
- `infer_status_*_test` (9 tests) — Status inference from action classifications: became-law/executive-signature → Enacted, executive-veto → Vetoed, passage → PassedChamber, committee-referral/committee-passage → InCommittee, introduction → Introduced, empty → Introduced, uses last action
- `extract_sponsor_names_*_test` (3 tests) — Extract from person.name when available, fallback to sponsorship.name, mixed sources
- `extract_summary_test` / `extract_summary_empty_test` — First abstract text or empty string
- `map_bill_to_legislation_test` — Full mapping: all fields including State("CA") level, sponsors, topics, summary
- `map_bill_resolution_type_test` — Resolution classification maps to Resolution type
- `map_bill_no_abstracts_test` — Empty abstracts produces empty summary
- `map_bill_no_first_action_date_test` — None first_action_date produces empty introduced_date

#### State Ingestion Integration (`test/philstubs/ingestion/state_ingestion_test.gleam`)

**Mock HTTP Tests** (5 tests):
- `ingest_jurisdiction_with_mock_test` — Full pipeline with mock dispatcher: fetch → map → store → verify DB records with State("CA") level
- `ingest_jurisdiction_updates_ingestion_state_test` — Verify ingestion state tracking with jurisdiction/session fields
- `ingest_jurisdiction_idempotent_test` — Run ingestion twice, verify no duplicates (update existing records)
- `ingest_jurisdiction_handles_server_error_test` — Verify error handling marks ingestion state as failed
- `ingest_jurisdictions_continues_on_failure_test` — Verify per-jurisdiction error isolation (both jurisdictions get results)

**Live API Test** (1 test, gated on PLURAL_POLICY_KEY):
- `live_api_smoke_test` — Fetches real bills from Open States API, stores in memory DB, verifies State level and structure

### Legistar (Local/Municipal/County) Ingestion Tests

#### Legistar Types (`test/philstubs/ingestion/legistar_types_test.gleam`)

**JSON Decoder Tests** (9 tests):
- `decode_full_matter_test` — Decode matter with all 15 fields populated
- `decode_minimal_matter_test` — Decode matter with only required fields (MatterId, MatterGuid)
- `decode_null_fields_matter_test` — Decode matter with explicit null values for all optional fields
- `decode_sponsor_test` — Decode sponsor with MatterSponsorName
- `decode_empty_matters_array_test` — Decode empty JSON array (pagination end signal)
- `decode_matters_array_test` — Decode array with multiple matters
- `decode_sponsors_array_test` — Decode array with multiple sponsors
- `default_config_test` — Verify config constructor with no token
- `default_config_with_token_test` — Verify config constructor with token

#### Legistar Mapper (`test/philstubs/ingestion/legistar_mapper_test.gleam`)

**Pure Mapping Tests** (23 tests):
- `build_legislation_id_test` / `build_legislation_id_county_test` — Deterministic ID construction ("legistar-{client}-{id}")
- `map_type_*_test` (6 tests) — Ordinance → Ordinance, Resolution → Resolution, Motion → Bill, None → Bill, unknown → Bill, Executive Order → ExecutiveOrder
- `map_status_*_test` (8 tests) — Adopted/Passed → Enacted, Vetoed → Vetoed, Referred → InCommittee, Filed → Introduced, Withdrawn → Withdrawn, Expired → Expired, None → Introduced
- `extract_title_*_test` (4 tests) — Title fallback chain: matter_title → matter_name → matter_file → "Untitled"
- `parse_date_*_test` (3 tests) — Strip T00:00:00 suffix, handle bare date, handle None
- `build_source_url_test` — Legistar URL construction
- `extract_sponsor_names_test` / `extract_sponsor_names_empty_test` — Sponsor name extraction
- `map_matter_to_legislation_municipal_test` — Full mapping with Municipal("WA", "Seattle") level, sponsors, all fields
- `map_matter_to_legislation_county_test` — Full mapping with County("WA", "King County") level
- `map_matter_minimal_test` — Mapping with all-None optional fields, defaults to Bill/Introduced/empty

#### Jurisdiction Registry (`test/philstubs/ingestion/jurisdiction_registry_test.gleam`)

**Registry Tests** (5 tests):
- `get_by_client_id_found_test` — Look up "seattle" returns Municipal("WA", "Seattle")
- `get_by_client_id_not_found_test` — Look up "nonexistent" returns None
- `get_by_client_id_county_test` — Look up "kingcounty" returns County("WA", "King County")
- `all_jurisdictions_returns_expected_entries_test` — Verify 6 entries (4 Municipal, 2 County)
- `get_by_client_id_cook_county_test` — Look up "cookcounty" returns County("IL", "Cook County")

#### Legistar Ingestion Integration (`test/philstubs/ingestion/legistar_ingestion_test.gleam`)

**Mock HTTP Tests** (5 tests):
- `ingest_client_with_mock_test` — Full pipeline with mock dispatcher: fetch matters → fetch sponsors per matter → map → store → verify DB records with Municipal("WA", "Seattle") level, sponsors from separate endpoint
- `ingest_client_updates_ingestion_state_test` — Verify ingestion state tracking (source="legistar", jurisdiction=client_id, session="current")
- `ingest_client_idempotent_test` — Run ingestion twice, verify no duplicates (update existing records)
- `ingest_client_handles_server_error_test` — Verify error handling marks ingestion state as failed
- `ingest_clients_continues_on_failure_test` — Verify per-client error isolation (both clients get results)

**Live API Test** (1 test, always runs — Seattle is public/no token):
- `live_api_smoke_test` — Fetches real matters from Legistar Seattle (public, no token needed), stores in memory DB, verifies Municipal("WA", "Seattle") level and "legistar-" ID prefix. Gracefully handles API unavailability.

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
- Legistar mock dispatchers route by URL path to return different responses for matters vs sponsors endpoints
- Error dispatchers simulate API failures (500s, timeouts)
- Live tests gated on env vars — skip gracefully when unavailable:
  - `CONGRESS_API_KEY` for Congress.gov tests
  - `PLURAL_POLICY_KEY` for Open States tests
  - Legistar Seattle tests always run (public API, no token required)
- All database tests use fresh `:memory:` SQLite with `test_helpers.setup_test_db`
- All ingestion sources share the same `HttpDispatcher` type for consistency
- State ingestion tests verify `GovernmentLevel.State("CA")` is correctly set on stored records
- Legistar ingestion tests verify `GovernmentLevel.Municipal("WA", "Seattle")` and `GovernmentLevel.County("WA", "King County")` on stored records

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

# Search page:
curl http://localhost:8000/search              # Expect: HTML search page
curl "http://localhost:8000/search?q=test"     # Expect: Search results page

# Search API:
curl "http://localhost:8000/api/search?q=test"                       # Expect: JSON
curl "http://localhost:8000/api/search?level=federal&type=bill"      # Expect: Filtered JSON
curl "http://localhost:8000/api/search?q=test&page=2&per_page=10"   # Expect: Paginated JSON

# Templates:
curl http://localhost:8000/templates                 # Expect: HTML template listing
curl http://localhost:8000/templates/new              # Expect: HTML upload form
curl "http://localhost:8000/templates?sort=downloads"  # Expect: Sorted by downloads

# Template API:
curl http://localhost:8000/api/templates              # Expect: JSON array of templates
curl http://localhost:8000/api/templates/TEMPLATE_ID   # Expect: JSON template object

# Template upload (POST):
curl -X POST http://localhost:8000/templates \
  -d "title=Test+Template&description=A+test&body=SECTION+1.+Test&author=Test+Author&suggested_level=federal&suggested_type=bill&topics=test"
# Expect: 303 redirect to /templates/TEMPLATE_ID

# Template download:
curl "http://localhost:8000/templates/TEMPLATE_ID/download?format=text"       # Expect: Plain text
curl "http://localhost:8000/templates/TEMPLATE_ID/download?format=markdown"   # Expect: Markdown
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
