const express = require('express');
const db = require('../db');

const router = express.Router();

function serializeClip(clip) {
  return {
    id: clip.id,
    title: clip.title,
    description: clip.description,
    score: clip.score,
    startTime: clip.start_time,
    endTime: clip.end_time,
    downloadUrl: `/api/jobs/${clip.job_id}/clips/${clip.id}/file`,
    thumbnailUrl: clip.thumbnail_path
      ? `/api/jobs/${clip.job_id}/clips/${clip.id}/thumbnail`
      : null,
  };
}

function serializeJob(job) {
  return {
    id: job.id,
    originalName: job.original_name,
    status: job.status,
    durationSeconds: job.duration_seconds,
    error: job.error,
    createdAt: job.created_at,
    updatedAt: job.updated_at,
  };
}

router.get('/', async (req, res, next) => {
  try {
    const jobs = await db.listJobs();
    res.json(jobs.map(serializeJob));
  } catch (err) {
    next(err);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const job = await db.getJob(req.params.id);
    if (!job) return res.status(404).json({ error: 'Job not found' });

    const clips = (await db.getClipsForJob(job.id)).map(serializeClip);
    res.json({ ...serializeJob(job), clips });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
