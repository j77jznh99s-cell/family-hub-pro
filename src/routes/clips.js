const express = require('express');

const storage = require('../services/storage');
const db = require('../db');

const router = express.Router({ mergeParams: true });

async function loadClip(req, res, next) {
  try {
    const clip = await db.getClip(req.params.jobId, req.params.clipId);
    if (!clip) return res.status(404).json({ error: 'Clip not found' });
    req.clip = clip;
    next();
  } catch (err) {
    next(err);
  }
}

// Local backend serves the file directly; S3 backend redirects to a short-lived
// presigned URL so bytes flow straight from the bucket instead of through this server.
// downloadFilename forces an attachment (clip downloads); its absence keeps the
// response inline, matching the original behavior for thumbnails (<img src>).
async function serve(res, key, opts) {
  if (!key) return res.status(404).json({ error: 'Not found' });
  const info = await storage.getServeInfo(key, opts);
  if (!info) return res.status(404).json({ error: 'Not found' });
  if (info.type === 'redirect') return res.redirect(302, info.url);
  if (opts?.downloadFilename) return res.download(info.path, opts.downloadFilename);
  return res.sendFile(info.path);
}

router.get('/:clipId/file', loadClip, async (req, res, next) => {
  try {
    const safeName = `${(req.clip.title || 'clip').replace(/[^a-z0-9-_ ]/gi, '').trim() || 'clip'}.mp4`;
    await serve(res, req.clip.file_path, { downloadFilename: safeName });
  } catch (err) {
    next(err);
  }
});

router.get('/:clipId/thumbnail', loadClip, async (req, res, next) => {
  try {
    await serve(res, req.clip.thumbnail_path);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
