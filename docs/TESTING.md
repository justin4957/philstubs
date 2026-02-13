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

### Landing Page Tests (`test/philstubs_test.gleam`)

**Landing Page** (7 tests):
- `landing_page_renders_test` — Verifies the Lustre landing page renders with title, tagline, and government levels
- `landing_page_shows_stats_test` — Verifies live stats (legislation count, template count) are rendered
- `landing_page_shows_search_bar_test` — Verifies the hero search bar form renders with /search action
- `landing_page_shows_how_it_works_test` — Verifies the How It Works section with Browse, Search, Templates cards
- `landing_page_shows_level_counts_test` — Verifies level counts display in the Government Levels overview
- `landing_page_shows_cta_test` — Verifies the "Start Exploring" CTA renders
- `landing_page_empty_data_test` — Verifies page renders correctly with zero/empty data

### Shared Component Tests (`test/philstubs/ui/components_test.gleam`)

**Badge** (2 tests):
- `badge_renders_test` — Renders badge with CSS class and text (e.g., "level-badge" + "Federal")
- `badge_custom_class_test` — Custom class names applied correctly (e.g., "status-badge")

**Metadata Item** (1 test):
- `metadata_item_renders_test` — Renders label/value pair with metadata-item/metadata-label/metadata-value classes

**Topics Section** (2 tests):
- `topics_section_renders_test` — Renders topic tags with topic-tags CSS class
- `topics_section_empty_returns_none_test` — Empty topics list renders as empty string (element.none())

**Stat Card** (1 test):
- `stat_card_renders_test` — Renders stat-card with value and label

**Search Bar** (2 tests):
- `search_bar_renders_test` — Renders search form with placeholder and /search action
- `search_bar_has_accessible_label_test` — Includes sr-only label for screen reader accessibility

**Stats Row** (1 test):
- `stats_row_renders_multiple_test` — Renders multiple stat cards in a stats-row container

**Action Card** (1 test):
- `action_card_renders_test` — Renders linked card with icon, title, description, and URL

**Level Overview Card** (2 tests):
- `level_overview_card_renders_test` — Renders card with title, count, description, and link
- `level_overview_card_zero_count_test` — Renders correctly with zero count

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

### Browse Repository Tests (`test/philstubs/data/browse_repo_test.gleam`)

**Government Level Counts** (2 tests):
- `count_by_government_level_test` — Counts legislation grouped by level (federal, state, county, municipal)
- `count_by_government_level_empty_db_test` — Returns empty list on empty database

**State Counts** (2 tests):
- `count_by_state_test` — Counts all legislation per state (includes state, county, municipal levels)
- `count_by_state_alphabetical_order_test` — State codes returned in alphabetical order

**County/Municipality Counts** (4 tests):
- `count_counties_in_state_test` — Counts county-level legislation within a state
- `count_counties_in_state_empty_test` — Returns empty list for state with no counties
- `count_municipalities_in_state_test` — Counts municipal-level legislation within a state
- `count_municipalities_in_state_different_state_test` — Counts municipalities for different states independently

**State Legislation Count** (2 tests):
- `count_state_legislation_test` — Counts state-level-only legislation for a specific state
- `count_state_legislation_empty_test` — Returns 0 for state with no state-level legislation

**Topic Counts** (3 tests):
- `count_topics_test` — Extracts topics from JSON arrays and counts across all legislation
- `count_topics_ordered_by_count_descending_test` — Topics ordered by count descending
- `count_topics_empty_db_test` — Returns empty list on empty database

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

### Browse Handler Tests (`test/philstubs/web/browse_handler_test.gleam`)

**Browse Root** (4 tests):
- `browse_root_renders_test` — GET /browse renders page with all government level names
- `browse_root_shows_counts_test` — Root page displays legislation counts per level
- `browse_root_shows_topic_link_test` — Root page includes link to /browse/topics
- `browse_root_empty_db_test` — Empty database shows 0 counts

