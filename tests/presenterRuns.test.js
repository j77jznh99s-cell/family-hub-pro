const { test } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');
const express = require('express');

const runs = require('../src/presenter/runs');
const { presenterRouter } = require('../src/routes/presenter');

function makeRun(dir, id, script, files = []) {
  fs.mkdirSync(path.join(dir, id));
  fs.writeFileSync(path.join(dir, id, 'script.json'), JSON.stringify(script));
  for (const f of files) fs.writeFileSync(path.join(dir, id, f), f === 'post.txt' ? 'Title\n\nPost body' : 'x');
}

async function withServer(dir, fn) {
  const app = express();
  app.use('/api/presenter', presenterRouter(dir));
  const server = app.listen(0);
  try {
    await fn(`http://127.0.0.1:${server.address().port}/api/presenter`);
  } finally {
    server.close();
  }
}

test('validId rejects traversal and odd names', () => {
  assert.equal(runs.validId('2026-09-24-ai-rate-cut'), true);
  assert.equal(runs.validId('demo-2026-09-24T09-39-44'), true);
  for (const bad of ['..', '../etc', 'a/b', 'a\\b', '.hidden', '', 'x..y', null]) assert.equal(runs.validId(bad), false, bad);
});

test('lists runs with status, skips non-run folders, and serves details + video', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'runs-test-'));
  try {
    makeRun(dir, '2026-09-24-ai-topic', { topic: 'T', title: 'Title A', niche: 'ai', script: 'hello', sources: [{ title: 's', url: 'https://e.com' }] },
      ['video.mp4', 'video.captioned.mp4', 'post.txt']);
    makeRun(dir, 'demo-2026-09-24T10-00-00', { topic: 'Demo run', title: 'Demo', niche: 'ai', script: 'demo', demo: true });
    fs.mkdirSync(path.join(dir, 'not-a-run'));
    fs.writeFileSync(path.join(dir, 'calendar.md'), '# cal');

    const list = await runs.listRuns(dir);
    assert.deepEqual(list.map((r) => r.id).sort(), ['2026-09-24-ai-topic', 'demo-2026-09-24T10-00-00']);
    const byId = Object.fromEntries(list.map((r) => [r.id, r]));
    assert.equal(byId['2026-09-24-ai-topic'].status, 'captioned');
    assert.equal(byId['demo-2026-09-24T10-00-00'].status, 'scripted');
    assert.equal(byId['demo-2026-09-24T10-00-00'].demo, true);

    await withServer(dir, async (base) => {
      const detail = await (await fetch(`${base}/runs/2026-09-24-ai-topic`)).json();
      assert.equal(detail.post, 'Title\n\nPost body');
      assert.equal(detail.sources[0].url, 'https://e.com');
      const video = await fetch(`${base}/runs/2026-09-24-ai-topic/video`);
      assert.equal(video.status, 200);
      assert.equal(await video.text(), 'x');
      assert.equal((await fetch(`${base}/runs/demo-2026-09-24T10-00-00/video`)).status, 404);
      assert.equal((await fetch(`${base}/runs/..%2F..%2Fetc`)).status, 404);
      assert.equal((await fetch(`${base}/runs/nope`)).status, 404);
      const cal = await (await fetch(`${base}/calendar`)).json();
      assert.equal(cal.length, 7);
    });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('missing output folder lists nothing', async () => {
  assert.deepEqual(await runs.listRuns('/nonexistent/presenter'), []);
});
