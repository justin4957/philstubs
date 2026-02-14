-- Saved explorations table for persisting interactive graph states.
-- Stores the serialized D3.js graph state as a JSON blob.
CREATE TABLE IF NOT EXISTS saved_explorations (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  graph_state TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  is_public INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_saved_explorations_user ON saved_explorations(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_explorations_public ON saved_explorations(is_public);
CREATE INDEX IF NOT EXISTS idx_saved_explorations_created ON saved_explorations(created_at DESC);
