import gleam/json
import gleam/option.{type Option, None, Some}

/// Opaque identifier for a saved exploration.
pub opaque type ExplorationId {
  ExplorationId(String)
}

/// Create an ExplorationId from a string value.
pub fn exploration_id(value: String) -> ExplorationId {
  ExplorationId(value)
}

/// Extract the underlying string from an ExplorationId.
pub fn exploration_id_to_string(identifier: ExplorationId) -> String {
  let ExplorationId(value) = identifier
  value
}

/// A saved exploration graph state, persisted server-side.
pub type SavedExploration {
  SavedExploration(
    id: ExplorationId,
    user_id: Option(String),
    title: String,
    description: String,
    graph_state: String,
    created_at: String,
    updated_at: String,
    is_public: Bool,
  )
}

/// Encode a SavedExploration to JSON for API responses.
pub fn to_json(exploration: SavedExploration) -> json.Json {
  json.object([
    #("id", json.string(exploration_id_to_string(exploration.id))),
    #("user_id", case exploration.user_id {
      Some(uid) -> json.string(uid)
      None -> json.null()
    }),
    #("title", json.string(exploration.title)),
    #("description", json.string(exploration.description)),
    #("graph_state", json.string(exploration.graph_state)),
    #("created_at", json.string(exploration.created_at)),
    #("updated_at", json.string(exploration.updated_at)),
    #("is_public", json.bool(exploration.is_public)),
  ])
}
