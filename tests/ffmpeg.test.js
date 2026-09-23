const { test } = require('node:test');
const assert = require('node:assert/strict');
const { parseAspect, buildVideoFilters } = require('../src/services/ffmpeg');

test('parseAspect returns width/height ratio for W:H strings', () => {
  assert.equal(parseAspect('9:16'), 9 / 16);
  assert.equal(parseAspect(' 1 : 1 '), 1);
  assert.equal(parseAspect('4:5'), 0.8);
});

test('parseAspect returns null for unset or invalid values', () => {
  for (const value of ['', undefined, null, '916', '9:0', '0:16', 'abc', '9:16:1', '-9:16']) {
    assert.equal(parseAspect(value), null, `expected null for ${value}`);
  }
});

test('buildVideoFilters returns null when there is nothing to apply', () => {
  assert.equal(buildVideoFilters(), null);
  assert.equal(buildVideoFilters({ aspect: '' }), null);
});

test('buildVideoFilters center-crops with escaped commas and even dimensions', () => {
  const vf = buildVideoFilters({ aspect: '9:16' });
  assert.equal(vf, "crop=w='trunc(min(iw\\,ih*0.562500)/2)*2':h='trunc(min(ih\\,iw/0.562500)/2)*2'");
});

test('buildVideoFilters crops before burning in subtitles', () => {
  const vf = buildVideoFilters({ aspect: '9:16', subtitlesPath: '/tmp/x.srt' });
  assert.ok(vf.startsWith('crop='));
  assert.ok(vf.indexOf('crop=') < vf.indexOf('subtitles='));
});

test('buildVideoFilters keeps subtitles-only behavior unchanged', () => {
  const vf = buildVideoFilters({ subtitlesPath: '/tmp/x.srt' });
  assert.match(vf, /^subtitles=\/tmp\/x\.srt:force_style=/);
});

const { summarizeProbe, describeProbeProblem } = require('../src/services/ffmpeg');

test('summarizeProbe reads video/audio streams and duration', () => {
  const probe = summarizeProbe({
    streams: [
      { codec_type: 'video', codec_name: 'h264', width: 1920, height: 1080, disposition: { attached_pic: 0 } },
      { codec_type: 'audio', codec_name: 'aac' },
    ],
    format: { duration: '5.000000' },
  });
  assert.deepEqual(probe, { duration: 5, hasVideo: true, hasAudio: true, videoCodec: 'h264', width: 1920, height: 1080 });
  assert.equal(describeProbeProblem(probe), null);
});

test('album art in an audio file does not count as a video track', () => {
  const probe = summarizeProbe({
    streams: [
      { codec_type: 'audio', codec_name: 'mp3' },
      { codec_type: 'video', codec_name: 'mjpeg', width: 600, height: 600, disposition: { attached_pic: 1 } },
    ],
    format: { duration: '180.0' },
  });
  assert.equal(probe.hasVideo, false);
  assert.match(describeProbeProblem(probe), /no video track/);
});

test('describeProbeProblem flags missing duration or dimensions', () => {
  const base = { duration: 10, hasVideo: true, hasAudio: true, videoCodec: 'h264', width: 640, height: 360 };
  assert.match(describeProbeProblem({ ...base, duration: null }), /length/);
  assert.match(describeProbeProblem({ ...base, duration: 0 }), /length/);
  assert.match(describeProbeProblem({ ...base, width: null }), /dimensions/);
  assert.equal(describeProbeProblem({ ...base, hasAudio: false }), null); // silent video is fine
});

test('summarizeProbe tolerates empty ffprobe output', () => {
  const probe = summarizeProbe({});
  assert.equal(probe.hasVideo, false);
  assert.equal(probe.duration, null);
});
