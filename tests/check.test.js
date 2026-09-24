const { test } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');

const writer = require('../src/presenter/writer');
const { postText } = require('../src/presenter');
const { checkRun, checkAll, formatResults } = require('../src/presenter/check');

const WORDS = Array.from({ length: 130 }, (_, i) => `word${i}`).join(' ');
const URL_A = 'https://news.example-source.org/a';

// Build a run folder the same way the real pipeline does (finalizeScript + postText).
function makeRun(dir, name, niche, { raw = {}, files = ['video.mp4', 'video.captioned.mp4'], mutate } = {}) {
  const { script } = writer.finalizeScript(
    { topic: 't', title: 'T', hook: 'h', script: WORDS, on_screen_text: ['a'], description: 'd', hashtags: ['x'],
      sources: [{ title: 's', url: URL_A }], ...raw },
    niche,
    new Set([URL_A])
  );
  if (mutate) mutate(script);
  const runDir = path.join(dir, name);
  fs.mkdirSync(runDir);
  fs.writeFileSync(path.join(runDir, 'script.json'), JSON.stringify(script));
  fs.writeFileSync(path.join(runDir, 'post.txt'), postText(script));
  for (const f of files) fs.writeFileSync(path.join(runDir, f), 'x');
  return runDir;
}

test('a run built by the real pipeline passes, in every lane', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'check-test-'));
  try {
    for (const niche of ['ai', 'money', 'markets', 'food']) {
      const r = await checkRun(makeRun(dir, `2026-09-24-${niche}-x`, niche));
      assert.deepEqual(r.problems, [], niche);
      assert.equal(r.ok, true);
    }
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('catches missing disclaimer, disclosure, sources, video and demo runs', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'check-test-'));
  try {
    const noDisclaimer = await checkRun(makeRun(dir, 'a', 'markets', {
      mutate: (s) => { s.script = WORDS; s.description = `d\n\n${writer.AI_DISCLOSURE}`; },
    }));
    assert.ok(noDisclaimer.problems.includes('spoken script is missing the financial disclaimer'));
    assert.ok(noDisclaimer.problems.includes('description is missing the disclaimer'));

    const noDisclosure = await checkRun(makeRun(dir, 'b', 'ai', { mutate: (s) => { s.description = 'd'; } }));
    assert.ok(noDisclosure.problems.includes('description is missing the AI disclosure'));
    assert.ok(noDisclosure.problems.includes('post.txt is missing the AI disclosure'));

    const noVideo = await checkRun(makeRun(dir, 'c', 'food', { files: [] }));
    assert.deepEqual(noVideo.problems, ['no video rendered yet']);

    const plainOnly = await checkRun(makeRun(dir, 'd', 'food', { files: ['video.mp4'] }));
    assert.equal(plainOnly.ok, true);
    assert.match(plainOnly.warnings[0], /no captioned video/);

    const demo = await checkRun(makeRun(dir, 'demo-x', 'ai', {
      mutate: (s) => { s.sources = [{ title: 'p', url: 'https://example.com/demo' }]; },
    }));
    assert.ok(demo.problems.includes('demo run - not for posting'));
    assert.ok(demo.problems.includes('placeholder source URL'));

    const urlInSpeech = await checkRun(makeRun(dir, 'e', 'ai', { mutate: (s) => { s.script = `${WORDS} https://x.io`; } }));
    assert.ok(urlInSpeech.problems.includes('spoken script contains a URL'));

    const all = await checkAll(dir);
    assert.equal(all.length, 6);
    assert.match(formatResults(all), /^FAIL a\n/m);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('unreadable script and empty folder', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'check-test-'));
  try {
    fs.mkdirSync(path.join(dir, 'broken'));
    fs.writeFileSync(path.join(dir, 'broken', 'script.json'), '{nope');
    const r = await checkRun(path.join(dir, 'broken'));
    assert.deepEqual(r.problems, ['script.json missing or unreadable']);
    assert.equal(formatResults(await checkAll('/nonexistent')), 'No runs to check.');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
