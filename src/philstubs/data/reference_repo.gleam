import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import philstubs/core/reference.{
  type CrossReference, type Extractor, type QueryMap, type ReferenceType,
  CrossReference, QueryMap,
}
import sqlight

/// Insert or replace a cross-reference record.
pub fn insert_reference(
  connection: sqlight.Connection,
  ref: CrossReference,
) -> Result(Nil, sqlight.Error) {
  let sql =
    "INSERT OR REPLACE INTO legislation_references
      (id, source_legislation_id, target_legislation_id, citation_text,
       reference_type, confidence, extractor, extracted_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)"

  let target_param = case ref.target_legislation_id {
    Some(target_id) -> sqlight.text(target_id)
    None -> sqlight.null()
  }

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(reference.reference_id_to_string(ref.id)),
      sqlight.text(ref.source_legislation_id),
      target_param,
      sqlight.text(ref.citation_text),
      sqlight.text(reference.reference_type_to_string(ref.reference_type)),
      sqlight.float(ref.confidence),
      sqlight.text(reference.extractor_to_string(ref.extractor)),
      sqlight.text(ref.extracted_at),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Find outgoing references from a piece of legislation.
pub fn find_references_from(
  connection: sqlight.Connection,
  legislation_id: String,
  limit: Int,
) -> Result(List(CrossReference), sqlight.Error) {
  let sql =
    "SELECT id, source_legislation_id, target_legislation_id, citation_text,
            reference_type, confidence, extractor, extracted_at
     FROM legislation_references
     WHERE source_legislation_id = ?
     ORDER BY extracted_at DESC
     LIMIT ?"

  sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(legislation_id), sqlight.int(limit)],
    expecting: cross_reference_decoder(),
  )
}

/// Find incoming references to a piece of legislation.
pub fn find_references_to(
  connection: sqlight.Connection,
  legislation_id: String,
  limit: Int,
) -> Result(List(CrossReference), sqlight.Error) {
  let sql =
    "SELECT id, source_legislation_id, target_legislation_id, citation_text,
            reference_type, confidence, extractor, extracted_at
     FROM legislation_references
     WHERE target_legislation_id = ?
     ORDER BY extracted_at DESC
     LIMIT ?"

  sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(legislation_id), sqlight.int(limit)],
    expecting: cross_reference_decoder(),
  )
}

/// Delete all references for a given source legislation (for re-extraction).
pub fn delete_references_for(
  connection: sqlight.Connection,
  legislation_id: String,
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "DELETE FROM legislation_references WHERE source_legislation_id = ?",
    on: connection,
    with: [sqlight.text(legislation_id)],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Count total cross-references in the database.
pub fn count_references(
  connection: sqlight.Connection,
) -> Result(Int, sqlight.Error) {
  let count_decoder = {
    use count <- decode.field(0, decode.int)
    decode.success(count)
  }

  use rows <- result.try(sqlight.query(
    "SELECT COUNT(*) FROM legislation_references",
    on: connection,
    with: [],
    expecting: count_decoder,
  ))

  case rows {
    [count, ..] -> Ok(count)
    [] -> Ok(0)
  }
}

/// Insert or replace a query map.
pub fn insert_query_map(
  connection: sqlight.Connection,
  query_map: QueryMap,
) -> Result(Nil, sqlight.Error) {
  let sql =
    "INSERT OR REPLACE INTO query_maps
      (id, name, description, query_template, parameters, created_at)
     VALUES (?, ?, ?, ?, ?, ?)"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(reference.query_map_id_to_string(query_map.id)),
      sqlight.text(query_map.name),
      sqlight.text(query_map.description),
      sqlight.text(query_map.query_template),
      sqlight.text(query_map.parameters),
      sqlight.text(query_map.created_at),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Get a query map by its ID.
pub fn get_query_map_by_id(
  connection: sqlight.Connection,
  query_map_id: String,
) -> Result(Option(QueryMap), sqlight.Error) {
  let sql =
    "SELECT id, name, description, query_template, parameters, created_at
     FROM query_maps WHERE id = ?"

  use rows <- result.try(sqlight.query(
    sql,
    on: connection,
    with: [sqlight.text(query_map_id)],
    expecting: query_map_decoder(),
  ))

  case rows {
    [query_map, ..] -> Ok(Some(query_map))
    [] -> Ok(None)
  }
}

/// List all query maps.
pub fn list_query_maps(
  connection: sqlight.Connection,
) -> Result(List(QueryMap), sqlight.Error) {
  let sql =
    "SELECT id, name, description, query_template, parameters, created_at
     FROM query_maps ORDER BY name ASC"

  sqlight.query(sql, on: connection, with: [], expecting: query_map_decoder())
}

/// Delete a query map by its ID.
pub fn delete_query_map(
  connection: sqlight.Connection,
  query_map_id: String,
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "DELETE FROM query_maps WHERE id = ?",
    on: connection,
    with: [sqlight.text(query_map_id)],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

// --- Row decoders ---

fn cross_reference_decoder() -> decode.Decoder(CrossReference) {
  use id_str <- decode.field(0, decode.string)
  use source_legislation_id <- decode.field(1, decode.string)
  use target_legislation_id <- decode.field(2, decode.optional(decode.string))
  use citation_text <- decode.field(3, decode.string)
  use reference_type_str <- decode.field(4, decode.string)
  use confidence <- decode.field(5, decode.float)
  use extractor_str <- decode.field(6, decode.string)
  use extracted_at <- decode.field(7, decode.string)

  let reference_type: ReferenceType =
    reference.reference_type_from_string(reference_type_str)
  let extractor: Extractor = reference.extractor_from_string(extractor_str)

  decode.success(CrossReference(
    id: reference.reference_id(id_str),
    source_legislation_id:,
    target_legislation_id:,
    citation_text:,
    reference_type:,
    confidence:,
    extractor:,
    extracted_at:,
  ))
}

fn query_map_decoder() -> decode.Decoder(QueryMap) {
  use id_str <- decode.field(0, decode.string)
  use name <- decode.field(1, decode.string)
  use description <- decode.field(2, decode.string)
  use query_template <- decode.field(3, decode.string)
  use parameters <- decode.field(4, decode.string)
  use created_at <- decode.field(5, decode.string)

  decode.success(QueryMap(
    id: reference.query_map_id(id_str),
    name:,
    description:,
    query_template:,
    parameters:,
    created_at:,
  ))
}
