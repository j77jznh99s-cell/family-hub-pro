// Exercises whichever queue driver is active (in-process by default, BullMQ when
// REDIS_URL is set - see src/services/queue/index.js) end-to-end: enqueue a job and
// confirm it actually gets processed (the pipeline fails fast on the nonexistent source
// file - that's fine, it's the queue mechanics being verified here, not the pipeline
// itself, which tests/pipeline.integration.test.js covers).
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');

const tmpDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'clipdetect-queue-test-'));
process.env.DATA_DIR = tmpDataDir;

const db = require('../src/db');
const { enqueue } = require('../src/services/queue');

after(() => {
  fs.rmSync(tmpDataDir, { recursive: true, force: true });
});

async function waitForStatus(jobId, { timeoutMs = 10000 } = {}) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const job = await db.getJob(jobId);
    if (job.status === 'complete' || job.status === 'failed') return job;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`Timed out waiting for job ${jobId} to finish (still processing/queued)`);
}

test('enqueue eventually runs the job through the pipeline', async () => {
  const jobId = `queue-test-${Date.now()}`;
  await db.createJob({ id: jobId, originalName: 'x.mp4', storedPath: '/nonexistent/x.mp4' });

  await enqueue(jobId, '/nonexistent/x.mp4');

  const job = await waitForStatus(jobId);
  // Missing source file (or missing ffmpeg) both surface as a failure with a message -
  // the point is the queue actually drove it to a terminal state, not what the message says.
  assert.equal(job.status, 'failed');
  assert.ok(job.error);
});
