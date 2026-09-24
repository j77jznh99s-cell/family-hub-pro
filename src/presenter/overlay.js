// Burns text onto a rendered presenter video: short key-fact callouts at the top
// (script.on_screen_text, spread across the video) and captions at the bottom.
// Captions use HeyGen's own timed SRT when the render provided one; otherwise they're
// estimated by spreading the script's words across the video at an even speaking pace.
const fs = require('fs/promises');
const path = require('path');
const { execFile } = require('child_process');
const { promisify } = require('util');
const ffmpeg = require('../services/ffmpeg');

const execFileAsync = promisify(execFile);

// Split the script into caption-sized chunks and time each by its share of the words.
function estimateCaptionSegments(script, duration, { wordsPerChunk = 6 } = {}) {
  const words = script.split(/\s+/).filter(Boolean);
  if (!words.length || !(duration > 0)) return [];
  const perWord = duration / words.length;
  const segments = [];
  for (let i = 0; i < words.length; i += wordsPerChunk) {
    const chunk = words.slice(i, i + wordsPerChunk);
    segments.push({ start: i * perWord, end: Math.min(duration, (i + chunk.length) * perWord), text: chunk.join(' ') });
  }
  return segments;
}

// Spread the callouts evenly across the video after the first couple of seconds (the
// hook), each shown for most of its slot so consecutive callouts don't overlap.
function calloutSegments(items, duration, { skipStart = 2, gap = 0.4 } = {}) {
  const texts = (items || []).map((t) => String(t).trim()).filter(Boolean);
  if (!texts.length || duration <= skipStart + 1) return [];
  const slot = (duration - skipStart) / texts.length;
  return texts.map((text, i) => ({
    start: skipStart + i * slot,
    end: skipStart + (i + 1) * slot - gap,
    text: text.toUpperCase(),
  }));
}

function assTime(seconds) {
  const cs = Math.max(0, Math.round(seconds * 100));
  const h = Math.floor(cs / 360000);
  const m = Math.floor((cs % 360000) / 6000);
  const sec = Math.floor((cs % 6000) / 100);
  return `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}.${String(cs % 100).padStart(2, '0')}`;
}

function assText(text) {
  // Braces start ASS override tags; newlines become hard breaks.
  return String(text).replace(/[{}]/g, '').replace(/\r?\n/g, '\\N');
}

// Minimal SRT parser for HeyGen's caption file.
function parseSrt(srt) {
  const toSec = (t) => {
    const [hms, ms] = t.trim().split(',');
    const [h, m, sec] = hms.split(':').map(Number);
    return h * 3600 + m * 60 + sec + Number(ms || 0) / 1000;
  };
  return srt
    .replace(/\r/g, '')
    .split(/\n\s*\n/)
    .map((block) => {
      const lines = block.trim().split('\n');
      const timeIdx = lines.findIndex((l) => l.includes('-->'));
      if (timeIdx === -1) return null;
      const [a, b] = lines[timeIdx].split('-->');
      return { start: toSec(a), end: toSec(b), text: lines.slice(timeIdx + 1).join('\n') };
    })
    .filter((s) => s && s.text && s.end > s.start);
}

// One ASS file with two styles, laid out in real pixels (PlayRes = video size) so the
// positions hold on a 1080x1920 vertical video: callouts in a box near the top, captions
// above the bottom area that platforms cover with their own UI.
function buildAss({ width, height, callouts, captions }) {
  const scale = height / 1920;
  const px = (n) => Math.round(n * scale);
  const header = [
    '[Script Info]',
    'ScriptType: v4.00+',
    `PlayResX: ${width}`,
    `PlayResY: ${height}`,
    'WrapStyle: 0',
    'ScaledBorderAndShadow: yes',
    '',
    '[V4+ Styles]',
    'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding',
    `Style: Callout,DejaVu Sans,${px(76)},&H00FFFFFF,&H00FFFFFF,&H99000000,&H99000000,-1,0,0,0,100,100,0,0,3,${px(18)},0,8,${px(80)},${px(80)},${px(300)},1`,
    `Style: Caption,DejaVu Sans,${px(60)},&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,1,${px(5)},0,2,${px(90)},${px(90)},${px(420)},1`,
    '',
    '[Events]',
    'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text',
  ];
  const events = [
    ...callouts.map((c) => `Dialogue: 1,${assTime(c.start)},${assTime(c.end)},Callout,,0,0,0,,${assText(c.text)}`),
    ...captions.map((c) => `Dialogue: 0,${assTime(c.start)},${assTime(c.end)},Caption,,0,0,0,,${assText(c.text)}`),
  ];
  return [...header, ...events].join('\n') + '\n';
}

async function videoInfo(file) {
  const { stdout } = await execFileAsync(
    'ffprobe',
    ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height:format=duration', '-of', 'json', file],
    { maxBuffer: ffmpeg.MAX_BUFFER }
  );
  const j = JSON.parse(stdout);
  return { width: j.streams[0].width, height: j.streams[0].height, duration: parseFloat(j.format.duration) };
}

async function burnText(runDir, { captionSrtPath, outName = 'video.captioned.mp4', log = () => {} } = {}) {
  const script = JSON.parse(await fs.readFile(path.join(runDir, 'script.json'), 'utf8'));
  const input = path.join(runDir, 'video.mp4');
  const output = path.join(runDir, outName);
  const { width, height, duration } = await videoInfo(input);

  const captions = captionSrtPath
    ? parseSrt(await fs.readFile(captionSrtPath, 'utf8'))
    : estimateCaptionSegments(script.script || '', duration);
  const callouts = calloutSegments(script.on_screen_text, duration);
  if (!captions.length && !callouts.length) throw new Error('Nothing to burn in: script has no on-screen text or words');

  const assPath = path.join(runDir, 'overlay.ass');
  await fs.writeFile(assPath, buildAss({ width, height, callouts, captions }), 'utf8');
  await execFileAsync(
    ffmpeg.FFMPEG_PATH,
    ['-y', '-i', input, '-vf', `ass=${ffmpeg.escapeForFilterPath(assPath)}`, '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20', '-c:a', 'copy', '-movflags', '+faststart', output],
    { maxBuffer: ffmpeg.MAX_BUFFER }
  );
  log(`[presenter] burned text -> ${output}`);
  return output;
}

module.exports = { burnText, estimateCaptionSegments, calloutSegments, buildAss, parseSrt, assTime };
