import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

/// How search results should be ordered.
pub type SortField {
  Relevance
  Date
  Title
}

/// A parsed, validated search request built from URL query params.
pub type SearchQuery {
  SearchQuery(
    text: Option(String),
    government_level: Option(String),
    state_code: Option(String),
    legislation_type: Option(String),
    status: Option(String),
    date_from: Option(String),
    date_to: Option(String),
    page: Int,
    per_page: Int,
    sort_by: SortField,
  )
}

/// A search query with no filters and default pagination.
pub fn default() -> SearchQuery {
  SearchQuery(
    text: None,
    government_level: None,
    state_code: None,
    legislation_type: None,
    status: None,
    date_from: None,
    date_to: None,
    page: 1,
    per_page: 20,
    sort_by: Relevance,
  )
}

/// Parse a SearchQuery from URL query parameters.
/// Unrecognized keys are ignored. Values are validated and clamped.
pub fn from_query_params(params: List(#(String, String))) -> SearchQuery {
  let query = default()
  list.fold(params, query, fn(accumulated_query, param) {
    let #(key, value) = param
    case key {
      "q" -> SearchQuery(..accumulated_query, text: non_empty(value))
      "level" ->
        SearchQuery(..accumulated_query, government_level: non_empty(value))
      "state" -> SearchQuery(..accumulated_query, state_code: non_empty(value))
      "type" ->
        SearchQuery(..accumulated_query, legislation_type: non_empty(value))
      "status" -> SearchQuery(..accumulated_query, status: non_empty(value))
      "date_from" ->
        SearchQuery(..accumulated_query, date_from: non_empty(value))
      "date_to" -> SearchQuery(..accumulated_query, date_to: non_empty(value))
      "page" ->
        SearchQuery(
          ..accumulated_query,
          page: parse_int_clamped(value, 1, 10_000, 1),
        )
      "per_page" ->
        SearchQuery(
          ..accumulated_query,
          per_page: parse_int_clamped(value, 1, 100, 20),
        )
      "sort" -> SearchQuery(..accumulated_query, sort_by: parse_sort(value))
      _ -> accumulated_query
    }
  })
}

/// Serialize a SearchQuery back to URL query parameters.
/// Only includes non-default values for clean URLs.
pub fn to_query_params(query: SearchQuery) -> List(#(String, String)) {
  let params = []
  let params = case query.text {
    Some(text) -> [#("q", text), ..params]
    None -> params
  }
  let params = case query.government_level {
    Some(level) -> [#("level", level), ..params]
    None -> params
  }
  let params = case query.state_code {
    Some(state_code) -> [#("state", state_code), ..params]
    None -> params
  }
  let params = case query.legislation_type {
    Some(legislation_type) -> [#("type", legislation_type), ..params]
    None -> params
  }
  let params = case query.status {
    Some(status) -> [#("status", status), ..params]
    None -> params
  }
  let params = case query.date_from {
    Some(date_from) -> [#("date_from", date_from), ..params]
    None -> params
  }
  let params = case query.date_to {
    Some(date_to) -> [#("date_to", date_to), ..params]
    None -> params
  }
  let params = case query.page {
    1 -> params
    page -> [#("page", int.to_string(page)), ..params]
  }
  let params = case query.per_page {
    20 -> params
    per_page -> [#("per_page", int.to_string(per_page)), ..params]
  }
  let params = case query.sort_by {
    Relevance -> params
    Date -> [#("sort", "date"), ..params]
    Title -> [#("sort", "title"), ..params]
  }
  list.reverse(params)
}

/// Whether the query has any active filters beyond just text search.
pub fn has_filters(query: SearchQuery) -> Bool {
  option.is_some(query.government_level)
  || option.is_some(query.state_code)
  || option.is_some(query.legislation_type)
  || option.is_some(query.status)
  || option.is_some(query.date_from)
  || option.is_some(query.date_to)
}

/// Calculate the SQL OFFSET from page and per_page.
pub fn offset(query: SearchQuery) -> Int {
  { query.page - 1 } * query.per_page
}

// --- Internal helpers ---

fn non_empty(value: String) -> Option(String) {
  case value {
    "" -> None
    trimmed -> Some(trimmed)
  }
}

fn parse_int_clamped(
  value: String,
  minimum: Int,
  maximum: Int,
  fallback: Int,
) -> Int {
  case int.parse(value) {
    Ok(parsed) -> int.clamp(parsed, minimum, maximum)
    Error(_) -> fallback
  }
}

fn parse_sort(value: String) -> SortField {
  case value {
    "date" -> Date
    "title" -> Title
    _ -> Relevance
  }
}
