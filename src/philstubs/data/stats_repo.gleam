import gleam/dynamic/decode
import gleam/json
import gleam/result
import philstubs/data/browse_repo
import sqlight

/// Aggregated statistics about legislation in the database.
pub type LegislationStats {
  LegislationStats(
    total: Int,
    by_level: List(#(String, Int)),
    by_type: List(#(String, Int)),
    by_status: List(#(String, Int)),
  )
}

/// Collect aggregated legislation statistics: total count, breakdowns by
/// government level, legislation type, and status.
pub fn get_legislation_stats(
  connection: sqlight.Connection,
) -> Result(LegislationStats, sqlight.Error) {
  use total <- result.try(count_total(connection))
  use by_level <- result.try(browse_repo.count_by_government_level(connection))
  use by_type <- result.try(count_by_type(connection))
  use by_status <- result.try(count_by_status(connection))

  Ok(LegislationStats(total:, by_level:, by_type:, by_status:))
}

/// Encode LegislationStats to JSON.
pub fn stats_to_json(stats: LegislationStats) -> json.Json {
  json.object([
    #("total", json.int(stats.total)),
    #("by_level", json.array(stats.by_level, label_count_to_json)),
    #("by_type", json.array(stats.by_type, label_count_to_json)),
    #("by_status", json.array(stats.by_status, label_count_to_json)),
  ])
}

// --- Internal queries ---

fn count_total(connection: sqlight.Connection) -> Result(Int, sqlight.Error) {
  let count_decoder = {
    use count <- decode.field(0, decode.int)
    decode.success(count)
  }

  use rows <- result.try(sqlight.query(
    "SELECT COUNT(*) FROM legislation",
    on: connection,
    with: [],
    expecting: count_decoder,
  ))

  case rows {
    [count, ..] -> Ok(count)
    [] -> Ok(0)
  }
}

fn count_by_type(
  connection: sqlight.Connection,
) -> Result(List(#(String, Int)), sqlight.Error) {
  sqlight.query(
    "SELECT legislation_type, COUNT(*) as count
    FROM legislation
    GROUP BY legislation_type
    ORDER BY count DESC",
    on: connection,
    with: [],
    expecting: string_count_decoder(),
  )
}

fn count_by_status(
  connection: sqlight.Connection,
) -> Result(List(#(String, Int)), sqlight.Error) {
  sqlight.query(
    "SELECT status, COUNT(*) as count
    FROM legislation
    GROUP BY status
    ORDER BY count DESC",
    on: connection,
    with: [],
    expecting: string_count_decoder(),
  )
}

fn string_count_decoder() -> decode.Decoder(#(String, Int)) {
  use label <- decode.field(0, decode.string)
  use count <- decode.field(1, decode.int)
  decode.success(#(label, count))
}

fn label_count_to_json(item: #(String, Int)) -> json.Json {
  let #(label, count) = item
  json.object([
    #("label", json.string(label)),
    #("count", json.int(count)),
  ])
}

/// Count legislation grouped by type. Exposed for direct use.
pub fn count_by_legislation_type(
  connection: sqlight.Connection,
) -> Result(List(#(String, Int)), sqlight.Error) {
  count_by_type(connection)
}

/// Count legislation grouped by status. Exposed for direct use.
pub fn count_by_legislation_status(
  connection: sqlight.Connection,
) -> Result(List(#(String, Int)), sqlight.Error) {
  count_by_status(connection)
}
