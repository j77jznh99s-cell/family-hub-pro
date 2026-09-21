// Small in-process job queue. Uploads fire fast (multer already wrote the file to disk),
// but the actual ffmpeg + Claude pipeline is heavy - without this, N simultaneous uploads
// would kick off N concurrent ffmpeg processes and Claude requests on what's usually a
// single small instance. MAX_CONCURRENT_JOBS keeps that bounded (default: 1 at a time).

const { MAX_CONCURRENT_JOBS } = require('../config');
const { processJob } = require('./pipeline');

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
