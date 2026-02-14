import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option}
import philstubs/core/government_level.{
  type GovernmentLevel, County, Federal, Municipal, State,
}
import philstubs/core/impact_types.{
  type DependencyGraph, type LegislationSummary, DependencyGraph, GraphEdge,
  LegislationSummary,
}
import philstubs/core/legislation_type
import philstubs/core/reference
import sqlight

/// Load the full cross-reference graph as dual adjacency lists.
/// Only includes references with resolved target_legislation_id.
pub fn load_dependency_graph(
  connection: sqlight.Connection,
) -> Result(DependencyGraph, sqlight.Error) {
  let sql =
    "SELECT source_legislation_id, target_legislation_id, reference_type, confidence
     FROM legislation_references
     WHERE target_legislation_id IS NOT NULL"

  let edge_decoder = {
    use source_id <- decode.field(0, decode.string)
    use target_id <- decode.field(1, decode.string)
    use reference_type_str <- decode.field(2, decode.string)
    use confidence <- decode.field(3, decode.float)
    decode.success(#(
      source_id,
      target_id,
      reference.reference_type_from_string(reference_type_str),
      confidence,
    ))
  }

  case sqlight.query(sql, on: connection, with: [], expecting: edge_decoder) {
    Ok(rows) -> Ok(build_graph(rows))
    Error(database_error) -> Error(database_error)
  }
}

/// Load lightweight metadata for all legislation records.
pub fn load_legislation_metadata(
  connection: sqlight.Connection,
) -> Result(Dict(String, LegislationSummary), sqlight.Error) {
  let sql =
    "SELECT id, title, government_level, level_state_code,
            level_county_name, level_municipality_name, legislation_type
     FROM legislation"

  let metadata_decoder = {
    use legislation_id <- decode.field(0, decode.string)
    use title <- decode.field(1, decode.string)
    use level_str <- decode.field(2, decode.string)
    use state_code <- decode.field(3, decode.optional(decode.string))
    use county_name <- decode.field(4, decode.optional(decode.string))
    use municipality_name <- decode.field(5, decode.optional(decode.string))
    use legislation_type_str <- decode.field(6, decode.string)

    let level =
      government_level_from_columns(
        level_str,
        state_code,
        county_name,
        municipality_name,
      )

    decode.success(LegislationSummary(
      legislation_id:,
      title:,
      level:,
      legislation_type: legislation_type_from_db_string(legislation_type_str),
    ))
  }

  case
    sqlight.query(sql, on: connection, with: [], expecting: metadata_decoder)
  {
    Ok(summaries) -> {
      let metadata_dict =
        list.fold(summaries, dict.new(), fn(accumulated, summary) {
          dict.insert(accumulated, summary.legislation_id, summary)
        })
      Ok(metadata_dict)
    }
    Error(database_error) -> Error(database_error)
  }
}

// --- Internal helpers ---

fn build_graph(
  rows: List(#(String, String, reference.ReferenceType, Float)),
) -> DependencyGraph {
  let #(outgoing, incoming) =
    list.fold(rows, #(dict.new(), dict.new()), fn(accumulated, row) {
      let #(source_id, target_id, reference_type, confidence) = row
      let #(outgoing_dict, incoming_dict) = accumulated

      let outgoing_edge = GraphEdge(target_id:, reference_type:, confidence:)
      let incoming_edge =
        GraphEdge(target_id: source_id, reference_type:, confidence:)

      let updated_outgoing =
        dict.upsert(outgoing_dict, source_id, fn(existing) {
          case existing {
            option.Some(edges) -> [outgoing_edge, ..edges]
            option.None -> [outgoing_edge]
          }
        })

      let updated_incoming =
        dict.upsert(incoming_dict, target_id, fn(existing) {
          case existing {
            option.Some(edges) -> [incoming_edge, ..edges]
            option.None -> [incoming_edge]
          }
        })

      #(updated_outgoing, updated_incoming)
    })

  DependencyGraph(outgoing:, incoming:)
}

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

fn legislation_type_from_db_string(
  value: String,
) -> legislation_type.LegislationType {
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
