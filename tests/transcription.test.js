const { test } = require('node:test');
const assert = require('node:assert/strict');
const { textForRange } = require('../src/services/transcription');

const transcript = {
  segments: [
    { start: 0, end: 5, text: 'Welcome to the show.' },
    { start: 5, end: 12, text: "Today we're talking about clips." },
    { start: 50, end: 55, text: 'Totally unrelated later segment.' },
  ],
};

test('returns empty string when transcript is null', () => {
  assert.equal(textForRange(null, 0, 10), '');
});

test('concatenates only segments overlapping the given range', () => {
  const text = textForRange(transcript, 0, 12);
  assert.equal(text, "Welcome to the show. Today we're talking about clips.");
});

test('excludes segments outside the range', () => {
  const text = textForRange(transcript, 0, 12);
  assert.ok(!text.includes('Totally unrelated'));
});

test('returns empty string when nothing overlaps', () => {
  assert.equal(textForRange(transcript, 100, 110), '');
});
