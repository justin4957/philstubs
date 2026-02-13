import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import philstubs/core/government_level.{type GovernmentLevel}
import philstubs/core/legislation_type.{type LegislationType}

/// Opaque identifier for a legislation template.
pub opaque type TemplateId {
  TemplateId(String)
}

/// Create a TemplateId from a string value.
pub fn template_id(value: String) -> TemplateId {
  TemplateId(value)
}

/// Extract the underlying string from a TemplateId.
pub fn template_id_to_string(identifier: TemplateId) -> String {
  let TemplateId(value) = identifier
  value
}

/// A model/template piece of legislation that users can upload, search,
/// and download. Templates suggest a government level and type but can
/// be adapted to any jurisdiction.
pub type LegislationTemplate {
  LegislationTemplate(
    id: TemplateId,
    title: String,
    description: String,
    body: String,
    suggested_level: GovernmentLevel,
    suggested_type: LegislationType,
    author: String,
    topics: List(String),
    created_at: String,
    download_count: Int,
    owner_user_id: Option(String),
  )
}

/// Encode a LegislationTemplate record to JSON.
pub fn to_json(template: LegislationTemplate) -> json.Json {
  json.object([
    #("id", json.string(template_id_to_string(template.id))),
    #("title", json.string(template.title)),
    #("description", json.string(template.description)),
    #("body", json.string(template.body)),
    #("suggested_level", government_level.to_json(template.suggested_level)),
    #("suggested_type", legislation_type.to_json(template.suggested_type)),
    #("author", json.string(template.author)),
    #("topics", json.array(template.topics, json.string)),
    #("created_at", json.string(template.created_at)),
    #("download_count", json.int(template.download_count)),
    #("owner_user_id", case template.owner_user_id {
      Some(owner_id) -> json.string(owner_id)
      None -> json.null()
    }),
  ])
}

/// Decode a LegislationTemplate record from JSON.
pub fn decoder() -> decode.Decoder(LegislationTemplate) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use body <- decode.field("body", decode.string)
  use suggested_level <- decode.field(
    "suggested_level",
    government_level.decoder(),
  )
  use suggested_type <- decode.field(
    "suggested_type",
    legislation_type.decoder(),
  )
  use author <- decode.field("author", decode.string)
  use topics <- decode.field("topics", decode.list(decode.string))
  use created_at <- decode.field("created_at", decode.string)
  use download_count <- decode.field("download_count", decode.int)
  use owner_user_id <- decode.field(
    "owner_user_id",
    decode.optional(decode.string),
  )
  decode.success(LegislationTemplate(
    id: template_id(id),
    title:,
    description:,
    body:,
    suggested_level:,
    suggested_type:,
    author:,
    topics:,
    created_at:,
    download_count:,
    owner_user_id:,
  ))
}

/// Encode a TemplateId to JSON (as a string).
pub fn template_id_to_json(identifier: TemplateId) -> json.Json {
  json.string(template_id_to_string(identifier))
}

/// Decode a TemplateId from a JSON string.
pub fn template_id_decoder() -> decode.Decoder(TemplateId) {
  use value <- decode.then(decode.string)
  decode.success(template_id(value))
}
