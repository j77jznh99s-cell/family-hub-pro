// Default DB driver - zero config, used whenever DATABASE_URL is unset. Every function
// is declared async (even though better-sqlite3 itself is synchronous) so this driver is
// a drop-in for db/postgres.js and callers never need to know which one is active.
const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');
const { buildStats } = require('./stats');

const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, '..', '..', 'data');
fs.mkdirSync(DATA_DIR, { recursive: true });

const db = new Database(path.join(DATA_DIR, 'clipdetect.sqlite'));
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
db.exec(schema);

// Columns added after a table first shipped - CREATE TABLE IF NOT EXISTS won't add them to
// an existing DB file, and SQLite has no ADD COLUMN IF NOT EXISTS.
const jobColumns = new Set(db.prepare('PRAGMA table_info(jobs)').all().map((c) => c.name));
if (!jobColumns.has('processing_ms')) db.exec('ALTER TABLE jobs ADD COLUMN processing_ms INTEGER');

async function createJob({ id, originalName, storedPath }) {
  db.prepare(
    `INSERT INTO jobs (id, original_name, stored_path, status) VALUES (?, ?, ?, 'uploaded')`
  ).run(id, originalName, storedPath);
}

async function updateJob(id, fields) {
  const keys = Object.keys(fields);
  if (keys.length === 0) return;
  const setClause = keys.map((k) => `${k} = ?`).join(', ');
  const values = keys.map((k) => fields[k]);
  db.prepare(`UPDATE jobs SET ${setClause}, updated_at = datetime('now') WHERE id = ?`).run(
    ...values,
    id
  );
}

async function getJob(id) {
  return db.prepare('SELECT * FROM jobs WHERE id = ?').get(id);
}

async function listJobs() {
  return db.prepare('SELECT * FROM jobs ORDER BY created_at DESC').all();
}

async function insertClip(clip) {
  db.prepare(
    `INSERT INTO clips (id, job_id, title, description, score, start_time, end_time, file_path, thumbnail_path)
     VALUES (@id, @job_id, @title, @description, @score, @start_time, @end_time, @file_path, @thumbnail_path)`
  ).run(clip);
}

async function getClipsForJob(jobId) {
  return db.prepare('SELECT * FROM clips WHERE job_id = ? ORDER BY score DESC').all(jobId);
}

async function getClip(jobId, clipId) {
  return db.prepare('SELECT * FROM clips WHERE job_id = ? AND id = ?').get(jobId, clipId);
}

// A job left in 'processing' means the server died mid-pipeline (crash/restart/deploy) -
// nothing is going to resume it, so surface that instead of leaving it stuck forever.
async function failStaleProcessingJobs() {
  const result = db
    .prepare(
      `UPDATE jobs SET status = 'failed', error = 'Interrupted by a server restart - please re-upload', updated_at = datetime('now')
       WHERE status = 'processing'`
    )
    .run();
  return result.changes;
}

async function getOrCreateAccount(accountId) {
  db.prepare(`INSERT OR IGNORE INTO accounts (id, credits) VALUES (?, 0)`).run(accountId);
  return db.prepare('SELECT * FROM accounts WHERE id = ?').get(accountId);
}

async function addCredits(accountId, amount) {
  await getOrCreateAccount(accountId);
  db.prepare('UPDATE accounts SET credits = credits + ?, updated_at = datetime(\'now\') WHERE id = ?').run(
    amount,
    accountId
  );
  return db.prepare('SELECT * FROM accounts WHERE id = ?').get(accountId);
}

// Deducts a credit only if the account has one available, atomically, so two concurrent
// uploads can't both pass a balance check race and spend the same last credit.
async function spendCreditIfAvailable(accountId) {
  await getOrCreateAccount(accountId);
  const result = db
    .prepare(
      `UPDATE accounts SET credits = credits - 1, updated_at = datetime('now')
       WHERE id = ? AND credits > 0`
    )
    .run(accountId);
  return result.changes > 0;
}

async function recordStripeEvent(eventId) {
  try {
    db.prepare('INSERT INTO processed_stripe_events (id) VALUES (?)').run(eventId);
    return true; // newly recorded - safe to act on
  } catch {
    return false; // already processed - webhook retry, ignore
  }
}

// Aggregate usage numbers for GET /api/stats. Same shape as postgres.js's getStats.
async function getStats() {
  const statusRows = db.prepare('SELECT status, COUNT(*) AS count FROM jobs GROUP BY status').all();
  const totals = db
    .prepare(
      `SELECT
         COUNT(*) AS completed,
         COALESCE(SUM(duration_seconds), 0) AS source_seconds,
         AVG(processing_ms) AS avg_processing_ms,
         MAX(processing_ms) AS max_processing_ms
       FROM jobs WHERE status = 'complete'`
    )
    .get();
  const recent = db
    .prepare(
      `SELECT
         SUM(CASE WHEN created_at >= datetime('now', '-1 day') THEN 1 ELSE 0 END) AS last_24h,
         SUM(CASE WHEN created_at >= datetime('now', '-7 days') THEN 1 ELSE 0 END) AS last_7d
       FROM jobs`
    )
    .get();
  const { clips } = db.prepare('SELECT COUNT(*) AS clips FROM clips').get();
  return buildStats({ statusRows, totals, recent, clips });
}

module.exports = {
  createJob,
  updateJob,
  getJob,
  listJobs,
  insertClip,
  getClipsForJob,
  getClip,
  failStaleProcessingJobs,
  getOrCreateAccount,
  addCredits,
  spendCreditIfAvailable,
  recordStripeEvent,
  getStats,
};
