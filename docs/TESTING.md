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
