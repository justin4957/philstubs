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
- `run_migrations_fresh_database_test` — Runs all 8 migrations on empty `:memory:` DB, verifies tables exist (legislation, legislation_templates, similarity tables, ingestion_jobs, topics, cross-references)
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

### Similarity Algorithm Tests (`test/philstubs/core/similarity_test.gleam`)

**Text Normalization** (3 tests):
- `normalize_text_lowercases_and_strips_punctuation_test` — Lowercases text and removes punctuation
- `normalize_text_collapses_whitespace_test` — Collapses multiple spaces to single space and trims
- `normalize_text_empty_string_test` — Empty string returns empty string

**Word N-grams** (4 tests):
- `word_ngrams_trigrams_test` — Extracts trigrams from "the quick brown fox jumps"
- `word_ngrams_short_text_test` — Text shorter than n returns empty set
- `word_ngrams_bigrams_test` — Extracts bigrams from "an act to establish"
- `word_ngrams_exact_length_test` — Text with exactly n words returns single n-gram

**Jaccard Similarity** (4 tests):
- `jaccard_similarity_identical_sets_test` — Returns 1.0 for identical sets
- `jaccard_similarity_disjoint_sets_test` — Returns 0.0 for disjoint sets
- `jaccard_similarity_partial_overlap_test` — Returns expected fraction for partial overlap
- `jaccard_similarity_empty_sets_test` — Returns 0.0 for empty sets

**Text Similarity** (3 tests):
- `text_similarity_identical_test` — Identical text returns 1.0
- `text_similarity_completely_different_test` — Unrelated text returns near 0.0
- `text_similarity_partial_match_test` — Similar text returns high but not perfect score

**Title Similarity** (2 tests):
- `title_similarity_test` — Similar titles with bigram comparison return >0.5
- `title_similarity_different_test` — Different titles return <0.3

**Topic Overlap** (4 tests):
- `topic_overlap_identical_test` — Identical topic lists return 1.0
- `topic_overlap_partial_test` — Partial overlap returns expected Jaccard fraction
- `topic_overlap_empty_test` — Empty topic lists return 0.0
- `topic_overlap_case_insensitive_test` — Case-insensitive comparison

**Combined Similarity** (2 tests):
- `combined_similarity_weights_test` — Identical inputs verify 0.7 + 0.2 + 0.1 = 1.0 weighting
- `combined_similarity_zero_test` — Completely different inputs return <0.3

**Text Diff** (4 tests):
- `compute_diff_identical_test` — Identical text produces all Same hunks
- `compute_diff_completely_different_test` — Different text produces Removed and Added hunks
- `compute_diff_mixed_test` — Mixed changes produce Same, Added, and Removed hunks
- `compute_diff_empty_texts_test` — Empty texts produce single hunk

**Formatting** (1 test):
- `format_as_percentage_test` — Converts 0.87 → "87%", 1.0 → "100%", 0.0 → "0%"

### Similarity Repository Tests (`test/philstubs/data/similarity_repo_test.gleam`)

**Store and Query** (4 tests):
- `store_and_find_similar_test` — Store similarity, query back, verify all scores and joined legislation
- `find_similar_respects_min_score_test` — Only returns results above minimum score threshold
- `find_similar_orders_by_score_test` — Higher similarity scores returned first
- `find_similar_limits_results_test` — Respects max_results limit parameter

**Edge Cases** (3 tests):
- `find_similar_empty_test` — Nonexistent legislation returns empty list
- `store_similarity_idempotent_test` — INSERT OR REPLACE updates scores for existing pairs
- `find_similar_bidirectional_test` — Similarity queryable from either direction (A→B and B→A)

**Template Matching** (1 test):
- `store_template_match_and_find_test` — Store template-to-legislation match, query back with joined legislation

**Adoption Timeline** (1 test):
- `adoption_timeline_ordered_by_date_test` — Similar legislation returned in chronological order by introduced_date

**Management** (2 tests):
- `delete_similarities_for_test` — Removes all similarity pairs for a given legislation ID
- `count_similarities_test` — Counts total stored similarities (both directions)

### Similarity Pipeline Tests (`test/philstubs/core/similarity_pipeline_test.gleam`)

**Legislation Similarity Computation** (3 tests):
- `compute_similarities_for_stores_results_test` — Computes and stores similarity pairs above threshold
- `compute_similarities_skips_low_scores_test` — Below-threshold pairs not stored
- `compute_similarities_for_nonexistent_test` — Nonexistent legislation ID stores 0 pairs

**Batch Operations** (1 test):
- `compute_all_similarities_test` — Pairwise computation across all legislation, results queryable

**Template Matching** (1 test):
- `compute_template_matches_test` — Computes template-to-legislation matches, stores results

### Export Handler Tests (`test/philstubs/web/export_handler_test.gleam`)

**Legislation Export** (7 tests):
- `export_legislation_json_test` — GET /api/export/legislation returns JSON with export_format, total_count, and items
- `export_legislation_csv_test` — GET /api/export/legislation?format=csv returns CSV with header and data rows
- `export_legislation_csv_content_type_test` — CSV response has text/csv; charset=utf-8 content-type
- `export_legislation_csv_content_disposition_test` — CSV has Content-Disposition: attachment; filename="legislation-export.csv"
- `export_legislation_default_format_is_json_test` — No format param defaults to application/json content-type
- `export_legislation_empty_test` — Empty database returns CSV with only header row
- `export_legislation_cors_headers_test` — Export responses include Access-Control-Allow-Origin: * header

**Template Export** (3 tests):
- `export_templates_json_test` — GET /api/export/templates returns JSON with template data
- `export_templates_csv_test` — GET /api/export/templates?format=csv returns CSV with template header and data
- `export_templates_empty_test` — Empty database returns CSV with only header row

