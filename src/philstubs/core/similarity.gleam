import gleam/float
import gleam/int
import gleam/list
import gleam/set.{type Set}
import gleam/string

/// A hunk in a line-based diff between two texts.
pub type DiffHunk {
  Same(text: String)
  Added(text: String)
  Removed(text: String)
}

/// Normalize text for comparison: lowercase, strip punctuation, collapse whitespace.
pub fn normalize_text(text: String) -> String {
  text
  |> string.lowercase
  |> string.to_graphemes
  |> list.map(fn(grapheme) {
    case is_alphanumeric_or_space(grapheme) {
      True -> grapheme
      False -> " "
    }
  })
  |> string.join("")
  |> collapse_whitespace
  |> string.trim
}

/// Extract word-level n-grams from text after normalization.
/// Returns a set of n-gram word lists (e.g., trigrams as List(String) of length 3).
pub fn word_ngrams(text: String, n: Int) -> Set(List(String)) {
  let normalized_text = normalize_text(text)
  let words =
    string.split(normalized_text, " ")
    |> list.filter(fn(word) { word != "" })

  case list.length(words) < n {
    True -> set.new()
    False -> sliding_window(words, n, set.new())
  }
}

/// Jaccard similarity between two sets: |A intersection B| / |A union B|.
/// Returns 0.0 when both sets are empty, otherwise 0.0-1.0.
pub fn jaccard_similarity(set_a: Set(a), set_b: Set(a)) -> Float {
  let intersection_size = set.size(set.intersection(set_a, set_b))
  let union_size = set.size(set.union(set_a, set_b))

  case union_size {
    0 -> 0.0
    _ -> int.to_float(intersection_size) /. int.to_float(union_size)
  }
}

/// Compute text similarity between two strings using word trigrams (n=3).
pub fn text_similarity(text_a: String, text_b: String) -> Float {
  let ngrams_a = word_ngrams(text_a, 3)
  let ngrams_b = word_ngrams(text_b, 3)
  jaccard_similarity(ngrams_a, ngrams_b)
}

/// Compute title similarity using word bigrams (n=2) for shorter text.
pub fn title_similarity(title_a: String, title_b: String) -> Float {
  let ngrams_a = word_ngrams(title_a, 2)
  let ngrams_b = word_ngrams(title_b, 2)
  jaccard_similarity(ngrams_a, ngrams_b)
}

/// Topic overlap using Jaccard on topic sets.
pub fn topic_overlap(topics_a: List(String), topics_b: List(String)) -> Float {
  let set_a =
    list.map(topics_a, string.lowercase)
    |> set.from_list
  let set_b =
    list.map(topics_b, string.lowercase)
    |> set.from_list
  jaccard_similarity(set_a, set_b)
}

/// Combined weighted score: 0.7 * body_similarity + 0.2 * title_similarity + 0.1 * topic_overlap.
pub fn combined_similarity(
  body_a: String,
  body_b: String,
  title_a: String,
  title_b: String,
  topics_a: List(String),
  topics_b: List(String),
) -> Float {
  let body_score = text_similarity(body_a, body_b)
  let title_score = title_similarity(title_a, title_b)
  let topic_score = topic_overlap(topics_a, topics_b)

  0.7 *. body_score +. 0.2 *. title_score +. 0.1 *. topic_score
}

/// Simple line-based diff between two texts. Returns list of diff hunks.
/// Uses a basic longest-common-subsequence approach on lines.
pub fn compute_diff(text_a: String, text_b: String) -> List(DiffHunk) {
  let lines_a = string.split(text_a, "\n")
  let lines_b = string.split(text_b, "\n")

  let lcs_lines = lcs(lines_a, lines_b)
  build_diff_hunks(lines_a, lines_b, lcs_lines, [])
}

/// Format a Float as a percentage string (e.g., 0.87 -> "87%").
pub fn format_as_percentage(score: Float) -> String {
  let rounded = float.round(score *. 100.0)
  int.to_string(rounded) <> "%"
}

// --- Private helpers ---

fn is_alphanumeric_or_space(grapheme: String) -> Bool {
  case grapheme {
    " " -> True
    _ -> {
      case string.to_utf_codepoints(grapheme) {
        [codepoint] -> {
          let code = string.utf_codepoint_to_int(codepoint)
          // a-z, A-Z, 0-9
          { code >= 97 && code <= 122 }
          || { code >= 65 && code <= 90 }
          || { code >= 48 && code <= 57 }
        }
        _ -> False
      }
    }
  }
}

fn collapse_whitespace(text: String) -> String {
  collapse_whitespace_loop(string.to_graphemes(text), False, [])
  |> list.reverse
  |> string.join("")
}

fn collapse_whitespace_loop(
  graphemes: List(String),
  previous_was_space: Bool,
  accumulator: List(String),
) -> List(String) {
  case graphemes {
    [] -> accumulator
    [grapheme, ..rest] -> {
      case grapheme == " " {
        True ->
          case previous_was_space {
            True -> collapse_whitespace_loop(rest, True, accumulator)
            False -> collapse_whitespace_loop(rest, True, [" ", ..accumulator])
          }
        False ->
          collapse_whitespace_loop(rest, False, [grapheme, ..accumulator])
      }
    }
  }
}

fn sliding_window(
  words: List(String),
  window_size: Int,
  accumulator: Set(List(String)),
) -> Set(List(String)) {
  case list.length(words) < window_size {
    True -> accumulator
    False -> {
      let window = list.take(words, window_size)
      let remaining = list.drop(words, 1)
      sliding_window(remaining, window_size, set.insert(accumulator, window))
    }
  }
}

/// Compute the longest common subsequence of two lists.
/// Returns the LCS as a list of elements.
fn lcs(list_a: List(String), list_b: List(String)) -> List(String) {
  case list_a, list_b {
    [], _ | _, [] -> []
    [head_a, ..tail_a], [head_b, ..tail_b] -> {
      case head_a == head_b {
        True -> [head_a, ..lcs(tail_a, tail_b)]
        False -> {
          let lcs_skip_a = lcs(tail_a, list_b)
          let lcs_skip_b = lcs(list_a, tail_b)
          case list.length(lcs_skip_a) >= list.length(lcs_skip_b) {
            True -> lcs_skip_a
            False -> lcs_skip_b
          }
        }
      }
    }
  }
}

/// Build diff hunks by walking through both line lists and the LCS.
fn build_diff_hunks(
  lines_a: List(String),
  lines_b: List(String),
  lcs_lines: List(String),
  accumulator: List(DiffHunk),
) -> List(DiffHunk) {
  case lines_a, lines_b, lcs_lines {
    [], [], _ -> list.reverse(accumulator)
    [head_a, ..tail_a], _, [lcs_head, ..lcs_tail] if head_a == lcs_head -> {
      case lines_b {
        [head_b, ..tail_b] if head_b == lcs_head ->
          build_diff_hunks(tail_a, tail_b, lcs_tail, [
            Same(head_a),
            ..accumulator
          ])
        [head_b, ..tail_b] ->
          build_diff_hunks(lines_a, tail_b, lcs_lines, [
            Added(head_b),
            ..accumulator
          ])
        [] ->
          build_diff_hunks(tail_a, [], lcs_tail, [Same(head_a), ..accumulator])
      }
    }
    [head_a, ..tail_a], _, _ ->
      build_diff_hunks(tail_a, lines_b, lcs_lines, [
        Removed(head_a),
        ..accumulator
      ])
    [], [head_b, ..tail_b], _ ->
      build_diff_hunks([], tail_b, lcs_lines, [Added(head_b), ..accumulator])
  }
}
