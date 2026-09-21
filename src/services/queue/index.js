// Dispatches to queue/bullmq.js when REDIS_URL is set, queue/inProcess.js otherwise.
// Both drivers export the same enqueue(jobId, videoPath) / stats() functions.
const { REDIS_URL } = require('../../config');

module.exports = REDIS_URL ? require('./bullmq') : require('./inProcess');
