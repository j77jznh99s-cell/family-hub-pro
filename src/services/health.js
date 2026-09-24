// Deep health check for GET /healthz?deep=1: the things a fresh deploy most often gets
// wrong, each checked for real (run ffmpeg, query the database, write a file). Reports
// pass/fail and a hint, never secrets or paths' contents. Plain /healthz stays a cheap
// liveness probe for the platform.
const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');

async function checkWritable(dir) {
  const probe = path.join(dir, `.healthz-${crypto.randomBytes(6).toString('hex')}`);
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(probe, 'ok');
  await fs.unlink(probe);
}

async function run(name, fn, hint) {
  try {
    const detail = await fn();
    return { name, ok: true, ...(detail ? { detail } : {}) };
  } catch (err) {
    return { name, ok: false, hint, error: String(err && err.message ? err.message : err).slice(0, 200) };
  }
}

// deps are injected so tests can fake each piece.
async function deepHealth({ ffmpeg, db, config, req }) {
  const checks = [];
  checks.push(await run('ffmpeg', async () => {
    const missing = await ffmpeg.checkAvailable();
    if (missing.length) throw new Error(`missing: ${missing.join(', ')}`);
  }, 'Deploy with the Dockerfile (or nixpacks.toml) so ffmpeg is installed.'));
  checks.push(await run('database', async () => {
    await db.getStats();
    return config.DATABASE_URL ? 'postgres' : 'sqlite';
  }, config.DATABASE_URL ? 'Check DATABASE_URL.' : 'Check DATA_DIR is on a writable volume.'));
  if (config.S3_BUCKET) {
    checks.push({ name: 'storage', ok: true, detail: 's3 (not probed; uploads will show errors if credentials are wrong)' });
  } else {
    for (const [name, dir] of [['uploads folder', config.UPLOAD_DIR], ['clips folder', config.CLIPS_DIR]]) {
      checks.push(await run(name, () => checkWritable(dir),
        'Mount a volume and point UPLOAD_DIR / CLIPS_DIR / DATA_DIR at it, or files vanish on redeploy.'));
    }
  }
  const warnings = [];
  // Behind a platform proxy every request carries X-Forwarded-For; without TRUST_PROXY
  // all clients share one rate-limit bucket.
  if (req && req.headers['x-forwarded-for'] && !config.TRUST_PROXY) {
    warnings.push('Requests arrive through a proxy but TRUST_PROXY is not set: set TRUST_PROXY=1.');
  }
  return { ok: checks.every((c) => c.ok), checks, warnings };
}

// Things only the operator should see, so they go to the server log, not the HTTP reply.
function startupWarnings(config) {
  const out = [];
  if (config.NODE_ENV === 'production' && !config.ACCESS_TOKEN) {
    out.push('ACCESS_TOKEN is not set: anyone with the URL can upload and read clips.');
  }
  if (config.ACCESS_TOKEN && !config.PRESENTER_TOKEN) {
    out.push('PRESENTER_TOKEN is not set: clients holding ACCESS_TOKEN can read your presenter runs.');
  }
  return out;
}

module.exports = { deepHealth, startupWarnings, checkWritable };
