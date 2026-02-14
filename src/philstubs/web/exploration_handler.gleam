import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import philstubs/core/saved_exploration.{SavedExploration}
import philstubs/core/user
import philstubs/data/exploration_repo
import philstubs/web/api_error
import sqlight
import wisp.{type Request, type Response}

/// Decoded exploration creation/update request body.
type ExplorationRequest {
  ExplorationRequest(
    title: String,
    description: String,
    graph_state: String,
    is_public: Bool,
  )
}

/// Handle POST /api/explorations — create a saved exploration.
pub fn handle_create(
  request: Request,
  db_connection: sqlight.Connection,
  current_user_id: String,
) -> Response {
  use json_body <- wisp.require_json(request)

  case decode_exploration_request(json_body) {
    Error(validation_message) -> api_error.validation_error(validation_message)
    Ok(exploration_request) -> {
      let exploration_id = "expl-" <> wisp.random_string(16)
      let exploration =
        SavedExploration(
          id: saved_exploration.exploration_id(exploration_id),
          user_id: Some(current_user_id),
          title: exploration_request.title,
          description: exploration_request.description,
          graph_state: exploration_request.graph_state,
          created_at: "",
          updated_at: "",
          is_public: exploration_request.is_public,
        )

      case exploration_repo.insert(db_connection, exploration) {
        Ok(_) ->
          saved_exploration.to_json(exploration)
          |> json.to_string
          |> wisp.json_response(201)
        Error(_) -> api_error.internal_error()
      }
    }
  }
}

/// Handle GET /api/explorations — list explorations.
/// Authenticated users see their own; ?public=true shows public only.
pub fn handle_list(
  request: Request,
  db_connection: sqlight.Connection,
  current_user: Option(user.User),
) -> Response {
  let query_params = wisp.get_query(request)
  let public_only =
    list.key_find(query_params, "public")
    |> fn(result) {
      case result {
        Ok("true") -> True
        _ -> False
      }
    }

  let explorations_result = case public_only {
    True -> exploration_repo.list_public(db_connection)
    False ->
      case current_user {
        Some(authenticated_user) ->
          exploration_repo.list_by_user(
            db_connection,
            user.user_id_to_string(authenticated_user.id),
          )
        None -> exploration_repo.list_public(db_connection)
      }
  }

  case explorations_result {
    Ok(explorations) -> {
      let exploration_json_items =
        list.map(explorations, saved_exploration.to_json)
      json.object([
        #("explorations", json.preprocessed_array(exploration_json_items)),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> api_error.internal_error()
  }
}

/// Handle GET /api/explorations/:id — get a single exploration.
/// Public explorations are visible to anyone; private ones require ownership.
pub fn handle_get(
  exploration_id: String,
  db_connection: sqlight.Connection,
  current_user: Option(user.User),
) -> Response {
  case exploration_repo.get_by_id(db_connection, exploration_id) {
    Ok(Some(exploration)) -> {
      case exploration.is_public {
        True ->
          saved_exploration.to_json(exploration)
          |> json.to_string
          |> wisp.json_response(200)
        False -> {
          let is_owner = case current_user, exploration.user_id {
            Some(authenticated_user), Some(owner_id) ->
              user.user_id_to_string(authenticated_user.id) == owner_id
            _, _ -> False
          }
          case is_owner {
            True ->
              saved_exploration.to_json(exploration)
              |> json.to_string
              |> wisp.json_response(200)
            False -> api_error.forbidden()
          }
        }
      }
    }
    Ok(None) -> api_error.not_found("Exploration")
    Error(_) -> api_error.internal_error()
  }
}

/// Handle PUT /api/explorations/:id — update an exploration (owner only).
pub fn handle_update(
  request: Request,
  exploration_id: String,
  db_connection: sqlight.Connection,
  current_user_id: String,
) -> Response {
  case exploration_repo.get_by_id(db_connection, exploration_id) {
    Ok(Some(existing_exploration)) -> {
      case existing_exploration.user_id {
        Some(owner_id) if owner_id == current_user_id -> {
          use json_body <- wisp.require_json(request)
          case decode_exploration_request(json_body) {
            Error(validation_message) ->
              api_error.validation_error(validation_message)
            Ok(exploration_request) -> {
              let updated_exploration =
                SavedExploration(
                  ..existing_exploration,
                  title: exploration_request.title,
                  description: exploration_request.description,
                  graph_state: exploration_request.graph_state,
                  is_public: exploration_request.is_public,
                )
              case exploration_repo.update(db_connection, updated_exploration) {
                Ok(_) ->
                  saved_exploration.to_json(updated_exploration)
                  |> json.to_string
                  |> wisp.json_response(200)
                Error(_) -> api_error.internal_error()
              }
            }
          }
        }
        _ -> api_error.forbidden()
      }
    }
    Ok(None) -> api_error.not_found("Exploration")
    Error(_) -> api_error.internal_error()
  }
}

/// Handle DELETE /api/explorations/:id — delete an exploration (owner only).
pub fn handle_delete(
  exploration_id: String,
  db_connection: sqlight.Connection,
  current_user_id: String,
) -> Response {
  case exploration_repo.get_by_id(db_connection, exploration_id) {
    Ok(Some(existing_exploration)) -> {
      case existing_exploration.user_id {
        Some(owner_id) if owner_id == current_user_id -> {
          case exploration_repo.delete(db_connection, exploration_id) {
            Ok(_) -> wisp.response(204)
            Error(_) -> api_error.internal_error()
          }
        }
        _ -> api_error.forbidden()
      }
    }
    Ok(None) -> api_error.not_found("Exploration")
    Error(_) -> api_error.internal_error()
  }
}

// --- Request decoder ---

fn decode_exploration_request(
  json_body: Dynamic,
) -> Result(ExplorationRequest, String) {
  let exploration_decoder = {
    use title <- decode.field("title", decode.string)
    use description <- decode.optional_field("description", "", decode.string)
    use graph_state <- decode.field("graph_state", decode.string)
    use is_public <- decode.optional_field("is_public", False, decode.bool)
    decode.success(ExplorationRequest(
      title:,
      description:,
      graph_state:,
      is_public:,
    ))
  }

  case decode.run(json_body, exploration_decoder) {
    Ok(exploration_request) -> validate_exploration_request(exploration_request)
    Error(_) ->
      Error("Invalid request body. Required fields: title, graph_state")
  }
}

fn validate_exploration_request(
  exploration_request: ExplorationRequest,
) -> Result(ExplorationRequest, String) {
  case
    string.trim(exploration_request.title),
    string.trim(exploration_request.graph_state)
  {
    "", _ -> Error("title is required and cannot be empty")
    _, "" -> Error("graph_state is required and cannot be empty")
    _, _ -> Ok(exploration_request)
  }
}
