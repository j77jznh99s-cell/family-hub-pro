const fs = require('fs/promises');
const path = require('path');
const { v4: uuid } = require('uuid');

const {
  CLIPS_DIR,
  CLIP_COUNT,
  DELETE_SOURCE_AFTER_PROCESSING,
  S3_BUCKET,
  OPENAI_API_KEY,
  BURN_IN_CAPTIONS,
  CLIP_ASPECT,
} = require('../config');
const ffmpeg = require('./ffmpeg');
const { buildCandidateSegments } = require('./segmenter');
const { analyzeSegments } = require('./claudeAnalyzer');
const { transcribe } = require('./transcription');
const { buildSrt } = require('./captions');
const storage = require('./storage');
const db = require('../db');

async function safeTranscribe(videoPath, audioPath) {
  if (!OPENAI_API_KEY) return null;
  try {
    return await transcribe(videoPath, audioPath);
  } catch (err) {
    // Transcription is an enhancement, not a requirement - a Whisper hiccup shouldn't
    // sink the job, it should just fall back to the original frame-only scoring.
    console.warn('[pipeline] transcription failed, falling back to frame-only scoring:', err.message);
    return null;
  }
}

async function processJob(jobId, videoPath) {
  const jobClipsDir = path.join(CLIPS_DIR, jobId);
  const framesDir = path.join(jobClipsDir, 'frames');
  const audioPath = path.join(jobClipsDir, 'audio.wav');
  const startedAt = Date.now();

  try {
    await db.updateJob(jobId, { status: 'processing', error: null });

    const duration = await ffmpeg.getDuration(videoPath);
    await db.updateJob(jobId, { duration_seconds: duration });

    await fs.mkdir(jobClipsDir, { recursive: true });

    const [silences, transcript] = await Promise.all([
      ffmpeg.detectSilences(videoPath),
      safeTranscribe(videoPath, audioPath),
    ]);
    const candidates = buildCandidateSegments(duration, silences);

    if (candidates.length === 0) {
      throw new Error('No usable segments were found in this video');
    }

    const scored = await analyzeSegments(videoPath, candidates, framesDir, transcript);
    const selected = [...scored].sort((a, b) => b.score - a.score).slice(0, CLIP_COUNT);
    // Re-sort chronologically so the dashboard lists clips in the order they appear in the source.
    selected.sort((a, b) => a.start - b.start);

    for (const segment of selected) {
      const clipId = uuid();
      const clipFile = `${clipId}.mp4`;
      const thumbFile = `${clipId}.jpg`;
      const clipPath = path.join(jobClipsDir, clipFile);
      const thumbPath = path.join(jobClipsDir, thumbFile);

      let subtitlesPath = null;
      if (transcript && BURN_IN_CAPTIONS) {
        const srt = buildSrt(transcript, segment.start, segment.end);
        if (srt) {
          subtitlesPath = path.join(jobClipsDir, `${clipId}.srt`);
          await fs.writeFile(subtitlesPath, srt, 'utf8');
        }
      }

      await ffmpeg.extractClip(videoPath, segment.start, segment.end, clipPath, {
        subtitlesPath,
        aspect: CLIP_ASPECT,
      });
      if (subtitlesPath) await fs.rm(subtitlesPath, { force: true });

      const clipKey = path.join(jobId, clipFile);
      await storage.store(clipPath, clipKey);

      let thumbnailKey = null;
      if (segment.thumbnailPath) {
        if (ffmpeg.parseAspect(CLIP_ASPECT)) {
          await ffmpeg.cropImage(segment.thumbnailPath, thumbPath, CLIP_ASPECT);
        } else {
          await fs.copyFile(segment.thumbnailPath, thumbPath);
        }
        thumbnailKey = path.join(jobId, thumbFile);
        await storage.store(thumbPath, thumbnailKey);
      }

      await db.insertClip({
        id: clipId,
        job_id: jobId,
        title: segment.title,
        description: segment.description,
        score: segment.score,
        start_time: segment.start,
        end_time: segment.end,
        file_path: clipKey,
        thumbnail_path: thumbnailKey,
      });
    }

    await db.updateJob(jobId, { status: 'complete', processing_ms: Date.now() - startedAt });

    if (S3_BUCKET) {
      // Every clip/thumbnail was uploaded to S3 and its local scratch copy removed -
      // the (now empty) local job directory served no purpose beyond that.
      await fs.rm(jobClipsDir, { recursive: true, force: true });
    }

    if (DELETE_SOURCE_AFTER_PROCESSING) {
      // Clips are already cut from it - the source video is the biggest file per job,
      // and disk on most deploy targets is limited/ephemeral. Safe to drop it now.
      await fs.rm(videoPath, { force: true });
    }
  } catch (err) {
    await db.updateJob(jobId, {
      status: 'failed',
      error: err.message,
      processing_ms: Date.now() - startedAt,
    });
    throw err;
  } finally {
    await fs.rm(framesDir, { recursive: true, force: true });
    await fs.rm(audioPath, { force: true });
  }
}

module.exports = { processJob };
