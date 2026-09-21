const { execFile } = require('child_process');
const { promisify } = require('util');

const execFileAsync = promisify(execFile);

const FFMPEG_PATH = process.env.FFMPEG_PATH || 'ffmpeg';
const FFPROBE_PATH = process.env.FFPROBE_PATH || 'ffprobe';

const MAX_BUFFER = 1024 * 1024 * 50; // 50MB of stdout/stderr, ffmpeg logs can be chatty

async function getDuration(filePath) {
  const { stdout } = await execFileAsync(
    FFPROBE_PATH,
    ['-v', 'error', '-show_entries', 'format=duration', '-of', 'json', filePath],
    { maxBuffer: MAX_BUFFER }
  );
  const parsed = JSON.parse(stdout);
  const duration = parseFloat(parsed?.format?.duration);
  if (!Number.isFinite(duration)) {
    throw new Error('Could not determine video duration');
  }
  return duration;
}

// Runs silencedetect and returns [{start, end}] gaps of silence in the audio track.
async function detectSilences(filePath, { noiseDb = -30, minSilenceDuration = 0.6 } = {}) {
  let stderr = '';
  try {
    await execFileAsync(
      FFMPEG_PATH,
      [
        '-i',
        filePath,
        '-af',
        `silencedetect=noise=${noiseDb}dB:d=${minSilenceDuration}`,
        '-f',
        'null',
        '-',
      ],
      { maxBuffer: MAX_BUFFER }
    );
  } catch (err) {
    // ffmpeg with -f null exits non-zero on some inputs even though it produced usable logs;
    // the silencedetect output lives in stderr either way.
    stderr = err.stderr || '';
    if (!stderr) throw err;
  }

  const silences = [];
  let pendingStart = null;
  const startRe = /silence_start:\s*([0-9.]+)/;
  const endRe = /silence_end:\s*([0-9.]+)/;

  for (const line of stderr.split('\n')) {
    const startMatch = line.match(startRe);
    if (startMatch) {
      pendingStart = parseFloat(startMatch[1]);
      continue;
    }
    const endMatch = line.match(endRe);
    if (endMatch && pendingStart !== null) {
      silences.push({ start: pendingStart, end: parseFloat(endMatch[1]) });
      pendingStart = null;
    }
  }
  return silences;
}

async function extractFrame(filePath, timestampSeconds, outPath, { width = 480 } = {}) {
  await execFileAsync(
    FFMPEG_PATH,
    [
      '-y',
      '-ss',
      String(Math.max(0, timestampSeconds)),
      '-i',
      filePath,
      '-frames:v',
      '1',
      '-vf',
      `scale=${width}:-2`,
      '-q:v',
      '4',
      outPath,
    ],
    { maxBuffer: MAX_BUFFER }
  );
}

async function extractClip(filePath, startSeconds, endSeconds, outPath) {
  const duration = Math.max(0.1, endSeconds - startSeconds);
  await execFileAsync(
    FFMPEG_PATH,
    [
      '-y',
      '-ss',
      String(Math.max(0, startSeconds)),
      '-i',
      filePath,
      '-t',
      String(duration),
      '-c:v',
      'libx264',
      '-preset',
      'veryfast',
      '-c:a',
      'aac',
      '-movflags',
      '+faststart',
      outPath,
    ],
    { maxBuffer: MAX_BUFFER }
  );
}

// Checked once at server startup so a missing ffmpeg/ffprobe fails loudly at boot
// instead of surfacing as a confusing ENOENT deep inside a client's job.
async function checkAvailable() {
  const missing = [];
  for (const [name, bin] of [['ffmpeg', FFMPEG_PATH], ['ffprobe', FFPROBE_PATH]]) {
    try {
      await execFileAsync(bin, ['-version'], { maxBuffer: MAX_BUFFER });
    } catch {
      missing.push(name);
    }
  }
  return missing;
}

module.exports = {
  getDuration,
  detectSilences,
  extractFrame,
  extractClip,
  checkAvailable,
};
