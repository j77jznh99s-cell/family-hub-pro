const { test } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');
const { execFileSync } = require('node:child_process');
const overlay = require('../src/presenter/overlay');

let hasFfmpeg = true;
try {
  execFileSync('ffmpeg', ['-version'], { stdio: 'ignore' });
} catch {
  hasFfmpeg = false;
}

test('estimateCaptionSegments covers the whole video in order', () => {
  const words = Array.from({ length: 30 }, (_, i) => `w${i}`).join(' ');
  const segs = overlay.estimateCaptionSegments(words, 12, { wordsPerChunk: 6 });
  assert.equal(segs.length, 5);
  assert.equal(segs[0].start, 0);
  assert.ok(Math.abs(segs.at(-1).end - 12) < 1e-9);
  for (let i = 1; i < segs.length; i++) assert.ok(segs[i].start >= segs[i - 1].end - 1e-9);
  assert.deepEqual(overlay.estimateCaptionSegments('', 10), []);
});

test('calloutSegments spreads callouts after the hook without overlap', () => {
  const segs = overlay.calloutSegments(['a', ' b ', ''], 22);
  assert.deepEqual(segs.map((s) => s.text), ['A', 'B']);
  assert.equal(segs[0].start, 2);
  assert.ok(segs[0].end < segs[1].start);
  assert.ok(segs[1].end <= 22);
  assert.deepEqual(overlay.calloutSegments(['a'], 2.5), []); // too short to show anything
});

test('assTime and parseSrt handle HeyGen-style SRT', () => {
  assert.equal(overlay.assTime(3723.456), '1:02:03.46');
  const segs = overlay.parseSrt('1\r\n00:00:01,500 --> 00:00:03,000\r\nHello there\r\n\r\n2\r\n00:00:03,000 --> 00:00:04,250\r\nTwo\nlines\r\n');
  assert.deepEqual(segs, [
    { start: 1.5, end: 3, text: 'Hello there' },
    { start: 3, end: 4.25, text: 'Two\nlines' },
  ]);
});

test('buildAss uses real pixel coordinates and escapes text', () => {
  const ass = overlay.buildAss({
    width: 1080,
    height: 1920,
    callouts: [{ start: 2, end: 4, text: 'UP {10%}' }],
    captions: [{ start: 0, end: 1, text: 'line one\nline two' }],
  });
  assert.match(ass, /PlayResX: 1080\nPlayResY: 1920/);
  assert.match(ass, /Style: Callout,.*,8,80,80,300,1/); // top-center, 300px from top
  assert.match(ass, /Dialogue: 1,0:00:02.00,0:00:04.00,Callout,,0,0,0,,UP 10%/);
  assert.match(ass, /Caption,,0,0,0,,line one\\Nline two/);
});

test('burnText renders a captioned video with the same size and length', { skip: !hasFfmpeg && 'ffmpeg not installed' }, async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'overlay-test-'));
  try {
    execFileSync('ffmpeg', ['-loglevel', 'error', '-y', '-f', 'lavfi', '-i', 'color=c=gray:s=540x960:d=8', '-f', 'lavfi', '-i', 'sine=d=8', '-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'aac', '-shortest', path.join(dir, 'video.mp4')]);
    fs.writeFileSync(path.join(dir, 'script.json'), JSON.stringify({ script: 'one two three four five six seven eight nine ten', on_screen_text: ['Fact one', 'Fact two'] }));
    const out = await overlay.burnText(dir);
    {
      const info = execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'stream=width,height:format=duration', '-of', 'csv=p=0', out]).toString();
      assert.match(info, /540,960/);
      const dur = parseFloat(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', out]).toString());
      assert.ok(Math.abs(dur - 8) < 0.2);
      // The overlaid frame must differ from the plain one (text was actually drawn).
      const plain = execFileSync('ffmpeg', ['-loglevel', 'error', '-ss', '3', '-i', path.join(dir, 'video.mp4'), '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'gray', '-']);
      const drawn = execFileSync('ffmpeg', ['-loglevel', 'error', '-ss', '3', '-i', out, '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'gray', '-']);
      assert.notDeepEqual(plain, drawn);
    }
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
