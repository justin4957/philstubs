import gleam/json
import gleam/option.{type Option}

/// Opaque identifier for a cross-reference. Wraps a string to prevent
/// accidental misuse of raw strings as reference IDs.
pub opaque type ReferenceId {
  ReferenceId(String)
}

/// Create a ReferenceId from a string value.
pub fn reference_id(value: String) -> ReferenceId {
  ReferenceId(value)
}

/// Extract the underlying string from a ReferenceId.
pub fn reference_id_to_string(identifier: ReferenceId) -> String {
  let ReferenceId(value) = identifier
  value
}

/// Opaque identifier for a query map. Wraps a string to prevent
/// accidental misuse of raw strings as query map IDs.
pub opaque type QueryMapId {
  QueryMapId(String)
}

/// Create a QueryMapId from a string value.
pub fn query_map_id(value: String) -> QueryMapId {
  QueryMapId(value)
}

/// Extract the underlying string from a QueryMapId.
pub fn query_map_id_to_string(identifier: QueryMapId) -> String {
  let QueryMapId(value) = identifier
  value
}

/// The relationship between source and target legislation.
pub type ReferenceType {
  References
  Amends
  Supersedes
  Implements
  Delegates
}

/// Convert a ReferenceType to its database string representation.
pub fn reference_type_to_string(reference_type: ReferenceType) -> String {
  case reference_type {
    References -> "references"
    Amends -> "amends"
    Supersedes -> "supersedes"
    Implements -> "implements"
    Delegates -> "delegates"
  }
}

/// Parse a database string into a ReferenceType.
pub fn reference_type_from_string(value: String) -> ReferenceType {
  case value {
    "amends" -> Amends
    "supersedes" -> Supersedes
    "implements" -> Implements
    "delegates" -> Delegates
    _ -> References
  }
}

/// Which extraction engine produced this reference.
pub type Extractor {
  GleamNative
  Regula
  Manual
}

/// Convert an Extractor to its database string representation.
pub fn extractor_to_string(extractor: Extractor) -> String {
  case extractor {
    GleamNative -> "gleam_native"
    Regula -> "regula"
    Manual -> "manual"
  }
}

/// Parse a database string into an Extractor.
pub fn extractor_from_string(value: String) -> Extractor {
  case value {
    "regula" -> Regula
    "manual" -> Manual
    _ -> GleamNative
  }
}

/// A cross-reference linking one piece of legislation to another.
pub type CrossReference {
  CrossReference(
    id: ReferenceId,
    source_legislation_id: String,
    target_legislation_id: Option(String),
    citation_text: String,
    reference_type: ReferenceType,
    confidence: Float,
    extractor: Extractor,
    extracted_at: String,
  )
}

/// A named, reusable query pattern for legislation cross-reference exploration.
pub type QueryMap {
  QueryMap(
    id: QueryMapId,
    name: String,
    description: String,
    query_template: String,
    parameters: String,
    created_at: String,
  )
}

/// Encode a CrossReference to JSON.
pub fn cross_reference_to_json(reference: CrossReference) -> json.Json {
  json.object([
    #("id", json.string(reference_id_to_string(reference.id))),
    #("source_legislation_id", json.string(reference.source_legislation_id)),
    #(
      "target_legislation_id",
      json.nullable(reference.target_legislation_id, json.string),
    ),
    #("citation_text", json.string(reference.citation_text)),
    #(
      "reference_type",
      json.string(reference_type_to_string(reference.reference_type)),
    ),
    #("confidence", json.float(reference.confidence)),
    #("extractor", json.string(extractor_to_string(reference.extractor))),
    #("extracted_at", json.string(reference.extracted_at)),
  ])
}

/// Encode a QueryMap to JSON.
pub fn query_map_to_json(query_map: QueryMap) -> json.Json {
  json.object([
    #("id", json.string(query_map_id_to_string(query_map.id))),
    #("name", json.string(query_map.name)),
    #("description", json.string(query_map.description)),
    #("query_template", json.string(query_map.query_template)),
    #("parameters", json.string(query_map.parameters)),
    #("created_at", json.string(query_map.created_at)),
  ])
}