**Federal Redirect** (1 test):
- `browse_federal_redirects_to_search_test` — GET /browse/federal returns 303 redirect to /search?level=federal

**States Browser** (4 tests):
- `browse_states_renders_test` — GET /browse/states renders page with state codes and counts
- `browse_states_shows_breadcrumbs_test` — States page includes breadcrumb navigation
- `browse_states_empty_test` — Empty database shows "No state legislation available" message
- `browse_states_links_to_state_detail_test` — State items link to /browse/state/:code

**State Detail** (6 tests):
- `browse_state_detail_renders_test` — GET /browse/state/CA renders page with state title
- `browse_state_detail_shows_breadcrumbs_test` — State detail shows Browse > States > CA breadcrumbs
- `browse_state_detail_shows_counties_test` — State detail displays county names with counts
- `browse_state_detail_shows_municipalities_test` — State detail displays municipality names with counts
- `browse_state_detail_links_to_search_test` — State legislature link points to search with filters
- `browse_state_detail_empty_counties_test` — Empty state shows "No county/municipal legislation" messages

**Topics Browser** (4 tests):
- `browse_topics_renders_test` — GET /browse/topics renders page with topic names
- `browse_topics_links_to_search_test` — Topic items link to /search?q=TOPIC
- `browse_topics_shows_breadcrumbs_test` — Topics page includes breadcrumb navigation
- `browse_topics_empty_test` — Empty database shows "No topics available" message

**Navigation** (1 test):
- `browse_link_in_navigation_test` — Browse link appears in site navigation

### Stats Repository Tests (`test/philstubs/data/stats_repo_test.gleam`)

**Legislation Statistics** (5 tests):
- `get_legislation_stats_total_test` — Verifies total legislation count across all levels
- `get_legislation_stats_by_level_test` — Counts grouped by government level (federal, state, county, municipal)
- `get_legislation_stats_by_type_test` — Counts grouped by legislation type (bill, resolution, ordinance)
- `get_legislation_stats_by_status_test` — Counts grouped by status (introduced, enacted, in_committee)
- `get_legislation_stats_empty_db_test` — All counts return 0 on empty database

### API Handler Tests (`test/philstubs/web/api_handler_test.gleam`)

**Legislation API** (4 tests):
- `api_legislation_list_test` — GET /api/legislation returns paginated JSON with items, total_count, page
- `api_legislation_list_with_level_filter_test` — Filtering by level=federal returns only federal legislation
- `api_legislation_list_empty_test` — Empty database returns total_count 0
- `api_legislation_list_has_cors_headers_test` — Response includes Access-Control-Allow-Origin: * header

**Legislation Stats** (2 tests):
- `api_legislation_stats_test` — GET /api/legislation/stats returns total, by_level, by_type, by_status
- `api_legislation_stats_empty_test` — Empty database returns total 0 with empty arrays

**Error Format** (1 test):
- `api_legislation_not_found_error_format_test` — GET /api/legislation/:id returns 404 for nonexistent

**Template CRUD via API** (7 tests, all require authentication):
- `api_template_create_test` — POST /api/templates with JSON body creates template, returns 201
- `api_template_create_missing_title_test` — Empty title returns 400 with VALIDATION_ERROR code
- `api_template_create_invalid_json_test` — Malformed JSON body returns 400
- `api_template_update_test` — PUT /api/templates/:id updates template fields, returns 200
- `api_template_update_not_found_test` — PUT to nonexistent template returns 404 with NOT_FOUND code
- `api_template_delete_test` — DELETE /api/templates/:id returns 204 and removes from database
- `api_template_delete_not_found_test` — DELETE nonexistent template returns 404

**Template Download via API** (3 tests):
- `api_template_download_text_test` — GET /api/templates/:id/download returns text/plain content
- `api_template_download_markdown_test` — GET /api/templates/:id/download?format=markdown returns markdown
- `api_template_download_not_found_test` — Download of nonexistent template returns 404

