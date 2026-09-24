// Tracks what each presenter run consumed: Claude tokens and web searches, and HeyGen
// render time. Saved per run as usage.json; `--usage` totals them per month.
//
// Dollar estimates cover Claude tokens only, at list price (claude-opus-5: $5 / $25 per
// million input / output tokens; cache writes 1.25x input, cache reads 0.1x input). Override
// with PRESENTER_PRICE_INPUT_PER_MTOK / PRESENTER_PRICE_OUTPUT_PER_MTOK if your rate differs.
// Web searches and HeyGen minutes are counted, not priced - check those on your invoices.
const fs = require('fs/promises');
const path = require('path');

function emptyUsage() {
  return { claude: { calls: 0, input_tokens: 0, output_tokens: 0, cache_creation_input_tokens: 0, cache_read_input_tokens: 0, web_searches: 0 }, heygen: { renders: 0, seconds: 0, test: false } };
}

// Add one Messages API response to the running total.
function addClaudeResponse(total, response) {
  const u = response.usage || {};
  total.claude.calls += 1;
  for (const k of ['input_tokens', 'output_tokens', 'cache_creation_input_tokens', 'cache_read_input_tokens']) {
    total.claude[k] += Number(u[k]) || 0;
  }
  total.claude.web_searches += (response.content || []).filter(
    (b) => b.type === 'server_tool_use' && b.name === 'web_search'
  ).length;
  return total;
}

function prices(env = process.env) {
  const input = parseFloat(env.PRESENTER_PRICE_INPUT_PER_MTOK || '5');
  const output = parseFloat(env.PRESENTER_PRICE_OUTPUT_PER_MTOK || '25');
  return { input, output, cacheWrite: input * 1.25, cacheRead: input * 0.1 };
}

function claudeCost(claude, p = prices()) {
  const usd =
    (claude.input_tokens * p.input +
      claude.output_tokens * p.output +
      claude.cache_creation_input_tokens * p.cacheWrite +
      claude.cache_read_input_tokens * p.cacheRead) /
    1e6;
  return Math.round(usd * 10000) / 10000;
}

async function readUsage(runDir) {
  try {
    return JSON.parse(await fs.readFile(path.join(runDir, 'usage.json'), 'utf8'));
  } catch {
    return null;
  }
}

const FAILED_LOG = 'usage-failed.jsonl';

// Attempts that never got a run folder (script failed its checks) still spent tokens.
async function logFailedAttempt(outputDir, entry) {
  await fs.mkdir(outputDir, { recursive: true });
  await fs.appendFile(path.join(outputDir, FAILED_LOG), `${JSON.stringify(entry)}\n`, 'utf8');
}

async function readFailedAttempts(outputDir) {
  let text;
  try {
    text = await fs.readFile(path.join(outputDir, FAILED_LOG), 'utf8');
  } catch {
    return [];
  }
  return text.split('\n').filter(Boolean).flatMap((line) => {
    try {
      return [JSON.parse(line)];
    } catch {
      return []; // a torn last line from an interrupted write
    }
  });
}

// Per-run usage for every run folder, plus totals per calendar month (from the folder's
// leading YYYY-MM-DD; demo runs are skipped since they use no APIs).
async function summarize(outputDir) {
  let entries = [];
  try {
    entries = (await fs.readdir(outputDir, { withFileTypes: true })).filter((e) => e.isDirectory()).map((e) => e.name).sort();
  } catch {
    // nothing yet
  }
  const runs = [];
  const months = {};
  for (const name of entries) {
    if (name.startsWith('demo-')) continue;
    const u = await readUsage(path.join(outputDir, name));
    if (!u) continue;
    const month = /^\d{4}-\d{2}/.test(name) ? name.slice(0, 7) : 'unknown';
    const cost = claudeCost(u.claude);
    runs.push({ run: name, month, claudeUsd: cost, webSearches: u.claude.web_searches, heygenSeconds: u.heygen.seconds });
    const m = (months[month] ||= { runs: 0, claudeUsd: 0, webSearches: 0, heygenSeconds: 0, renders: 0 });
    m.runs += 1;
    m.claudeUsd = Math.round((m.claudeUsd + cost) * 10000) / 10000;
    m.webSearches += u.claude.web_searches;
    m.heygenSeconds += u.heygen.seconds;
    m.renders += u.heygen.renders;
  }
  for (const f of await readFailedAttempts(outputDir)) {
    const month = String(f.at || '').slice(0, 7) || 'unknown';
    const cost = claudeCost(f.usage.claude);
    const m = (months[month] ||= { runs: 0, claudeUsd: 0, webSearches: 0, heygenSeconds: 0, renders: 0 });
    m.failedAttempts = (m.failedAttempts || 0) + 1;
    m.claudeUsd = Math.round((m.claudeUsd + cost) * 10000) / 10000;
    m.webSearches += f.usage.claude.web_searches;
  }
  return { runs, months };
}

function formatSummary({ runs, months }) {
  if (!runs.length && !Object.keys(months).length) {
    return 'No usage recorded yet (usage.json is written by runs made after this feature was added).';
  }
  const lines = ['Run                                             Claude $  searches  HeyGen s'];
  for (const r of runs) {
    lines.push(`${r.run.slice(0, 46).padEnd(46)} ${r.claudeUsd.toFixed(2).padStart(9)} ${String(r.webSearches).padStart(9)} ${String(Math.round(r.heygenSeconds)).padStart(9)}`);
  }
  lines.push('', 'Month      runs  failed  Claude $  searches  HeyGen min');
  for (const [month, m] of Object.entries(months)) {
    lines.push(`${month.padEnd(9)} ${String(m.runs).padStart(5)} ${String(m.failedAttempts || 0).padStart(7)} ${m.claudeUsd.toFixed(2).padStart(9)} ${String(m.webSearches).padStart(9)} ${(m.heygenSeconds / 60).toFixed(1).padStart(11)}`);
  }
  lines.push('', 'Claude $ is tokens at list price only; web searches and HeyGen minutes are billed separately - check your invoices.');
  return lines.join('\n');
}

module.exports = { emptyUsage, addClaudeResponse, claudeCost, prices, readUsage, summarize, formatSummary, logFailedAttempt, readFailedAttempts };