**Search Export** (2 tests):
- `export_search_json_test` — GET /api/export/search?q=climate returns JSON with matching legislation
- `export_search_csv_test` — GET /api/export/search?q=climate&format=csv returns CSV with matching data

**API Docs Page** (4 tests):
- `api_docs_page_renders_test` — GET /docs/api returns 200 with "API Documentation" title
- `api_docs_page_contains_export_docs_test` — Page includes export endpoint documentation
- `api_docs_page_contains_openapi_link_test` — Page includes link to openapi.json
- `api_docs_page_nav_link_test` — Page navigation includes API link

**Content-Disposition** (1 test):
- `export_legislation_json_content_disposition_test` — JSON export has filename="legislation-export.json"

### Similarity Handler Tests (`test/philstubs/web/similarity_handler_test.gleam`)

**Similar Legislation API** (2 tests):
- `api_similar_legislation_test` — GET /api/legislation/:id/similar returns JSON with similarity scores
- `api_similar_legislation_empty_test` — Returns empty similar array when no similarities exist

**Adoption Timeline API** (2 tests):
- `api_adoption_timeline_test` — GET /api/legislation/:id/adoption-timeline returns chronological events
- `api_adoption_timeline_empty_test` — Returns empty timeline for nonexistent legislation

**Diff View** (3 tests):
- `diff_page_renders_test` — GET /legislation/:id/diff/:comparison_id renders HTML diff view with both titles
- `diff_page_not_found_test` — Returns 404 when comparison legislation not found
- `diff_page_both_not_found_test` — Returns 404 when both legislation not found

**Similarity Computation API** (2 tests):
- `api_compute_similarities_test` — POST /api/similarity/compute triggers computation and returns counts
- `api_compute_similarities_get_not_allowed_test` — GET to compute endpoint returns 405

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

### Export Format Tests (`test/philstubs/core/export_format_test.gleam`)

**Format Parsing** (3 tests):
- `from_string_json_test` — "json" parses to Json
- `from_string_csv_test` — "csv" parses to Csv
- `from_string_unknown_defaults_to_json_test` — Unknown strings ("xml", "", "CSV") default to Json

**Format Properties** (4 tests):
- `content_type_json_test` — Json → "application/json; charset=utf-8"
- `content_type_csv_test` — Csv → "text/csv; charset=utf-8"
- `file_extension_json_test` — Json → ".json"
- `file_extension_csv_test` — Csv → ".csv"

**String Conversion** (3 tests):
- `to_string_json_test` — Json → "json"
- `to_string_csv_test` — Csv → "csv"
- `to_string_roundtrip_test` — Roundtrip conversion for both formats

### CSV Export Tests (`test/philstubs/core/csv_export_test.gleam`)

**Field Escaping** (6 tests):
- `escape_csv_field_plain_text_test` — Plain text passes through unchanged
- `escape_csv_field_with_comma_test` — Commas trigger quoting ("Hello, World" → "\"Hello, World\"")
- `escape_csv_field_with_quotes_test` — Double quotes are doubled and field is quoted
- `escape_csv_field_with_newline_test` — Newlines trigger quoting
- `escape_csv_field_empty_string_test` — Empty string passes through unchanged
- `escape_csv_field_with_all_special_chars_test` — Combined commas, quotes, and newlines

**Semicolon Joining** (3 tests):
- `join_with_semicolons_test` — Joins multiple values with ";"
- `join_with_semicolons_empty_test` — Empty list returns empty string
- `join_with_semicolons_single_test` — Single value returns unchanged

**Legislation CSV** (5 tests):
- `legislation_to_csv_single_record_test` — Header row + data row with all fields
- `legislation_to_csv_multiple_records_test` — Header + 2 data rows
- `legislation_to_csv_empty_list_test` — Only header row for empty list
- `legislation_to_csv_special_characters_test` — Title with commas is quoted in CSV output
- `legislation_to_csv_none_source_url_test` — None source_url produces empty field (consecutive commas)

**Template CSV** (2 tests):
- `templates_to_csv_single_record_test` — Header row + data row with template fields
- `templates_to_csv_empty_list_test` — Only header row for empty list

### Topic Domain Tests (`test/philstubs/core/topic_test.gleam`)

**TopicId** (2 tests):
- `topic_id_roundtrip_test` — Create TopicId and extract string
- `topic_id_to_json_test` — TopicId JSON encoding

**AssignmentMethod** (2 tests):
- `assignment_method_to_string_test` — All 3 methods to string (manual, auto_keyword, ingestion)
- `assignment_method_from_string_roundtrip_test` — Roundtrip all 3 methods

**Topic JSON** (1 test):
- `topic_to_json_test` — Full Topic JSON encoding with all fields

**TopicWithCount JSON** (1 test):
- `topic_with_count_to_json_test` — TopicWithCount JSON encoding with legislation/template counts

**CrossLevelSummary JSON** (1 test):
- `cross_level_summary_to_json_test` — CrossLevelSummary JSON encoding with per-level counts and state breakdown

### Auto-Tagger Tests (`test/philstubs/core/auto_tagger_test.gleam`)

**Keyword Matching** (5 tests):
- `find_matching_topics_title_match_test` — Matches keyword in title, returns InTitle source
- `find_matching_topics_summary_match_test` — Matches keyword in summary, returns InSummary source
- `find_matching_topics_both_match_test` — Keyword in both title and summary returns InBoth source
- `find_matching_topics_case_insensitive_test` — Case-insensitive matching ("HOUSING" matches "housing")
- `find_matching_topics_no_match_test` — Unrelated text returns empty list

**Multi-Topic Matching** (1 test):
- `find_matching_topics_multiple_topics_test` — Multiple topics matched from different keyword rules

**Deduplication** (1 test):
- `deduplicate_matches_prefers_in_both_test` — Same topic matched multiple times: InBoth > InTitle > InSummary

