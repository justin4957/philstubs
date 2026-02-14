import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
import philstubs/core/auto_tagger
import philstubs/core/topic
import philstubs/data/topic_repo
import sqlight

/// Auto-tag a single legislation record by matching its title and summary
/// against topic keywords. Returns the list of topic IDs assigned.
pub fn auto_tag_legislation(
  connection: sqlight.Connection,
  legislation_id: String,
  title: String,
  summary: String,
) -> Result(List(String), sqlight.Error) {
  use keyword_data <- result.try(topic_repo.list_all_topics_with_keywords(
    connection,
  ))

  let keyword_rules =
    list.map(keyword_data, fn(entry) {
      let #(target_topic_id, keywords) = entry
      auto_tagger.TopicKeywordRule(
        topic_id: target_topic_id,
        keywords: keywords,
      )
    })

  let matches =
    auto_tagger.find_matching_topics(title, summary, keyword_rules)
    |> auto_tagger.deduplicate_matches

  let assigned_topic_ids =
    list.map(matches, fn(match) { topic.topic_id_to_string(match.topic_id) })

  use _ <- result.try(
    list.try_each(matches, fn(match) {
      topic_repo.assign_legislation_topic(
        connection,
        legislation_id,
        match.topic_id,
        topic.AutoKeyword,
      )
    }),
  )

  Ok(assigned_topic_ids)
}

/// Auto-tag all legislation that has no topic assignments yet.
/// Returns the count of legislation records tagged.
pub fn auto_tag_all_untagged(
  connection: sqlight.Connection,
) -> Result(Int, sqlight.Error) {
  // Find legislation with no topic assignments
  use untagged <- result.try(
    sqlight.query(
      "SELECT l.id, l.title, l.summary
       FROM legislation l
       WHERE l.id NOT IN (SELECT DISTINCT legislation_id FROM legislation_topics)
       ORDER BY l.introduced_date DESC",
      on: connection,
      with: [],
      expecting: {
        use id <- decode.field(0, decode.string)
        use title <- decode.field(1, decode.string)
        use summary <- decode.field(2, decode.string)
        decode.success(#(id, title, summary))
      },
    ),
  )

  use tagged_count <- result.try(
    list.try_fold(untagged, 0, fn(accumulated_count, record) {
      let #(legislation_id, title, summary) = record
      use assigned <- result.try(auto_tag_legislation(
        connection,
        legislation_id,
        title,
        summary,
      ))
      case assigned {
        [] -> Ok(accumulated_count)
        _ -> Ok(accumulated_count + 1)
      }
    }),
  )

  Ok(tagged_count)
}

/// Backfill topic assignments from the JSON topics column on legislation.
/// Matches JSON topic strings against taxonomy names, slugs, and keywords.
/// Returns the count of assignments created.
pub fn backfill_from_json_topics(
  connection: sqlight.Connection,
) -> Result(Int, sqlight.Error) {
  // Get all legislation with their JSON topics
  use legislation_with_topics <- result.try(
    sqlight.query(
      "SELECT l.id, je.value
       FROM legislation l, json_each(l.topics) je
       WHERE je.value != ''",
      on: connection,
      with: [],
      expecting: {
        use legislation_id <- decode.field(0, decode.string)
        use topic_value <- decode.field(1, decode.string)
        decode.success(#(legislation_id, topic_value))
      },
    ),
  )

  // Get all topics for matching
  use all_topics <- result.try(topic_repo.list_parent_topics(connection))
  use child_topic_lists <- result.try(
    list.try_map(all_topics, fn(parent: topic.Topic) {
      topic_repo.list_children(connection, parent.id)
    }),
  )
  let all_child_topics = list.flatten(child_topic_lists)
  let all_available_topics = list.append(all_topics, all_child_topics)

  // Match each JSON topic value against taxonomy
  use assignment_count <- result.try(
    list.try_fold(legislation_with_topics, 0, fn(accumulated_count, entry) {
      let #(legislation_id, topic_value) = entry
      let lowercase_value = string.lowercase(topic_value)

      // Try to find a matching taxonomy topic by name or slug
      let matched_topic =
        list.find(all_available_topics, fn(candidate) {
          string.lowercase(candidate.name) == lowercase_value
          || candidate.slug == lowercase_value
        })

      case matched_topic {
        Ok(found_topic) -> {
          use _ <- result.try(topic_repo.assign_legislation_topic(
            connection,
            legislation_id,
            found_topic.id,
            topic.Ingestion,
          ))
          Ok(accumulated_count + 1)
        }
        Error(_) -> Ok(accumulated_count)
      }
    }),
  )

  Ok(assignment_count)
}
