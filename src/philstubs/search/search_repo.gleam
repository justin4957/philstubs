import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import philstubs/core/government_level.{
  type GovernmentLevel, County, Federal, Municipal, State,
}
import philstubs/core/legislation.{Legislation}
import philstubs/core/legislation_status.{type LegislationStatus}
import philstubs/core/legislation_type.{type LegislationType}
import philstubs/search/search_query.{type SearchQuery, Date, Relevance, Title}
import philstubs/search/search_results.{
  type SearchResult, type SearchResults, SearchResult, SearchResults,
}
import sqlight

/// Search legislation with full-text search and faceted filtering.
/// Builds dynamic SQL with parameterized filters to avoid injection.
pub fn search(
  connection: sqlight.Connection,
  query: SearchQuery,
) -> Result(SearchResults, sqlight.Error) {
  let has_text = option.is_some(query.text)
  let #(where_clauses, where_params) = build_where_clauses(query)

  // Count query
  use total_count <- result.try(count_results(
    connection,
    has_text,
    query,
    where_clauses,
    where_params,
  ))

  case total_count {
    0 -> Ok(search_results.empty(query))
    _ -> {
      // Results query
      use items <- result.try(fetch_results(
        connection,
        has_text,
        query,
        where_clauses,
        where_params,
      ))

      let total_pages =
        search_results.compute_total_pages(total_count, query.per_page)

      Ok(SearchResults(
        items: items,
        total_count: total_count,
        page: query.page,
        per_page: query.per_page,
        total_pages: total_pages,
        query: query,
      ))
    }
  }
}

// --- SQL construction ---

fn build_where_clauses(
  query: SearchQuery,
) -> #(List(String), List(sqlight.Value)) {
  let clauses = []
  let params = []

  let #(clauses, params) = case query.government_level {
    Some(level) -> #(["l.government_level = ?", ..clauses], [
      sqlight.text(level),
      ..params
    ])
    None -> #(clauses, params)
  }

  let #(clauses, params) = case query.state_code {
    Some(state_code) -> #(["l.level_state_code = ?", ..clauses], [
      sqlight.text(state_code),
      ..params
    ])
    None -> #(clauses, params)
  }

  let #(clauses, params) = case query.legislation_type {
    Some(legislation_type) -> #(["l.legislation_type = ?", ..clauses], [
      sqlight.text(legislation_type),
      ..params
    ])
    None -> #(clauses, params)
  }

  let #(clauses, params) = case query.status {
    Some(status) -> #(["l.status = ?", ..clauses], [
      sqlight.text(status),
      ..params
    ])
    None -> #(clauses, params)
  }

  let #(clauses, params) = case query.date_from {
    Some(date_from) -> #(["l.introduced_date >= ?", ..clauses], [
      sqlight.text(date_from),
      ..params
    ])
    None -> #(clauses, params)
  }

  let #(clauses, params) = case query.date_to {
    Some(date_to) -> #(["l.introduced_date <= ?", ..clauses], [
      sqlight.text(date_to),
      ..params
    ])
    None -> #(clauses, params)
  }

  #(list.reverse(clauses), list.reverse(params))
}

fn build_where_sql(has_text: Bool, where_clauses: List(String)) -> String {
  let fts_clause = case has_text {
    True -> ["legislation_fts MATCH ?"]
    False -> []
  }

  let all_clauses = list.append(fts_clause, where_clauses)

  case all_clauses {
    [] -> ""
    clauses -> " WHERE " <> string.join(clauses, " AND ")
  }
}

fn build_order_sql(query: SearchQuery, has_text: Bool) -> String {
  case query.sort_by {
    Relevance if has_text -> " ORDER BY fts.rank"
    Relevance -> " ORDER BY l.introduced_date DESC"
    Date -> " ORDER BY l.introduced_date DESC"
    Title -> " ORDER BY l.title ASC"
  }
}

fn count_results(
  connection: sqlight.Connection,
  has_text: Bool,
  query: SearchQuery,
  where_clauses: List(String),
  where_params: List(sqlight.Value),
) -> Result(Int, sqlight.Error) {
  let from_clause = case has_text {
    True ->
      " FROM legislation_fts fts JOIN legislation l ON l.rowid = fts.rowid"
    False -> " FROM legislation l"
  }

  let where_sql = build_where_sql(has_text, where_clauses)

  let sql = "SELECT COUNT(*)" <> from_clause <> where_sql

  let all_params = case has_text {
    True -> {
      let assert Some(text) = query.text
      [sqlight.text(text), ..where_params]
    }
    False -> where_params
  }

  let count_decoder = {
    use count <- decode.field(0, decode.int)
    decode.success(count)
  }

  use rows <- result.try(sqlight.query(
    sql,
    on: connection,
    with: all_params,
    expecting: count_decoder,
  ))

  case rows {
    [count, ..] -> Ok(count)
    [] -> Ok(0)
  }
}

