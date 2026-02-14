-- Topic taxonomy tables for hierarchical topic organization, legislation/template
-- topic assignments, and keyword-based auto-tagging.

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