### Topic Seed Tests (`test/philstubs/data/topic_seed_test.gleam`)

**Seed Data** (2 tests):
- `seed_topic_taxonomy_creates_topics_test` — Seeds 9 parent topics + child topics + keywords, verifies parent count
- `seed_topic_taxonomy_idempotent_test` — Running seed twice produces same result (INSERT OR IGNORE)

### Topic Repository Tests (`test/philstubs/data/topic_repo_test.gleam`)

**CRUD Operations** (3 tests):
- `insert_and_get_by_id_test` — Insert topic, retrieve by ID, verify all fields
- `get_by_slug_test` — Retrieve topic by slug
- `get_by_id_not_found_test` — Returns Ok(None) for nonexistent ID

**Hierarchy** (2 tests):
- `list_parent_topics_test` — List top-level topics (parent_id IS NULL)
- `list_children_test` — List child topics for a given parent

**Topic Tree** (1 test):
- `list_topic_tree_test` — Full hierarchical tree with parents and nested children

**Legislation Topic Assignments** (3 tests):
- `assign_and_get_legislation_topics_test` — Assign topic to legislation and retrieve assignments
- `remove_legislation_topic_test` — Remove topic assignment
- `assign_legislation_topic_idempotent_test` — INSERT OR IGNORE prevents duplicates

**Template Topic Assignments** (1 test):
- `assign_and_get_template_topics_test` — Assign topic to template and retrieve assignments

**Aggregation** (1 test):
- `count_legislation_by_topic_test` — Count legislation per parent topic with child rollup

**Cross-Level Summary** (1 test):
- `get_cross_level_summary_test` — Counts by government level (federal, state, county, municipal) for a topic

**Search** (1 test):
- `search_topics_test` — Prefix search for autocomplete (e.g., "Hou" matches "Housing")

**Pagination** (1 test):
- `list_legislation_for_topic_test` — Paginated legislation list for a topic slug

**Keywords** (1 test):
- `list_all_topics_with_keywords_test` — Bulk load topic IDs with keyword lists for auto-tagger

### Auto-Tagger Service Tests (`test/philstubs/data/auto_tagger_service_test.gleam`)

**Single Legislation Tagging** (2 tests):
- `auto_tag_legislation_single_test` — Tags legislation based on title/summary keyword matching, verifies "housing" topic assigned
- `auto_tag_legislation_no_match_test` — Unrelated legislation receives no topic assignments

**Bulk Tagging** (1 test):
- `auto_tag_all_untagged_test` — Bulk auto-tags all legislation without topic assignments, verifies count and topic data

**JSON Backfill** (1 test):
- `backfill_from_json_topics_test` — Migrates JSON topics column values to normalized join table by matching against taxonomy names/slugs

### Citation Extractor Tests (`test/philstubs/core/citation_extractor_test.gleam`)

**Citation Extraction** (9 tests):
- `extract_usc_citation_test` — Extracts USC citations like "42 U.S.C. 1983" with confidence 0.9
- `extract_public_law_citation_test` — Extracts "Pub. L. 117-169" citations with confidence 0.9
- `extract_public_law_full_text_test` — Extracts "Public Law 110-343" full-form citations
- `extract_cfr_citation_test` — Extracts CFR citations like "40 C.F.R. 98" with confidence 0.9
- `extract_bill_reference_test` — Extracts bill references "H.R. 1234" and "S. 567" with confidence 0.8
- `extract_section_reference_test` — Extracts "section 101" references with confidence 0.6
- `extract_multiple_citations_test` — Extracts multiple citation types from a single text
- `extract_case_insensitive_test` — Both lowercase and mixed-case citations are extracted
- `extract_empty_text_returns_empty_test` — Empty text returns no citations
- `extract_irrelevant_text_returns_empty_test` — Non-legal text returns no citations

**Reference Type Inference** (5 tests):
- `infer_amends_reference_type_test` — "amends" context word → Amends type
- `infer_supersedes_from_repeal_test` — "repeal" context word → Supersedes type
- `infer_implements_from_pursuant_test` — "pursuant to" context → Implements type
- `infer_delegates_reference_type_test` — "delegate" context word → Delegates type
- `infer_default_references_type_test` — Neutral context defaults to References type

**Deduplication** (1 test):
- `deduplicate_keeps_highest_confidence_test` — Duplicate citations keep highest confidence score

**Utility** (3 tests):
- `citation_type_to_string_test` — All 5 citation types convert to string
- `context_based_reference_type_extraction_test` — Full extraction with "amends" context infers Amends type
- `joint_resolution_bill_reference_test` — H.J.Res. patterns detected as bill references

### Reference Repository Tests (`test/philstubs/data/reference_repo_test.gleam`)

**Cross-Reference CRUD** (6 tests):
- `insert_and_find_references_from_test` — Insert reference, query outgoing refs, verify citation text
- `insert_and_find_references_to_test` — Insert reference with target, query incoming refs
- `unresolved_citation_has_null_target_test` — Unresolved citations have None target_legislation_id
- `idempotent_insert_test` — INSERT OR REPLACE prevents duplicate references
- `delete_references_for_test` — Deletes all references for a source legislation
- `count_references_empty_test` — Empty table returns count 0

**Query Map CRUD** (4 tests):
- `insert_and_get_query_map_test` — Insert query map and retrieve by ID
- `get_nonexistent_query_map_returns_none_test` — Returns None for nonexistent ID
- `list_query_maps_test` — Lists all query maps ordered by name ASC
- `delete_query_map_test` — Deletes query map, verifies gone

### Reference Handler Tests (`test/philstubs/web/reference_handler_test.gleam`)

**References API** (3 tests):
- `api_references_from_returns_200_test` — GET /api/legislation/:id/references returns JSON with outgoing references
- `api_references_from_empty_test` — Returns empty references array for nonexistent legislation
- `api_referenced_by_returns_200_test` — GET /api/legislation/:id/referenced-by returns incoming references

