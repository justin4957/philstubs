import gleam/float
import gleam/list
import gleam/set
import gleeunit/should
import philstubs/core/similarity.{Added, Removed, Same}

// --- normalize_text tests ---

pub fn normalize_text_lowercases_and_strips_punctuation_test() {
  similarity.normalize_text("Hello, World! This is a TEST.")
  |> should.equal("hello world this is a test")
}

pub fn normalize_text_collapses_whitespace_test() {
  similarity.normalize_text("  too   many    spaces   ")
  |> should.equal("too many spaces")
}

pub fn normalize_text_empty_string_test() {
  similarity.normalize_text("")
  |> should.equal("")
}

// --- word_ngrams tests ---

pub fn word_ngrams_trigrams_test() {
  let ngrams = similarity.word_ngrams("the quick brown fox jumps", 3)
  let expected =
    set.from_list([
      ["the", "quick", "brown"],
      ["quick", "brown", "fox"],
      ["brown", "fox", "jumps"],
    ])
  ngrams |> should.equal(expected)
}

pub fn word_ngrams_short_text_test() {
  let ngrams = similarity.word_ngrams("two words", 3)
  set.size(ngrams) |> should.equal(0)
}

pub fn word_ngrams_bigrams_test() {
  let ngrams = similarity.word_ngrams("an act to establish", 2)
  let expected =
    set.from_list([
      ["an", "act"],
      ["act", "to"],
      ["to", "establish"],
    ])
  ngrams |> should.equal(expected)
}

pub fn word_ngrams_exact_length_test() {
  let ngrams = similarity.word_ngrams("one two three", 3)
  let expected = set.from_list([["one", "two", "three"]])
  ngrams |> should.equal(expected)
}

// --- jaccard_similarity tests ---

pub fn jaccard_similarity_identical_sets_test() {
  let set_a = set.from_list([1, 2, 3])
  let set_b = set.from_list([1, 2, 3])
  similarity.jaccard_similarity(set_a, set_b)
  |> should.equal(1.0)
}

pub fn jaccard_similarity_disjoint_sets_test() {
  let set_a = set.from_list([1, 2, 3])
  let set_b = set.from_list([4, 5, 6])
  similarity.jaccard_similarity(set_a, set_b)
  |> should.equal(0.0)
}

pub fn jaccard_similarity_partial_overlap_test() {
  let set_a = set.from_list([1, 2, 3, 4])
  let set_b = set.from_list([3, 4, 5, 6])
  // intersection = {3, 4} size 2, union = {1,2,3,4,5,6} size 6
  let result = similarity.jaccard_similarity(set_a, set_b)
  let expected = 2.0 /. 6.0
  let assert True = float_close(result, expected, 0.001)
}

pub fn jaccard_similarity_empty_sets_test() {
  let set_a = set.new()
  let set_b = set.new()
  similarity.jaccard_similarity(set_a, set_b)
  |> should.equal(0.0)
}

// --- text_similarity tests ---

pub fn text_similarity_identical_test() {
  let text =
    "an act to establish standards for environmental protection and regulate emissions from industrial facilities"
  similarity.text_similarity(text, text)
  |> should.equal(1.0)
}

pub fn text_similarity_completely_different_test() {
  let text_a = "the quick brown fox jumps over the lazy dog"
  let text_b = "an act concerning water rights and agricultural irrigation"
  let result = similarity.text_similarity(text_a, text_b)
  let assert True = result <. 0.1
}

pub fn text_similarity_partial_match_test() {
  let text_a =
    "an act to establish standards for environmental protection and regulate emissions from industrial facilities"
  let text_b =
    "an act to establish standards for environmental protection and regulate emissions from industrial facilities in california"
  let result = similarity.text_similarity(text_a, text_b)
  // Very similar, score should be high but below 1.0
  let assert True = result >. 0.7
  let assert True = result <. 1.0
}

// --- title_similarity tests ---

pub fn title_similarity_test() {
  let title_a = "clean air standards act"
  let title_b = "clean air standards act of california"
  let result = similarity.title_similarity(title_a, title_b)
  let assert True = result >. 0.5
}

