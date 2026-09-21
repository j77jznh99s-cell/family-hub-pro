const { test } = require('node:test');
const assert = require('node:assert/strict');
const { buildSrt } = require('../src/services/captions');

const transcript = {
  segments: [
    { start: 10.0, end: 12.5, text: 'Hello there.' },
    { start: 12.5, end: 15.2, text: 'This is a test.' },
    { start: 40.0, end: 42.0, text: 'Way outside the clip.' },
  ],
};

test('returns null when transcript is missing', () => {
  assert.equal(buildSrt(null, 10, 20), null);
});

test('returns null when nothing overlaps the clip range', () => {
  assert.equal(buildSrt(transcript, 100, 110), null);
});

test('re-times overlapping segments relative to the clip start', () => {
  const srt = buildSrt(transcript, 10, 20);
  assert.match(srt, /^1\n00:00:00,000 --> 00:00:02,500\nHello there\./m);
  assert.match(srt, /2\n00:00:02,500 --> 00:00:05,200\nThis is a test\./m);
  assert.ok(!srt.includes('Way outside the clip.'));
});

test('clamps a segment that runs past the end of the clip', () => {
  const srt = buildSrt(transcript, 11, 13);
  // "Hello there." spans 10-12.5, clip is 11-13 -> relative 0 to 1.5 (clamped to clip end)
  assert.match(srt, /00:00:00,000 --> 00:00:01,500/);
});
