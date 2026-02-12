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
