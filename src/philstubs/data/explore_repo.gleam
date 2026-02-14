import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import philstubs/core/explore_graph.{type SimilarityEdgeRow, SimilarityEdgeRow}
import philstubs/core/legislation.{type Legislation}
import philstubs/core/reference.{type CrossReference}
import philstubs/core/topic.{type Topic}
import philstubs/data/legislation_repo
import philstubs/data/reference_repo
import philstubs/data/topic_repo
import sqlight

/// Load a legislation node with its topics.
pub fn load_node(
  connection: sqlight.Connection,
  legislation_id: String,
) -> Result(Option(#(Legislation, List(Topic))), sqlight.Error) {
  use maybe_legislation <- result.try(legislation_repo.get_by_id(
    connection,
    legislation_id,
  ))

  case maybe_legislation {
    None -> Ok(None)
    Some(legislation) -> {
      use topics <- result.try(topic_repo.get_legislation_topics(
        connection,
        legislation_id,
      ))
      Ok(Some(#(legislation, topics)))
    }
  }
}

/// Load all edges for a node: outgoing refs, incoming refs, and similarity edges.
pub fn load_node_edges(
  connection: sqlight.Connection,
  legislation_id: String,
) -> Result(
  #(List(CrossReference), List(CrossReference), List(SimilarityEdgeRow)),
  sqlight.Error,
) {
  use outgoing <- result.try(reference_repo.find_references_from(
    connection,
    legislation_id,
    100,
  ))
  use incoming <- result.try(reference_repo.find_references_to(
    connection,
    legislation_id,
    100,
  ))
  use similarities <- result.try(load_similarity_edges(
    connection,
    legislation_id,
    0.1,
    50,
  ))
  Ok(#(outgoing, incoming, similarities))
}

/// Load similarity edges for a given legislation.
pub fn load_similarity_edges(
  connection: sqlight.Connection,
  legislation_id: String,
  min_score: Float,
  limit: Int,
) -> Result(List(SimilarityEdgeRow), sqlight.Error) {
  let sql =
    "SELECT target_legislation_id, similarity_score, title_score, body_score, topic_score
     FROM legislation_similarities
     WHERE source_legislation_id = ? AND similarity_score >= ?
     ORDER BY similarity_score DESC
     LIMIT ?"

  sqlight.query(
    sql,
    on: connection,
    with: [
      sqlight.text(legislation_id),
      sqlight.float(min_score),
      sqlight.int(limit),
    ],
    expecting: similarity_edge_row_decoder(),
  )
}

/// Load the full similarity adjacency dict for BFS expand.
pub fn load_similarity_adjacency(
  connection: sqlight.Connection,
  min_score: Float,
) -> Result(Dict(String, List(SimilarityEdgeRow)), sqlight.Error) {
  let sql =
    "SELECT source_legislation_id, target_legislation_id, similarity_score,
            title_score, body_score, topic_score
     FROM legislation_similarities
     WHERE similarity_score >= ?
     ORDER BY similarity_score DESC"

  let row_decoder = {
    use source_id <- decode.field(0, decode.string)
    use target_id <- decode.field(1, decode.string)
    use similarity_score <- decode.field(2, decode.float)
    use title_score <- decode.field(3, decode.float)
    use body_score <- decode.field(4, decode.float)
    use topic_score <- decode.field(5, decode.float)
    decode.success(#(
      source_id,
      SimilarityEdgeRow(
        target_legislation_id: target_id,
        similarity_score:,
        title_score:,
        body_score:,
        topic_score:,
      ),
    ))
  }

  use rows <- result.try(sqlight.query(
    sql,
    on: connection,
    with: [sqlight.float(min_score)],
    expecting: row_decoder,
  ))

  let adjacency =
    list.fold(rows, dict.new(), fn(accumulated, row) {
      let #(source_id, edge_row) = row
      dict.upsert(accumulated, source_id, fn(existing) {
        case existing {
          option.Some(edges) -> [edge_row, ..edges]
          option.None -> [edge_row]
        }
      })
    })

  Ok(adjacency)
}

/// Load cross-references where both source and target are in the given ID set.
pub fn load_inter_references(
  connection: sqlight.Connection,
  legislation_ids: List(String),
) -> Result(List(CrossReference), sqlight.Error) {
  case legislation_ids {
    [] -> Ok([])
    _ -> {
      let #(placeholders, params) = build_in_clause(legislation_ids)
      let sql =
        "SELECT id, source_legislation_id, target_legislation_id, citation_text,
                reference_type, confidence, extractor, extracted_at
         FROM legislation_references
         WHERE source_legislation_id IN (" <> placeholders <> ")
         AND target_legislation_id IN (" <> placeholders <> ")"

      let all_params = list.append(params, params)

      sqlight.query(
        sql,
        on: connection,
        with: all_params,
        expecting: cross_reference_decoder(),
      )
    }
  }
}

/// Load similarities where both source and target are in the given ID set.
pub fn load_inter_similarities(
  connection: sqlight.Connection,
  legislation_ids: List(String),
  min_score: Float,
) -> Result(List(SimilarityEdgeRow), sqlight.Error) {
  case legislation_ids {
    [] -> Ok([])
    _ -> {
      let #(placeholders, params) = build_in_clause(legislation_ids)
      let sql =
        "SELECT target_legislation_id, similarity_score, title_score, body_score, topic_score
         FROM legislation_similarities
         WHERE source_legislation_id IN ("
        <> placeholders
        <> ")
         AND target_legislation_id IN ("
        <> placeholders
        <> ")
         AND similarity_score >= ?
         ORDER BY similarity_score DESC"

      let all_params =
        list.flatten([params, params, [sqlight.float(min_score)]])

      sqlight.query(
        sql,
        on: connection,
        with: all_params,
        expecting: similarity_edge_row_decoder(),
      )
    }
  }
}

/// Load legislation IDs for a topic (by slug), including children.
pub fn load_legislation_ids_for_topic(
  connection: sqlight.Connection,
  slug: String,
  limit: Int,
) -> Result(Option(#(Topic, List(String))), sqlight.Error) {
  use maybe_topic <- result.try(topic_repo.get_by_slug(connection, slug))

  case maybe_topic {
    None -> Ok(None)
    Some(found_topic) -> {
      let topic_id_str = topic.topic_id_to_string(found_topic.id)
      use rows <- result.try(
        sqlight.query(
          "SELECT DISTINCT lt.legislation_id
         FROM legislation_topics lt
         WHERE lt.topic_id = ? OR lt.topic_id IN (
           SELECT id FROM topics WHERE parent_id = ?
         )
         LIMIT ?",
          on: connection,
          with: [
            sqlight.text(topic_id_str),
            sqlight.text(topic_id_str),
            sqlight.int(limit),
          ],
          expecting: {
            use legislation_id <- decode.field(0, decode.string)
            decode.success(legislation_id)
          },
        ),
      )
      Ok(Some(#(found_topic, rows)))
    }
  }
}

// --- Helpers ---

/// Build a SQL IN clause with placeholders and corresponding values.
pub fn build_in_clause(items: List(String)) -> #(String, List(sqlight.Value)) {
  let placeholders =
    list.map(items, fn(_) { "?" })
    |> string.join(", ")
  let values = list.map(items, sqlight.text)
  #(placeholders, values)
}

// --- Row decoders ---

fn similarity_edge_row_decoder() -> decode.Decoder(SimilarityEdgeRow) {
  use target_legislation_id <- decode.field(0, decode.string)
  use similarity_score <- decode.field(1, decode.float)
  use title_score <- decode.field(2, decode.float)
  use body_score <- decode.field(3, decode.float)
  use topic_score <- decode.field(4, decode.float)
  decode.success(SimilarityEdgeRow(
    target_legislation_id:,
    similarity_score:,
    title_score:,
    body_score:,
    topic_score:,
  ))
}

fn cross_reference_decoder() -> decode.Decoder(CrossReference) {
  use id_str <- decode.field(0, decode.string)
  use source_legislation_id <- decode.field(1, decode.string)
  use target_legislation_id <- decode.field(2, decode.optional(decode.string))
  use citation_text <- decode.field(3, decode.string)
  use reference_type_str <- decode.field(4, decode.string)
  use confidence <- decode.field(5, decode.float)
  use extractor_str <- decode.field(6, decode.string)
  use extracted_at <- decode.field(7, decode.string)

  decode.success(reference.CrossReference(
    id: reference.reference_id(id_str),
    source_legislation_id:,
    target_legislation_id:,
    citation_text:,
    reference_type: reference.reference_type_from_string(reference_type_str),
    confidence:,
    extractor: reference.extractor_from_string(extractor_str),
    extracted_at:,
  ))
}
