const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { deepHealth, startupWarnings } = require('../src/services/health');

const okFfmpeg = { checkAvailable: async () => [] };
const okDb = { getStats: async () => ({}) };
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'health-'));

test('deep health passes when ffmpeg, database and folders all work', async () => {
  const config = { UPLOAD_DIR: tmp(), CLIPS_DIR: path.join(tmp(), 'new-subdir'), TRUST_PROXY: '1' };
  const r = await deepHealth({ ffmpeg: okFfmpeg, db: okDb, config, req: { headers: { 'x-forwarded-for': '1.2.3.4' } } });
  assert.equal(r.ok, true);
  assert.deepEqual(r.checks.map((c) => c.name), ['ffmpeg', 'database', 'uploads folder', 'clips folder']);
  assert.deepEqual(r.warnings, []);
  assert.deepEqual(fs.readdirSync(config.UPLOAD_DIR), []); // probe file cleaned up
});

test('deep health names each failure with a fix, and flags a proxy without TRUST_PROXY', async () => {
  const blocker = path.join(tmp(), 'a-file');
  fs.writeFileSync(blocker, 'x'); // a file where a folder should be: not writable as a dir
  const r = await deepHealth({
    ffmpeg: { checkAvailable: async () => ['ffprobe'] },
    db: { getStats: async () => { throw new Error('connect ECONNREFUSED'); } },
    config: { UPLOAD_DIR: blocker, CLIPS_DIR: tmp(), DATABASE_URL: 'postgres://x' },
    req: { headers: { 'x-forwarded-for': '1.2.3.4' } },
  });
  assert.equal(r.ok, false);
  const by = Object.fromEntries(r.checks.map((c) => [c.name, c]));
  assert.match(by.ffmpeg.error, /ffprobe/);
  assert.match(by.ffmpeg.hint, /Dockerfile/);
  assert.match(by.database.hint, /DATABASE_URL/);
  assert.equal(by['uploads folder'].ok, false);
  assert.equal(by['clips folder'].ok, true);
  assert.match(r.warnings[0], /TRUST_PROXY/);
  assert.ok(!JSON.stringify(r).includes('postgres://x')); // never echoes config values
});

test('s3 storage skips the folder probes', async () => {
  const r = await deepHealth({ ffmpeg: okFfmpeg, db: okDb, config: { S3_BUCKET: 'b' }, req: { headers: {} } });
  assert.deepEqual(r.checks.map((c) => c.name), ['ffmpeg', 'database', 'storage']);
});

test('startup warnings cover missing tokens without printing them', () => {
  assert.match(startupWarnings({ NODE_ENV: 'production', ACCESS_TOKEN: '' })[0], /ACCESS_TOKEN is not set/);
  const w = startupWarnings({ ACCESS_TOKEN: 'sekret', PRESENTER_TOKEN: '' });
  assert.match(w[0], /PRESENTER_TOKEN/);
  assert.ok(!w.join(' ').includes('sekret'));
  assert.deepEqual(startupWarnings({ ACCESS_TOKEN: 'a', PRESENTER_TOKEN: 'b' }), []);
});
