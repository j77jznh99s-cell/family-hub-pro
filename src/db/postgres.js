// Used instead of db/sqlite.js whenever DATABASE_URL is set. Same exported function
// signatures as sqlite.js (all async) so routes/services never need to know which
// driver is active - see db/index.js.
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
const { DATABASE_URL } = require('../config');
const { buildStats } = require('./stats');

const pool = new Pool({ connectionString: DATABASE_URL });

const schema = fs.readFileSync(path.join(__dirname, 'schema.pg.sql'), 'utf8');
const ready = pool.query(schema).catch((err) => {
  console.error('Failed to apply Postgres schema:', err.message);
  throw err;
});

// pg returns TIMESTAMPTZ columns as JS Date objects - normalize to ISO strings so the
// API's JSON shape doesn't depend on which DB driver is active.
function normalizeDates(row) {
  if (!row) return row;
  for (const key of ['created_at', 'updated_at', 'processed_at']) {
    if (row[key] instanceof Date) row[key] = row[key].toISOString();
  }
  return row;
}

async function query(text, params) {
  await ready;
  return pool.query(text, params);
}

async function createJob({ id, originalName, storedPath }) {
  await query(
    `INSERT INTO jobs (id, original_name, stored_path, status) VALUES ($1, $2, $3, 'uploaded')`,
    [id, originalName, storedPath]
  );
}

async function updateJob(id, fields) {
  const keys = Object.keys(fields);
  if (keys.length === 0) return;
  const setClause = keys.map((k, i) => `${k} = $${i + 1}`).join(', ');
  const values = keys.map((k) => fields[k]);
  await query(`UPDATE jobs SET ${setClause}, updated_at = now() WHERE id = $${keys.length + 1}`, [
    ...values,
    id,
  ]);
}

async function getJob(id) {
  const { rows } = await query('SELECT * FROM jobs WHERE id = $1', [id]);
  return normalizeDates(rows[0]);
}

async function listJobs() {
  const { rows } = await query('SELECT * FROM jobs ORDER BY created_at DESC');
  return rows.map(normalizeDates);
}

async function insertClip(clip) {
  await query(
    `INSERT INTO clips (id, job_id, title, description, score, start_time, end_time, file_path, thumbnail_path)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
    [
      clip.id,
      clip.job_id,
      clip.title,
      clip.description,
      clip.score,
      clip.start_time,
      clip.end_time,
      clip.file_path,
      clip.thumbnail_path,
    ]
  );
}

async function getClipsForJob(jobId) {
  const { rows } = await query('SELECT * FROM clips WHERE job_id = $1 ORDER BY score DESC', [
    jobId,
  ]);
  return rows.map(normalizeDates);
}

async function getClip(jobId, clipId) {
  const { rows } = await query('SELECT * FROM clips WHERE job_id = $1 AND id = $2', [
    jobId,
    clipId,
  ]);
  return normalizeDates(rows[0]);
}

async function failStaleProcessingJobs() {
  const result = await query(
    `UPDATE jobs SET status = 'failed', error = 'Interrupted by a server restart - please re-upload', updated_at = now()
     WHERE status = 'processing'`
  );
  return result.rowCount;
}

async function getOrCreateAccount(accountId) {
  await query('INSERT INTO accounts (id, credits) VALUES ($1, 0) ON CONFLICT (id) DO NOTHING', [
    accountId,
  ]);
  const { rows } = await query('SELECT * FROM accounts WHERE id = $1', [accountId]);
  return normalizeDates(rows[0]);
}

async function addCredits(accountId, amount) {
  await getOrCreateAccount(accountId);
  await query('UPDATE accounts SET credits = credits + $1, updated_at = now() WHERE id = $2', [
    amount,
    accountId,
  ]);
  const { rows } = await query('SELECT * FROM accounts WHERE id = $1', [accountId]);
  return normalizeDates(rows[0]);
}

// Deducts a credit only if the account has one available, atomically, so two concurrent
// uploads can't both pass a balance check race and spend the same last credit.
async function spendCreditIfAvailable(accountId) {
  await getOrCreateAccount(accountId);
  const result = await query(
    `UPDATE accounts SET credits = credits - 1, updated_at = now()
     WHERE id = $1 AND credits > 0`,
    [accountId]
  );
  return result.rowCount > 0;
}

async function recordStripeEvent(eventId) {
  const result = await query(
    'INSERT INTO processed_stripe_events (id) VALUES ($1) ON CONFLICT (id) DO NOTHING',
    [eventId]
  );
  return result.rowCount > 0; // true only if this call actually inserted it
}

// Aggregate usage numbers for GET /api/stats. Same shape as sqlite.js's getStats.
// COUNT/SUM come back from pg as strings (bigint/numeric) - buildStats normalizes them.
async function getStats() {
  const { rows: statusRows } = await query(
    'SELECT status, COUNT(*) AS count FROM jobs GROUP BY status'
  );
  const {
    rows: [totals],
  } = await query(
    `SELECT
       COUNT(*) AS completed,
       COALESCE(SUM(duration_seconds), 0) AS source_seconds,
       AVG(processing_ms) AS avg_processing_ms,
       MAX(processing_ms) AS max_processing_ms
     FROM jobs WHERE status = 'complete'`
  );
  const {
    rows: [recent],
  } = await query(
    `SELECT
       COUNT(*) FILTER (WHERE created_at >= now() - interval '1 day') AS last_24h,
       COUNT(*) FILTER (WHERE created_at >= now() - interval '7 days') AS last_7d
     FROM jobs`
  );
  const {
    rows: [{ clips }],
  } = await query('SELECT COUNT(*) AS clips FROM clips');
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
