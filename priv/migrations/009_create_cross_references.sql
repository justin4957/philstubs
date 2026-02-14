-- Cross-reference tracking between legislation records.
-- Stores citations extracted from legislation text, with optional
-- resolution to target legislation records in the database.
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

-- Named, reusable query patterns for legislation cross-reference exploration.
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
