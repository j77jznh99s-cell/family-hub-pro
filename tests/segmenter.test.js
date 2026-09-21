const { test } = require('node:test');
const assert = require('node:assert/strict');
const { buildCandidateSegments } = require('../src/services/segmenter');

test('splits video into speech segments around silence gaps', () => {
  const segments = buildCandidateSegments(300, [
    { start: 10, end: 11 },
    { start: 40, end: 41.5 },
    { start: 90, end: 92 },
  ]);
  assert.ok(segments.length > 0);
  for (const seg of segments) {
    assert.ok(seg.end > seg.start);
    assert.ok(seg.start >= 0 && seg.end <= 300);
  }
});

test('merges silences shorter than the merge-gap threshold', () => {
  const segments = buildCandidateSegments(100, [{ start: 30, end: 30.5 }], {
    mergeGapSeconds: 1.2,
    minClipSeconds: 5,
    maxClipSeconds: 200,
  });
  // The 0.5s gap is below the merge threshold, so 0-30 and 30.5-100 should merge into one segment.
  assert.equal(segments.length, 1);
  assert.equal(segments[0].start, 0);
  assert.equal(segments[0].end, 100);
});

test('splits a long silence-free segment into target-length chunks', () => {
  const segments = buildCandidateSegments(200, [], {
    targetClipSeconds: 50,
    maxClipSeconds: 90,
    minClipSeconds: 5,
  });
  assert.ok(segments.length >= 2);
  for (const seg of segments) {
    assert.ok(seg.end - seg.start <= 90 + 1e-6);
  }
});

test('falls back to fixed windows when there are no usable segments', () => {
  // A single silence spanning the whole video leaves no speech at all.
  const segments = buildCandidateSegments(120, [{ start: 0, end: 120 }], {
    targetClipSeconds: 40,
  });
  assert.ok(segments.length > 0);
});

test('drops segments shorter than minClipSeconds', () => {
  const segments = buildCandidateSegments(
    50,
    [
      { start: 5, end: 40 }, // leaves a 5s and a 10s speech segment
    ],
    { minClipSeconds: 8, mergeGapSeconds: 0 }
  );
  for (const seg of segments) {
    assert.ok(seg.end - seg.start >= 8);
  }
});

test('caps the number of candidates returned', () => {
  const silences = [];
  for (let i = 1; i < 20; i++) silences.push({ start: i * 10, end: i * 10 + 2 });
  const segments = buildCandidateSegments(300, silences, { maxCandidates: 5, minClipSeconds: 1 });
  assert.ok(segments.length <= 5);
});
