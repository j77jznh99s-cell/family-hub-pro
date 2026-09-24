// One markdown page for a quick weekly review: the last 7 days of the calendar (what got
// made, what was missed), the pre-posting check for each run in that window, and what
// the month has cost so far. Reads files only - no API calls.
const path = require('path');
const calendar = require('./calendar');
const check = require('./check');
const usage = require('./usage');

const DAY_MS = 86400000;

async function buildWeeklyReport(outputDir, { now = new Date(), times } = {}) {
  const start = new Date(now.getTime() - 6 * DAY_MS);
  const slots = await calendar.attachRuns(calendar.planWeek({ start, days: 7, times }), outputDir);
  const todayIso = now.toISOString().slice(0, 10);

  const checked = [];
  for (const slot of slots.filter((s) => s.runDir)) {
    checked.push({ slot, result: await check.checkRun(path.join(outputDir, slot.runDir)) });
  }

  const made = slots.filter((s) => s.status !== 'planned').length;
  const missed = slots.filter((s) => s.status === 'planned' && s.date < todayIso).length;
  const ready = checked.filter((c) => c.result.ok).length;

  const lines = [
    `# Presenter week: ${slots[0].date} to ${slots[slots.length - 1].date}`,
    '',
    `**${made} of ${slots.length} slots have a run, ${ready} pass the pre-posting check, ${missed} missed.**`,
    '',
    '## Calendar',
    '',
    calendar.toMarkdown(slots, { today: now }).split('\n').slice(2).join('\n').trim(),
    '',
    '## Pre-posting check',
    '',
  ];
  if (!checked.length) lines.push('No runs this week.');
  for (const { slot, result } of checked) {
    lines.push(`- **${result.ok ? 'Ready' : 'Not ready'}** - ${slot.weekday} ${slot.date}, ${slot.label}: ${slot.topic || slot.runDir}`);
    for (const p of result.problems) lines.push(`  - problem: ${p}`);
    for (const w of result.warnings) lines.push(`  - check: ${w}`);
  }

  const month = todayIso.slice(0, 7);
  const m = (await usage.summarize(outputDir)).months[month];
  lines.push('', `## Spend in ${month}`, '');
  if (m) {
    lines.push(
      `- Runs with usage recorded: ${m.runs}`,
      `- Claude (estimate at list price): $${m.claudeUsd.toFixed(2)}`,
      `- Web searches: ${m.webSearches}`,
      `- HeyGen: ${m.renders} render(s), ${(m.heygenSeconds / 60).toFixed(1)} min`,
      '',
      'Web searches and HeyGen minutes are billed separately - check the invoices.'
    );
  } else {
    lines.push('No usage recorded this month.');
  }
  lines.push('', '_Nothing in this report posts anything. Review, then post by hand._');
  return `${lines.join('\n')}\n`;
}

module.exports = { buildWeeklyReport };
