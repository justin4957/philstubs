import gleam/list
import gleeunit/should
import philstubs/core/auto_tagger
import philstubs/core/topic

fn sample_rules() -> List(auto_tagger.TopicKeywordRule) {
  [
    auto_tagger.TopicKeywordRule(topic_id: topic.topic_id("housing"), keywords: [
      "housing",
      "rent",
      "affordable",
    ]),
    auto_tagger.TopicKeywordRule(
      topic_id: topic.topic_id("environment"),
      keywords: ["environment", "climate", "emissions"],
    ),
    auto_tagger.TopicKeywordRule(
      topic_id: topic.topic_id("healthcare"),
      keywords: ["health", "medical", "hospital"],
    ),
  ]
}

pub fn find_matching_topics_title_match_test() {
  let matches =
    auto_tagger.find_matching_topics(
      "Affordable Housing Act",
      "A bill about other things",
      sample_rules(),
    )

  // Should match "housing" and "affordable" in title
  let housing_matches =
    list.filter(matches, fn(match) {
      topic.topic_id_to_string(match.topic_id) == "housing"
    })
  housing_matches |> list.length |> should.equal(2)
}

pub fn find_matching_topics_summary_match_test() {
  let matches =
    auto_tagger.find_matching_topics(
      "Senate Bill 42",
      "This bill addresses climate emissions",
      sample_rules(),
    )

  let environment_matches =
    list.filter(matches, fn(match) {
      topic.topic_id_to_string(match.topic_id) == "environment"
    })
  environment_matches |> list.length |> should.equal(2)

  // All should be InSummary
  list.each(environment_matches, fn(match) {
    match.match_source |> should.equal(auto_tagger.InSummary)
  })
}

pub fn find_matching_topics_case_insensitive_test() {
  let matches =
    auto_tagger.find_matching_topics("HOUSING Reform Act", "", sample_rules())

  let housing_matches =
    list.filter(matches, fn(match) {
      topic.topic_id_to_string(match.topic_id) == "housing"
    })
  housing_matches |> list.length |> should.equal(1)
}

pub fn find_matching_topics_no_match_test() {
  let matches =
    auto_tagger.find_matching_topics(
      "Tax Reform Act",
      "Revenue and fiscal policy",
      sample_rules(),
    )

  matches |> list.length |> should.equal(0)
}

pub fn find_matching_topics_multi_topic_test() {
  let matches =
    auto_tagger.find_matching_topics(
      "Affordable Housing and Health Act",
      "",
      sample_rules(),
    )

  let topic_ids =
    list.map(matches, fn(match) { topic.topic_id_to_string(match.topic_id) })

  topic_ids |> list.contains("housing") |> should.be_true
  topic_ids |> list.contains("healthcare") |> should.be_true
}

pub fn find_matching_topics_in_both_test() {
  let matches =
    auto_tagger.find_matching_topics(
      "Housing Reform",
      "Addresses housing and rent",
      sample_rules(),
    )

  let housing_both =
    list.find(matches, fn(match) {
      topic.topic_id_to_string(match.topic_id) == "housing"
      && match.match_source == auto_tagger.InBoth
    })
  housing_both |> should.be_ok
}

pub fn deduplicate_matches_prefers_in_both_test() {
  let matches = [
    auto_tagger.TagMatch(
      topic_id: topic.topic_id("housing"),
      matched_keyword: "housing",
      match_source: auto_tagger.InTitle,
    ),
    auto_tagger.TagMatch(
      topic_id: topic.topic_id("housing"),
      matched_keyword: "rent",
      match_source: auto_tagger.InBoth,
    ),
    auto_tagger.TagMatch(
      topic_id: topic.topic_id("environment"),
      matched_keyword: "climate",
      match_source: auto_tagger.InSummary,
    ),
  ]

  let deduped = auto_tagger.deduplicate_matches(matches)
  deduped |> list.length |> should.equal(2)

  let housing_match =
    list.find(deduped, fn(match) {
      topic.topic_id_to_string(match.topic_id) == "housing"
    })
  let assert Ok(found_match) = housing_match
  found_match.match_source |> should.equal(auto_tagger.InBoth)
}
