// Default storage driver - zero config, used whenever S3_BUCKET is unset. ffmpeg already
// wrote the clip/thumbnail to its final location under CLIPS_DIR, so "storing" it is a
// no-op; the DB "key" is just its path relative to CLIPS_DIR.
const fs = require('fs');
const path = require('path');
const { CLIPS_DIR } = require('../../config');

function resolveSafePath(key) {
  const resolved = path.resolve(CLIPS_DIR, key);
  if (!resolved.startsWith(path.resolve(CLIPS_DIR) + path.sep)) {
    return null; // path traversal guard
  }
  return resolved;
}

async function store(localPath, key) {
  return key;
}

async function getServeInfo(key, _opts) {
  const filePath = resolveSafePath(key);
  if (!filePath || !fs.existsSync(filePath)) return null;
  return { type: 'file', path: filePath };
}

module.exports = { store, getServeInfo };