pub fn title_similarity_different_test() {
  let title_a = "clean air standards act"
  let title_b = "water rights amendment"
  let result = similarity.title_similarity(title_a, title_b)
  let assert True = result <. 0.3
}

// --- topic_overlap tests ---

pub fn topic_overlap_identical_test() {
  similarity.topic_overlap(["environment", "air quality"], [
    "environment",
    "air quality",
  ])
  |> should.equal(1.0)
}

pub fn topic_overlap_partial_test() {
  let result =
    similarity.topic_overlap(["environment", "air quality", "climate"], [
      "environment",
      "water",
    ])
  // intersection = {"environment"} = 1, union = {"environment", "air quality", "climate", "water"} = 4
  let expected = 1.0 /. 4.0
  let assert True = float_close(result, expected, 0.001)
}

pub fn topic_overlap_empty_test() {
  similarity.topic_overlap([], [])
  |> should.equal(0.0)
}

pub fn topic_overlap_case_insensitive_test() {
  similarity.topic_overlap(["Environment"], ["environment"])
  |> should.equal(1.0)
}

// --- combined_similarity tests ---

pub fn combined_similarity_weights_test() {
  // Use identical texts to verify weighting
  let body = "an act to establish standards for environmental protection"
  let title = "clean air act"
  let topics = ["environment"]

  let result =
    similarity.combined_similarity(body, body, title, title, topics, topics)
  // All scores should be 1.0, combined = 0.7 + 0.2 + 0.1 = 1.0
  let assert True = float_close(result, 1.0, 0.001)
}

pub fn combined_similarity_zero_test() {
  let result =
    similarity.combined_similarity(
      "alpha beta gamma delta epsilon",
      "one two three four five",
      "first title here",
      "second title here",
      ["topic_a"],
      ["topic_b"],
    )
  // Should be very low since texts are completely different
  let assert True = result <. 0.3
}

// --- compute_diff tests ---

pub fn compute_diff_identical_test() {
  let text = "line one\nline two\nline three"
  let hunks = similarity.compute_diff(text, text)
  let all_same =
    list.all(hunks, fn(hunk) {
      case hunk {
        Same(_) -> True
        _ -> False
      }
    })
  all_same |> should.be_true
  list.length(hunks) |> should.equal(3)
}

pub fn compute_diff_completely_different_test() {
  let text_a = "line one\nline two"
  let text_b = "entirely different\nalso new"
  let hunks = similarity.compute_diff(text_a, text_b)

  // Should have Removed and Added hunks only
  let has_removed =
    list.any(hunks, fn(hunk) {
      case hunk {
        Removed(_) -> True
        _ -> False
      }
    })
  let has_added =
    list.any(hunks, fn(hunk) {
      case hunk {
        Added(_) -> True
        _ -> False
      }
    })
  has_removed |> should.be_true
  has_added |> should.be_true
}

pub fn compute_diff_mixed_test() {
  let text_a = "line one\nline two\nline three"
  let text_b = "line one\nline modified\nline three"
  let hunks = similarity.compute_diff(text_a, text_b)

  // Should contain Same("line one"), some change for "line two"/"line modified", Same("line three")
  let has_same =
    list.any(hunks, fn(hunk) {
      case hunk {
        Same("line one") -> True
        _ -> False
      }
    })
  has_same |> should.be_true

  let has_same_three =
    list.any(hunks, fn(hunk) {
      case hunk {
        Same("line three") -> True
        _ -> False
      }
    })
  has_same_three |> should.be_true
}

pub fn compute_diff_empty_texts_test() {
  let hunks = similarity.compute_diff("", "")
  // Empty string split by "\n" gives one empty line
  list.length(hunks) |> should.equal(1)
}

// --- format_as_percentage tests ---

pub fn format_as_percentage_test() {
  similarity.format_as_percentage(0.87) |> should.equal("87%")
  similarity.format_as_percentage(1.0) |> should.equal("100%")
  similarity.format_as_percentage(0.0) |> should.equal("0%")
}

// --- Helper ---

fn float_close(actual: Float, expected: Float, tolerance: Float) -> Bool {
  let difference = float.absolute_value(actual -. expected)
  difference <. tolerance
}
