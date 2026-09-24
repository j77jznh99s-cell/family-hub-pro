const { test } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');
const { execFileSync } = require('node:child_process');

const { createDemoRun } = require('../src/presenter/demo');
const presenter = require('../src/presenter');
const calendar = require('../src/presenter/calendar');

let hasFfmpeg = true;
try {
  execFileSync('ffmpeg', ['-version'], { stdio: 'ignore' });
} catch {
  hasFfmpeg = false;
}

test('demo run builds a full run folder with captions burned in', { skip: !hasFfmpeg && 'ffmpeg not installed' }, async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'demo-test-'));
  try {
    const now = new Date('2026-09-24T12:00:00Z');
    const { runDir, captionedPath } = await createDemoRun({ outputDir: dir, now, seconds: 4, log: () => {} });
    assert.ok(path.basename(runDir).startsWith('demo-'));
    for (const f of ['script.json', 'post.txt', 'research.md', 'render.json', 'video.mp4', 'overlay.ass']) {
      assert.ok(fs.existsSync(path.join(runDir, f)), f);
    }
    assert.ok(fs.statSync(captionedPath).size > 0);
    assert.match(fs.readFileSync(path.join(runDir, 'post.txt'), 'utf8'), /^DEMO - DO NOT POST/);

    // Demo folders are invisible to topic history and to the calendar.
    assert.deepEqual(await presenter.recentTopics(dir), []);
    const [slot] = await calendar.attachRuns(calendar.planWeek({ start: now, days: 1 }), dir);
    assert.equal(slot.status, 'planned');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
