import gleam/list
import gleam/string
import philstubs/core/topic

/// Where a keyword match was found.
pub type MatchSource {
  InTitle
  InSummary
  InBoth
}

/// A keyword rule mapping a topic to its associated keywords.
pub type TopicKeywordRule {
  TopicKeywordRule(topic_id: topic.TopicId, keywords: List(String))
}

/// A match result indicating which topic matched and where.
pub type TagMatch {
  TagMatch(
    topic_id: topic.TopicId,
    matched_keyword: String,
    match_source: MatchSource,
  )
}

/// Find all topics whose keywords appear in the title or summary.
/// Uses case-insensitive substring matching.
pub fn find_matching_topics(
  title: String,
  summary: String,
  keyword_rules: List(TopicKeywordRule),
) -> List(TagMatch) {
  let lowercase_title = string.lowercase(title)
  let lowercase_summary = string.lowercase(summary)

  list.flat_map(keyword_rules, fn(rule) {
    list.filter_map(rule.keywords, fn(keyword) {
      let lowercase_keyword = string.lowercase(keyword)
      let in_title = string.contains(lowercase_title, lowercase_keyword)
      let in_summary = string.contains(lowercase_summary, lowercase_keyword)

      case in_title, in_summary {
        True, True ->
          Ok(TagMatch(
            topic_id: rule.topic_id,
            matched_keyword: keyword,
            match_source: InBoth,
          ))
        True, False ->
          Ok(TagMatch(
            topic_id: rule.topic_id,
            matched_keyword: keyword,
            match_source: InTitle,
          ))
        False, True ->
          Ok(TagMatch(
            topic_id: rule.topic_id,
            matched_keyword: keyword,
            match_source: InSummary,
          ))
        False, False -> Error(Nil)
      }
    })
  })
}

/// Deduplicate matches so each topic appears at most once.
/// Prefers InBoth > InTitle > InSummary when the same topic matches
/// multiple keywords.
pub fn deduplicate_matches(matches: List(TagMatch)) -> List(TagMatch) {
  list.fold(matches, [], fn(accumulated: List(TagMatch), match: TagMatch) {
    let topic_id_str = topic.topic_id_to_string(match.topic_id)
    case
      list.find(accumulated, fn(existing: TagMatch) {
        topic.topic_id_to_string(existing.topic_id) == topic_id_str
      })
    {
      Ok(existing_match) -> {
        case should_replace(existing_match.match_source, match.match_source) {
          True ->
            list.map(accumulated, fn(item: TagMatch) {
              case topic.topic_id_to_string(item.topic_id) == topic_id_str {
                True -> match
                False -> item
              }
            })
          False -> accumulated
        }
      }
      Error(_) -> [match, ..accumulated]
    }
  })
  |> list.reverse
}

/// Determine if a new match source should replace an existing one.
fn should_replace(existing: MatchSource, candidate: MatchSource) -> Bool {
  case existing, candidate {
    InBoth, _ -> False
    InTitle, InBoth -> True
    InTitle, _ -> False
    InSummary, InBoth -> True
    InSummary, InTitle -> True
    InSummary, InSummary -> False
  }
}
