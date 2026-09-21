CREATE TABLE IF NOT EXISTS jobs (
  id TEXT PRIMARY KEY,
  original_name TEXT NOT NULL,
  stored_path TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'uploaded', -- uploaded | processing | complete | failed
  duration_seconds REAL,
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