**Query Maps API** (4 tests):
- `api_list_query_maps_returns_200_test` — GET /api/query-maps returns JSON with query_maps array
- `api_create_query_map_returns_201_test` — POST /api/query-maps creates query map, returns 201
- `api_query_map_detail_test` — GET /api/query-maps/:id returns single query map
- `api_query_map_not_found_test` — Returns 404 for nonexistent query map
- `api_create_query_map_missing_name_returns_400_test` — Missing name field returns 400 validation error

**Citation Extraction API** (2 tests):
- `api_extract_citations_test` — POST /api/references/extract extracts citations from posted text
- `api_extract_citations_empty_text_returns_400_test` — Empty text returns 400 validation error

### Impact Analysis Types Tests (`test/philstubs/core/impact_types_test.gleam`)

**Direction String Conversions** (5 tests):
- `direction_to_string_incoming_test` — Incoming → "incoming"
- `direction_to_string_outgoing_test` — Outgoing → "outgoing"
- `direction_to_string_both_test` — Both → "both"
- `direction_from_string_valid_test` — Roundtrip all 3 directions
- `direction_from_string_unknown_defaults_to_both_test` — Unknown string defaults to Both

**ImpactKind Conversions** (1 test):
- `impact_kind_to_string_test` — Direct → "direct", Transitive → "transitive"

**JSON Serialization** (2 tests):
- `impact_node_json_contains_expected_fields_test` — ImpactNode JSON includes legislation_id, title, level, impact_kind, reference_type
- `impact_result_json_structure_test` — Full ImpactResult JSON includes root_legislation_id, direction, nodes, summary with by_level/by_type

### Impact Analyzer Tests (`test/philstubs/core/impact_analyzer_test.gleam`)

**BFS Traversal** (9 tests):
- `empty_graph_produces_no_nodes_test` — No edges → empty result
- `single_outgoing_edge_test` — A→B returns B at depth 1, Direct
- `single_incoming_edge_test` — Incoming traversal finds sources
- `chain_a_b_c_produces_direct_and_transitive_test` — A→B→C, B=Direct depth 1, C=Transitive depth 2
- `depth_limiting_stops_traversal_test` — max_depth=2 stops at C, omits D
- `cycle_prevention_test` — A→B→C→A cycle doesn't loop infinitely
- `diamond_deduplication_test` — A→B, A→C, B→D, C→D: D appears once
- `both_directions_merges_results_test` — Both direction merges outgoing and incoming
- `missing_metadata_skips_node_test` — Nodes without metadata are skipped
- `max_depth_zero_returns_no_nodes_test` — max_depth=0 returns empty

**Summarize Impact** (1 test):
- `summarize_impact_counts_correctly_test` — Counts direct/transitive, max_depth, totals

**Group By** (1 test):
- `group_by_level_test` — Groups nodes by government level string

### Impact Repository Tests (`test/philstubs/data/impact_repo_test.gleam`)

**Graph Loading** (3 tests):
- `empty_graph_from_empty_db_test` — Empty DB → empty outgoing/incoming dicts
- `resolved_references_appear_in_graph_test` — A→B reference creates outgoing and incoming edges
- `unresolved_references_excluded_from_graph_test` — NULL target_legislation_id excluded from graph

**Metadata Loading** (2 tests):
- `metadata_loading_with_government_levels_test` — Loads metadata with Federal, State, County, Municipal levels
- `empty_metadata_from_empty_db_test` — Empty DB → empty metadata dict

### Impact Handler Tests (`test/philstubs/web/impact_handler_test.gleam`)

**Impact API** (6 tests):
- `impact_endpoint_returns_200_with_empty_graph_test` — GET /api/legislation/:id/impact returns 200 with empty nodes
- `impact_endpoint_returns_direct_impacts_test` — A→B reference, impact shows B as direct
- `impact_endpoint_respects_direction_param_test` — direction=outgoing finds targets, direction=incoming finds sources
- `impact_endpoint_respects_max_depth_param_test` — max_depth=1 limits traversal to depth 1
- `impact_endpoint_defaults_to_both_and_depth_3_test` — Default params: direction=both, max_depth=3
- `impact_endpoint_invalid_direction_defaults_to_both_test` — Invalid direction string defaults to both

### Explore Types Tests (`test/philstubs/core/explore_types_test.gleam`)

**Edge Type Roundtrips** (4 tests):
- `edge_type_references_roundtrip_test` — ReferencesEdge → "references" → ReferencesEdge
- `edge_type_similar_to_roundtrip_test` — SimilarToEdge → "similar_to" → SimilarToEdge
- `edge_type_all_types_roundtrip_test` — All 6 edge types roundtrip through string conversion
- `edge_type_from_string_invalid_test` — Invalid string returns Error(Nil)

**JSON Serialization** (5 tests):
- `explore_node_to_json_matches_schema_test` — ExploreNode JSON includes id, type, label, date, level kind, source_identifier, sponsors
- `explore_edge_to_json_matches_schema_test` — ExploreEdge JSON includes source, target, type, citation
- `node_neighborhood_to_json_test` — NodeNeighborhood JSON includes node, edges, neighbors keys
- `expand_result_to_json_test` — ExpandResult JSON includes root_id, depth, edge_types
- `path_result_to_json_test` — PathResult JSON includes from_id, to_id, distance
- `cluster_result_to_json_test` — ClusterResult JSON includes topic_slug, topic_name

**Edge Type Parsing** (3 tests):
- `parse_edge_types_empty_returns_all_test` — Empty string returns all 6 edge types
- `parse_edge_types_single_test` — "references" returns [ReferencesEdge]
- `parse_edge_types_multiple_test` — "references,similar_to" returns [ReferencesEdge, SimilarToEdge]

