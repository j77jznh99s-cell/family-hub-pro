const { test } = require('node:test');
const assert = require('node:assert/strict');
const { extractJsonArray } = require('../src/services/claudeAnalyzer');

test('parses a bare JSON array', () => {
  const result = extractJsonArray('[{"index":0,"score":5}]');
  assert.deepEqual(result, [{ index: 0, score: 5 }]);
});

test('parses a JSON array wrapped in a markdown code fence', () => {
  const text = '```json\n[{"index":1,"title":"Hi","score":8}]\n```';
  const result = extractJsonArray(text);
  assert.deepEqual(result, [{ index: 1, title: 'Hi', score: 8 }]);
});

test('parses a JSON array with surrounding prose', () => {
  const result = extractJsonArray('Sure, here you go: [{"index":2,"score":3}] hope that helps');
  assert.deepEqual(result, [{ index: 2, score: 3 }]);
});

test('throws a descriptive error when there is no JSON array', () => {
  assert.throws(() => extractJsonArray('I cannot help with that.'), /Could not find a JSON array/);
});
