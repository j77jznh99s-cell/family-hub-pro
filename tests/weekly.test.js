const { test } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');

const writer = require('../src/presenter/writer');
const { postText } = require('../src/presenter');
const calendar = require('../src/presenter/calendar');
const usage = require('../src/presenter/usage');
const { buildWeeklyReport } = require('../src/presenter/weekly');

const WORDS = Array.from({ length: 130 }, (_, i) => `word${i}`).join(' ');
const URL_A = 'https://news.example-source.org/a';

test('weekly report: made / ready / missed counts, check details and spend', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'weekly-test-'));
  try {
    const now = new Date('2026-09-24T18:00:00Z');
    const slots = calendar.planWeek({ start: new Date(now.getTime() - 6 * 86400000), days: 7 });
    // A ready run on the first day, a scripted-only run on the second; the rest are empty.
    const make = (slot, withVideo) => {
      const { script } = writer.finalizeScript(
        { topic: `Topic ${slot.date}`, title: 'T', hook: 'h', script: WORDS, on_screen_text: ['a'], description: 'd', hashtags: [],
          sources: [{ title: 's', url: URL_A }] },
        slot.niche,
        new Set([URL_A])
      );
      const runDir = path.join(dir, `${slot.date}-${slot.niche}-topic`);
      fs.mkdirSync(runDir);
      fs.writeFileSync(path.join(runDir, 'script.json'), JSON.stringify(script));
      fs.writeFileSync(path.join(runDir, 'post.txt'), postText(script));
      if (withVideo) fs.writeFileSync(path.join(runDir, 'video.captioned.mp4'), 'x');
      const u = usage.emptyUsage();
      usage.addClaudeResponse(u, { usage: { input_tokens: 1e6, output_tokens: 0 }, content: [] });
      fs.writeFileSync(path.join(runDir, 'usage.json'), JSON.stringify(u));
    };
    make(slots[0], true);
    make(slots[1], false);

    const md = await buildWeeklyReport(dir, { now });
    assert.match(md, /\*\*2 of 7 slots have a run, 1 pass the pre-posting check, 4 missed\.\*\*/);
    assert.match(md, /\*\*Ready\*\* - .*Topic 2026-09-18/);
    assert.match(md, /\*\*Not ready\*\* - .*\n {2}- problem: no video rendered yet/);
    assert.match(md, /Claude \(estimate at list price\): \$10\.00/);
    assert.match(md, /Nothing in this report posts anything/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('weekly report with no runs', async () => {
  const md = await buildWeeklyReport('/nonexistent/presenter', { now: new Date('2026-09-24T12:00:00Z') });
  assert.match(md, /0 of 7 slots have a run/);
  assert.match(md, /No runs this week/);
  assert.match(md, /No usage recorded this month/);
});
