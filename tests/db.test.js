// Exercises whichever DB driver is currently active (sqlite by default, postgres when
// DATABASE_URL is set - see src/db/index.js) through the full CRUD + credits surface.
// Uses isolated per-test-run data (DATA_DIR set below) and unique ids so it's safe to
// run repeatedly against a shared Postgres instance too.
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');

let tmpDataDir;
if (!process.env.DATABASE_URL) {
  tmpDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'clipdetect-db-test-'));
  process.env.DATA_DIR = tmpDataDir;
}

const db = require('../src/db');

after(() => {
  if (tmpDataDir) fs.rmSync(tmpDataDir, { recursive: true, force: true });
});

function uniqueId(prefix) {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

test('job lifecycle: create, update, read, list', async () => {
  const jobId = uniqueId('job');
  await db.createJob({ id: jobId, originalName: 'test.mp4', storedPath: '/tmp/test.mp4' });

  let job = await db.getJob(jobId);
  assert.equal(job.status, 'uploaded');
  assert.equal(job.original_name, 'test.mp4');

  await db.updateJob(jobId, { status: 'processing', duration_seconds: 42.5 });
  job = await db.getJob(jobId);
  assert.equal(job.status, 'processing');
  assert.equal(job.duration_seconds, 42.5);

  const jobs = await db.listJobs();
  assert.ok(jobs.some((j) => j.id === jobId));

  await db.updateJob(jobId, { status: 'complete' });
  job = await db.getJob(jobId);
  assert.equal(job.status, 'complete');
});

test('clips: insert and fetch, ordered by score', async () => {
  const jobId = uniqueId('job');
  await db.createJob({ id: jobId, originalName: 'clips.mp4', storedPath: '/tmp/clips.mp4' });

  const clipLow = { id: uniqueId('clip'), job_id: jobId, title: 'Low', description: '', score: 2, start_time: 0, end_time: 10, file_path: 'a.mp4', thumbnail_path: null };
  const clipHigh = { id: uniqueId('clip'), job_id: jobId, title: 'High', description: '', score: 9, start_time: 10, end_time: 20, file_path: 'b.mp4', thumbnail_path: null };
  await db.insertClip(clipLow);
  await db.insertClip(clipHigh);

  const clips = await db.getClipsForJob(jobId);
  assert.equal(clips.length, 2);
  assert.equal(clips[0].id, clipHigh.id); // highest score first

  const fetched = await db.getClip(jobId, clipLow.id);
  assert.equal(fetched.title, 'Low');

  assert.equal(await db.getClip(jobId, 'does-not-exist'), undefined);
});

test('failStaleProcessingJobs marks processing jobs as failed', async () => {
  const jobId = uniqueId('job');
  await db.createJob({ id: jobId, originalName: 'stuck.mp4', storedPath: '/tmp/stuck.mp4' });
  await db.updateJob(jobId, { status: 'processing' });

  const changed = await db.failStaleProcessingJobs();
  assert.ok(changed >= 1);

  const job = await db.getJob(jobId);
  assert.equal(job.status, 'failed');
  assert.match(job.error, /restart/);
});

test('credits: add, spend, and refuse to spend below zero', async () => {
  const accountId = uniqueId('acct');

  const created = await db.getOrCreateAccount(accountId);
  assert.equal(created.credits, 0);

  await db.addCredits(accountId, 3);
  let account = await db.getOrCreateAccount(accountId);
  assert.equal(account.credits, 3);

  assert.equal(await db.spendCreditIfAvailable(accountId), true);
  assert.equal(await db.spendCreditIfAvailable(accountId), true);
  assert.equal(await db.spendCreditIfAvailable(accountId), true);
  account = await db.getOrCreateAccount(accountId);
  assert.equal(account.credits, 0);

  // No credits left - must refuse, not go negative.
  assert.equal(await db.spendCreditIfAvailable(accountId), false);
  account = await db.getOrCreateAccount(accountId);
  assert.equal(account.credits, 0);
});

test('recordStripeEvent is idempotent per event id', async () => {
  const eventId = uniqueId('evt');
  assert.equal(await db.recordStripeEvent(eventId), true);
  assert.equal(await db.recordStripeEvent(eventId), false); // webhook retry - already processed
});

test('getStats reflects new jobs, clips, and processing time', async () => {
  // Deltas, not absolutes - the Postgres run in CI shares one database across test runs.
  const before = await db.getStats();

  const doneId = uniqueId('job');
  await db.createJob({ id: doneId, originalName: 'done.mp4', storedPath: '/tmp/done.mp4' });
  await db.updateJob(doneId, { status: 'complete', duration_seconds: 120, processing_ms: 4000 });
  await db.insertClip({ id: uniqueId('clip'), job_id: doneId, title: 't', description: '', score: 5, start_time: 0, end_time: 10, file_path: 'x.mp4', thumbnail_path: null });

  const failedId = uniqueId('job');
  await db.createJob({ id: failedId, originalName: 'bad.mp4', storedPath: '/tmp/bad.mp4' });
  await db.updateJob(failedId, { status: 'failed', error: 'boom', processing_ms: 500 });

  const after = await db.getStats();
  assert.equal(after.jobs.total - before.jobs.total, 2);
  assert.equal(after.jobs.byStatus.complete - before.jobs.byStatus.complete, 1);
  assert.equal(after.jobs.byStatus.failed - before.jobs.byStatus.failed, 1);
  assert.equal(after.jobs.last24h - before.jobs.last24h, 2);
  assert.equal(after.jobs.last7d - before.jobs.last7d, 2);
  assert.equal(after.clips.total - before.clips.total, 1);
  assert.ok(Math.abs(after.processing.sourceMinutesProcessed - before.processing.sourceMinutesProcessed - 2) < 0.01);
  assert.equal(typeof after.processing.avgSeconds, 'number');
  assert.ok(after.processing.maxSeconds >= 4);
  assert.ok(after.jobs.failureRate > 0 && after.jobs.failureRate < 1);

  const job = await db.getJob(doneId);
  assert.equal(Number(job.processing_ms), 4000);
});
