CREATE TABLE IF NOT EXISTS jobs (
  id TEXT PRIMARY KEY,
  original_name TEXT NOT NULL,
  stored_path TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'uploaded', -- uploaded | processing | complete | failed
  duration_seconds REAL,
  processing_ms INTEGER, -- wall-clock pipeline time, set when a job completes or fails
  error TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS clips (
  id TEXT PRIMARY KEY,
  job_id TEXT NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  title TEXT,
  description TEXT,
  score REAL,
  start_time REAL NOT NULL,
  end_time REAL NOT NULL,
  file_path TEXT,
  thumbnail_path TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_clips_job_id ON clips(job_id);

-- One row per paying account (keyed by whatever the caller uses to identify a client -
-- e.g. their ACCESS_TOKEN or an email). Only used when Stripe billing is enabled;
-- absent that, uploads aren't gated on credits at all.
CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  credits INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Stripe can and does deliver the same webhook event more than once - this makes
-- crediting an account idempotent per event id.
CREATE TABLE IF NOT EXISTS processed_stripe_events (
  id TEXT PRIMARY KEY,
  processed_at TEXT NOT NULL DEFAULT (datetime('now'))
);
