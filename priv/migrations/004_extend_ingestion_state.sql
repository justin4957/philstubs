-- Migration 004: Generalize ingestion_state table for multi-source ingestion
-- Adds support for Open States state legislation ingestion alongside Congress.gov

-- Rename old table
ALTER TABLE ingestion_state RENAME TO ingestion_state_old;

-- Create new table with nullable congress fields + new state fields
CREATE TABLE ingestion_state (
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

-- Copy existing data
INSERT INTO ingestion_state (id, source, congress_number, bill_type, last_offset, last_update_date, total_bills_fetched, status, started_at, completed_at, error_message, created_at, updated_at)
SELECT id, source, congress_number, bill_type, last_offset, last_update_date, total_bills_fetched, status, started_at, completed_at, error_message, created_at, updated_at
FROM ingestion_state_old;

-- Drop old table
DROP TABLE ingestion_state_old;
