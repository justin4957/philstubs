import gleam/json

/// Opaque identifier for a user.
pub opaque type UserId {
  UserId(String)
}

/// Create a UserId from a string value.
pub fn user_id(value: String) -> UserId {
  UserId(value)
}

/// Extract the underlying string from a UserId.
pub fn user_id_to_string(identifier: UserId) -> String {
  let UserId(value) = identifier
  value
}

/// A user account authenticated via GitHub OAuth.
pub type User {
  User(
    id: UserId,
    github_id: Int,
    username: String,
    display_name: String,
    avatar_url: String,
    created_at: String,
  )
}

/// Encode a User record to JSON.
pub fn to_json(user: User) -> json.Json {
  json.object([
    #("id", json.string(user_id_to_string(user.id))),
    #("github_id", json.int(user.github_id)),
    #("username", json.string(user.username)),
    #("display_name", json.string(user.display_name)),
    #("avatar_url", json.string(user.avatar_url)),
    #("created_at", json.string(user.created_at)),
  ])
}
