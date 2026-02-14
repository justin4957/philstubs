import gleam/float
import gleam/list
import gleam/order
import gleam/string
import philstubs/core/reference.{type ReferenceType}

/// The type of legal citation found in text.
pub type CitationType {
  UscReference
  PublicLawReference
  CfrReference
  BillReference
  SectionReference
}

/// Convert a CitationType to a display string.
pub fn citation_type_to_string(citation_type: CitationType) -> String {
  case citation_type {
    UscReference -> "usc"
    PublicLawReference -> "public_law"
    CfrReference -> "cfr"
    BillReference -> "bill"
    SectionReference -> "section"
  }
}

/// A citation extracted from legislation text.
pub type ExtractedCitation {
  ExtractedCitation(
    citation_text: String,
    citation_type: CitationType,
    reference_type: ReferenceType,
    confidence: Float,
  )
}

/// Extract all legal citations from the given text.
/// Uses substring scanning (no regex) following project conventions.
pub fn extract_citations(text: String) -> List(ExtractedCitation) {
  let lowercase_text = string.lowercase(text)

  [
    extract_usc_citations(lowercase_text, text),
    extract_public_law_citations(lowercase_text, text),
    extract_cfr_citations(lowercase_text, text),
    extract_bill_citations(lowercase_text, text),
    extract_section_citations(lowercase_text, text),
  ]
  |> list.flatten
  |> deduplicate_citations
}

/// Deduplicate citations by citation_text, keeping the one with highest confidence.
pub fn deduplicate_citations(
  citations: List(ExtractedCitation),
) -> List(ExtractedCitation) {
  list.fold(citations, [], fn(accumulated, citation: ExtractedCitation) {
    let normalized_text = string.lowercase(citation.citation_text)
    case
      list.find(accumulated, fn(existing: ExtractedCitation) {
        string.lowercase(existing.citation_text) == normalized_text
      })
    {
      Ok(existing) -> {
        case
          float.compare(citation.confidence, existing.confidence) == order.Gt
        {
          True ->
            list.map(accumulated, fn(item: ExtractedCitation) {
              case string.lowercase(item.citation_text) == normalized_text {
                True -> citation
                False -> item
              }
            })
          False -> accumulated
        }
      }
      Error(_) -> [citation, ..accumulated]
    }
  })
  |> list.reverse
}

/// Extract U.S. Code citations like "42 U.S.C. § 1983" or "26 u.s.c. 501".
fn extract_usc_citations(
  lowercase_text: String,
  _original_text: String,
) -> List(ExtractedCitation) {
  extract_marker_citations(lowercase_text, "u.s.c.", UscReference, 0.9)
}

/// Extract Public Law citations like "Pub. L. 117-169" or "Public Law 110-343".
fn extract_public_law_citations(
  lowercase_text: String,
  _original_text: String,
) -> List(ExtractedCitation) {
  let pub_l_citations =
    extract_marker_citations(lowercase_text, "pub. l.", PublicLawReference, 0.9)
  let public_law_citations =
    extract_marker_citations(
      lowercase_text,
      "public law",
      PublicLawReference,
      0.9,
    )
  list.append(pub_l_citations, public_law_citations)
}

/// Extract Code of Federal Regulations citations like "40 C.F.R. Part 98".
fn extract_cfr_citations(
  lowercase_text: String,
  _original_text: String,
) -> List(ExtractedCitation) {
  extract_marker_citations(lowercase_text, "c.f.r.", CfrReference, 0.9)
}

/// Extract bill reference citations like "H.R. 1234", "S. 567", "H.J.Res. 89".
fn extract_bill_citations(
  lowercase_text: String,
  _original_text: String,
) -> List(ExtractedCitation) {
  let bill_markers = [
    "h.r.",
    "s.",
    "h.j.res.",
    "s.j.res.",
    "h.con.res.",
    "s.con.res.",
    "h.res.",
    "s.res.",
  ]
  list.flat_map(bill_markers, fn(marker) {
    find_bill_references(lowercase_text, marker)
  })
}

/// Extract section references like "section 101 of" or "Section 501(c)(3)".
fn extract_section_citations(
  lowercase_text: String,
  _original_text: String,
) -> List(ExtractedCitation) {
  find_section_references(lowercase_text)
}

