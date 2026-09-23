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

// Stream-level summary of a media file. Throws if ffprobe can't parse it at all
// (corrupt/truncated/not media) - callers treat that as "not a usable video".
async function probeMedia(filePath) {
  const { stdout } = await execFileAsync(
    FFPROBE_PATH,
    [
      '-v',
      'error',
      '-show_entries',
      'format=duration:stream=codec_type,codec_name,width,height:stream_disposition=attached_pic',
      '-of',
      'json',
      filePath,
    ],
    { maxBuffer: MAX_BUFFER }
  );
  return summarizeProbe(JSON.parse(stdout));
}

function summarizeProbe(parsed) {
  const streams = parsed?.streams || [];
  // Album art in an audio file (mp3/m4a) shows up as a one-frame "video" stream.
  const video = streams.find((s) => s.codec_type === 'video' && !s.disposition?.attached_pic);
  const duration = parseFloat(parsed?.format?.duration);
  return {
    duration: Number.isFinite(duration) ? duration : null,
    hasVideo: Boolean(video),
    hasAudio: streams.some((s) => s.codec_type === 'audio'),
    videoCodec: video?.codec_name || null,
    width: video?.width || null,
    height: video?.height || null,
  };
}

// Returns a client-facing reason the file can't be processed, or null if it's usable.
function describeProbeProblem(probe) {
  if (!probe.hasVideo) return 'This file has no video track - upload a video file';
  if (!probe.duration || probe.duration <= 0) {
    return 'Could not read the length of this video - it may be corrupt or still encoding';
  }
  if (!probe.width || !probe.height) return 'Could not read the dimensions of this video';
  return null;
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

// ffmpeg's filtergraph syntax treats ':' and other characters as special inside a
// filename argument (e.g. subtitles=path) - escape them so a normal path never breaks
// the filter string. Not a security boundary (paths here are always ones we generated).
function escapeForFilterPath(filePath) {
  return filePath.replace(/\\/g, '\\\\').replace(/:/g, '\\:').replace(/'/g, "\\'");
}

// Parses "W:H" (e.g. "9:16") into a width/height ratio, or null for unset/invalid -
// null means "keep the source aspect ratio", which is the default.
function parseAspect(aspect) {
  const match = /^\s*(\d+(?:\.\d+)?)\s*:\s*(\d+(?:\.\d+)?)\s*$/.exec(aspect || '');
  if (!match) return null;
  const w = parseFloat(match[1]);
  const h = parseFloat(match[2]);
  if (!(w > 0 && h > 0)) return null;
  return w / h;
}

// Center-crops to the target ratio using the largest window that fits the source frame
// (never upscales). Dimensions are rounded down to even numbers since libx264 requires it.
// Commas are escaped because they'd otherwise split the filtergraph.
function buildCropFilter(ratio) {
  const r = ratio.toFixed(6);
  return `crop=w='trunc(min(iw\\,ih*${r})/2)*2':h='trunc(min(ih\\,iw/${r})/2)*2'`;
}

// Crop runs before subtitles so captions are laid out for the final frame size rather
// than being cut off at the edges of a vertical crop.
function buildVideoFilters({ aspect, subtitlesPath } = {}) {
  const filters = [];
  const ratio = parseAspect(aspect);
  if (ratio) filters.push(buildCropFilter(ratio));
  if (subtitlesPath) {
    filters.push(
      `subtitles=${escapeForFilterPath(subtitlesPath)}:force_style='FontSize=20,PrimaryColour=&HFFFFFF,OutlineColour=&H000000,BorderStyle=1,Outline=2,Alignment=2'`
    );
  }
  return filters.length ? filters.join(',') : null;
}

async function extractClip(filePath, startSeconds, endSeconds, outPath, { subtitlesPath, aspect } = {}) {
  const duration = Math.max(0.1, endSeconds - startSeconds);
  const args = [
    '-y',
    '-ss',
    String(Math.max(0, startSeconds)),
    '-i',
    filePath,
    '-t',
    String(duration),
  ];

  const videoFilters = buildVideoFilters({ aspect, subtitlesPath });
  if (videoFilters) args.push('-vf', videoFilters);

  args.push(
    '-c:v',
    'libx264',
    '-preset',
    'veryfast',
    '-c:a',
    'aac',
    '-movflags',
    '+faststart',
    outPath
  );

  await execFileAsync(FFMPEG_PATH, args, { maxBuffer: MAX_BUFFER });
}

// Writes a copy of a still image, center-cropped to the given aspect ratio - keeps a
// clip's thumbnail the same shape as the clip itself when CLIP_ASPECT is set.
async function cropImage(inPath, outPath, aspect) {
  const ratio = parseAspect(aspect);
  if (!ratio) throw new Error(`Invalid aspect ratio: ${aspect}`);
  await execFileAsync(
    FFMPEG_PATH,
    ['-y', '-i', inPath, '-vf', buildCropFilter(ratio), '-q:v', '4', outPath],
    { maxBuffer: MAX_BUFFER }
  );
}

// Mono 16kHz WAV - small, and exactly what Whisper-family transcription APIs expect.
// No extra codec needed (pcm_s16le is always built into ffmpeg), unlike mp3/aac.
async function extractAudio(filePath, outPath) {
  await execFileAsync(
    FFMPEG_PATH,
    ['-y', '-i', filePath, '-vn', '-ac', '1', '-ar', '16000', '-c:a', 'pcm_s16le', outPath],
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
  probeMedia,
  summarizeProbe,
  describeProbeProblem,
  detectSilences,
  extractFrame,
  extractClip,
  extractAudio,
  cropImage,
  checkAvailable,
  parseAspect,
  buildVideoFilters,
};
