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
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
"

/// SQL for creating ingestion state table (matches priv/migrations/003_create_ingestion_state.sql).
pub const create_ingestion_state_sql = "
CREATE TABLE IF NOT EXISTS ingestion_state (
  id TEXT PRIMARY KEY,
  source TEXT NOT NULL DEFAULT 'congress_gov',
  congress_number INTEGER NOT NULL,
  bill_type TEXT NOT NULL,
  last_offset INTEGER NOT NULL DEFAULT 0,
  last_update_date TEXT,
  total_bills_fetched INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  started_at TEXT,
  completed_at TEXT,
  error_message TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(source, congress_number, bill_type)
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

/// All migrations as version/SQL pairs for use with run_migrations_from_sql.
pub fn all_migrations() -> List(#(String, String)) {
  [
    #("001", create_tables_sql),
    #("002", create_fts_sql),
    #("003", create_ingestion_state_sql),
  ]
}

/// Set up a fresh in-memory database with all migrations applied.
pub fn setup_test_db(
  connection: sqlight.Connection,
) -> Result(List(String), sqlight.Error) {
  migration.run_migrations_from_sql(connection, all_migrations())
}
