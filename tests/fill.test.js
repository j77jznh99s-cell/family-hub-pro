const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const calendar = require('../src/presenter/calendar');
const fill = require('../src/presenter/fill');

const TODAY = new Date('2026-09-24T15:00:00Z');

test('pending slots skip ones that already have a run', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fill-'));
  const [first] = calendar.planWeek({ start: TODAY, days: 1 });
  fs.mkdirSync(path.join(dir, `${first.date}-${first.niche}-done-already`));
  fs.writeFileSync(path.join(dir, `${first.date}-${first.niche}-done-already`, 'script.json'), '{"topic":"x"}');
  const pending = await fill.pendingSlots(dir, { today: TODAY, days: 3 });
  assert.deepEqual(pending.map((s) => s.date), ['2026-09-25', '2026-09-26']);
  assert.match(fill.describe(pending), /2 slot\(s\) without a script/);
  assert.match(fill.describe([]), /Nothing to fill/);
});

test('filling writes script-only runs dated for each slot, carries on past a failure, and the calendar then matches them', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fill-'));
  const pending = await fill.pendingSlots(dir, { today: TODAY, days: 3 });
  const calls = [];
  const create = async ({ niche, render, forDate }) => {
    calls.push({ niche, render, date: forDate.toISOString().slice(0, 10) });
    if (calls.length === 2) throw new Error('Script failed checks: too short');
    const runDir = path.join(dir, `${forDate.toISOString().slice(0, 10)}-${niche}-topic-${calls.length}`);
    fs.mkdirSync(runDir);
    fs.writeFileSync(path.join(runDir, 'script.json'), JSON.stringify({ topic: `topic ${calls.length}` }));
    return { runDir };
  };
  const logs = [];
  const results = await fill.fillSlots(pending, { create, log: (m) => logs.push(m) });
  assert.deepEqual(calls.map((c) => c.render), [false, false, false]);
  assert.deepEqual(calls.map((c) => c.date), ['2026-09-24', '2026-09-25', '2026-09-26']);
  assert.deepEqual(results.map((r) => r.ok), [true, false, true]);
  assert.match(logs[0], /too short/);
  const after = await calendar.attachRuns(calendar.planWeek({ start: TODAY, days: 3 }), dir);
  assert.deepEqual(after.map((s) => s.status), ['scripted', 'planned', 'scripted']);
});

test('each new script gets the pre-posting check and the batch is summarized in one place', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fill-'));
  const pending = await fill.pendingSlots(dir, { today: TODAY, days: 3 });
  let n = 0;
  const create = async ({ niche, forDate }) => {
    n++;
    if (n === 3) throw new Error('Script failed checks: no sources');
    return { runDir: path.join(dir, `${forDate.toISOString().slice(0, 10)}-${niche}-t${n}`) };
  };
  const checked = [];
  const checkRun = async (runDir) => {
    checked.push(runDir);
    return checked.length === 1
      ? { runDir, ok: true, problems: [], warnings: [] }
      : { runDir, ok: false, problems: ['missing AI disclosure'], warnings: [] };
  };
  const results = await fill.fillSlots(pending, { create, checkRun, log: () => {} });
  assert.equal(checked.length, 2); // failed creates aren't checked
  const text = fill.summarize(results);
  assert.match(text, /OK .*t1/);
  assert.match(text, /FAIL .*t2\n\s+x missing AI disclosure/);
  assert.match(text, /Still empty: 2026-09-26/);
});