**Levels API** (2 tests):
- `api_levels_list_test` — GET /api/levels returns levels array with level, label, and count fields
- `api_levels_list_empty_test` — Empty database returns empty levels array

**Jurisdictions API** (5 tests):
- `api_level_state_jurisdictions_test` — GET /api/levels/state/jurisdictions returns state names with counts
- `api_level_county_jurisdictions_test` — GET /api/levels/county/jurisdictions?state=CA returns county names
- `api_level_county_requires_state_param_test` — County jurisdictions without state param returns 400
- `api_level_municipal_jurisdictions_test` — GET /api/levels/municipal/jurisdictions?state=WA returns municipalities
- `api_level_unknown_returns_not_found_test` — Unknown level returns 404 with NOT_FOUND code

**Topics API** (2 tests):
- `api_topics_list_test` — GET /api/topics returns topics array with topic and count fields
- `api_topics_list_empty_test` — Empty database returns empty topics array

**CORS** (2 tests):
- `api_cors_headers_on_get_test` — All API responses include CORS headers
- `api_cors_preflight_test` — OPTIONS requests return 204 with CORS headers

**Error Handling** (3 tests):
- `api_templates_method_not_allowed_test` — PATCH to /api/templates returns 405 with METHOD_NOT_ALLOWED
- `api_unknown_endpoint_test` — Unknown API path returns 404 with NOT_FOUND
- `api_json_content_type_on_responses_test` — API responses use application/json content-type

### Legislation Handler Tests (`test/philstubs/web/legislation_handler_test.gleam`)

**Legislation Detail View** (14 tests):
- `legislation_detail_renders_test` — GET /legislation/:id renders page with title, identifier, status, date
- `legislation_detail_shows_summary_test` — Detail page includes summary text
- `legislation_detail_shows_body_text_test` — Detail page includes "Full Text" section with legislation body
- `legislation_detail_shows_sponsors_test` — Detail page lists all sponsors
- `legislation_detail_shows_topics_test` — Detail page displays topic tags
- `legislation_detail_shows_source_link_test` — Detail page includes "View original" link when source_url is Some
- `legislation_detail_hides_source_link_when_none_test` — No source link when source_url is None
- `legislation_detail_shows_download_buttons_test` — Detail page has download buttons with correct URLs for text and markdown
- `legislation_detail_shows_find_similar_link_test` — Detail page has "Find similar legislation" search link
- `legislation_detail_shows_related_legislation_test` — Related legislation section appears with topic-matched records
- `legislation_detail_enacted_status_badge_test` — Enacted status renders with status-enacted CSS class
- `legislation_detail_not_found_test` — Returns 404 for nonexistent legislation ID
- `legislation_detail_open_graph_meta_test` — Page includes og:title, og:description, og:type meta tags
- `legislation_detail_no_summary_section_when_empty_test` — Summary section omitted when summary is empty string
- `legislation_detail_no_sponsors_section_when_empty_test` — Sponsors section omitted when sponsors list is empty

**Legislation Download** (5 tests):
- `legislation_download_plain_text_test` — Downloads as text/plain with title, identifier, sponsors, and content-disposition header
- `legislation_download_markdown_test` — Downloads as text/markdown with heading formatting and content-type header
- `legislation_download_default_format_is_text_test` — No format param defaults to text/plain
- `legislation_download_not_found_test` — Returns 404 for nonexistent legislation
- `legislation_download_includes_summary_test` — Summary section included in text download when present
- `legislation_download_omits_summary_when_empty_test` — Summary section omitted from text download when empty

**Legislation JSON API** (2 tests):
- `api_legislation_detail_test` — GET /api/legislation/:id returns JSON with application/json content-type
- `api_legislation_not_found_test` — Returns 404 for nonexistent legislation

