const { test } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');

const { ORDER, nicheForDate } = require('../src/presenter/niches');
const calendar = require('../src/presenter/calendar');

const START = new Date('2026-09-24T15:00:00Z');

test('one a day matches the lane --niche auto picks for each date', () => {
  const slots = calendar.planWeek({ start: START });
  assert.equal(slots.length, 7);
  for (const s of slots) assert.equal(s.niche, nicheForDate(new Date(`${s.date}T12:00:00Z`)));
  assert.equal(slots[0].date, '2026-09-24');
  assert.equal(slots[0].weekday, 'Thu');
  assert.equal(slots[0].postAt, '12:00');
});

test('several a day rotate evenly and never repeat a lane back to back', () => {
  const slots = calendar.planWeek({ start: START, days: 6, perDay: 2 });
  assert.equal(slots.length, 12);
  for (let i = 1; i < slots.length; i++) assert.notEqual(slots[i].niche, slots[i - 1].niche);
  const counts = Object.fromEntries(ORDER.map((k) => [k, 0]));
  for (const s of slots) counts[s.niche]++;
  for (const k of ORDER) assert.equal(counts[k], 3);
  assert.deepEqual(slots.slice(0, 2).map((s) => s.postAt), ['12:00', '18:00']);
});

test('rejects bad options', () => {
  assert.throws(() => calendar.planWeek({ times: '25:00' }), /Bad post time/);
  assert.throws(() => calendar.planWeek({ days: 0 }), /days/);
  assert.throws(() => calendar.planWeek({ perDay: 9 }), /perDay/);
});

test('PRESENTER_PER_DAY sets the shared videos-per-day default; bad values error', () => {
  assert.equal(calendar.defaultPerDay({}), 1);
  assert.equal(calendar.defaultPerDay({ PRESENTER_PER_DAY: ' ' }), 1);
  assert.equal(calendar.defaultPerDay({ PRESENTER_PER_DAY: '3' }), 3);
  for (const bad of ['0', 'abc', '1.5', '7']) {
    assert.throws(() => calendar.defaultPerDay({ PRESENTER_PER_DAY: bad }), /PRESENTER_PER_DAY must be/, bad);
  }
  const saved = process.env.PRESENTER_PER_DAY;
  process.env.PRESENTER_PER_DAY = '2';
  try {
    assert.equal(calendar.planWeek({ start: START, days: 3 }).length, 6);
    assert.equal(calendar.planWeek({ start: START, days: 3, perDay: 1 }).length, 3);
  } finally {
    if (saved === undefined) delete process.env.PRESENTER_PER_DAY;
    else process.env.PRESENTER_PER_DAY = saved;
  }
});

test('marks slots with finished runs and flags missed ones', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'calendar-test-'));
  try {
    const slots = calendar.planWeek({ start: START, days: 3 });
    const [a, b] = slots;
    const runA = path.join(dir, `${a.date}-${a.niche}-some-topic`);
    fs.mkdirSync(runA);
    fs.writeFileSync(path.join(runA, 'script.json'), JSON.stringify({ topic: 'Rate cut explained' }));
    fs.writeFileSync(path.join(runA, 'video.mp4'), '');
    fs.writeFileSync(path.join(runA, 'video.captioned.mp4'), '');
    // A run for the wrong lane on day 2 must not count.
    const other = ORDER.find((k) => k !== b.niche);
    fs.mkdirSync(path.join(dir, `${b.date}-${other}-x`));

    const withRuns = await calendar.attachRuns(slots, dir);
    assert.equal(withRuns[0].status, 'captioned');
    assert.equal(withRuns[0].topic, 'Rate cut explained');
    assert.equal(withRuns[1].status, 'planned');

    const md = calendar.toMarkdown(withRuns, { today: new Date('2026-09-26T00:00:00Z') });
    assert.match(md, /captioned \| Rate cut explained/);
    assert.match(md, new RegExp(`${b.date} \\| 12:00 \\| [^|]+ \\| missed`));
    assert.match(md, /--niche /);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('a topic with "|" or a line break stays in its table row', () => {
  const [slot] = calendar.planWeek({ start: START, days: 1 });
  const md = calendar.toMarkdown([{ ...slot, status: 'scripted', topic: 'Nvidia | AMD\nearnings', runDir: 'x' }], { today: START });
  const row = md.split('\n').find((l) => l.startsWith('|') && l.includes(slot.date));
  assert.ok(row.includes('Nvidia \\| AMD earnings'));
  assert.equal(row.split(/(?<!\\)\|/).length, 7); // 5 cells + the two outer pipes
});

test('missing output folder means everything is planned', async () => {
  const slots = await calendar.attachRuns(calendar.planWeek({ start: START, days: 2 }), '/nonexistent/dir');
  assert.deepEqual(slots.map((s) => s.status), ['planned', 'planned']);
});