/// Find citations around a marker word in text.
/// Extracts surrounding context to build a meaningful citation string.
fn extract_marker_citations(
  lowercase_text: String,
  marker: String,
  citation_type: CitationType,
  base_confidence: Float,
) -> List(ExtractedCitation) {
  find_all_marker_positions(lowercase_text, marker, 0)
  |> list.filter_map(fn(position) {
    let citation_text =
      extract_citation_around_marker(lowercase_text, position, marker)
    case string.length(citation_text) > string.length(marker) {
      True -> {
        let surrounding_context =
          extract_surrounding_context(lowercase_text, position, 100)
        let inferred_reference_type = infer_reference_type(surrounding_context)
        Ok(ExtractedCitation(
          citation_text:,
          citation_type:,
          reference_type: inferred_reference_type,
          confidence: base_confidence,
        ))
      }
      False -> Error(Nil)
    }
  })
}

/// Find all positions of a marker in text.
fn find_all_marker_positions(
  text: String,
  marker: String,
  start_offset: Int,
) -> List(Int) {
  let remaining = string.drop_start(text, start_offset)
  case find_substring_position(remaining, marker) {
    Ok(relative_position) -> {
      let absolute_position = start_offset + relative_position
      let next_offset = absolute_position + string.length(marker)
      [
        absolute_position,
        ..find_all_marker_positions(text, marker, next_offset)
      ]
    }
    Error(_) -> []
  }
}

/// Find the position of a substring within text.
fn find_substring_position(text: String, substring: String) -> Result(Int, Nil) {
  find_substring_at(text, substring, 0)
}

/// Recursive helper to find substring position starting at an offset.
fn find_substring_at(
  text: String,
  substring: String,
  current_position: Int,
) -> Result(Int, Nil) {
  let substring_length = string.length(substring)
  let text_length = string.length(text)
  case current_position + substring_length > text_length {
    True -> Error(Nil)
    False -> {
      let slice = string.slice(text, current_position, substring_length)
      case slice == substring {
        True -> Ok(current_position)
        False -> find_substring_at(text, substring, current_position + 1)
      }
    }
  }
}

/// Extract a citation string from text around a marker position.
/// Looks backward for a preceding number and forward for following identifiers.
fn extract_citation_around_marker(
  text: String,
  marker_position: Int,
  marker: String,
) -> String {
  let preceding = extract_preceding_number(text, marker_position)
  let marker_end = marker_position + string.length(marker)
  let following = extract_following_identifier(text, marker_end)
  let citation_parts = case preceding, following {
    "", "" -> marker
    pre, "" -> pre <> " " <> marker
    "", fol -> marker <> " " <> fol
    pre, fol -> pre <> " " <> marker <> " " <> fol
  }
  string.trim(citation_parts)
}

/// Extract a number that precedes the marker (e.g., "42" in "42 U.S.C.").
fn extract_preceding_number(text: String, marker_position: Int) -> String {
  let before_marker = string.slice(text, 0, marker_position)
  let trimmed = string.trim_end(before_marker)
  extract_trailing_number(trimmed)
}

/// Extract trailing digits/hyphens from the end of a string.
fn extract_trailing_number(text: String) -> String {
  let graphemes = string.to_graphemes(text)
  let reversed = list.reverse(graphemes)
  let number_chars =
    list.take_while(reversed, fn(char) {
      is_digit(char) || char == "-" || char == "."
    })
  case number_chars {
    [] -> ""
    chars -> {
      let result = chars |> list.reverse |> string.join("")
      // Don't return strings that are just punctuation
      case string.trim(result) {
        "" -> ""
        trimmed -> {
          case is_digit(string.slice(trimmed, 0, 1)) {
            True -> trimmed
            False -> ""
          }
        }
      }
    }
  }
}

/// Extract an identifier following the marker (section numbers, part numbers, etc.).
fn extract_following_identifier(text: String, start: Int) -> String {
  let after_marker = string.drop_start(text, start)
  let trimmed = string.trim_start(after_marker)
  // Skip section symbol if present
  let cleaned = case string.starts_with(trimmed, "§") {
    True -> string.trim_start(string.drop_start(trimmed, 1))
    False -> trimmed
  }
  extract_leading_identifier(cleaned)
}

/// Extract leading digits, hyphens, dots, and parenthesized parts.
fn extract_leading_identifier(text: String) -> String {
  let graphemes = string.to_graphemes(text)
  extract_identifier_chars(graphemes, [])
  |> list.reverse
  |> string.join("")
  |> string.trim_end
}

