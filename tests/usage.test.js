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
