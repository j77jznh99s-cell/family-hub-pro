// Default queue driver - zero config, used whenever REDIS_URL is unset. Jobs live only
// in memory: fine for a single instance, but a crash/restart loses anything still queued
// (in-flight jobs are separately recovered as 'failed' by db.failStaleProcessingJobs).
// See queue/bullmq.js for the persistent, multi-instance-capable alternative.

const { MAX_CONCURRENT_JOBS } = require('../../config');
const { processJob } = require('../pipeline');

const pending = [];
let active = 0;

function pump() {
  while (active < MAX_CONCURRENT_JOBS && pending.length > 0) {
    const { jobId, videoPath } = pending.shift();
    active++;
    processJob(jobId, videoPath)
      .catch((err) => {
        console.error(`[job ${jobId}] processing failed:`, err);
      })
      .finally(() => {
        active--;
        pump();
      });
  }
}

function enqueue(jobId, videoPath) {
  pending.push({ jobId, videoPath });
  pump();
}

function stats() {
  return { active, queued: pending.length };
}

module.exports = { enqueue, stats };
