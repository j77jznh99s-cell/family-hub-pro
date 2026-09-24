const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { makePresenterAuth } = require('../src/middleware/auth');

async function status(auth, headers = {}, query = '') {
  const app = express();
  app.get('/p', auth, (req, res) => res.json({ ok: true }));
  const server = app.listen(0);
  try {
    const res = await fetch(`http://127.0.0.1:${server.address().port}/p${query}`, { headers });
    return res.status;
  } finally {
    server.close();
  }
}

test('with PRESENTER_TOKEN set, the shared ACCESS_TOKEN is rejected', async () => {
  const auth = makePresenterAuth({ presenterToken: 'owner-secret', accessToken: 'client-shared', warn: () => {} });
  assert.equal(await status(auth), 401);
  assert.equal(await status(auth, { 'x-access-token': 'client-shared' }), 401);
  assert.equal(await status(auth, {}, '?token=client-shared'), 401);
  assert.equal(await status(auth, { 'x-presenter-token': 'owner-secret' }), 200);
  assert.equal(await status(auth, {}, '?ptoken=owner-secret'), 200);
});

test('without PRESENTER_TOKEN it falls back to ACCESS_TOKEN and warns once', async () => {
  const warnings = [];
  const auth = makePresenterAuth({ presenterToken: '', accessToken: 'shared', warn: (m) => warnings.push(m) });
  assert.equal(await status(auth, { 'x-access-token': 'shared' }), 200);
  assert.equal(await status(auth, { 'x-access-token': 'wrong' }), 401);
  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /PRESENTER_TOKEN is not set/);
});

test('no tokens at all (local dev) lets requests through', async () => {
  const auth = makePresenterAuth({ presenterToken: '', accessToken: '', warn: () => {} });
  assert.equal(await status(auth), 200);
});
