const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { tokensMatch, authFailureLimiter, makePresenterAuth } = require('../src/middleware/auth');

test('tokensMatch: exact match only, safe on odd input', () => {
  assert.equal(tokensMatch('secret', 'secret'), true);
  assert.equal(tokensMatch('secret ', 'secret'), false);
  assert.equal(tokensMatch('', 'secret'), false);
  assert.equal(tokensMatch(undefined, 'secret'), false);
  assert.equal(tokensMatch(['secret'], 'secret'), false); // ?token=a&token=b arrives as an array
  assert.equal(tokensMatch('x'.repeat(10000), 'secret'), false);
  assert.equal(tokensMatch('secret', ''), false);
});

test('failed-auth limiter blocks guessing but never counts successful requests', async () => {
  const app = express();
  app.use(authFailureLimiter({ limit: 3, windowMs: 60_000 }));
  app.get('/p', makePresenterAuth({ presenterToken: 'good', accessToken: '', warn: () => {} }), (req, res) => res.json({ ok: 1 }));
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}/p`;
  const code = async (q) => (await fetch(base + q)).status;
  try {
    for (let i = 0; i < 10; i++) assert.equal(await code('?ptoken=good'), 200); // successes don't count
    assert.deepEqual([await code('?ptoken=x'), await code('?ptoken=y'), await code('?ptoken=z')], [401, 401, 401]);
    assert.equal(await code('?ptoken=w'), 429); // 4th wrong guess is refused outright
    assert.equal(await code('?ptoken=good'), 429); // and so is this IP until the window passes
  } finally {
    server.close();
  }
});
