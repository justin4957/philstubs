import gleam/dynamic/decode
import gleam/result
import sqlight

/// Count legislation records grouped by government level.
/// Returns tuples like ("federal", 50), ("state", 1234), ordered by hierarchy.
pub fn count_by_government_level(
  connection: sqlight.Connection,
) -> Result(List(#(String, Int)), sqlight.Error) {
  let sql =
    "SELECT government_level, COUNT(*) as count
    FROM legislation
    GROUP BY government_level
    ORDER BY CASE government_level
      WHEN 'federal' THEN 1
      WHEN 'state' THEN 2
      WHEN 'county' THEN 3
      WHEN 'municipal' THEN 4
    END"

  sqlight.query(
    sql,
    on: connection,
    with: [],
    expecting: string_count_decoder(),
  )
}

/// Count all legislation per state (includes state, county, and municipal levels).
/// Returns tuples like ("CA", 450), ("TX", 380), ordered alphabetically.
pub fn count_by_state(
  connection: sqlight.Connection,
) -> Result(List(#(String, Int)), sqlight.Error) {
  let sql =
    "SELECT level_state_code, COUNT(*) as count
    FROM legislation
    WHERE level_state_code IS NOT NULL AND level_state_code != ''
    GROUP BY level_state_code
    ORDER BY level_state_code"

  sqlight.query(
    sql,
    on: connection,
    with: [],
    expecting: string_count_decoder(),
  )
}

/// Count county-level legislation within a state.
/// Returns tuples like ("Cook", 45), ("Los Angeles", 67).
pub fn count_counties_in_state(
  connection: sqlight.Connection,
  state_code: String,
) -> Result(List(#(String, Int)), sqlight.Error) {
  let sql =
    "SELECT level_county_name, COUNT(*) as count
    FROM legislation
    WHERE government_level = 'county'
      AND level_state_code = ?
      AND level_county_name IS NOT NULL
    GROUP BY level_county_name
    ORDER BY level_county_name"

  sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(state_code)],
    expecting: string_count_decoder(),
  )
}

/// Count municipal-level legislation within a state.
/// Returns tuples like ("Austin", 23), ("Seattle", 45).
pub fn count_municipalities_in_state(
  connection: sqlight.Connection,
  state_code: String,
) -> Result(List(#(String, Int)), sqlight.Error) {
  let sql =
    "SELECT level_municipality_name, COUNT(*) as count
    FROM legislation
    WHERE government_level = 'municipal'
      AND level_state_code = ?
      AND level_municipality_name IS NOT NULL
    GROUP BY level_municipality_name
    ORDER BY level_municipality_name"

  sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(state_code)],
    expecting: string_count_decoder(),
  )
}

/// Count state-level legislation for a specific state (excludes county/municipal).
pub fn count_state_legislation(
  connection: sqlight.Connection,
  state_code: String,
) -> Result(Int, sqlight.Error) {
  let sql =
    "SELECT COUNT(*) FROM legislation
    WHERE government_level = 'state' AND level_state_code = ?"

  let count_decoder = {
    use count <- decode.field(0, decode.int)
    decode.success(count)
  }

  use rows <- result.try(sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(state_code)],
    expecting: count_decoder,
  ))

  case rows {
    [count, ..] -> Ok(count)
    [] -> Ok(0)
  }
}

/// Count legislation grouped by topic, extracted from JSON arrays.
/// Returns tuples like ("environment", 120), ("housing", 85), ordered by count descending.
pub fn count_topics(
  connection: sqlight.Connection,
) -> Result(List(#(String, Int)), sqlight.Error) {
  let sql =
    "SELECT je.value as topic, COUNT(*) as count
    FROM legislation, json_each(legislation.topics) je
    WHERE je.value != ''
    GROUP BY je.value
    ORDER BY count DESC"

  sqlight.query(
    sql,
    on: connection,
    with: [],
    expecting: string_count_decoder(),
  )
}

// --- Decoders ---

fn string_count_decoder() -> decode.Decoder(#(String, Int)) {
  use label <- decode.field(0, decode.string)
  use count <- decode.field(1, decode.int)
  decode.success(#(label, count))
}
