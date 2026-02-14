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
