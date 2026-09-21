const path = require('path');

const ROOT = path.join(__dirname, '..');

module.exports = {
  UPLOAD_DIR: process.env.UPLOAD_DIR || path.join(ROOT, 'uploads'),
  CLIPS_DIR: process.env.CLIPS_DIR || path.join(ROOT, 'clips'),
  MAX_UPLOAD_MB: parseInt(process.env.MAX_UPLOAD_MB || '2048', 10),
  CLIP_COUNT: parseInt(process.env.CLIP_COUNT || '4', 10),
  ACCESS_TOKEN: process.env.ACCESS_TOKEN || '',
  PORT: parseInt(process.env.PORT || '3000', 10),
};
