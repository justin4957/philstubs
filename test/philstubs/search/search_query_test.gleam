import gleam/option.{None, Some}
import gleeunit/should
import philstubs/search/search_query.{Date, Relevance, SearchQuery, Title}

pub fn default_query_test() {
  let query = search_query.default()
  query.text |> should.equal(None)
  query.government_level |> should.equal(None)
  query.state_code |> should.equal(None)
  query.legislation_type |> should.equal(None)
  query.status |> should.equal(None)
  query.date_from |> should.equal(None)
  query.date_to |> should.equal(None)
  query.page |> should.equal(1)
  query.per_page |> should.equal(20)
  query.sort_by |> should.equal(Relevance)
}

pub fn from_query_params_with_text_test() {
  let query = search_query.from_query_params([#("q", "healthcare")])
  query.text |> should.equal(Some("healthcare"))
  query.page |> should.equal(1)
  query.per_page |> should.equal(20)
}

pub fn from_query_params_with_filters_test() {
  let query =
    search_query.from_query_params([
      #("level", "federal"),
      #("type", "bill"),
      #("status", "enacted"),
      #("state", "CA"),
    ])
  query.government_level |> should.equal(Some("federal"))
  query.legislation_type |> should.equal(Some("bill"))
  query.status |> should.equal(Some("enacted"))
  query.state_code |> should.equal(Some("CA"))
}

pub fn from_query_params_with_pagination_test() {
  let query =
    search_query.from_query_params([
      #("page", "3"),
      #("per_page", "50"),
    ])
  query.page |> should.equal(3)
  query.per_page |> should.equal(50)
}

pub fn from_query_params_clamps_values_test() {
  // Page below minimum gets clamped to 1
  let query_low_page = search_query.from_query_params([#("page", "0")])
  query_low_page.page |> should.equal(1)

  // per_page above maximum gets clamped to 100
  let query_high_per_page =
    search_query.from_query_params([#("per_page", "500")])
  query_high_per_page.per_page |> should.equal(100)

  // Invalid number falls back to default
  let query_invalid = search_query.from_query_params([#("page", "abc")])
  query_invalid.page |> should.equal(1)
}

pub fn to_query_params_roundtrip_test() {
  let original =
    SearchQuery(
      text: Some("healthcare"),
      government_level: Some("federal"),
      state_code: None,
      legislation_type: Some("bill"),
      status: None,
      date_from: Some("2024-01-01"),
      date_to: None,
      page: 2,
      per_page: 20,
      sort_by: Date,
    )

  let params = search_query.to_query_params(original)
  let roundtripped = search_query.from_query_params(params)

  roundtripped.text |> should.equal(original.text)
  roundtripped.government_level |> should.equal(original.government_level)
  roundtripped.legislation_type |> should.equal(original.legislation_type)
  roundtripped.date_from |> should.equal(original.date_from)
  roundtripped.page |> should.equal(original.page)
  roundtripped.sort_by |> should.equal(Date)
}

pub fn has_filters_test() {
  // Default has no filters
  search_query.default()
  |> search_query.has_filters
  |> should.equal(False)

  // Text-only query has no filters
  SearchQuery(..search_query.default(), text: Some("test"))
  |> search_query.has_filters
  |> should.equal(False)

  // Level filter counts
  SearchQuery(..search_query.default(), government_level: Some("federal"))
  |> search_query.has_filters
  |> should.equal(True)

  // Date filter counts
  SearchQuery(..search_query.default(), date_from: Some("2024-01-01"))
  |> search_query.has_filters
  |> should.equal(True)
}

pub fn from_query_params_with_sort_test() {
  let date_sort = search_query.from_query_params([#("sort", "date")])
  date_sort.sort_by |> should.equal(Date)

  let title_sort = search_query.from_query_params([#("sort", "title")])
  title_sort.sort_by |> should.equal(Title)

  let default_sort = search_query.from_query_params([#("sort", "unknown")])
  default_sort.sort_by |> should.equal(Relevance)
}

pub fn offset_calculation_test() {
  let query = SearchQuery(..search_query.default(), page: 1, per_page: 20)
  search_query.offset(query) |> should.equal(0)

  let query_page_3 =
    SearchQuery(..search_query.default(), page: 3, per_page: 10)
  search_query.offset(query_page_3) |> should.equal(20)
}

pub fn from_query_params_empty_values_ignored_test() {
  let query =
    search_query.from_query_params([
      #("q", ""),
      #("level", ""),
      #("type", ""),
    ])
  query.text |> should.equal(None)
  query.government_level |> should.equal(None)
  query.legislation_type |> should.equal(None)
}

pub fn to_query_params_omits_defaults_test() {
  let params = search_query.to_query_params(search_query.default())
  params |> should.equal([])
}