**Related Legislation Query** (2 tests):
- `related_legislation_query_test` — find_related returns topic-matched records excluding the source record
- `related_legislation_empty_topics_test` — Empty topics list returns empty results

### Template Handler Tests (`test/philstubs/web/template_handler_test.gleam`)

**Template Listing** (3 tests):
- `templates_list_empty_test` — Empty listing shows "No templates yet" message
- `templates_list_with_items_test` — Listing renders all template titles
- `templates_list_sorted_by_downloads_test` — Sort=downloads orders by download count

**Template Upload Form** (1 test):
- `template_new_form_test` — GET /templates/new renders upload form (requires authentication)

**Template Creation** (5 tests, all require authentication):
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

**Template Deletion** (2 tests, require authentication):
- `template_delete_test` — POST /templates/:id deletes template and redirects to listing
- `template_delete_not_found_test` — Returns 404 for nonexistent template

**JSON API** (3 tests):
- `api_templates_list_test` — GET /api/templates returns JSON array with content-type header
- `api_template_detail_test` — GET /api/templates/:id returns JSON object
- `api_template_not_found_test` — Returns 404 for nonexistent template

### User Repository Tests (`test/philstubs/data/user_repo_test.gleam`)

**User CRUD** (6 tests):
- `upsert_creates_new_user_test` — Creates a new user from GitHub OAuth data, verifies all fields
- `upsert_updates_existing_user_test` — Upserts existing user, verifies fields updated while ID preserved
- `get_by_id_found_test` — Retrieves user by internal ID
- `get_by_id_not_found_test` — Returns None for nonexistent ID
- `get_by_github_id_found_test` — Retrieves user by GitHub ID
- `get_by_github_id_not_found_test` — Returns None for nonexistent GitHub ID

### Session Repository Tests (`test/philstubs/data/session_repo_test.gleam`)

**Session Management** (5 tests):
- `create_session_returns_token_test` — Creates session and returns non-empty token string
- `get_user_by_session_valid_test` — Looks up session token and returns associated user
- `get_user_by_session_invalid_token_test` — Returns None for nonexistent session token
- `delete_session_test` — Deletes session, verifies lookup returns None afterward
- `delete_expired_sessions_test` — Cleanup succeeds even with no sessions

**Configuration** (1 test):
- `max_age_seconds_test` — Session max age is 604,800 seconds (7 days)

### Auth Handler Tests (`test/philstubs/web/auth_handler_test.gleam`)

**Login Flow** (2 tests):
- `login_shows_error_when_not_configured_test` — Shows error message when GitHub OAuth env vars not set
- `login_redirects_to_github_when_configured_test` — Redirects to GitHub OAuth authorize URL with client_id

**OAuth Callback** (4 tests):
- `callback_missing_code_shows_error_test` — Returns 400 when authorization code is missing
- `callback_token_exchange_failure_shows_error_test` — Returns 400 when HTTP request to GitHub fails
- `callback_invalid_token_response_shows_error_test` — Returns 400 when token response lacks access_token
- `callback_successful_login_test` — Full flow: exchanges code, fetches user, creates session, redirects to /

**Profile Page** (2 tests):
- `profile_redirects_when_not_logged_in_test` — GET /profile redirects to /login when unauthenticated
- `profile_shows_user_info_when_logged_in_test` — GET /profile renders username when authenticated

**Auth Protection** (4 tests):
- `unauthenticated_template_create_redirects_test` — POST /templates redirects to /login when unauthenticated
- `unauthenticated_api_template_create_returns_401_test` — POST /api/templates returns 401 when unauthenticated
- `unauthenticated_api_template_delete_returns_401_test` — DELETE /api/templates/:id returns 401
- `unauthenticated_api_template_update_returns_401_test` — PUT /api/templates/:id returns 401

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

# Legislation detail:
curl http://localhost:8000/legislation/LEGISLATION_ID                         # Expect: HTML detail page
curl "http://localhost:8000/legislation/LEGISLATION_ID/download?format=text"  # Expect: Plain text download
curl "http://localhost:8000/legislation/LEGISLATION_ID/download?format=markdown"  # Expect: Markdown download

