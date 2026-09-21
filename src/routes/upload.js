const express = require('express');
const multer = require('multer');
const rateLimit = require('express-rate-limit');
const path = require('path');
const fs = require('fs');
const { v4: uuid } = require('uuid');

const { UPLOAD_DIR, MAX_UPLOAD_MB, UPLOAD_RATE_LIMIT_PER_HOUR } = require('../config');
const db = require('../db');
const { enqueue } = require('../services/queue');

const uploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: UPLOAD_RATE_LIMIT_PER_HOUR,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many uploads from this client - try again later' },
});

fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.mp4';
    cb(null, `${uuid()}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: MAX_UPLOAD_MB * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (!file.mimetype.startsWith('video/')) {
      return cb(new Error('Only video files are accepted'));
    }
    cb(null, true);
  },
});

const router = express.Router();

router.post('/', uploadLimiter, (req, res) => {
  upload.single('video')(req, res, (err) => {
    if (err) {
      return res.status(400).json({ error: err.message });
    }
    if (!req.file) {
      return res.status(400).json({ error: 'No video file was uploaded (field name: video)' });
    }

    const jobId = uuid();
    db.createJob({
      id: jobId,
      originalName: req.file.originalname,
      storedPath: req.file.path,
    });

    // Queued, not fired directly: the client polls GET /api/jobs/:id for progress.
    enqueue(jobId, req.file.path);

    res.status(202).json({ jobId });
  });
});

module.exports = router;
