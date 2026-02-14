import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import philstubs/core/citation_extractor
import philstubs/core/reference
import philstubs/data/legislation_repo
import philstubs/data/reference_repo
import sqlight

/// Extract citations from a legislation record and store them as cross-references.
/// Returns the number of references stored.
pub fn extract_and_store_references(
  connection: sqlight.Connection,
  legislation_id: String,
) -> Result(Int, sqlight.Error) {
  use legislation_option <- result.try(legislation_repo.get_by_id(
    connection,
    legislation_id,
  ))

  case legislation_option {
    None -> Ok(0)
    Some(legislation) -> {
      let combined_text = legislation.summary <> " " <> legislation.body
      let citations = citation_extractor.extract_citations(combined_text)

      use stored_count <- result.try(
        list.try_fold(
          citations,
          0,
          fn(accumulated_count, citation: citation_extractor.ExtractedCitation) {
            // Try to resolve the citation to a target legislation
            use target_id <- result.try(resolve_citation(
              connection,
              citation.citation_text,
            ))

            let ref_id = legislation_id <> ":" <> citation.citation_text
            let cross_ref =
              reference.CrossReference(
                id: reference.reference_id(ref_id),
                source_legislation_id: legislation_id,
                target_legislation_id: target_id,
                citation_text: citation.citation_text,
                reference_type: citation.reference_type,
                confidence: citation.confidence,
                extractor: reference.GleamNative,
                extracted_at: "",
              )

            use _ <- result.try(reference_repo.insert_reference(
              connection,
              cross_ref,
            ))
            Ok(accumulated_count + 1)
          },
        ),
      )

      Ok(stored_count)
    }
  }
}

/// Try to resolve a citation text to a legislation ID by matching against source_identifiers.
fn resolve_citation(
  connection: sqlight.Connection,
  citation_text: String,
) -> Result(option.Option(String), sqlight.Error) {
  let sql =
    "SELECT id FROM legislation
     WHERE LOWER(source_identifier) = LOWER(?)
     LIMIT 1"

  use rows <- result.try(
    sqlight.query(
      sql,
      on: connection,
      with: [sqlight.text(citation_text)],
      expecting: {
        use id <- decode.field(0, decode.string)
        decode.success(id)
      },
    ),
  )

  case rows {
    [legislation_id, ..] -> Ok(Some(legislation_id))
    [] -> Ok(None)
  }
}

/// Resolve pending citations (references with NULL target_legislation_id)
/// by matching citation_text against legislation source_identifiers.
/// Returns the number of references resolved.
pub fn resolve_pending_citations(
  connection: sqlight.Connection,
) -> Result(Int, sqlight.Error) {
  let sql =
    "SELECT r.id, r.citation_text
     FROM legislation_references r
     WHERE r.target_legislation_id IS NULL"

  use pending_refs <- result.try(
    sqlight.query(sql, on: connection, with: [], expecting: {
      use ref_id <- decode.field(0, decode.string)
      use citation_text <- decode.field(1, decode.string)
      decode.success(#(ref_id, citation_text))
    }),
  )

  use resolved_count <- result.try(
    list.try_fold(pending_refs, 0, fn(accumulated_count, pending) {
      let #(ref_id, citation_text) = pending
      use target_id <- result.try(resolve_citation(connection, citation_text))

      case target_id {
        Some(target_legislation_id) -> {
          use _ <- result.try(sqlight.query(
            "UPDATE legislation_references SET target_legislation_id = ? WHERE id = ?",
            on: connection,
            with: [
              sqlight.text(target_legislation_id),
              sqlight.text(ref_id),
            ],
            expecting: decode.success(Nil),
          ))
          Ok(accumulated_count + 1)
        }
        None -> Ok(accumulated_count)
      }
    }),
  )

  Ok(resolved_count)
}