/// Recursively collect identifier characters.
fn extract_identifier_chars(
  remaining: List(String),
  accumulated: List(String),
) -> List(String) {
  case remaining {
    [] -> accumulated
    [char, ..rest] -> {
      case
        is_digit(char)
        || char == "-"
        || char == "."
        || char == "("
        || char == ")"
      {
        True -> extract_identifier_chars(rest, [char, ..accumulated])
        False -> {
          // Allow single letters after numbers for subsections like "501(c)(3)"
          case is_lowercase_letter(char) {
            True -> {
              case accumulated {
                ["(", ..] ->
                  extract_identifier_chars(rest, [char, ..accumulated])
                [")", ..] | [_, ..] -> {
                  case rest {
                    ["(", ..] ->
                      extract_identifier_chars(rest, [char, ..accumulated])
                    _ -> accumulated
                  }
                }
                _ -> accumulated
              }
            }
            False -> accumulated
          }
        }
      }
    }
  }
}

/// Find bill references like "H.R. 1234" or "S. 567".
fn find_bill_references(text: String, marker: String) -> List(ExtractedCitation) {
  find_all_marker_positions(text, marker, 0)
  |> list.filter_map(fn(position) {
    let marker_end = position + string.length(marker)
    let following = extract_following_identifier(text, marker_end)
    // Only valid if there's a number after the marker
    case has_digit(following) {
      True -> {
        let citation_text = string.trim(marker <> " " <> following)
        let surrounding_context =
          extract_surrounding_context(text, position, 100)
        let inferred_reference_type = infer_reference_type(surrounding_context)
        Ok(ExtractedCitation(
          citation_text:,
          citation_type: BillReference,
          reference_type: inferred_reference_type,
          confidence: 0.8,
        ))
      }
      False -> Error(Nil)
    }
  })
}

/// Find section references like "section 101 of" or "Section 501(c)(3)".
fn find_section_references(text: String) -> List(ExtractedCitation) {
  find_all_marker_positions(text, "section ", 0)
  |> list.filter_map(fn(position) {
    let marker_end = position + string.length("section ")
    let following = extract_following_identifier(text, marker_end)
    case has_digit(following) {
      True -> {
        let citation_text = string.trim("section " <> following)
        let surrounding_context =
          extract_surrounding_context(text, position, 100)
        let inferred_reference_type = infer_reference_type(surrounding_context)
        Ok(ExtractedCitation(
          citation_text:,
          citation_type: SectionReference,
          reference_type: inferred_reference_type,
          confidence: 0.6,
        ))
      }
      False -> Error(Nil)
    }
  })
}

/// Infer the reference type from surrounding context keywords.
pub fn infer_reference_type(context: String) -> ReferenceType {
  let lowercase_context = string.lowercase(context)
  infer_from_keywords(lowercase_context, [
    #("amend", reference.Amends),
    #("repeal", reference.Supersedes),
    #("supersede", reference.Supersedes),
    #("implement", reference.Implements),
    #("pursuant to", reference.Implements),
    #("delegat", reference.Delegates),
  ])
}

/// Check keywords in order, returning the first matching reference type.
fn infer_from_keywords(
  context: String,
  keyword_pairs: List(#(String, ReferenceType)),
) -> ReferenceType {
  case keyword_pairs {
    [] -> reference.References
    [#(keyword, ref_type), ..rest] -> {
      case string.contains(context, keyword) {
        True -> ref_type
        False -> infer_from_keywords(context, rest)
      }
    }
  }
}

/// Extract surrounding text for context analysis.
fn extract_surrounding_context(
  text: String,
  position: Int,
  context_size: Int,
) -> String {
  let start = case position > context_size {
    True -> position - context_size
    False -> 0
  }
  let text_length = string.length(text)
  let end_position = position + context_size
  let length = case end_position > text_length {
    True -> text_length - start
    False -> end_position - start
  }
  string.slice(text, start, length)
}

/// Check if a character is a digit.
fn is_digit(char: String) -> Bool {
  case char {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

/// Check if a character is a lowercase letter.
fn is_lowercase_letter(char: String) -> Bool {
  case char {
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z" -> True
    _ -> False
  }
}

/// Check if a string contains at least one digit.
fn has_digit(text: String) -> Bool {
  string.to_graphemes(text)
  |> list.any(is_digit)
}
