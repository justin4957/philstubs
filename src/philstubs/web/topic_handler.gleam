import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import lustre/element
import philstubs/core/topic
import philstubs/data/auto_tagger_service
import philstubs/data/browse_repo
import philstubs/data/topic_repo
import philstubs/ui/browse_page
import philstubs/ui/topic_detail_page
import sqlight
import wisp.{type Request, type Response}

/// Handle GET /api/topics/taxonomy — full hierarchical tree with counts.
pub fn handle_taxonomy(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)

  case topic_repo.list_topic_tree(db_connection) {
    Ok(topic_tree) ->
      json.object([
        #("taxonomy", json.array(topic_tree, topic.topic_tree_node_to_json)),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    Error(_) ->
      json.object([#("taxonomy", json.preprocessed_array([]))])
      |> json.to_string
      |> wisp.json_response(500)
  }
}

/// Handle GET /api/topics/:slug — cross-level breakdown for a topic.
pub fn handle_topic_detail(
  request: Request,
  slug: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)

  case topic_repo.get_cross_level_summary(db_connection, slug) {
    Ok(Some(summary)) ->
      topic.cross_level_summary_to_json(summary)
      |> json.to_string
      |> wisp.json_response(200)
    Ok(None) ->
      json.object([
        #("error", json.string("Topic not found")),
        #("code", json.string("NOT_FOUND")),
      ])
      |> json.to_string
      |> wisp.json_response(404)
    Error(_) ->
      json.object([
        #("error", json.string("Internal server error")),
        #("code", json.string("INTERNAL_ERROR")),
      ])
      |> json.to_string
      |> wisp.json_response(500)
  }
}

/// Handle GET /api/topics/:slug/legislation?limit=20&page=1 — paginated legislation.
pub fn handle_topic_legislation(
  request: Request,
  slug: String,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)

  let query_params = wisp.get_query(request)
  let limit =
    list.key_find(query_params, "limit")
    |> result.try(int.parse)
    |> result.unwrap(20)
  let page =
    list.key_find(query_params, "page")
    |> result.try(int.parse)
    |> result.unwrap(1)
  let offset = { page - 1 } * limit

  case
    topic_repo.list_legislation_for_topic(db_connection, slug, limit, offset)
  {
    Ok(legislation_list) -> {
      let items =
        list.map(legislation_list, fn(item) {
          json.object([
            #("id", json.string(item.id)),
            #("title", json.string(item.title)),
            #("government_level", json.string(item.government_level)),
            #("introduced_date", json.string(item.introduced_date)),
          ])
        })
      json.object([
        #("items", json.preprocessed_array(items)),
        #("page", json.int(page)),
        #("limit", json.int(limit)),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) ->
      json.object([
        #("error", json.string("Internal server error")),
        #("code", json.string("INTERNAL_ERROR")),
      ])
      |> json.to_string
      |> wisp.json_response(500)
  }
}

/// Handle GET /api/topics/search?q=hou — autocomplete results.
pub fn handle_topic_search(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Get)

  let query_prefix =
    wisp.get_query(request)
    |> list.key_find("q")
    |> result.unwrap("")

  case topic_repo.search_topics(db_connection, query_prefix, 10) {
    Ok(matching_topics) ->
      json.object([
        #("topics", json.array(matching_topics, topic.to_json)),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    Error(_) ->
      json.object([#("topics", json.preprocessed_array([]))])
      |> json.to_string
      |> wisp.json_response(500)
  }
}

/// Handle POST /api/topics/auto-tag — trigger bulk auto-tagging.
pub fn handle_auto_tag(
  request: Request,
  db_connection: sqlight.Connection,
) -> Response {
  use <- wisp.require_method(request, http.Post)

  case auto_tagger_service.auto_tag_all_untagged(db_connection) {
    Ok(tagged_count) ->
      json.object([
        #("tagged_count", json.int(tagged_count)),
        #("message", json.string("Auto-tagging completed")),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    Error(_) ->
      json.object([
        #("error", json.string("Auto-tagging failed")),
        #("code", json.string("INTERNAL_ERROR")),
      ])
      |> json.to_string
      |> wisp.json_response(500)
  }
}

/// Handle GET /browse/topics — hierarchical topic browser (HTML).
pub fn handle_browse_topics(db_connection: sqlight.Connection) -> Response {
  let topic_tree = case topic_repo.list_topic_tree(db_connection) {
    Ok(tree) -> tree
    Error(_) -> []
  }

  let flat_topic_counts = case browse_repo.count_topics(db_connection) {
    Ok(counts) -> counts
    Error(_) -> []
  }

  browse_page.browse_topics_page(topic_tree, flat_topic_counts)
  |> element.to_document_string
  |> wisp.html_response(200)
}

/// Handle GET /browse/topics/:slug — topic detail page (HTML).
pub fn handle_browse_topic_detail(
  slug: String,
  db_connection: sqlight.Connection,
) -> Response {
  case topic_repo.get_cross_level_summary(db_connection, slug) {
    Ok(Some(summary)) -> {
      let child_topics = case
        topic_repo.list_children(db_connection, summary.topic.id)
      {
        Ok(children) -> children
        Error(_) -> []
      }

      let recent_legislation = case
        topic_repo.list_legislation_for_topic(db_connection, slug, 10, 0)
      {
        Ok(legislation_list) -> legislation_list
        Error(_) -> []
      }

      topic_detail_page.topic_detail_page(
        summary,
        child_topics,
        recent_legislation,
      )
      |> element.to_document_string
      |> wisp.html_response(200)
    }
    Ok(None) -> wisp.not_found()
    Error(_) -> wisp.internal_server_error()
  }
}
