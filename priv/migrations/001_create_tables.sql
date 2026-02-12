-- 001_create_tables.sql
-- Creates the core legislation and templates tables, plus the schema_migrations
-- tracking table used by the migration runner.

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
