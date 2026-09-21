const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuid } = require('uuid');

const { UPLOAD_DIR, MAX_UPLOAD_MB } = require('../config');
const db = require('../db');
const { processJob } = require('../services/pipeline');

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

router.post('/', (req, res) => {
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

    // Fire and forget: the client polls GET /api/jobs/:id for progress.
    processJob(jobId, req.file.path).catch((err) => {
      console.error(`[job ${jobId}] processing failed:`, err);
    });

    res.status(202).json({ jobId });
  });
});

module.exports = router;
