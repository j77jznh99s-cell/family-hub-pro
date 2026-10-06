const { test } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');

const usage = require('../src/presenter/usage');

const RESEARCH_RESPONSE = {
  usage: { input_tokens: 20000, output_tokens: 1500, cache_creation_input_tokens: 0, cache_read_input_tokens: 4000 },
  content: [
    { type: 'server_tool_use', name: 'web_search', id: 'a', input: {} },
    { type: 'web_search_tool_result', content: [] },
    { type: 'server_tool_use', name: 'web_search', id: 'b', input: {} },
    { type: 'text', text: 'brief' },
  ],
};
const SCRIPT_RESPONSE = { usage: { input_tokens: 3000, output_tokens: 800 }, content: [{ type: 'text', text: '{}' }] };

test('adds up tokens and counts web searches across calls', () => {
  const total = usage.emptyUsage();
  usage.addClaudeResponse(total, RESEARCH_RESPONSE);
  usage.addClaudeResponse(total, SCRIPT_RESPONSE);
  assert.deepEqual(total.claude, {
    calls: 2, input_tokens: 23000, output_tokens: 2300, cache_creation_input_tokens: 0, cache_read_input_tokens: 4000, web_searches: 2,
  });
});

test('claude cost at list price, overridable', () => {
  const c = { input_tokens: 1e6, output_tokens: 1e6, cache_creation_input_tokens: 1e6, cache_read_input_tokens: 1e6 };
  // 5 + 25 + 6.25 + 0.5
  assert.equal(usage.claudeCost(c), 36.75);
  assert.equal(usage.claudeCost(c, usage.prices({ PRESENTER_PRICE_INPUT_PER_MTOK: '2', PRESENTER_PRICE_OUTPUT_PER_MTOK: '10' })), 2 + 10 + 2.5 + 0.2);
});

test('summarize groups runs by month and skips demo runs', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'usage-test-'));
  try {
    const write = (name, u) => {
      fs.mkdirSync(path.join(dir, name));
      fs.writeFileSync(path.join(dir, name, 'usage.json'), JSON.stringify(u));
    };
    const u = usage.emptyUsage();
    usage.addClaudeResponse(u, RESEARCH_RESPONSE);
    u.heygen = { renders: 1, seconds: 60, test: false };
    write('2026-09-24-ai-x', u);
    write('2026-09-25-food-y', u);
    write('2026-10-01-money-z', u);
    write('demo-2026-09-24T10-00-00', u);
    fs.mkdirSync(path.join(dir, '2026-09-26-ai-no-usage'));

    const s = await usage.summarize(dir);
    assert.equal(s.runs.length, 3);
    assert.equal(s.months['2026-09'].runs, 2);
    assert.equal(s.months['2026-09'].heygenSeconds, 120);
    assert.equal(s.months['2026-09'].webSearches, 4);
    assert.equal(s.months['2026-10'].runs, 1);
    assert.match(usage.formatSummary(s), /2026-09 +2/);
    assert.match(usage.formatSummary({ runs: [], months: {} }), /No usage recorded/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('summarize survives odd usage.json files and failed-log lines without NaN', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'usage-test-'));
  try {
    const write = (name, text) => {
      fs.mkdirSync(path.join(dir, name));
      fs.writeFileSync(path.join(dir, name, 'usage.json'), text);
    };
    const good = usage.emptyUsage();
    usage.addClaudeResponse(good, { usage: { input_tokens: 1e6, output_tokens: 0 }, content: [] });
    write('2026-09-24-ai-good', JSON.stringify(good));
    write('2026-09-25-ai-empty-object', '{}');
    write('2026-09-26-ai-no-heygen', JSON.stringify({ claude: { input_tokens: 1e6 } }));
    write('2026-09-27-ai-string', '"oops"');
    write('2026-09-28-ai-torn', '{"claude":');
    fs.writeFileSync(
      path.join(dir, 'usage-failed.jsonl'),
      `${JSON.stringify({ at: '2026-09-29T10:00:00Z' })}\n${JSON.stringify({ at: '2026-09-29T11:00:00Z', usage: good })}\n`
    );

    const s = await usage.summarize(dir);
    const m = s.months['2026-09'];
    // good + {} + no-heygen count as runs; the string and the torn file are skipped.
    assert.equal(m.runs, 3);
    assert.equal(m.claudeUsd, 15); // 5 + 0 + 5 from runs, + 5 from the one failed line with usage
    assert.equal(m.failedAttempts, 1);
    assert.equal(m.heygenSeconds, 0);
    assert.equal(m.webSearches, 0);
    assert.doesNotMatch(usage.formatSummary(s), /NaN/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('a non-numeric price override is rejected instead of turning totals into NaN', () => {
  assert.throws(() => usage.prices({ PRESENTER_PRICE_INPUT_PER_MTOK: '$5' }), /plain numbers/);
  assert.throws(() => usage.prices({ PRESENTER_PRICE_OUTPUT_PER_MTOK: 'abc' }), /plain numbers/);
  assert.equal(usage.prices({ PRESENTER_PRICE_INPUT_PER_MTOK: '0' }).input, 0);
});

test('formatSummary lists months in order even when one only has failed attempts', () => {
  const month = (extra) => ({ runs: 0, claudeUsd: 0, webSearches: 0, heygenSeconds: 0, renders: 0, ...extra });
  // Insertion order as summarize builds it: run months first, failed-only months after.
  const text = usage.formatSummary({ runs: [], months: { '2026-10': month({ runs: 1 }), '2026-09': month({ failedAttempts: 1 }) } });
  assert.ok(text.indexOf('2026-09') < text.indexOf('2026-10'));
});