### Explore Graph Tests (`test/philstubs/core/explore_graph_test.gleam`)

**Neighborhood Assembly** (2 tests):
- `empty_neighborhood_test` — No edges produces node with empty edges/neighbors lists
- `neighborhood_with_mixed_edges_test` — Mix of references and similarities produces correct edge types and deduplicates neighbors

**BFS Expansion** (3 tests):
- `expand_references_only_test` — Expand with ReferencesEdge filter only follows reference edges
- `expand_similarity_only_test` — Expand with SimilarToEdge filter only follows similarity edges
- `expand_depth_limiting_test` — depth=1 limits BFS to immediate neighbors, excludes 2-hop nodes

**Shortest Path** (5 tests):
- `path_direct_test` — A→B direct edge found at distance 1
- `path_two_hops_test` — A→B→C path found at distance 2 with correct edge reconstruction
- `path_unreachable_test` — Disconnected nodes return distance -1
- `path_same_node_test` — Same source and target returns distance 0
- `path_cycle_safe_test` — Cycles (A→B→C→A) don't cause infinite loops

**Cluster Building** (1 test):
- `cluster_edge_filtering_test` — Only includes edges where both source and target are in the cluster ID set

### Explore Repository Tests (`test/philstubs/data/explore_repo_test.gleam`)

**Node Loading** (2 tests):
- `load_node_with_topics_test` — Loads legislation with assigned topics from in-memory DB
- `load_node_not_found_test` — Returns None for nonexistent legislation ID

**Edge Loading** (1 test):
- `load_node_edges_test` — Loads outgoing cross-references for a legislation node

**Inter-Reference Queries** (1 test):
- `load_inter_references_filtered_test` — IN clause filters to only edges where both source and target are in the ID set

**Inter-Similarity Queries** (1 test):
- `load_inter_similarities_filtered_test` — IN clause filters similarities to within-set edges with min_score threshold

**Adjacency Loading** (1 test):
- `load_similarity_adjacency_test` — Builds full adjacency dict for BFS expand from similarity table

### Explore Handler Tests (`test/philstubs/web/explore_handler_test.gleam`)

**Node Endpoint** (3 tests):
- `explore_node_200_test` — GET /api/explore/node/:id returns 200 with node, edges, neighbors
- `explore_node_404_test` — Nonexistent legislation ID returns 404 with NOT_FOUND code
- `explore_node_with_edges_test` — Node with cross-references returns edges and neighbor nodes

**Expand Endpoint** (3 tests):
- `explore_expand_defaults_test` — GET /api/explore/expand/:id returns 200 with root_id, depth, nodes, edges
- `explore_expand_filtered_test` — edge_types=references filters to only reference edges
- `explore_expand_depth_clamped_test` — depth=99 is clamped to 3

**Path Endpoint** (2 tests):
- `explore_path_found_test` — GET /api/explore/path/:from/:to returns 200 with from_id, to_id, distance
- `explore_path_not_found_test` — Disconnected nodes return distance -1

**Cluster Endpoint** (2 tests):
- `explore_cluster_found_test` — GET /api/explore/cluster/:slug returns 200 with topic_slug, topic_name, nodes, edges
- `explore_cluster_404_test` — Nonexistent topic slug returns 404 with NOT_FOUND code

### Topic Handler Tests (`test/philstubs/web/topic_handler_test.gleam`)

**Taxonomy API** (2 tests):
- `api_topics_taxonomy_test` — GET /api/topics/taxonomy returns JSON with taxonomy tree including children
- `api_topics_taxonomy_has_cors_test` — Response includes Access-Control-Allow-Origin: * header

**Topic Detail API** (2 tests):
- `api_topic_detail_test` — GET /api/topics/housing returns JSON with cross-level counts (federal_count, state_count)
- `api_topic_detail_not_found_test` — Returns 404 with NOT_FOUND code for nonexistent topic slug

**Topic Legislation API** (1 test):
- `api_topic_legislation_test` — GET /api/topics/housing/legislation returns paginated JSON with items

**Topic Search API** (1 test):
- `api_topic_search_test` — GET /api/topics/search?q=Hou returns matching topics for autocomplete

**Auto-Tag API** (1 test):
- `api_auto_tag_test` — POST /api/topics/auto-tag triggers bulk auto-tagging, returns tagged_count

**Browse Pages** (2 tests):
- `browse_topics_page_test` — GET /browse/topics renders hierarchical topic browser with "Browse by Topic"
- `browse_topic_detail_page_test` — GET /browse/topics/housing renders cross-level comparison page

### Ingestion Job Domain Tests (`test/philstubs/core/ingestion_job_test.gleam`)

**Source/Status String Conversions** (5 tests):
- `source_to_string_federal_test` — Federal → "federal"
- `source_to_string_state_test` — State → "state"
- `source_to_string_local_test` — Local → "local"
- `source_from_string_roundtrip_test` — Roundtrip all 3 sources
- `source_from_string_invalid_test` — Unknown string returns Error(Nil)

**Status Conversions** (3 tests):
- `status_to_string_all_test` — All 4 statuses to string
- `status_from_string_roundtrip_test` — Roundtrip all 4 statuses
- `status_from_string_invalid_test` — Unknown string returns Error(Nil)

**Schedule Config** (1 test):
- `default_schedule_config_test` — Federal: 24h, State: 168h, Local: 168h

**Backoff Calculation** (4 tests):
- `calculate_backoff_zero_retries_test` — 0 retries → 30,000ms
- `calculate_backoff_one_retry_test` — 1 retry → 60,000ms
- `calculate_backoff_two_retries_test` — 2 retries → 120,000ms
- `calculate_backoff_capped_test` — High retry count caps at 3,600,000ms (1 hour)

**Retry Logic** (3 tests):
- `should_retry_under_max_test` — Under max retries returns True
- `should_retry_at_max_test` — At max retries returns False
- `should_retry_over_max_test` — Over max retries returns False

