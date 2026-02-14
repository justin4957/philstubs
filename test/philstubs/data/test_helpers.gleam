import philstubs/data/migration
import sqlight

/// SQL for creating core tables (matches priv/migrations/001_create_tables.sql).
pub const create_tables_sql = "
CREATE TABLE IF NOT EXISTS schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS legislation (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  summary TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL,
  government_level TEXT NOT NULL,
  level_state_code TEXT,
  level_county_name TEXT,
  level_municipality_name TEXT,
  legislation_type TEXT NOT NULL,
  status TEXT NOT NULL,
  introduced_date TEXT NOT NULL DEFAULT '',
  source_url TEXT,
  source_identifier TEXT NOT NULL DEFAULT '',
  sponsors TEXT NOT NULL DEFAULT '[]',
  topics TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS legislation_templates (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL,
  suggested_level TEXT,
  suggested_level_state_code TEXT,
  suggested_level_county_name TEXT,
  suggested_level_municipality_name TEXT,
  suggested_type TEXT,
  author TEXT NOT NULL,
  topics TEXT NOT NULL DEFAULT '[]',
  download_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  owner_user_id TEXT
);
"

/// SQL for creating ingestion state table (matches priv/migrations/003 + 004).
pub const create_ingestion_state_sql = "
CREATE TABLE IF NOT EXISTS ingestion_state (
  id TEXT PRIMARY KEY,
  source TEXT NOT NULL DEFAULT 'congress_gov',
  congress_number INTEGER,
  bill_type TEXT,
  jurisdiction TEXT,
  session TEXT,
  last_offset INTEGER NOT NULL DEFAULT 0,
  last_page INTEGER NOT NULL DEFAULT 0,
  last_update_date TEXT,
  total_bills_fetched INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  started_at TEXT,
  completed_at TEXT,
  error_message TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
"

/// SQL for creating FTS5 tables and triggers (matches priv/migrations/002_create_fts_tables.sql).
pub const create_fts_sql = "
CREATE VIRTUAL TABLE IF NOT EXISTS legislation_fts USING fts5(
  title, summary, body, topics,
  content=legislation, content_rowid=rowid
);

CREATE TRIGGER IF NOT EXISTS legislation_fts_insert
AFTER INSERT ON legislation BEGIN
  INSERT INTO legislation_fts(rowid, title, summary, body, topics)
  VALUES (new.rowid, new.title, new.summary, new.body, new.topics);
END;

CREATE TRIGGER IF NOT EXISTS legislation_fts_update
AFTER UPDATE ON legislation BEGIN
  INSERT INTO legislation_fts(legislation_fts, rowid, title, summary, body, topics)
  VALUES ('delete', old.rowid, old.title, old.summary, old.body, old.topics);
  INSERT INTO legislation_fts(rowid, title, summary, body, topics)
  VALUES (new.rowid, new.title, new.summary, new.body, new.topics);
END;

CREATE TRIGGER IF NOT EXISTS legislation_fts_delete
AFTER DELETE ON legislation BEGIN
  INSERT INTO legislation_fts(legislation_fts, rowid, title, summary, body, topics)
  VALUES ('delete', old.rowid, old.title, old.summary, old.body, old.topics);
END;

CREATE VIRTUAL TABLE IF NOT EXISTS templates_fts USING fts5(
  title, description, body, topics,
  content=legislation_templates, content_rowid=rowid
);

CREATE TRIGGER IF NOT EXISTS templates_fts_insert
AFTER INSERT ON legislation_templates BEGIN
  INSERT INTO templates_fts(rowid, title, description, body, topics)
  VALUES (new.rowid, new.title, new.description, new.body, new.topics);
END;

CREATE TRIGGER IF NOT EXISTS templates_fts_update
AFTER UPDATE ON legislation_templates BEGIN
  INSERT INTO templates_fts(templates_fts, rowid, title, description, body, topics)
  VALUES ('delete', old.rowid, old.title, old.description, old.body, old.topics);
  INSERT INTO templates_fts(rowid, title, description, body, topics)
  VALUES (new.rowid, new.title, new.description, new.body, new.topics);
END;

CREATE TRIGGER IF NOT EXISTS templates_fts_delete
AFTER DELETE ON legislation_templates BEGIN
  INSERT INTO templates_fts(templates_fts, rowid, title, description, body, topics)
  VALUES ('delete', old.rowid, old.title, old.description, old.body, old.topics);
END;
"

/// SQL for creating users and sessions tables (matches priv/migrations/005).
pub const create_users_sessions_sql = "
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  github_id INTEGER NOT NULL UNIQUE,
  username TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  avatar_url TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS sessions (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
"

/// SQL for creating ingestion jobs table (matches priv/migrations/007_create_ingestion_jobs.sql).
pub const create_ingestion_jobs_sql = "
CREATE TABLE IF NOT EXISTS ingestion_jobs (
  id TEXT PRIMARY KEY,
  source TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  started_at TEXT,
  completed_at TEXT,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  records_fetched INTEGER NOT NULL DEFAULT 0,
  records_stored INTEGER NOT NULL DEFAULT 0,
  error_message TEXT,
  retry_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_ingestion_jobs_source ON ingestion_jobs(source);
CREATE INDEX IF NOT EXISTS idx_ingestion_jobs_created_at ON ingestion_jobs(created_at DESC);
"

/// SQL for creating topic taxonomy tables (matches priv/migrations/008_create_topic_taxonomy.sql).
pub const create_topic_taxonomy_sql = "
CREATE TABLE IF NOT EXISTS topics (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL DEFAULT '',
  parent_id TEXT REFERENCES topics(id),
  display_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS legislation_topics (
  legislation_id TEXT NOT NULL REFERENCES legislation(id) ON DELETE CASCADE,
  topic_id TEXT NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  assignment_method TEXT NOT NULL DEFAULT 'manual',
  PRIMARY KEY (legislation_id, topic_id)
);

CREATE TABLE IF NOT EXISTS template_topics (
  template_id TEXT NOT NULL REFERENCES legislation_templates(id) ON DELETE CASCADE,
  topic_id TEXT NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  assignment_method TEXT NOT NULL DEFAULT 'manual',
  PRIMARY KEY (template_id, topic_id)
);

CREATE TABLE IF NOT EXISTS topic_keywords (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  topic_id TEXT NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  keyword TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_topics_parent ON topics(parent_id);
CREATE INDEX IF NOT EXISTS idx_topics_slug ON topics(slug);
CREATE INDEX IF NOT EXISTS idx_legislation_topics_topic ON legislation_topics(topic_id);
CREATE INDEX IF NOT EXISTS idx_legislation_topics_legislation ON legislation_topics(legislation_id);
CREATE INDEX IF NOT EXISTS idx_template_topics_topic ON template_topics(topic_id);
CREATE INDEX IF NOT EXISTS idx_template_topics_template ON template_topics(template_id);
CREATE INDEX IF NOT EXISTS idx_topic_keywords_topic ON topic_keywords(topic_id);
"

/// SQL for creating cross-reference tables (matches priv/migrations/009_create_cross_references.sql).
pub const create_cross_references_sql = "
CREATE TABLE IF NOT EXISTS legislation_references (
  id TEXT PRIMARY KEY,
  source_legislation_id TEXT NOT NULL,
  target_legislation_id TEXT,
  citation_text TEXT NOT NULL,
  reference_type TEXT NOT NULL DEFAULT 'references',
  confidence REAL NOT NULL DEFAULT 1.0,
  extractor TEXT NOT NULL DEFAULT 'gleam_native',
  extracted_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(source_legislation_id, citation_text),
  FOREIGN KEY(source_legislation_id) REFERENCES legislation(id),
  FOREIGN KEY(target_legislation_id) REFERENCES legislation(id)
);

CREATE INDEX IF NOT EXISTS idx_references_source
  ON legislation_references(source_legislation_id);
CREATE INDEX IF NOT EXISTS idx_references_target
  ON legislation_references(target_legislation_id);
CREATE INDEX IF NOT EXISTS idx_references_type
  ON legislation_references(reference_type);

CREATE TABLE IF NOT EXISTS query_maps (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL DEFAULT '',
  query_template TEXT NOT NULL,
  parameters TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_query_maps_name
  ON query_maps(name);
"

/// SQL for creating similarity tables (matches priv/migrations/006_create_similarity_tables.sql).
pub const create_similarity_tables_sql = "
CREATE TABLE IF NOT EXISTS legislation_similarities (
  id TEXT PRIMARY KEY,
  source_legislation_id TEXT NOT NULL,
  target_legislation_id TEXT NOT NULL,
  similarity_score REAL NOT NULL,
  title_score REAL NOT NULL DEFAULT 0.0,
  body_score REAL NOT NULL DEFAULT 0.0,
  topic_score REAL NOT NULL DEFAULT 0.0,
  method TEXT NOT NULL DEFAULT 'ngram_jaccard',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(source_legislation_id, target_legislation_id),
  FOREIGN KEY(source_legislation_id) REFERENCES legislation(id),
  FOREIGN KEY(target_legislation_id) REFERENCES legislation(id)
);

CREATE INDEX IF NOT EXISTS idx_similarities_source
  ON legislation_similarities(source_legislation_id);
CREATE INDEX IF NOT EXISTS idx_similarities_target
  ON legislation_similarities(target_legislation_id);
CREATE INDEX IF NOT EXISTS idx_similarities_score
  ON legislation_similarities(similarity_score DESC);

CREATE TABLE IF NOT EXISTS template_legislation_matches (
  id TEXT PRIMARY KEY,
  template_id TEXT NOT NULL,
  legislation_id TEXT NOT NULL,
  similarity_score REAL NOT NULL,
  title_score REAL NOT NULL DEFAULT 0.0,
  body_score REAL NOT NULL DEFAULT 0.0,
  topic_score REAL NOT NULL DEFAULT 0.0,
  method TEXT NOT NULL DEFAULT 'ngram_jaccard',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(template_id, legislation_id),
  FOREIGN KEY(template_id) REFERENCES legislation_templates(id),
  FOREIGN KEY(legislation_id) REFERENCES legislation(id)
);

CREATE INDEX IF NOT EXISTS idx_template_matches_template
  ON template_legislation_matches(template_id);
CREATE INDEX IF NOT EXISTS idx_template_matches_legislation
  ON template_legislation_matches(legislation_id);
CREATE INDEX IF NOT EXISTS idx_template_matches_score
  ON template_legislation_matches(similarity_score DESC);
"

/// All migrations as version/SQL pairs for use with run_migrations_from_sql.
pub fn all_migrations() -> List(#(String, String)) {
  [
    #("001", create_tables_sql),
    #("002", create_fts_sql),
    #("003", create_ingestion_state_sql),
    #("005", create_users_sessions_sql),
    #("006", create_similarity_tables_sql),
    #("007", create_ingestion_jobs_sql),
    #("008", create_topic_taxonomy_sql),
    #("009", create_cross_references_sql),
  ]
}

/// Set up a fresh in-memory database with all migrations applied.
pub fn setup_test_db(
  connection: sqlight.Connection,
) -> Result(List(String), sqlight.Error) {
  migration.run_migrations_from_sql(connection, all_migrations())
}
