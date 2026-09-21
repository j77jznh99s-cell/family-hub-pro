const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');

const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, '..', '..', 'data');
fs.mkdirSync(DATA_DIR, { recursive: true });

const db = new Database(path.join(DATA_DIR, 'clipdetect.sqlite'));
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
db.exec(schema);

function createJob({ id, originalName, storedPath }) {
  db.prepare(
    `INSERT INTO jobs (id, original_name, stored_path, status) VALUES (?, ?, ?, 'uploaded')`
  ).run(id, originalName, storedPath);
}

function updateJob(id, fields) {
  const keys = Object.keys(fields);
  if (keys.length === 0) return;
  const setClause = keys.map((k) => `${k} = ?`).join(', ');
  const values = keys.map((k) => fields[k]);
  db.prepare(`UPDATE jobs SET ${setClause}, updated_at = datetime('now') WHERE id = ?`).run(
    ...values,
    id
  );
}

function getJob(id) {
  return db.prepare('SELECT * FROM jobs WHERE id = ?').get(id);
}

function listJobs() {
  return db.prepare('SELECT * FROM jobs ORDER BY created_at DESC').all();
}

function insertClip(clip) {
  db.prepare(
    `INSERT INTO clips (id, job_id, title, description, score, start_time, end_time, file_path, thumbnail_path)
     VALUES (@id, @job_id, @title, @description, @score, @start_time, @end_time, @file_path, @thumbnail_path)`
  ).run(clip);
}

function getClipsForJob(jobId) {
  return db
    .prepare('SELECT * FROM clips WHERE job_id = ? ORDER BY score DESC')
    .all(jobId);
}

function getClip(jobId, clipId) {
  return db.prepare('SELECT * FROM clips WHERE job_id = ? AND id = ?').get(jobId, clipId);
}

// A job left in 'processing' means the server died mid-pipeline (crash/restart/deploy) -
// nothing is going to resume it, so surface that instead of leaving it stuck forever.
function failStaleProcessingJobs() {
  const result = db
    .prepare(
      `UPDATE jobs SET status = 'failed', error = 'Interrupted by a server restart - please re-upload', updated_at = datetime('now')
       WHERE status = 'processing'`
    )
    .run();
  return result.changes;
}

module.exports = {
  db,
  createJob,
  updateJob,
  getJob,
  listJobs,
  insertClip,
  getClipsForJob,
  getClip,
  failStaleProcessingJobs,
};