**JSON Encoding** (2 tests):
- `job_to_json_test` — Full IngestionJob JSON encoding with all fields
- `source_status_to_json_test` — SourceStatus JSON encoding

**Utilities** (2 tests):
- `all_sources_test` — Returns [Federal, State, Local]
- `interval_for_source_test` — Returns correct interval per source from config

### Ingestion Job Repository Tests (`test/philstubs/data/ingestion_job_repo_test.gleam`)

**CRUD Operations** (4 tests):
- `insert_and_get_by_id_test` — Insert job, retrieve by ID, verify all fields
- `get_by_id_not_found_test` — Returns Ok(None) for nonexistent ID
- `mark_running_test` — Sets status to Running, started_at populated
- `mark_completed_test` — Sets status to Completed with counts and duration

**Failure Tracking** (1 test):
- `mark_failed_test` — Sets status to Failed with error message and duration

**Listing** (4 tests):
- `list_recent_ordering_test` — Returns jobs ordered by created_at DESC
- `list_recent_limit_test` — Respects limit parameter
- `list_by_source_filtering_test` — Filters by source string
- `get_latest_by_source_test` — Returns most recent job for a source

**Edge Cases** (1 test):
- `get_latest_by_source_empty_test` — Returns Ok(None) when no jobs exist for source

**Consecutive Failures** (2 tests):
- `count_consecutive_failures_no_jobs_test` — Returns 0 when no jobs exist
- `count_consecutive_failures_with_failures_test` — Counts trailing failures (stops at first non-failed job)

### Ingestion Runner Tests (`test/philstubs/ingestion/ingestion_runner_test.gleam`)

**Dispatch Tests** (1 test):
- `run_federal_dispatches_test` — Verifies federal source dispatch path, accepts both Ok and config Error results

### Scheduler Actor Tests (`test/philstubs/ingestion/scheduler_actor_test.gleam`)

**Lifecycle** (3 tests):
- `start_and_get_status_test` — Start actor, verify status (not running, config, source statuses)
- `trigger_source_test` — Trigger federal source manually via actor message
- `shutdown_stops_actor_test` — Send Shutdown, verify actor process terminates

Uses mock runner (`mock_success_runner`) that returns `Ok(RunResult(records_fetched: 5, records_stored: 5))` for deterministic testing without real API calls.

### Ingestion Handler Tests (`test/philstubs/web/ingestion_handler_test.gleam`)

**Status API** (1 test):
- `ingestion_status_no_scheduler_test` — GET /api/ingestion/status returns 503 when scheduler not running

**Jobs API** (4 tests):
- `ingestion_jobs_empty_test` — GET /api/ingestion/jobs returns empty list with count 0
- `ingestion_jobs_with_data_test` — Returns jobs and correct count
- `ingestion_jobs_with_source_filter_test` — ?source=federal filters to matching source
- `ingestion_jobs_with_limit_test` — ?limit=2 caps returned jobs

**Job Detail API** (2 tests):
- `ingestion_job_detail_test` — GET /api/ingestion/jobs/:id returns job JSON
- `ingestion_job_detail_not_found_test` — Returns 404 for nonexistent job

**Trigger API** (1 test):
- `ingestion_trigger_no_scheduler_test` — POST /api/ingestion/trigger returns 503 when scheduler not running

**Admin Dashboard** (2 tests):
- `ingestion_dashboard_renders_test` — GET /admin/ingestion renders dashboard with title and jobs section
- `ingestion_dashboard_shows_jobs_test` — Dashboard displays job rows with source and status

**Method Enforcement** (2 tests):
- `ingestion_jobs_post_not_allowed_test` — POST to /api/ingestion/jobs returns 405
- `ingestion_trigger_get_not_allowed_test` — GET to /api/ingestion/trigger returns 405

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

### Dialogue Tests for External Integrations

Dialogue tests document and validate the complete request/response interaction flow between the application and each external API. They differ from existing mock tests (which test individual operation correctness) by focusing on the **full interaction sequence**, request counting, and field mapping chains.

**Pattern**: Each dialogue test uses a **request-logging dispatcher** — a mock dispatcher that records every HTTP request URL via a `Subject(String)` channel, then returns canned responses. After ingestion completes, the test collects all logged requests and asserts on the interaction sequence.

```gleam
import gleam/erlang/process.{type Subject}

fn logging_success_dispatcher(
  request_log: Subject(String),
) -> congress_api_client.HttpDispatcher {
  fn(req: request.Request(String)) -> Result(Response(String), String) {
    process.send(request_log, req.path)
    Ok(Response(status: 200, headers: [], body: canned_response))
  }
}

pub fn my_dialogue_test() {
  let request_log = process.new_subject()
  // ... run ingestion with logging dispatcher ...
  let logged_requests = collect_logged_requests(request_log)
  list.length(logged_requests) |> should.equal(expected_count)
}
```

#### Congress.gov Dialogue Tests (`test/philstubs/ingestion/congress_dialogue_test.gleam`)

**Interaction Sequence Tests** (3 tests):
- `congress_success_dialogue_test` — Full pipeline: single API request to bill list endpoint → parse 2 bills → map to domain types → store in DB → update ingestion state to "completed". Verifies: 1 request made, correct URL pattern, both bills stored, ingestion state shows total_bills_fetched: 2.
- `congress_error_dialogue_test` — API returns 500 → pipeline returns error → ingestion state marked "failed". Verifies: request was attempted, no bills stored.
- `congress_field_mapping_dialogue_test` — Documents precise field transformations: `HR` type → `Bill`, `"Became Public Law"` action text → `Enacted` status, `"Referred to...Committee"` → `InCommittee`, `H.R. {number}` identifier format, source URL construction.

