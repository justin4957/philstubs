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

## Testing Strategy

- **Pure function tests**: Test domain logic in `core/` with direct assertions
- **Rendering tests**: Test UI components by rendering to string and checking content
- **Database tests**: Use `:memory:` SQLite databases via `database.with_named_connection`
- **HTTP tests**: Use `wisp/testing` module for request/response testing

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