fn fetch_results(
  connection: sqlight.Connection,
  has_text: Bool,
  query: SearchQuery,
  where_clauses: List(String),
  where_params: List(sqlight.Value),
) -> Result(List(SearchResult), sqlight.Error) {
  let #(select_columns, from_clause) = case has_text {
    True -> #(
      "SELECT l.id, l.title, l.summary, l.body, l.government_level, l.level_state_code, l.level_county_name, l.level_municipality_name, l.legislation_type, l.status, l.introduced_date, l.source_url, l.source_identifier, l.sponsors, l.topics, snippet(legislation_fts, -1, '<mark>', '</mark>', '...', 40)",
      " FROM legislation_fts fts JOIN legislation l ON l.rowid = fts.rowid",
    )
    False -> #(
      "SELECT l.id, l.title, l.summary, l.body, l.government_level, l.level_state_code, l.level_county_name, l.level_municipality_name, l.legislation_type, l.status, l.introduced_date, l.source_url, l.source_identifier, l.sponsors, l.topics, substr(l.summary, 1, 200)",
      " FROM legislation l",
    )
  }

  let where_sql = build_where_sql(has_text, where_clauses)
  let order_sql = build_order_sql(query, has_text)
  let limit_sql = " LIMIT ? OFFSET ?"

  let sql = select_columns <> from_clause <> where_sql <> order_sql <> limit_sql

  let text_params = case has_text {
    True -> {
      let assert Some(text) = query.text
      [sqlight.text(text)]
    }
    False -> []
  }

  let pagination_params = [
    sqlight.int(query.per_page),
    sqlight.int(search_query.offset(query)),
  ]

  let all_params = list.flatten([text_params, where_params, pagination_params])

  sqlight.query(
    sql,
    on: connection,
    with: all_params,
    expecting: search_result_decoder(),
  )
}

// --- Row decoder ---

fn search_result_decoder() -> decode.Decoder(SearchResult) {
  use id_str <- decode.field(0, decode.string)
  use title <- decode.field(1, decode.string)
  use summary <- decode.field(2, decode.string)
  use body <- decode.field(3, decode.string)
  use level_str <- decode.field(4, decode.string)
  use state_code <- decode.field(5, decode.optional(decode.string))
  use county_name <- decode.field(6, decode.optional(decode.string))
  use municipality_name <- decode.field(7, decode.optional(decode.string))
  use leg_type_str <- decode.field(8, decode.string)
  use status_str <- decode.field(9, decode.string)
  use introduced_date <- decode.field(10, decode.string)
  use source_url <- decode.field(11, decode.optional(decode.string))
  use source_identifier <- decode.field(12, decode.string)
  use sponsors_json <- decode.field(13, decode.string)
  use topics_json <- decode.field(14, decode.string)
  use snippet <- decode.field(15, decode.string)

  let level =
    government_level_from_columns(
      level_str,
      state_code,
      county_name,
      municipality_name,
    )
  let leg_type = legislation_type_from_db_string(leg_type_str)
  let status = legislation_status_from_db_string(status_str)

  decode.success(SearchResult(
    legislation: Legislation(
      id: legislation.legislation_id(id_str),
      title: title,
      summary: summary,
      body: body,
      level: level,
      legislation_type: leg_type,
      status: status,
      introduced_date: introduced_date,
      source_url: source_url,
      source_identifier: source_identifier,
      sponsors: json_text_to_list(sponsors_json),
      topics: json_text_to_list(topics_json),
    ),
    snippet: snippet,
  ))
}

// --- DB conversion helpers (duplicated from legislation_repo since they're private) ---

fn government_level_from_columns(
  level_str: String,
  state_code: Option(String),
  county_name: Option(String),
  municipality_name: Option(String),
) -> GovernmentLevel {
  case level_str {
    "state" -> State(state_code: option.unwrap(state_code, ""))
    "county" ->
      County(
        state_code: option.unwrap(state_code, ""),
        county_name: option.unwrap(county_name, ""),
      )
    "municipal" ->
      Municipal(
        state_code: option.unwrap(state_code, ""),
        municipality_name: option.unwrap(municipality_name, ""),
      )
    _ -> Federal
  }
}

fn legislation_type_from_db_string(value: String) -> LegislationType {
  case value {
    "bill" -> legislation_type.Bill
    "resolution" -> legislation_type.Resolution
    "ordinance" -> legislation_type.Ordinance
    "bylaw" -> legislation_type.Bylaw
    "amendment" -> legislation_type.Amendment
    "regulation" -> legislation_type.Regulation
    "executive_order" -> legislation_type.ExecutiveOrder
    _ -> legislation_type.Bill
  }
}

fn legislation_status_from_db_string(value: String) -> LegislationStatus {
  case value {
    "introduced" -> legislation_status.Introduced
    "in_committee" -> legislation_status.InCommittee
    "passed_chamber" -> legislation_status.PassedChamber
    "enacted" -> legislation_status.Enacted
    "vetoed" -> legislation_status.Vetoed
    "expired" -> legislation_status.Expired
    "withdrawn" -> legislation_status.Withdrawn
    _ -> legislation_status.Introduced
  }
}

fn json_text_to_list(json_text: String) -> List(String) {
  case json.parse(json_text, decode.list(decode.string)) {
    Ok(items) -> items
    Error(_) -> []
  }
}
