import gleam/list
import gleam/option.{None, Some}
import gleam/result
import philstubs/core/legislation.{type Legislation}
import philstubs/core/legislation_template.{type LegislationTemplate}
import philstubs/core/similarity
import philstubs/data/legislation_repo
import philstubs/data/similarity_repo
import philstubs/data/template_repo
import sqlight

/// Compare one legislation record against all others and store results.
/// Only stores pairs with combined_similarity >= min_score.
/// Returns count of pairs stored.
pub fn compute_similarities_for(
  connection: sqlight.Connection,
  legislation_id: String,
  min_score: Float,
) -> Result(Int, sqlight.Error) {
  use source_option <- result.try(legislation_repo.get_by_id(
    connection,
    legislation_id,
  ))

  case source_option {
    None -> Ok(0)
    Some(source_record) -> {
      use all_legislation <- result.try(legislation_repo.list_all(connection))
      let candidates =
        list.filter(all_legislation, fn(candidate) {
          legislation.legislation_id_to_string(candidate.id) != legislation_id
        })

      compute_and_store_pairs(
        connection,
        source_record,
        candidates,
        min_score,
        0,
      )
    }
  }
}

/// Compare all legislation pairwise (batch job). Returns count of pairs stored.
pub fn compute_all_similarities(
  connection: sqlight.Connection,
  min_score: Float,
) -> Result(Int, sqlight.Error) {
  use all_legislation <- result.try(legislation_repo.list_all(connection))
  compute_all_pairs(connection, all_legislation, min_score, 0)
}

/// Compare all templates against all legislation. Returns count of matches stored.
pub fn compute_template_matches(
  connection: sqlight.Connection,
  min_score: Float,
) -> Result(Int, sqlight.Error) {
  use all_templates <- result.try(template_repo.list_all(connection))
  use all_legislation <- result.try(legislation_repo.list_all(connection))

  compute_template_pairs(
    connection,
    all_templates,
    all_legislation,
    min_score,
    0,
  )
}

// --- Private helpers ---

fn compute_and_store_pairs(
  connection: sqlight.Connection,
  source_record: Legislation,
  candidates: List(Legislation),
  min_score: Float,
  stored_count: Int,
) -> Result(Int, sqlight.Error) {
  case candidates {
    [] -> Ok(stored_count)
    [candidate, ..remaining_candidates] -> {
      let source_id = legislation.legislation_id_to_string(source_record.id)
      let target_id = legislation.legislation_id_to_string(candidate.id)

      let body_score =
        similarity.text_similarity(source_record.body, candidate.body)
      let title_score =
        similarity.title_similarity(source_record.title, candidate.title)
      let topic_score =
        similarity.topic_overlap(source_record.topics, candidate.topics)
      let combined_score =
        0.7 *. body_score +. 0.2 *. title_score +. 0.1 *. topic_score

      case combined_score >=. min_score {
        True -> {
          use _ <- result.try(similarity_repo.store_similarity(
            connection,
            source_id,
            target_id,
            combined_score,
            title_score,
            body_score,
            topic_score,
          ))
          compute_and_store_pairs(
            connection,
            source_record,
            remaining_candidates,
            min_score,
            stored_count + 1,
          )
        }
        False ->
          compute_and_store_pairs(
            connection,
            source_record,
            remaining_candidates,
            min_score,
            stored_count,
          )
      }
    }
  }
}

fn compute_all_pairs(
  connection: sqlight.Connection,
  remaining_legislation: List(Legislation),
  min_score: Float,
  total_stored: Int,
) -> Result(Int, sqlight.Error) {
  case remaining_legislation {
    [] -> Ok(total_stored)
    [source_record, ..rest] -> {
      use stored_for_source <- result.try(compute_and_store_pairs(
        connection,
        source_record,
        rest,
        min_score,
        0,
      ))
      compute_all_pairs(
        connection,
        rest,
        min_score,
        total_stored + stored_for_source,
      )
    }
  }
}

fn compute_template_pairs(
  connection: sqlight.Connection,
  templates: List(LegislationTemplate),
  all_legislation: List(Legislation),
  min_score: Float,
  total_stored: Int,
) -> Result(Int, sqlight.Error) {
  case templates {
    [] -> Ok(total_stored)
    [template, ..remaining_templates] -> {
      use stored_for_template <- result.try(compute_template_vs_legislation(
        connection,
        template,
        all_legislation,
        min_score,
        0,
      ))
      compute_template_pairs(
        connection,
        remaining_templates,
        all_legislation,
        min_score,
        total_stored + stored_for_template,
      )
    }
  }
}

fn compute_template_vs_legislation(
  connection: sqlight.Connection,
  template: LegislationTemplate,
  legislation_list: List(Legislation),
  min_score: Float,
  stored_count: Int,
) -> Result(Int, sqlight.Error) {
  case legislation_list {
    [] -> Ok(stored_count)
    [legislation_record, ..remaining_legislation] -> {
      let tmpl_id = legislation_template.template_id_to_string(template.id)
      let leg_id = legislation.legislation_id_to_string(legislation_record.id)

      let body_score =
        similarity.text_similarity(template.body, legislation_record.body)
      let title_score =
        similarity.title_similarity(template.title, legislation_record.title)
      let topic_score =
        similarity.topic_overlap(template.topics, legislation_record.topics)
      let combined_score =
        0.7 *. body_score +. 0.2 *. title_score +. 0.1 *. topic_score

      case combined_score >=. min_score {
        True -> {
          use _ <- result.try(similarity_repo.store_template_match(
            connection,
            tmpl_id,
            leg_id,
            combined_score,
            title_score,
            body_score,
            topic_score,
          ))
          compute_template_vs_legislation(
            connection,
            template,
            remaining_legislation,
            min_score,
            stored_count + 1,
          )
        }
        False ->
          compute_template_vs_legislation(
            connection,
            template,
            remaining_legislation,
            min_score,
            stored_count,
          )
      }
    }
  }
}