#### Open States Dialogue Tests (`test/philstubs/ingestion/openstates_dialogue_test.gleam`)

**Interaction Sequence Tests** (3 tests):
- `openstates_success_dialogue_test` — Full pipeline: API request → parse bills with nested jurisdiction/sponsor/abstract objects → map to State("CA") level → store. Verifies: 1 request made, correct bill count, State level set, sponsors from nested person.name, summary from first abstract, topics from subject array.
- `openstates_error_dialogue_test` — API error → error result → ingestion state tracked with jurisdiction/session fields.
- `openstates_field_mapping_dialogue_test` — Documents nested extraction: OCD jurisdiction ID → state code "CA", classification ["bill"] → Bill type, action ["became-law"] → Enacted, ["committee-referral"] → InCommittee, person.name preferred over sponsorship name, empty abstracts → empty summary.

#### Legistar Dialogue Tests (`test/philstubs/ingestion/legistar_dialogue_test.gleam`)

**Interaction Sequence Tests** (4 tests):
- `legistar_success_dialogue_test` — Full pipeline: fetch matters list → per-matter sponsor fetch → map with Municipal level → store. Verifies: both matters stored, Municipal("WA", "Seattle") level, sponsors attached from separate endpoint.
- `legistar_multi_request_dialogue_test` — Verifies multi-endpoint interaction: 1 matters request + 2 sponsor requests = 3 total HTTP requests. Validates URL patterns for each request (matters vs sponsors endpoints with matter IDs).
- `legistar_error_dialogue_test` — API 500 on matters list → error → only 1 request made (no sponsor requests), ingestion state "failed".
- `legistar_field_mapping_dialogue_test` — Documents field transformations: MatterTypeName "Ordinance" → Ordinance, "Resolution" → Resolution, MatterStatusName "Adopted" → Enacted, "Filed" → Introduced, title fallback chain (MatterTitle > MatterName > MatterFile), date format stripping ("2024-03-01T00:00:00" → "2024-03-01"), summary from MatterNotes.

### Code Coverage

Gleam currently has no native code coverage tooling. The Erlang `cover` module exists on the BEAM but reports line numbers against generated `.erl` files, which do not map back to Gleam source lines, making the output impractical to use.

**Current approach**: Comprehensive testing (693+ tests) with CI enforcement via `gleam test` in the GitHub Actions workflow. Test coverage spans pure domain logic, database operations, HTTP handlers, ingestion pipelines, cross-reference extraction, impact analysis, navigation graph exploration, and interaction flow documentation (dialogue tests).

