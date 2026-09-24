// Reads presenter run folders for the dashboard: a list with each run's status, and one
// run's script, callouts, sources and post text. Run ids come from the URL, so they're
// checked against the folder-name pattern before touching the filesystem.
const fs = require('fs/promises');
const path = require('path');

const ID_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$/;

function validId(id) {
  return typeof id === 'string' && ID_RE.test(id) && !id.includes('..');
}

async function exists(file) {
  return fs.access(file).then(() => true, () => false);
}

async function readJson(file) {
  try {
    return JSON.parse(await fs.readFile(file, 'utf8'));
  } catch {
    return null;
  }
}

async function runSummary(outputDir, id) {
  const dir = path.join(outputDir, id);
  const script = await readJson(path.join(dir, 'script.json'));
  if (!script) return null; // not a run folder (or an incomplete one)
  const captioned = await exists(path.join(dir, 'video.captioned.mp4'));
  const rendered = captioned || (await exists(path.join(dir, 'video.mp4')));
  const stat = await fs.stat(path.join(dir, 'script.json'));
  return {
    id,
    demo: id.startsWith('demo-') || Boolean(script.demo),
    niche: script.niche || null,
    topic: script.topic || null,
    title: script.title || null,
    estimatedSeconds: script.estimatedSeconds || null,
    status: captioned ? 'captioned' : rendered ? 'rendered' : 'scripted',
    createdAt: stat.mtime.toISOString(),
  };
}

async function listRuns(outputDir) {
  let entries;
  try {
    entries = await fs.readdir(outputDir, { withFileTypes: true });
  } catch {
    return [];
  }
  const runs = [];
  for (const e of entries) {
    if (!e.isDirectory() || !validId(e.name)) continue;
    const summary = await runSummary(outputDir, e.name);
    if (summary) runs.push(summary);
  }
  return runs.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

async function getRun(outputDir, id) {
  if (!validId(id)) return null;
  const summary = await runSummary(outputDir, id);
  if (!summary) return null;
  const dir = path.join(outputDir, id);
  const script = await readJson(path.join(dir, 'script.json'));
  let post = null;
  try {
    post = await fs.readFile(path.join(dir, 'post.txt'), 'utf8');
  } catch {
    // older runs may not have one
  }
  return {
    ...summary,
    script: script.script || '',
    onScreenText: script.on_screen_text || [],
    sources: script.sources || [],
    hashtags: script.hashtags || [],
    post,
  };
}

// The best video to show: captioned if there is one, else the plain render.
async function videoPath(outputDir, id) {
  if (!validId(id)) return null;
  for (const name of ['video.captioned.mp4', 'video.mp4']) {
    const file = path.join(outputDir, id, name);
    if (await exists(file)) return file;
  }
  return null;
}

module.exports = { listRuns, getRun, videoPath, validId };
