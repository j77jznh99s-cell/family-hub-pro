const express = require('express');
const path = require('path');
const fs = require('fs');

const { CLIPS_DIR } = require('../config');
const db = require('../db');

const router = express.Router({ mergeParams: true });

function resolveSafePath(relativePath) {
  const resolved = path.resolve(CLIPS_DIR, relativePath);
  if (!resolved.startsWith(path.resolve(CLIPS_DIR) + path.sep)) {
    return null; // path traversal guard
  }
  return resolved;
}

function loadClip(req, res, next) {
  const clip = db.getClip(req.params.jobId, req.params.clipId);
  if (!clip) return res.status(404).json({ error: 'Clip not found' });
  req.clip = clip;
  next();
}

router.get('/:clipId/file', loadClip, (req, res) => {
  const filePath = resolveSafePath(req.clip.file_path);
  if (!filePath || !fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'Clip file not found' });
  }
  const safeName = `${(req.clip.title || 'clip').replace(/[^a-z0-9-_ ]/gi, '').trim() || 'clip'}.mp4`;
  res.download(filePath, safeName);
});

router.get('/:clipId/thumbnail', loadClip, (req, res) => {
  if (!req.clip.thumbnail_path) return res.status(404).json({ error: 'No thumbnail' });
  const filePath = resolveSafePath(req.clip.thumbnail_path);
  if (!filePath || !fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'Thumbnail not found' });
  }
  res.sendFile(filePath);
});

module.exports = router;