**Future**: The Gleam ecosystem may develop coverage tooling as the language matures. Monitor the [Gleam GitHub discussions](https://github.com/gleam-lang/gleam/discussions) and community tools for coverage support.

## Testing Strategy

- **Pure function tests**: Test domain logic in `core/` with direct assertions
- **Rendering tests**: Test UI components by rendering to string and checking content
- **Database tests**: Use `:memory:` SQLite databases via `database.with_named_connection`
- **HTTP tests**: Use `wisp/testing` module for request/response testing
- **Actor tests**: Use mock runner functions injected into scheduler actor for deterministic behavior
- **Taxonomy tests**: Seed taxonomy data in `setup_with_taxonomy` helper, then test against normalized topic tables

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

### Scheduler Actor Testing Pattern

The scheduler actor uses **function injection** for the runner, allowing mock runners in tests:

```gleam
import philstubs/ingestion/ingestion_runner.{type RunResult, RunResult}
import philstubs/ingestion/scheduler_actor

fn mock_success_runner(
  _connection: sqlight.Connection,
  _source: IngestionSource,
) -> Result(RunResult, ingestion_runner.RunError) {
  Ok(RunResult(records_fetched: 5, records_stored: 5))
}

pub fn start_and_get_status_test() {
  let config = ScheduleConfig(
    federal_interval_hours: 1,
    state_interval_hours: 1,
    local_interval_hours: 1,
  )
  let assert Ok(started) =
    scheduler_actor.start(config, mock_success_runner)

  let status = scheduler_actor.get_status(started.data)
  status.is_running |> should.be_false

  // Clean shutdown
  process.send(started.data, scheduler_actor.Shutdown)
}
```

Key patterns:
- Mock runners avoid real API calls and rate limiting delays
- Each test starts its own actor instance and shuts it down cleanly
- `scheduler_actor.start` accepts a `runner_fn` parameter matching `fn(Connection, IngestionSource) -> Result(RunResult, RunError)`
- Handler tests set `scheduler: None` in Context to test the "no scheduler" error paths
- Handler tests with scheduler running are avoided in unit tests since they require a live actor; these are covered by manual verification

### Topic Taxonomy Testing Pattern

Topic tests use a shared `setup_with_taxonomy` helper that seeds the full taxonomy before each test:

```gleam
import philstubs/data/database
import philstubs/data/test_helpers
import philstubs/data/topic_seed

fn setup_with_taxonomy(callback: fn(sqlight.Connection) -> Nil) -> Nil {
  use connection <- database.with_named_connection(":memory:")
  let assert Ok(_) = test_helpers.setup_test_db(connection)
  let assert Ok(_) = topic_seed.seed_topic_taxonomy(connection)
  callback(connection)
}
```

Key patterns:
- `topic_seed.seed_topic_taxonomy` populates 9 parent topics, ~27 child topics, and ~130 keywords
- Seed is idempotent (uses INSERT OR IGNORE) — safe to call multiple times
- Auto-tagger pure tests (`auto_tagger_test.gleam`) test keyword matching logic without a database
- Auto-tagger service tests (`auto_tagger_service_test.gleam`) integrate the pure matcher with the database (insert legislation, run matcher, verify join table entries)
- Topic handler tests use `wisp/simulate` for HTTP endpoint testing with seeded taxonomy
- Cross-level summary tests insert legislation at different government levels and verify per-level counts

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
curl http://localhost:8000/browse/topics               # Expect: HTML with hierarchical topic taxonomy
curl http://localhost:8000/browse/topics/housing       # Expect: HTML cross-level comparison for Housing topic

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

# Topic Taxonomy API:
curl http://localhost:8000/api/topics/taxonomy                              # Expect: JSON hierarchical tree with children and counts
curl http://localhost:8000/api/topics/housing                               # Expect: JSON with cross-level counts (federal_count, state_count, etc.)
curl http://localhost:8000/api/topics/housing/legislation                   # Expect: JSON paginated legislation for topic
curl "http://localhost:8000/api/topics/search?q=Hou"                       # Expect: JSON matching topics for autocomplete
curl -X POST http://localhost:8000/api/topics/auto-tag                     # Expect: JSON with tagged_count

# API Documentation:
curl http://localhost:8000/docs/api                                      # Expect: HTML API docs page
curl http://localhost:8000/static/openapi.json                            # Expect: OpenAPI 3.0 specification JSON

# Bulk Data Export:
curl "http://localhost:8000/api/export/legislation?format=json"           # Expect: JSON download with items array
curl "http://localhost:8000/api/export/legislation?format=csv"            # Expect: CSV download with header + data rows
curl "http://localhost:8000/api/export/legislation?level=federal&format=csv"  # Expect: Filtered CSV
curl "http://localhost:8000/api/export/templates?format=csv"              # Expect: Template CSV download
curl "http://localhost:8000/api/export/search?q=climate&format=csv"       # Expect: Search result CSV download

# Cross-Reference API:
curl http://localhost:8000/api/legislation/LEGISLATION_ID/references
# Expect: JSON with legislation_id and references array

curl http://localhost:8000/api/legislation/LEGISLATION_ID/referenced-by
# Expect: JSON with legislation_id and referenced_by array

# Query Maps API:
curl http://localhost:8000/api/query-maps
# Expect: JSON with query_maps array and count

curl -X POST http://localhost:8000/api/query-maps \
  -H "Content-Type: application/json" \
  -d '{"name":"Find amendments","query_template":"SELECT * FROM legislation_references WHERE reference_type = '\''amends'\''"}'
# Expect: 201 with created query map JSON

curl http://localhost:8000/api/query-maps/find-amendments
# Expect: JSON with query map details

# Citation Extraction API:
curl -X POST http://localhost:8000/api/references/extract \
  -H "Content-Type: application/json" \
  -d '{"text":"This bill amends 42 U.S.C. 1983 and references Pub. L. 117-169."}'
# Expect: JSON with citations array and count

# Impact Analysis API:
curl http://localhost:8000/api/legislation/LEGISLATION_ID/impact
# Expect: JSON with root_legislation_id, direction, max_depth, nodes array, and summary

curl "http://localhost:8000/api/legislation/LEGISLATION_ID/impact?direction=outgoing&max_depth=2"
# Expect: JSON with outgoing-only impact analysis limited to depth 2

curl "http://localhost:8000/api/legislation/LEGISLATION_ID/impact?direction=incoming"
# Expect: JSON with legislation that references the target

# Navigation Graph Explore API:
curl http://localhost:8000/api/explore/node/LEGISLATION_ID
# Expect: JSON with node (id, type, label, level, status, date, metadata), edges array, neighbors array

curl "http://localhost:8000/api/explore/expand/LEGISLATION_ID?edge_types=references,similar_to&depth=2"
# Expect: JSON with root_id, depth, edge_types, nodes array, edges array (BFS expansion)

curl "http://localhost:8000/api/explore/expand/LEGISLATION_ID?edge_types=references&depth=1"
# Expect: JSON with only reference edges, depth 1

curl http://localhost:8000/api/explore/path/FROM_LEGISLATION_ID/TO_LEGISLATION_ID
# Expect: JSON with from_id, to_id, path (node array), edges, distance (or distance: -1 if unreachable)

curl "http://localhost:8000/api/explore/cluster/healthcare?limit=50&min_similarity=0.3"
# Expect: JSON with topic_slug, topic_name, nodes array, edges array (inter-cluster connections)

curl http://localhost:8000/api/explore/node/nonexistent
# Expect: 404 with {"error":"...","code":"NOT_FOUND"}

curl http://localhost:8000/api/explore/cluster/nonexistent-topic
# Expect: 404 with {"error":"...","code":"NOT_FOUND"}

# Similarity API:
curl http://localhost:8000/api/legislation/LEGISLATION_ID/similar
# Expect: JSON with legislation_id and similar array containing similarity scores

curl http://localhost:8000/api/legislation/LEGISLATION_ID/adoption-timeline
# Expect: JSON with legislation_id and timeline array ordered by introduced_date

curl http://localhost:8000/api/templates/TEMPLATE_ID/matches
# Expect: JSON with template_id and matches array

curl -X POST http://localhost:8000/api/similarity/compute
# Expect: 200 with legislation_pairs_stored and template_matches_stored counts

# Diff view:
curl http://localhost:8000/legislation/LEGISLATION_ID/diff/COMPARISON_ID
# Expect: HTML diff page comparing two pieces of legislation

# Ingestion monitoring:
curl http://localhost:8000/admin/ingestion                              # Expect: HTML dashboard page
curl http://localhost:8000/api/ingestion/status                         # Expect: JSON with schedule config and source statuses
curl http://localhost:8000/api/ingestion/jobs                           # Expect: JSON with jobs array and count
curl "http://localhost:8000/api/ingestion/jobs?source=federal&limit=5"  # Expect: Filtered/limited jobs
curl http://localhost:8000/api/ingestion/jobs/JOB_ID                    # Expect: JSON single job detail
curl -X POST "http://localhost:8000/api/ingestion/trigger?source=federal"  # Expect: 202 accepted or config error

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
