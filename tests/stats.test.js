const { test } = require('node:test');
const assert = require('node:assert/strict');
const { buildStats } = require('../src/db/stats');

test('buildStats handles an empty database', () => {
  const stats = buildStats({
    statusRows: [],
    totals: { completed: 0, source_seconds: 0, avg_processing_ms: null, max_processing_ms: null },
    recent: { last_24h: null, last_7d: null },
    clips: 0,
  });
  assert.deepEqual(stats, {
    jobs: { total: 0, byStatus: { uploaded: 0, processing: 0, complete: 0, failed: 0 }, last24h: 0, last7d: 0, failureRate: null },
    clips: { total: 0 },
    processing: { sourceMinutesProcessed: 0, avgSeconds: null, maxSeconds: null },
  });
});

test('buildStats coerces pg string aggregates to numbers', () => {
  const stats = buildStats({
    statusRows: [
      { status: 'complete', count: '3' },
      { status: 'failed', count: '1' },
      { status: 'processing', count: '1' },
    ],
    totals: { completed: '3', source_seconds: '600.5', avg_processing_ms: '12345.678', max_processing_ms: 30000 },
    recent: { last_24h: '2', last_7d: '5' },
    clips: '12',
  });
  assert.equal(stats.jobs.total, 5);
  assert.equal(stats.jobs.byStatus.complete, 3);
  assert.equal(stats.jobs.last24h, 2);
  assert.equal(stats.jobs.failureRate, 0.25);
  assert.equal(stats.clips.total, 12);
  assert.equal(stats.processing.sourceMinutesProcessed, 10.01);
  assert.equal(stats.processing.avgSeconds, 12.3);
  assert.equal(stats.processing.maxSeconds, 30);
});
