// Used instead of queue/inProcess.js whenever REDIS_URL is set. Jobs are persisted in
// Redis, so they survive a process crash/restart, and - because BullMQ workers across
// multiple instances coordinate through the same Redis queue - this is what actually
// lets the app scale horizontally (in-process queue is strictly single-instance).
const { Queue, Worker } = require('bullmq');
const IORedis = require('ioredis');

const { REDIS_URL, MAX_CONCURRENT_JOBS } = require('../../config');
const { processJob } = require('../pipeline');

const QUEUE_NAME = 'clip-processing';

// BullMQ blocks on Redis commands and needs this disabled to avoid its own retry logic
// fighting with ioredis's.
const connection = new IORedis(REDIS_URL, { maxRetriesPerRequest: null });

const queue = new Queue(QUEUE_NAME, { connection });

const worker = new Worker(
  QUEUE_NAME,
  async (job) => {
    const { jobId, videoPath } = job.data;
    await processJob(jobId, videoPath);
  },
  { connection, concurrency: MAX_CONCURRENT_JOBS }
);

worker.on('failed', (job, err) => {
  // processJob already records the failure on the job row itself - this is just
  // process-level visibility, matching the in-process queue driver's behavior.
  console.error(`[job ${job?.data?.jobId}] processing failed:`, err.message);
});

async function enqueue(jobId, videoPath) {
  await queue.add(
    'process',
    { jobId, videoPath },
    { removeOnComplete: true, removeOnFail: 100 }
  );
}

async function stats() {
  const counts = await queue.getJobCounts('active', 'waiting');
  return { active: counts.active, queued: counts.waiting };
}

module.exports = { enqueue, stats };
