const fs = require('fs/promises');
const path = require('path');
const { v4: uuid } = require('uuid');

const { CLIPS_DIR, CLIP_COUNT, DELETE_SOURCE_AFTER_PROCESSING } = require('../config');
const ffmpeg = require('./ffmpeg');
const { buildCandidateSegments } = require('./segmenter');
const { analyzeSegments } = require('./claudeAnalyzer');
const db = require('../db');

async function processJob(jobId, videoPath) {
  const jobClipsDir = path.join(CLIPS_DIR, jobId);
  const framesDir = path.join(jobClipsDir, 'frames');

  try {
    db.updateJob(jobId, { status: 'processing', error: null });

    const duration = await ffmpeg.getDuration(videoPath);
    db.updateJob(jobId, { duration_seconds: duration });

    const silences = await ffmpeg.detectSilences(videoPath);
    const candidates = buildCandidateSegments(duration, silences);

    if (candidates.length === 0) {
      throw new Error('No usable segments were found in this video');
    }

    const scored = await analyzeSegments(videoPath, candidates, framesDir);
    const selected = [...scored].sort((a, b) => b.score - a.score).slice(0, CLIP_COUNT);
    // Re-sort chronologically so the dashboard lists clips in the order they appear in the source.
    selected.sort((a, b) => a.start - b.start);

    await fs.mkdir(jobClipsDir, { recursive: true });

    for (const segment of selected) {
      const clipId = uuid();
      const clipFile = `${clipId}.mp4`;
      const thumbFile = `${clipId}.jpg`;
      const clipPath = path.join(jobClipsDir, clipFile);
      const thumbPath = path.join(jobClipsDir, thumbFile);

      await ffmpeg.extractClip(videoPath, segment.start, segment.end, clipPath);
      if (segment.thumbnailPath) {
        await fs.copyFile(segment.thumbnailPath, thumbPath);
      }

      db.insertClip({
        id: clipId,
        job_id: jobId,
        title: segment.title,
        description: segment.description,
        score: segment.score,
        start_time: segment.start,
        end_time: segment.end,
        file_path: path.join(jobId, clipFile),
        thumbnail_path: segment.thumbnailPath ? path.join(jobId, thumbFile) : null,
      });
    }

    db.updateJob(jobId, { status: 'complete' });

    if (DELETE_SOURCE_AFTER_PROCESSING) {
      // Clips are already cut from it - the source video is the biggest file per job,
      // and disk on most deploy targets is limited/ephemeral. Safe to drop it now.
      await fs.rm(videoPath, { force: true });
    }
  } catch (err) {
    db.updateJob(jobId, { status: 'failed', error: err.message });
    throw err;
  } finally {
    await fs.rm(framesDir, { recursive: true, force: true });
  }
}

module.exports = { processJob };