# Legislation API:
curl http://localhost:8000/api/legislation/LEGISLATION_ID                     # Expect: JSON object

# Browse hierarchy:
curl http://localhost:8000/browse                    # Expect: HTML with government level cards
curl http://localhost:8000/browse/states              # Expect: HTML with state list and counts
curl http://localhost:8000/browse/state/CA             # Expect: HTML with CA counties/municipalities
curl -v http://localhost:8000/browse/federal           # Expect: 303 redirect to /search?level=federal
curl http://localhost:8000/browse/topics               # Expect: HTML with topic list and counts

# REST API — Legislation:
curl http://localhost:8000/api/legislation                    # Expect: Paginated JSON list
curl "http://localhost:8000/api/legislation?level=federal"     # Expect: Filtered by federal level
curl "http://localhost:8000/api/legislation?page=2&per_page=5" # Expect: Page 2, 5 per page
curl http://localhost:8000/api/legislation/stats              # Expect: JSON with total, by_level, by_type, by_status

# REST API — Templates CRUD:
curl http://localhost:8000/api/templates                      # Expect: JSON array of templates
curl -X POST http://localhost:8000/api/templates \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","description":"Desc","body":"Body","suggested_level":{"kind":"federal"},"suggested_type":"bill","author":"Me","topics":["test"]}'
# Expect: 201 with created template JSON

curl -X PUT http://localhost:8000/api/templates/TEMPLATE_ID \
  -H "Content-Type: application/json" \
  -d '{"title":"Updated","description":"New","body":"New body","suggested_level":{"kind":"federal"},"suggested_type":"bill","author":"Me","topics":["updated"]}'
# Expect: 200 with updated template JSON

curl -X DELETE http://localhost:8000/api/templates/TEMPLATE_ID
# Expect: 204 No Content

curl "http://localhost:8000/api/templates/TEMPLATE_ID/download?format=text"
# Expect: Plain text download

# REST API — Browse Data:
curl http://localhost:8000/api/levels                                      # Expect: JSON with levels array
curl http://localhost:8000/api/levels/state/jurisdictions                   # Expect: JSON with state jurisdictions
curl "http://localhost:8000/api/levels/county/jurisdictions?state=CA"       # Expect: JSON with CA county jurisdictions
curl "http://localhost:8000/api/levels/municipal/jurisdictions?state=WA"    # Expect: JSON with WA municipal jurisdictions
curl http://localhost:8000/api/topics                                       # Expect: JSON with topics array

# REST API — CORS:
curl -X OPTIONS http://localhost:8000/api/legislation -H "Origin: http://example.com" -v
# Expect: 204 with Access-Control-Allow-Origin: * headers

# REST API — Error format:
curl http://localhost:8000/api/legislation/nonexistent    # Expect: 404 with {"error":"...","code":"NOT_FOUND"}
curl http://localhost:8000/api/nonexistent                # Expect: 404 with {"error":"...","code":"NOT_FOUND"}

# Authentication (requires GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET env vars):
curl -v http://localhost:8000/login                       # Expect: 303 redirect to GitHub OAuth
curl http://localhost:8000/profile                        # Expect: 303 redirect to /login (unauthenticated)

# Auth-protected API endpoints (unauthenticated):
curl -X POST http://localhost:8000/api/templates \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","description":"","body":"Body","suggested_level":{"kind":"federal"},"suggested_type":"bill","author":"Me","topics":[]}'
# Expect: 401 Unauthorized

curl -X PUT http://localhost:8000/api/templates/some-id \
  -H "Content-Type: application/json" \
  -d '{"title":"Test"}'
# Expect: 401 Unauthorized

curl -X DELETE http://localhost:8000/api/templates/some-id
# Expect: 401 Unauthorized
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
