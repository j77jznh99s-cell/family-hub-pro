// Plans the week ahead: which lane each video slot covers, when to post it, and which
// slots already have a finished run folder. Pure planning - no API calls - so it can be
// run any time to see what's coming and what's been missed.
const fs = require('fs/promises');
const path = require('path');
const { NICHES, ORDER } = require('./niches');

const DAY_MS = 86400000;
const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

// Posting times are a starting point to tune against your own analytics, not a rule.
function parseTimes(value) {
  const times = String(value || '12:00,18:00')
    .split(',')
    .map((t) => t.trim())
    .filter(Boolean);
  for (const t of times) {
    if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(t)) throw new Error(`Bad post time "${t}" - use HH:MM, 24-hour`);
  }
  return times;
}

function dayIndex(date) {
  return Math.floor(date.getTime() / DAY_MS);
}

// Slots are numbered continuously (day * perDay + slot), so lanes rotate evenly across
// the week and consecutive days never open with the same lane. With one video a day
// this matches the lane `--niche auto` picks for that date.
function planWeek({ start = new Date(), days = 7, perDay = 1, times } = {}) {
  if (!Number.isInteger(days) || days < 1 || days > 31) throw new Error('days must be 1-31');
  if (!Number.isInteger(perDay) || perDay < 1 || perDay > 6) throw new Error('perDay must be 1-6');
  const postTimes = parseTimes(times);
  const first = dayIndex(start);
  const slots = [];
  for (let d = 0; d < days; d++) {
    const date = new Date((first + d) * DAY_MS);
    const isoDate = date.toISOString().slice(0, 10);
    for (let i = 0; i < perDay; i++) {
      const n = (first + d) * perDay + i;
      const niche = ORDER[((n % ORDER.length) + ORDER.length) % ORDER.length];
      slots.push({
        date: isoDate,
        weekday: WEEKDAYS[date.getUTCDay()],
        slot: i + 1,
        postAt: postTimes[i % postTimes.length],
        niche,
        label: NICHES[niche].label,
      });
    }
  }
  return slots;
}

// Run folders are named "<date>-<niche>-<slug>" (see index.js). Match each slot to one
// unused folder for the same date and lane, and note whether it got as far as a video.
async function attachRuns(slots, outputDir) {
  let entries = [];
  try {
    entries = (await fs.readdir(outputDir)).sort();
  } catch {
    // no runs yet
  }
  const used = new Set();
  const result = [];
  for (const slot of slots) {
    const prefix = `${slot.date}-${slot.niche}-`;
    const dir = entries.find((e) => e.startsWith(prefix) && !used.has(e));
    let status = 'planned';
    let topic = null;
    if (dir) {
      used.add(dir);
      const runDir = path.join(outputDir, dir);
      const exists = (f) => fs.access(path.join(runDir, f)).then(() => true, () => false);
      if (await exists('video.captioned.mp4')) status = 'captioned';
      else if (await exists('video.mp4')) status = 'rendered';
      else if (await exists('script.json')) status = 'scripted';
      try {
        topic = JSON.parse(await fs.readFile(path.join(runDir, 'script.json'), 'utf8')).topic || null;
      } catch {
        // incomplete run
      }
    }
    result.push({ ...slot, status, topic, runDir: dir || null });
  }
  return result;
}

function toMarkdown(slots, { today = new Date() } = {}) {
  const todayIso = today.toISOString().slice(0, 10);
  const lines = [
    `# Presenter calendar ${slots[0].date} to ${slots[slots.length - 1].date}`,
    '',
    '| Date | Post (local) | Lane | Status | Topic / command |',
    '| --- | --- | --- | --- | --- |',
  ];
  for (const s of slots) {
    const missed = s.status === 'planned' && s.date < todayIso;
    const status = missed ? 'missed' : s.status;
    const detail = s.topic || `\`npm run presenter -- --niche ${s.niche}\``;
    lines.push(`| ${s.weekday} ${s.date} | ${s.postAt} | ${s.label} | ${status} | ${detail} |`);
  }
  const counts = {};
  for (const s of slots) counts[s.label] = (counts[s.label] || 0) + 1;
  lines.push('', `Lanes this period: ${Object.entries(counts).map(([k, v]) => `${k} x${v}`).join(', ')}`);
  return `${lines.join('\n')}\n`;
}

module.exports = { planWeek, attachRuns, toMarkdown, parseTimes };
