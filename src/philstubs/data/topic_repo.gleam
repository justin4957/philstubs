import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import philstubs/core/topic.{
  type Topic, type TopicCrossLevelSummary, type TopicId, type TopicTreeNode,
  type TopicWithCount, Topic, TopicCrossLevelSummary, TopicTreeNode,
  TopicWithCount,
}
import sqlight

// --- Core CRUD ---

/// Insert a topic into the database.
pub fn insert(
  connection: sqlight.Connection,
  record: Topic,
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "INSERT INTO topics (id, name, slug, description, parent_id, display_order)
     VALUES (?, ?, ?, ?, ?, ?)",
    on: connection,
    with: [
      sqlight.text(topic.topic_id_to_string(record.id)),
      sqlight.text(record.name),
      sqlight.text(record.slug),
      sqlight.text(record.description),
      sqlight.nullable(
        sqlight.text,
        option.map(record.parent_id, topic.topic_id_to_string),
      ),
      sqlight.int(record.display_order),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Get a topic by its ID.
pub fn get_by_id(
  connection: sqlight.Connection,
  target_id: TopicId,
) -> Result(Option(Topic), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    "SELECT id, name, slug, description, parent_id, display_order
       FROM topics WHERE id = ?",
    on: connection,
    with: [sqlight.text(topic.topic_id_to_string(target_id))],
    expecting: topic_row_decoder(),
  ))
  case rows {
    [record, ..] -> Ok(Some(record))
    [] -> Ok(None)
  }
}

/// Get a topic by its slug.
pub fn get_by_slug(
  connection: sqlight.Connection,
  slug: String,
) -> Result(Option(Topic), sqlight.Error) {
  use rows <- result.try(sqlight.query(
    "SELECT id, name, slug, description, parent_id, display_order
       FROM topics WHERE slug = ?",
    on: connection,
    with: [sqlight.text(slug)],
    expecting: topic_row_decoder(),
  ))
  case rows {
    [record, ..] -> Ok(Some(record))
    [] -> Ok(None)
  }
}

// --- Hierarchy queries ---

/// List all parent topics (where parent_id IS NULL), ordered by display_order.
pub fn list_parent_topics(
  connection: sqlight.Connection,
) -> Result(List(Topic), sqlight.Error) {
  sqlight.query(
    "SELECT id, name, slug, description, parent_id, display_order
     FROM topics WHERE parent_id IS NULL ORDER BY display_order",
    on: connection,
    with: [],
    expecting: topic_row_decoder(),
  )
}

/// List children of a parent topic, ordered by display_order.
pub fn list_children(
  connection: sqlight.Connection,
  parent_id: TopicId,
) -> Result(List(Topic), sqlight.Error) {
  sqlight.query(
    "SELECT id, name, slug, description, parent_id, display_order
     FROM topics WHERE parent_id = ? ORDER BY display_order",
    on: connection,
    with: [sqlight.text(topic.topic_id_to_string(parent_id))],
    expecting: topic_row_decoder(),
  )
}

/// Build a full topic tree: parents with nested children and legislation counts.
pub fn list_topic_tree(
  connection: sqlight.Connection,
) -> Result(List(TopicTreeNode), sqlight.Error) {
  use parents <- result.try(list_parent_topics(connection))

  list.try_map(parents, fn(parent) {
    let parent_id_str = topic.topic_id_to_string(parent.id)

    // Get children with counts
    use children_with_counts <- result.try(sqlight.query(
      "SELECT t.id, t.name, t.slug, t.description, t.parent_id, t.display_order,
                COALESCE(lc.legislation_count, 0) as leg_count,
                COALESCE(tc.template_count, 0) as tmpl_count
         FROM topics t
         LEFT JOIN (
           SELECT topic_id, COUNT(*) as legislation_count
           FROM legislation_topics
           GROUP BY topic_id
         ) lc ON lc.topic_id = t.id
         LEFT JOIN (
           SELECT topic_id, COUNT(*) as template_count
           FROM template_topics
           GROUP BY topic_id
         ) tc ON tc.topic_id = t.id
         WHERE t.parent_id = ?
         ORDER BY t.display_order",
      on: connection,
      with: [sqlight.text(parent_id_str)],
      expecting: topic_with_count_row_decoder(),
    ))

    // Get parent's own legislation count
    use parent_count <- result.try(count_legislation_for_topic_and_children(
      connection,
      parent_id_str,
    ))

    Ok(TopicTreeNode(
      topic: parent,
      children: children_with_counts,
      legislation_count: parent_count,
    ))
  })
}

