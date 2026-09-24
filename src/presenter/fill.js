// --fill-week: write scripts ahead of time for calendar slots that don't have a run yet.
// Script-only on purpose: renders cost HeyGen credits and should be a deliberate step,
// and a script written days early should be re-read against the news before it's filmed.
const calendar = require('./calendar');

// Slots from today on that have no run folder yet, in calendar order.
async function pendingSlots(outputDir, { today = new Date(), days = 7, perDay = 1, times } = {}) {
  const slots = await calendar.attachRuns(calendar.planWeek({ start: today, days, perDay, times }), outputDir);
  const todayIso = today.toISOString().slice(0, 10);
  return slots.filter((s) => s.status === 'planned' && s.date >= todayIso);
}

// One slot at a time, carrying on past failures so one bad topic doesn't stop the week.
async function fillSlots(pending, { create, log = console.log } = {}) {
  const results = [];
  for (const slot of pending) {
    try {
      const { runDir } = await create({ niche: slot.niche, render: false, forDate: new Date(`${slot.date}T12:00:00Z`), log });
      results.push({ ...slot, ok: true, runDir });
    } catch (err) {
      log(`[presenter] ${slot.date} ${slot.label}: ${err.message}`);
      results.push({ ...slot, ok: false, error: err.message });
    }
  }
  return results;
}

function describe(pending) {
  if (!pending.length) return 'Every slot from today on already has a run. Nothing to fill.';
  return [
    `${pending.length} slot(s) without a script:`,
    ...pending.map((s) => `  ${s.weekday} ${s.date} ${s.postAt}  ${s.label}`),
  ].join('\n');
}

module.exports = { pendingSlots, fillSlots, describe };
