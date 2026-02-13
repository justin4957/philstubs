import gleam/int
import gleam/json
import philstubs/core/legislation.{type Legislation}
import philstubs/search/search_query.{type SearchQuery}

/// A single search result pairing a legislation record with a highlighted snippet.
pub type SearchResult {
  SearchResult(legislation: Legislation, snippet: String)
}

/// Paginated search results with metadata for navigation.
pub type SearchResults {
  SearchResults(
    items: List(SearchResult),
    total_count: Int,
    page: Int,
    per_page: Int,
    total_pages: Int,
    query: SearchQuery,
  )
}

/// Build an empty result set for a given query.
pub fn empty(query: SearchQuery) -> SearchResults {
  SearchResults(
    items: [],
    total_count: 0,
    page: query.page,
    per_page: query.per_page,
    total_pages: 0,
    query: query,
  )
}

/// Calculate total pages from count and per_page.
pub fn compute_total_pages(total_count: Int, per_page: Int) -> Int {
  case total_count {
    0 -> 0
    count -> { count + per_page - 1 } / per_page
  }
}

/// Encode search results to JSON for the API endpoint.
pub fn to_json(results: SearchResults) -> json.Json {
  json.object([
    #("items", json.array(results.items, search_result_to_json)),
    #("total_count", json.int(results.total_count)),
    #("page", json.int(results.page)),
    #("per_page", json.int(results.per_page)),
    #("total_pages", json.int(results.total_pages)),
  ])
}

fn search_result_to_json(search_result: SearchResult) -> json.Json {
  json.object([
    #("legislation", legislation.to_json(search_result.legislation)),
    #("snippet", json.string(search_result.snippet)),
  ])
}

/// Format a human-readable "Showing X-Y of Z results" string.
pub fn showing_label(results: SearchResults) -> String {
  case results.total_count {
    0 -> "No results found"
    total -> {
      let start = { results.page - 1 } * results.per_page + 1
      let end = int.min(start + results.per_page - 1, total)
      "Showing "
      <> int.to_string(start)
      <> "-"
      <> int.to_string(end)
      <> " of "
      <> int.to_string(total)
      <> " results"
    }
  }
}
