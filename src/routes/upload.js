const express = require('express');
const multer = require('multer');
const rateLimit = require('express-rate-limit');
const path = require('path');
const fs = require('fs');
const { v4: uuid } = require('uuid');

const { UPLOAD_DIR, MAX_UPLOAD_MB, UPLOAD_RATE_LIMIT_PER_HOUR, STRIPE_SECRET_KEY } = require('../config');
const db = require('../db');
const { enqueue } = require('../services/queue');
const ffmpeg = require('../services/ffmpeg');

const uploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: UPLOAD_RATE_LIMIT_PER_HOUR,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many uploads from this client - try again later' },
});

fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const diskStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.mp4';
    cb(null, `${uuid()}${ext}`);
  },
});

const upload = multer({
  storage: diskStorage,
  limits: { fileSize: MAX_UPLOAD_MB * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (!file.mimetype.startsWith('video/')) {
      return cb(new Error('Only video files are accepted'));
    }
    cb(null, true);
  },
});

const router = express.Router();

router.post('/', uploadLimiter, (req, res, next) => {
  upload.single('video')(req, res, async (err) => {
    if (err) {
      return res.status(400).json({ error: err.message });
    }
    if (!req.file) {
      return res.status(400).json({ error: 'No video file was uploaded (field name: video)' });
    }

    try {
      // Checked before spending a credit or queueing a job: a mislabeled, audio-only, or
      // corrupt file gets a clear 400 now instead of a vague failed job a minute later.
      let problem;
      try {
        problem = ffmpeg.describeProbeProblem(await ffmpeg.probeMedia(req.file.path));
      } catch {
        problem = 'This file could not be read as a video - it may be corrupt or an unsupported format';
      }
      if (problem) {
        await fs.promises.rm(req.file.path, { force: true });
        return res.status(400).json({ error: problem });
      }

      if (STRIPE_SECRET_KEY) {
        const accountId = req.body?.accountId || req.query.accountId;
        if (!accountId) {
          await fs.promises.rm(req.file.path, { force: true });
          return res.status(400).json({ error: 'accountId is required' });
        }
        const spent = await db.spendCreditIfAvailable(accountId);
        if (!spent) {
          await fs.promises.rm(req.file.path, { force: true });
          return res.status(402).json({
            error: 'No credits remaining for this account. Buy more via POST /api/billing/checkout.',
          });
        }
      }

      const jobId = uuid();
      await db.createJob({
        id: jobId,
        originalName: req.file.originalname,
        storedPath: req.file.path,
      });

      // Queued, not fired directly: the client polls GET /api/jobs/:id for progress.
      await enqueue(jobId, req.file.path);

      res.status(202).json({ jobId });
    } catch (dbErr) {
      next(dbErr);
    }
  });
});

module.exports = router;
