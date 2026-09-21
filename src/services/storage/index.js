// Dispatches to storage/s3.js when S3_BUCKET is set, storage/local.js otherwise. Both
// drivers export the same store(localPath, key) / getServeInfo(key) functions. `key` is
// always a path relative to CLIPS_DIR (e.g. "<jobId>/<clipId>.mp4"), independent of
// which backend actually holds the bytes.
const { S3_BUCKET } = require('../../config');

module.exports = S3_BUCKET ? require('./s3') : require('./local');
