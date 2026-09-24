// Runs the real pipeline (ffprobe -> silencedetect -> segment -> frames -> cut -> crop)
// against a generated video. Skipped when ffmpeg isn't installed; CI installs it.
// ANTHROPIC_API_KEY/OPENAI_API_KEY are cleared so scoring takes the offline fallback path
// and no network calls are made - this checks the ffmpeg plumbing, not Claude's picks.
const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');
const { execFileSync } = require('node:child_process');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'clipdetect-pipeline-test-'));
Object.assign(process.env, {
  DATA_DIR: path.join(tmp, 'data'),
  CLIPS_DIR: path.join(tmp, 'clips'),
  UPLOAD_DIR: path.join(tmp, 'uploads'),
  CLIP_ASPECT: '9:16',
  CLIP_COUNT: '2',
  DELETE_SOURCE_AFTER_PROCESSING: 'false',
});
delete process.env.ANTHROPIC_API_KEY;
delete process.env.OPENAI_API_KEY;
delete process.env.DATABASE_URL;
delete process.env.S3_BUCKET;

let hasFfmpeg = true;
try {
  execFileSync('ffmpeg', ['-version'], { stdio: 'ignore' });
  execFileSync('ffprobe', ['-version'], { stdio: 'ignore' });
} catch {
  hasFfmpeg = false;
}

after(() => fs.rmSync(tmp, { recursive: true, force: true }));

function probeSize(file) {
  const out = execFileSync('ffprobe', [
    '-v', 'error', '-select_streams', 'v:0',
    '-show_entries', 'stream=width,height', '-of', 'csv=p=0', file,
  ]).toString().trim();
  const [width, height] = out.split(',').map(Number);
  return { width, height };
}

test('processJob cuts vertical clips and thumbnails from a real video', { skip: !hasFfmpeg && 'ffmpeg not installed' }, async () => {
  fs.mkdirSync(process.env.UPLOAD_DIR, { recursive: true });
  const source = path.join(process.env.UPLOAD_DIR, 'source.mp4');
  // 60s of 1280x720 test pattern with a tone that drops out every 20s, so silencedetect
  // has real pauses to split on.
  execFileSync('ffmpeg', [
    '-loglevel', 'error', '-y',
    '-f', 'lavfi', '-i', 'testsrc=size=1280x720:rate=24:duration=60',
    '-f', 'lavfi', '-i', "sine=frequency=440:duration=60",
    '-af', "volume='if(lt(mod(t,20),18),1,0)':eval=frame",
    '-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'aac', '-shortest', source,
  ]);

  const db = require('../src/db');
  const { processJob } = require('../src/services/pipeline');
  const ffmpeg = require('../src/services/ffmpeg');

  const probe = await ffmpeg.probeMedia(source);
  assert.equal(ffmpeg.describeProbeProblem(probe), null);

  const jobId = 'pipeline-it';
  await db.createJob({ id: jobId, originalName: 'source.mp4', storedPath: source });
  await processJob(jobId, source);

  const job = await db.getJob(jobId);
  assert.equal(job.status, 'complete', job.error || '');
  assert.ok(Math.abs(job.duration_seconds - 60) < 1);
  assert.ok(job.processing_ms > 0);

  const clips = await db.getClipsForJob(jobId);
  assert.ok(clips.length >= 1 && clips.length <= 2, `expected 1-2 clips, got ${clips.length}`);

  for (const clip of clips) {
    const clipFile = path.join(process.env.CLIPS_DIR, clip.file_path);
    const { width, height } = probeSize(clipFile);
    assert.equal(height, 720);
    assert.equal(width, 404); // 720 * 9/16 = 405, rounded down to even
    assert.equal(width % 2, 0);

    assert.ok(clip.thumbnail_path, 'clip should have a thumbnail');
    const thumb = probeSize(path.join(process.env.CLIPS_DIR, clip.thumbnail_path));
    assert.ok(Math.abs(thumb.width / thumb.height - 9 / 16) < 0.02, `thumbnail ${thumb.width}x${thumb.height} is not 9:16`);
    assert.equal(thumb.height, 640); // full-res source frame, scaled down from 720 - not the 270px scoring frame
  }

  const stats = await db.getStats();
  assert.equal(stats.jobs.byStatus.complete, 1);
  assert.equal(stats.clips.total, clips.length);
});
