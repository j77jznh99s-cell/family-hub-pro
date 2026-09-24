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

test('missing output folder means everything is planned', async () => {
  const slots = await calendar.attachRuns(calendar.planWeek({ start: START, days: 2 }), '/nonexistent/dir');
  assert.deepEqual(slots.map((s) => s.status), ['planned', 'planned']);
});
