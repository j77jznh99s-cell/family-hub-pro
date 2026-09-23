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
