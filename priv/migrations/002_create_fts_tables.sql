-- 002_create_fts_tables.sql
-- Creates FTS5 virtual tables for full-text search on legislation and templates,
-- plus triggers to keep the FTS index in sync with the source tables.

-- Legislation full-text search index
CREATE VIRTUAL TABLE IF NOT EXISTS legislation_fts USING fts5(
  title, summary, body, topics,
  content=legislation, content_rowid=rowid
);

-- Triggers to keep legislation_fts in sync
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

-- Templates full-text search index
CREATE VIRTUAL TABLE IF NOT EXISTS templates_fts USING fts5(
  title, description, body, topics,
  content=legislation_templates, content_rowid=rowid
);

-- Triggers to keep templates_fts in sync
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