// --- Assignment operations ---

/// Assign a topic to a legislation record. Uses INSERT OR IGNORE
/// to avoid duplicate assignments.
pub fn assign_legislation_topic(
  connection: sqlight.Connection,
  legislation_id: String,
  target_topic_id: TopicId,
  method: topic.AssignmentMethod,
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "INSERT OR IGNORE INTO legislation_topics (legislation_id, topic_id, assignment_method)
     VALUES (?, ?, ?)",
    on: connection,
    with: [
      sqlight.text(legislation_id),
      sqlight.text(topic.topic_id_to_string(target_topic_id)),
      sqlight.text(topic.assignment_method_to_string(method)),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Remove a topic assignment from a legislation record.
pub fn remove_legislation_topic(
  connection: sqlight.Connection,
  legislation_id: String,
  target_topic_id: TopicId,
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "DELETE FROM legislation_topics WHERE legislation_id = ? AND topic_id = ?",
    on: connection,
    with: [
      sqlight.text(legislation_id),
      sqlight.text(topic.topic_id_to_string(target_topic_id)),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Get all topics assigned to a legislation record.
pub fn get_legislation_topics(
  connection: sqlight.Connection,
  legislation_id: String,
) -> Result(List(Topic), sqlight.Error) {
  sqlight.query(
    "SELECT t.id, t.name, t.slug, t.description, t.parent_id, t.display_order
     FROM topics t
     JOIN legislation_topics lt ON lt.topic_id = t.id
     WHERE lt.legislation_id = ?
     ORDER BY t.display_order",
    on: connection,
    with: [sqlight.text(legislation_id)],
    expecting: topic_row_decoder(),
  )
}

/// Assign a topic to a template record.
pub fn assign_template_topic(
  connection: sqlight.Connection,
  template_id: String,
  target_topic_id: TopicId,
  method: topic.AssignmentMethod,
) -> Result(Nil, sqlight.Error) {
  sqlight.query(
    "INSERT OR IGNORE INTO template_topics (template_id, topic_id, assignment_method)
     VALUES (?, ?, ?)",
    on: connection,
    with: [
      sqlight.text(template_id),
      sqlight.text(topic.topic_id_to_string(target_topic_id)),
      sqlight.text(topic.assignment_method_to_string(method)),
    ],
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// Get all topics assigned to a template record.
pub fn get_template_topics(
  connection: sqlight.Connection,
  template_id: String,
) -> Result(List(Topic), sqlight.Error) {
  sqlight.query(
    "SELECT t.id, t.name, t.slug, t.description, t.parent_id, t.display_order
     FROM topics t
     JOIN template_topics tt ON tt.topic_id = t.id
     WHERE tt.template_id = ?
     ORDER BY t.display_order",
    on: connection,
    with: [sqlight.text(template_id)],
    expecting: topic_row_decoder(),
  )
}

// --- Aggregation queries ---

/// Count legislation per parent topic, rolling up child counts.
pub fn count_legislation_by_topic(
  connection: sqlight.Connection,
) -> Result(List(TopicWithCount), sqlight.Error) {
  sqlight.query(
    "SELECT t.id, t.name, t.slug, t.description, t.parent_id, t.display_order,
            COALESCE(counts.total, 0) as leg_count,
            0 as tmpl_count
     FROM topics t
     LEFT JOIN (
       SELECT COALESCE(parent.id, child.id) as topic_id,
              COUNT(DISTINCT lt.legislation_id) as total
       FROM legislation_topics lt
       JOIN topics child ON child.id = lt.topic_id
       LEFT JOIN topics parent ON parent.id = child.parent_id
       GROUP BY COALESCE(parent.id, child.id)
     ) counts ON counts.topic_id = t.id
     WHERE t.parent_id IS NULL
     ORDER BY t.display_order",
    on: connection,
    with: [],
    expecting: topic_with_count_row_decoder(),
  )
}

/// Get a cross-level summary for a topic slug, showing counts by government level.
pub fn get_cross_level_summary(
  connection: sqlight.Connection,
  slug: String,
) -> Result(Option(TopicCrossLevelSummary), sqlight.Error) {
  use maybe_target_topic <- result.try(get_by_slug(connection, slug))

  case maybe_target_topic {
    None -> Ok(None)
    Some(target_topic) -> {
      let topic_id_str = topic.topic_id_to_string(target_topic.id)

      // Count by government level for this topic and its children
      use level_counts <- result.try(sqlight.query(
        "SELECT l.government_level, COUNT(DISTINCT l.id) as count
           FROM legislation l
           JOIN legislation_topics lt ON lt.legislation_id = l.id
           WHERE lt.topic_id = ? OR lt.topic_id IN (
             SELECT id FROM topics WHERE parent_id = ?
           )
           GROUP BY l.government_level",
        on: connection,
        with: [sqlight.text(topic_id_str), sqlight.text(topic_id_str)],
        expecting: string_count_decoder(),
      ))

      // State breakdown
      use state_counts <- result.try(sqlight.query(
        "SELECT l.level_state_code, COUNT(DISTINCT l.id) as count
           FROM legislation l
           JOIN legislation_topics lt ON lt.legislation_id = l.id
           WHERE (lt.topic_id = ? OR lt.topic_id IN (
             SELECT id FROM topics WHERE parent_id = ?
           ))
           AND l.level_state_code IS NOT NULL
           AND l.level_state_code != ''
           GROUP BY l.level_state_code
           ORDER BY count DESC",
        on: connection,
        with: [sqlight.text(topic_id_str), sqlight.text(topic_id_str)],
        expecting: string_count_decoder(),
      ))

      let federal_count = find_level_count(level_counts, "federal")
      let state_count = find_level_count(level_counts, "state")
      let county_count = find_level_count(level_counts, "county")
      let municipal_count = find_level_count(level_counts, "municipal")

      Ok(
        Some(TopicCrossLevelSummary(
          topic: target_topic,
          federal_count: federal_count,
          state_count: state_count,
          county_count: county_count,
          municipal_count: municipal_count,
          state_breakdown: state_counts,
        )),
      )
    }
  }
}

/// List legislation for a topic (including children), with pagination.
pub fn list_legislation_for_topic(
  connection: sqlight.Connection,
  slug: String,
  limit: Int,
  offset: Int,
) -> Result(List(LegislationSummary), sqlight.Error) {
  // First get the topic ID from slug
  use maybe_target_topic <- result.try(get_by_slug(connection, slug))

  case maybe_target_topic {
    None -> Ok([])
    Some(target_topic) -> {
      let topic_id_str = topic.topic_id_to_string(target_topic.id)
      sqlight.query(
        "SELECT DISTINCT l.id, l.title, l.government_level, l.introduced_date
         FROM legislation l
         JOIN legislation_topics lt ON lt.legislation_id = l.id
         WHERE lt.topic_id = ? OR lt.topic_id IN (
           SELECT id FROM topics WHERE parent_id = ?
         )
         ORDER BY l.introduced_date DESC
         LIMIT ? OFFSET ?",
        on: connection,
        with: [
          sqlight.text(topic_id_str),
          sqlight.text(topic_id_str),
          sqlight.int(limit),
          sqlight.int(offset),
        ],
        expecting: legislation_summary_decoder(),
      )
    }
  }
}

/// A lightweight legislation record for topic listing.
pub type LegislationSummary {
  LegislationSummary(
    id: String,
    title: String,
    government_level: String,
    introduced_date: String,
  )
}

/// Search topics by name prefix for autocomplete.
pub fn search_topics(
  connection: sqlight.Connection,
  query_prefix: String,
  limit: Int,
) -> Result(List(Topic), sqlight.Error) {
  sqlight.query(
    "SELECT id, name, slug, description, parent_id, display_order
     FROM topics
     WHERE name LIKE ? || '%'
     ORDER BY display_order
     LIMIT ?",
    on: connection,
    with: [sqlight.text(query_prefix), sqlight.int(limit)],
    expecting: topic_row_decoder(),
  )
}

/// Get all keywords for a specific topic.
pub fn get_topic_keywords(
  connection: sqlight.Connection,
  target_topic_id: TopicId,
) -> Result(List(String), sqlight.Error) {
  sqlight.query(
    "SELECT keyword FROM topic_keywords WHERE topic_id = ?",
    on: connection,
    with: [sqlight.text(topic.topic_id_to_string(target_topic_id))],
    expecting: {
      use keyword <- decode.field(0, decode.string)
      decode.success(keyword)
    },
  )
}

/// Bulk load all topics with their keywords for auto-tagging.
pub fn list_all_topics_with_keywords(
  connection: sqlight.Connection,
) -> Result(List(#(TopicId, List(String))), sqlight.Error) {
  use rows <- result.try(
    sqlight.query(
      "SELECT tk.topic_id, tk.keyword
       FROM topic_keywords tk
       ORDER BY tk.topic_id",
      on: connection,
      with: [],
      expecting: {
        use target_topic_id <- decode.field(0, decode.string)
        use keyword <- decode.field(1, decode.string)
        decode.success(#(target_topic_id, keyword))
      },
    ),
  )

  // Group keywords by topic_id
  let grouped =
    list.fold(rows, [], fn(accumulated, row) {
      let #(target_topic_id, keyword) = row
      case list.key_find(accumulated, target_topic_id) {
        Ok(existing_keywords) -> {
          list.key_set(accumulated, target_topic_id, [
            keyword,
            ..existing_keywords
          ])
        }
        Error(_) -> [#(target_topic_id, [keyword]), ..accumulated]
      }
    })

  Ok(
    list.map(grouped, fn(entry) {
      let #(target_topic_id, keywords) = entry
      #(topic.topic_id(target_topic_id), list.reverse(keywords))
    }),
  )
}

/// List all topic names for autocomplete suggestions.
pub fn list_all_topic_names(
  connection: sqlight.Connection,
) -> Result(List(String), sqlight.Error) {
  sqlight.query(
    "SELECT name FROM topics ORDER BY display_order, name",
    on: connection,
    with: [],
    expecting: {
      use name <- decode.field(0, decode.string)
      decode.success(name)
    },
  )
}

// --- Private helpers ---

fn topic_row_decoder() -> decode.Decoder(Topic) {
  use id_str <- decode.field(0, decode.string)
  use name <- decode.field(1, decode.string)
  use slug <- decode.field(2, decode.string)
  use description <- decode.field(3, decode.string)
  use parent_id_str <- decode.field(4, decode.optional(decode.string))
  use display_order <- decode.field(5, decode.int)

  decode.success(Topic(
    id: topic.topic_id(id_str),
    name: name,
    slug: slug,
    description: description,
    parent_id: option.map(parent_id_str, topic.topic_id),
    display_order: display_order,
  ))
}

fn topic_with_count_row_decoder() -> decode.Decoder(TopicWithCount) {
  use id_str <- decode.field(0, decode.string)
  use name <- decode.field(1, decode.string)
  use slug <- decode.field(2, decode.string)
  use description <- decode.field(3, decode.string)
  use parent_id_str <- decode.field(4, decode.optional(decode.string))
  use display_order <- decode.field(5, decode.int)
  use legislation_count <- decode.field(6, decode.int)
  use template_count <- decode.field(7, decode.int)

  decode.success(TopicWithCount(
    topic: Topic(
      id: topic.topic_id(id_str),
      name: name,
      slug: slug,
      description: description,
      parent_id: option.map(parent_id_str, topic.topic_id),
      display_order: display_order,
    ),
    legislation_count: legislation_count,
    template_count: template_count,
  ))
}

fn string_count_decoder() -> decode.Decoder(#(String, Int)) {
  use label <- decode.field(0, decode.string)
  use count <- decode.field(1, decode.int)
  decode.success(#(label, count))
}

fn legislation_summary_decoder() -> decode.Decoder(LegislationSummary) {
  use id <- decode.field(0, decode.string)
  use title <- decode.field(1, decode.string)
  use government_level <- decode.field(2, decode.string)
  use introduced_date <- decode.field(3, decode.string)
  decode.success(LegislationSummary(
    id: id,
    title: title,
    government_level: government_level,
    introduced_date: introduced_date,
  ))
}

fn find_level_count(level_counts: List(#(String, Int)), level: String) -> Int {
  case list.key_find(level_counts, level) {
    Ok(count) -> count
    Error(_) -> 0
  }
}

fn count_legislation_for_topic_and_children(
  connection: sqlight.Connection,
  topic_id_str: String,
) -> Result(Int, sqlight.Error) {
  use rows <- result.try(
    sqlight.query(
      "SELECT COUNT(DISTINCT lt.legislation_id)
       FROM legislation_topics lt
       WHERE lt.topic_id = ? OR lt.topic_id IN (
         SELECT id FROM topics WHERE parent_id = ?
       )",
      on: connection,
      with: [sqlight.text(topic_id_str), sqlight.text(topic_id_str)],
      expecting: {
        use count <- decode.field(0, decode.int)
        decode.success(count)
      },
    ),
  )
  case rows {
    [count] -> Ok(count)
    _ -> Ok(0)
  }
}
