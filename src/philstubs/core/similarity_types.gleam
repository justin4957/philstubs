import gleam/json
import philstubs/core/government_level
import philstubs/core/legislation.{type Legislation}

/// Method used to compute similarity between legislation.
pub type SimilarityMethod {
  NGramJaccard
}

/// A legislation record with similarity scores relative to a source.
pub type SimilarLegislation {
  SimilarLegislation(
    legislation: Legislation,
    similarity_score: Float,
    title_score: Float,
    body_score: Float,
    topic_score: Float,
  )
}

/// A legislation record matching a template with scores.
pub type TemplateMatch {
  TemplateMatch(
    legislation: Legislation,
    similarity_score: Float,
    title_score: Float,
    body_score: Float,
    topic_score: Float,
  )
}

/// A point in an adoption timeline showing when similar legislation appeared.
pub type AdoptionEvent {
  AdoptionEvent(
    legislation_id: String,
    title: String,
    level: government_level.GovernmentLevel,
    introduced_date: String,
    similarity_score: Float,
  )
}

/// Encode a SimilarLegislation to JSON.
pub fn similar_legislation_to_json(similar: SimilarLegislation) -> json.Json {
  json.object([
    #("legislation", legislation.to_json(similar.legislation)),
    #("similarity_score", json.float(similar.similarity_score)),
    #("title_score", json.float(similar.title_score)),
    #("body_score", json.float(similar.body_score)),
    #("topic_score", json.float(similar.topic_score)),
  ])
}

/// Encode a TemplateMatch to JSON.
pub fn template_match_to_json(match: TemplateMatch) -> json.Json {
  json.object([
    #("legislation", legislation.to_json(match.legislation)),
    #("similarity_score", json.float(match.similarity_score)),
    #("title_score", json.float(match.title_score)),
    #("body_score", json.float(match.body_score)),
    #("topic_score", json.float(match.topic_score)),
  ])
}

/// Encode an AdoptionEvent to JSON.
pub fn adoption_event_to_json(event: AdoptionEvent) -> json.Json {
  json.object([
    #("legislation_id", json.string(event.legislation_id)),
    #("title", json.string(event.title)),
    #("level", government_level.to_json(event.level)),
    #("introduced_date", json.string(event.introduced_date)),
    #("similarity_score", json.float(event.similarity_score)),
  ])
}

/// Convert a SimilarityMethod to its database string.
pub fn method_to_string(method: SimilarityMethod) -> String {
  case method {
    NGramJaccard -> "ngram_jaccard"
  }
}
