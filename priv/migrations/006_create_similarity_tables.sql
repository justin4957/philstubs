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
