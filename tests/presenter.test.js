const { test } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');

const tmpOut = fs.mkdtempSync(path.join(os.tmpdir(), 'presenter-test-'));
process.env.PRESENTER_OUTPUT_DIR = tmpOut;

const { NICHES, ORDER, nicheForDate, resolveNiche, hasSpokenDisclaimer } = require('../src/presenter/niches');
const writer = require('../src/presenter/writer');
const heygen = require('../src/presenter/heygen');
const presenter = require('../src/presenter');

test.after(() => fs.rmSync(tmpOut, { recursive: true, force: true }));

const WORDS_130 = Array.from({ length: 130 }, (_, i) => `word${i}`).join(' ');

function rawScript(overrides = {}) {
  return {
    topic: 'Fed holds rates',
    title: 'Why the Fed paused',
    hook: 'The Fed just hit pause.',
    script: `The Fed just hit pause. ${WORDS_130}`,
    on_screen_text: ['Rates unchanged'],
    description: 'What the pause means for you.',
    hashtags: ['#finance', 'fed rates'],
    sources: [{ title: 'Reuters', url: 'https://reuters.com/a' }],
    ...overrides,
  };
}

test('niche rotation walks every lane on consecutive days', () => {
  const start = new Date('2026-09-24T12:00:00Z');
  const seen = new Set(ORDER.map((_, i) => nicheForDate(new Date(start.getTime() + i * 86400000))));
  assert.equal(seen.size, ORDER.length);
  assert.equal(resolveNiche('food'), 'food');
  assert.ok(ORDER.includes(resolveNiche('auto')));
  assert.throws(() => resolveNiche('sports'), /Unknown niche/);
});

test('finalizeScript adds disclaimer and AI disclosure, cleans hashtags', () => {
  const searched = new Set(['https://reuters.com/a']);
  const { script, problems } = writer.finalizeScript(rawScript(), 'markets', searched);
  assert.deepEqual(problems, []);
  assert.match(script.script, /Not financial advice/);
  assert.match(script.description, /Not financial advice/);
  assert.ok(script.description.endsWith(writer.AI_DISCLOSURE));
  assert.deepEqual(script.hashtags, ['finance', 'fedrates']);
  assert.ok(script.estimatedSeconds > 40 && script.estimatedSeconds < 80);
});

test('finalizeScript does not double a disclaimer the model already spoke', () => {
  const raw = rawScript({ script: `${WORDS_130} This is general education, not financial advice.` });
  const { script } = writer.finalizeScript(raw, 'money', new Set(['https://reuters.com/a']));
  assert.equal(script.script.match(/not financial advice/gi).length, 1);
});

test('finalizeScript does not double a disclaimer spoken word-for-word', () => {
  const searched = new Set(['https://reuters.com/a']);
  for (const key of ['money', 'markets']) {
    const spoken = `${WORDS_130} ${NICHES[key].disclaimer}`;
    const { script } = writer.finalizeScript(rawScript({ script: spoken }), key, searched);
    assert.equal(script.script, spoken, key);
  }
});

test('finalizeScript reports a missing script instead of throwing', () => {
  const searched = new Set(['https://reuters.com/a']);
  for (const key of ['ai', 'markets']) {
    let result;
    assert.doesNotThrow(() => { result = writer.finalizeScript(rawScript({ script: undefined }), key, searched); });
    assert.ok(result.problems.includes('script text is missing'), key);
    assert.ok(result.problems.some((p) => /words/.test(p)), key);
  }
});

test('every disclaimer has a key phrase that appears in its own text', () => {
  for (const [key, niche] of Object.entries(NICHES)) {
    if (!niche.disclaimer) {
      assert.equal(niche.disclaimerKeyPhrase, null, key);
      continue;
    }
    assert.ok(niche.disclaimerKeyPhrase, `${key} has no disclaimerKeyPhrase`);
    assert.ok(niche.disclaimer.toLowerCase().includes(niche.disclaimerKeyPhrase.toLowerCase()), key);
  }
});

test('hasSpokenDisclaimer accepts the full disclaimer or its key phrase', () => {
  const { money, markets, ai } = NICHES;
  assert.equal(hasSpokenDisclaimer(`Intro. ${money.disclaimer}`, money), true);
  assert.equal(hasSpokenDisclaimer('Intro.  NOT   financial\nadvice, folks.', markets), true); // paraphrase, odd spacing
  assert.equal(hasSpokenDisclaimer('Do your own research before you trade.', markets), false);
  assert.equal(hasSpokenDisclaimer('', money), false);
  assert.equal(hasSpokenDisclaimer(undefined, money), false);
  assert.equal(hasSpokenDisclaimer('Anything at all.', ai), true); // lane needs no disclaimer
  // A reworded disclaimer is still recognised when spoken in full, even without the key phrase.
  const custom = { disclaimer: 'Educational only.', disclaimerKeyPhrase: null };
  assert.equal(hasSpokenDisclaimer('That was educational   only.', custom), true);
  assert.equal(hasSpokenDisclaimer('That was it.', custom), false);
});

test('finalizeScript rejects sources that the web search never returned', () => {
  const { problems } = writer.finalizeScript(rawScript(), 'ai', new Set(['https://other.com/x']));
  assert.ok(problems.some((p) => /no sources/.test(p)));
});

test('finalizeScript flags scripts that are too short/long or contain URLs', () => {
  const searched = new Set(['https://reuters.com/a']);
  assert.ok(writer.finalizeScript(rawScript({ script: 'Too short.' }), 'ai', searched).problems.some((p) => /words/.test(p)));
  const withUrl = rawScript({ script: `${WORDS_130} see https://x.com` });
  assert.ok(writer.finalizeScript(withUrl, 'ai', searched).problems.some((p) => /URL/.test(p)));
});

test('searchResultUrls collects URLs from web search result blocks only', () => {
  const urls = writer.searchResultUrls([
    { type: 'text', text: 'hi https://not-counted.com' },
    { type: 'web_search_tool_result', content: [{ url: 'https://a.com' }, { url: 'https://b.com' }] },
    { type: 'web_search_tool_result', content: { error_code: 'max_uses_exceeded' } },
  ]);
  assert.deepEqual([...urls].sort(), ['https://a.com', 'https://b.com']);
});

test('buildGenerateBody uses a video avatar when set, else a talking photo', () => {
  const base = { apiKey: 'k', voiceId: 'v1', avatarStyle: 'normal', test: true, width: 1080, height: 1920 };
  const avatar = heygen.buildGenerateBody({ ...base, avatarId: 'av1', talkingPhotoId: 'tp1' }, { script: 'Hi', title: 'T' });
  assert.deepEqual(avatar.video_inputs[0].character, { type: 'avatar', avatar_id: 'av1', avatar_style: 'normal' });
  assert.deepEqual(avatar.video_inputs[0].voice, { type: 'text', input_text: 'Hi', voice_id: 'v1' });
  assert.deepEqual(avatar.dimension, { width: 1080, height: 1920 });
  assert.equal(avatar.test, true);

  const photo = heygen.buildGenerateBody({ ...base, avatarId: '', talkingPhotoId: 'tp1' }, { script: 'Hi' });
  assert.deepEqual(photo.video_inputs[0].character, { type: 'talking_photo', talking_photo_id: 'tp1' });
});

test('missingConfig names every missing HeyGen setting', () => {
  assert.deepEqual(heygen.missingConfig(heygen.heygenConfig({})), [
    'HEYGEN_API_KEY',
    'HEYGEN_AVATAR_ID (or HEYGEN_TALKING_PHOTO_ID)',
    'HEYGEN_VOICE_ID',
  ]);
  assert.deepEqual(heygen.missingConfig(heygen.heygenConfig({ HEYGEN_API_KEY: 'k', HEYGEN_TALKING_PHOTO_ID: 't', HEYGEN_VOICE_ID: 'v' })), []);
});

function fakeFetch(routes) {
  const calls = [];
  const impl = async (url, opts = {}) => {
    calls.push({ url, opts });
    const handler = routes.find(([match]) => url.includes(match));
    if (!handler) throw new Error(`unexpected fetch ${url}`);
    const { status = 200, body } = handler[1](calls.length);
    return {
      ok: status < 400,
      status,
      text: async () => (typeof body === 'string' ? body : JSON.stringify(body)),
      arrayBuffer: async () => Buffer.from(typeof body === 'string' ? body : JSON.stringify(body)),
    };
  };
  return { impl, calls };
}

const CFG = { apiKey: 'secret', avatarId: 'av', voiceId: 'v', avatarStyle: 'normal', test: false, width: 1080, height: 1920 };

test('startVideo posts with the API key header and returns the video id', async () => {
  const { impl, calls } = fakeFetch([['/v2/video/generate', () => ({ body: { error: null, data: { video_id: 'vid1' } } })]]);
  assert.equal(await heygen.startVideo(CFG, { script: 'Hello' }, { fetchImpl: impl }), 'vid1');
  assert.equal(calls[0].opts.method, 'POST');
  assert.equal(calls[0].opts.headers['X-Api-Key'], 'secret');
  assert.equal(JSON.parse(calls[0].opts.body).video_inputs[0].voice.input_text, 'Hello');
});

test('startVideo surfaces HeyGen errors with the response body', async () => {
  const { impl } = fakeFetch([['/v2/video/generate', () => ({ status: 401, body: { error: { message: 'bad key' } } })]]);
  await assert.rejects(heygen.startVideo(CFG, { script: 'x' }, { fetchImpl: impl }), /401.*bad key/);
});

test('waitForVideo polls until completed', async () => {
  const statuses = ['pending', 'processing', 'completed'];
  let i = 0;
  const { impl } = fakeFetch([
    ['/v1/video_status.get', () => {
      const status = statuses[i++];
      return { body: { code: 100, data: { status, video_url: status === 'completed' ? 'https://cdn/v.mp4' : null } } };
    }],
  ]);
  const seen = [];
  const result = await heygen.waitForVideo(CFG, 'vid1', { fetchImpl: impl, intervalMs: 1, onStatus: (s) => seen.push(s) });
  assert.equal(result.videoUrl, 'https://cdn/v.mp4');
  assert.deepEqual(seen, statuses);
});

test('waitForVideo throws on a failed render', async () => {
  const { impl } = fakeFetch([['/v1/video_status.get', () => ({ body: { data: { status: 'failed', error: { message: 'voice missing' } } } })]]);
  await assert.rejects(heygen.waitForVideo(CFG, 'vid1', { fetchImpl: impl, intervalMs: 1 }), /voice missing/);
});

test('createPresenterVideo (script-only) saves research, script and post text', async (t) => {
  t.mock.method(writer, 'research', async (niche, { recentTopics }) => {
    assert.equal(niche, 'markets');
    assert.ok(Array.isArray(recentTopics));
    return { brief: 'TOPIC: Fed holds rates', searchedUrls: new Set(['https://reuters.com/a']) };
  });
  t.mock.method(writer, 'writeScript', async () => rawScript());

  const { runDir, script } = await presenter.createPresenterVideo({ niche: 'markets', render: false, log: () => {} });
  assert.match(path.basename(runDir), /-markets-fed-holds-rates$/);
  assert.equal(fs.readFileSync(path.join(runDir, 'research.md'), 'utf8'), 'TOPIC: Fed holds rates');
  const saved = JSON.parse(fs.readFileSync(path.join(runDir, 'script.json'), 'utf8'));
  assert.equal(saved.title, script.title);
  const post = fs.readFileSync(path.join(runDir, 'post.txt'), 'utf8');
  assert.match(post, /#finance/);
  assert.match(post, /https:\/\/reuters\.com\/a/);
  assert.match(post, /AI avatar/);

  assert.deepEqual(await presenter.recentTopics(), ['Fed holds rates']);
});

test('createPresenterVideo refuses to render a script that failed its checks', async (t) => {
  t.mock.method(writer, 'research', async () => ({ brief: 'b', searchedUrls: new Set(['https://reuters.com/a']) }));
  t.mock.method(writer, 'writeScript', async () => rawScript({ script: 'Too short.' }));
  await assert.rejects(presenter.createPresenterVideo({ niche: 'ai', render: false, log: () => {} }), /failed checks/);
});

test('createPresenterVideo with render=true requires HeyGen settings up front', async (t) => {
  const research = t.mock.method(writer, 'research', async () => ({ brief: 'b', searchedUrls: new Set() }));
  for (const k of ['HEYGEN_API_KEY', 'HEYGEN_AVATAR_ID', 'HEYGEN_TALKING_PHOTO_ID', 'HEYGEN_VOICE_ID']) delete process.env[k];
  await assert.rejects(presenter.createPresenterVideo({ niche: 'ai', render: true, log: () => {} }), /HEYGEN_API_KEY/);
  assert.equal(research.mock.calls.length, 0); // no Claude spend before config is valid
});

test('createPresenterVideo records Claude usage in usage.json', async (t) => {
  t.mock.method(writer, 'research', async (niche, { onResponse }) => {
    onResponse({ usage: { input_tokens: 1000, output_tokens: 200 }, content: [{ type: 'server_tool_use', name: 'web_search' }] });
    return { brief: 'TOPIC: Usage check', searchedUrls: new Set(['https://reuters.com/a']) };
  });
  t.mock.method(writer, 'writeScript', async (niche, brief, { onResponse }) => {
    onResponse({ usage: { input_tokens: 500, output_tokens: 300 }, content: [] });
    return rawScript({ topic: 'Usage check' });
  });
  const { runDir } = await presenter.createPresenterVideo({ niche: 'ai', render: false, log: () => {} });
  const saved = JSON.parse(fs.readFileSync(path.join(runDir, 'usage.json'), 'utf8'));
  assert.equal(saved.claude.calls, 2);
  assert.equal(saved.claude.input_tokens, 1500);
  assert.equal(saved.claude.output_tokens, 500);
  assert.equal(saved.claude.web_searches, 1);
  assert.equal(saved.heygen.renders, 0);
});

test('a script that fails its checks still logs the Claude spend', async (t) => {
  const usage = require('../src/presenter/usage');
  t.mock.method(writer, 'research', async (niche, { onResponse }) => {
    onResponse({ usage: { input_tokens: 2000, output_tokens: 100 }, content: [] });
    return { brief: 'b', searchedUrls: new Set(['https://reuters.com/a']) };
  });
  t.mock.method(writer, 'writeScript', async () => rawScript({ script: 'Too short.' }));
  await assert.rejects(presenter.createPresenterVideo({ niche: 'ai', render: false, log: () => {} }), /failed checks/);
  const failed = await usage.readFailedAttempts(tmpOut);
  assert.equal(failed.at(-1).usage.claude.input_tokens, 2000);
  assert.match(failed.at(-1).reason, /words/);
  const summary = await usage.summarize(tmpOut);
  const month = Object.values(summary.months).find((m) => m.failedAttempts);
  assert.ok(month.failedAttempts >= 1);
});

// The failed log is shared by every test in this file, so these compare entry counts
// before and after rather than the absolute contents.
test('research throwing after a Claude reply still logs the spend and rethrows', async (t) => {
  const usage = require('../src/presenter/usage');
  const before = (await usage.readFailedAttempts(tmpOut)).length;
  t.mock.method(writer, 'research', async (niche, { onResponse }) => {
    onResponse({ usage: { input_tokens: 3000, output_tokens: 40 }, content: [{ type: 'server_tool_use', name: 'web_search' }] });
    throw new Error('Research returned no brief');
  });
  const writeScript = t.mock.method(writer, 'writeScript', async () => rawScript());
  await assert.rejects(presenter.createPresenterVideo({ niche: 'ai', render: false, log: () => {} }), /^Error: Research returned no brief$/);
  assert.equal(writeScript.mock.calls.length, 0);
  const failed = await usage.readFailedAttempts(tmpOut);
  assert.equal(failed.length, before + 1);
  assert.equal(failed.at(-1).reason, 'Research returned no brief');
  assert.equal(failed.at(-1).niche, 'ai');
  assert.equal(failed.at(-1).usage.claude.calls, 1);
  assert.equal(failed.at(-1).usage.claude.input_tokens, 3000);
  assert.equal(failed.at(-1).usage.claude.web_searches, 1);
});

test('writeScript throwing logs research + script spend and rethrows the original error', async (t) => {
  const usage = require('../src/presenter/usage');
  const before = (await usage.readFailedAttempts(tmpOut)).length;
  t.mock.method(writer, 'research', async (niche, { onResponse }) => {
    onResponse({ usage: { input_tokens: 1000, output_tokens: 100 }, content: [] });
    return { brief: 'b', searchedUrls: new Set(['https://reuters.com/a']) };
  });
  const original = new Error('Script response was cut off (max_tokens)');
  t.mock.method(writer, 'writeScript', async (niche, brief, { onResponse }) => {
    onResponse({ usage: { input_tokens: 400, output_tokens: 16000 }, content: [] });
    throw original;
  });
  await assert.rejects(presenter.createPresenterVideo({ niche: 'ai', render: false, log: () => {} }), (err) => err === original);
  const failed = await usage.readFailedAttempts(tmpOut);
  assert.equal(failed.length, before + 1);
  assert.equal(failed.at(-1).reason, original.message);
  assert.equal(failed.at(-1).usage.claude.calls, 2);
  assert.equal(failed.at(-1).usage.claude.input_tokens, 1400);
  assert.equal(failed.at(-1).usage.claude.output_tokens, 16100);
});

test('an error before any Claude reply logs nothing', async (t) => {
  const usage = require('../src/presenter/usage');
  const before = (await usage.readFailedAttempts(tmpOut)).length;
  t.mock.method(writer, 'research', async () => { throw new Error('fetch failed'); });
  await assert.rejects(presenter.createPresenterVideo({ niche: 'ai', render: false, log: () => {} }), /fetch failed/);
  assert.equal((await usage.readFailedAttempts(tmpOut)).length, before);
});

test('a failing usage log does not hide the original error', async (t) => {
  const usage = require('../src/presenter/usage');
  t.mock.method(usage, 'logFailedAttempt', async () => { throw new Error('disk full'); });
  t.mock.method(writer, 'research', async (niche, { onResponse }) => {
    onResponse({ usage: { input_tokens: 10, output_tokens: 1 }, content: [] });
    throw new Error('Claude declined the research step (category: unspecified)');
  });
  const logs = [];
  await assert.rejects(presenter.createPresenterVideo({ niche: 'ai', render: false, log: (m) => logs.push(m) }), /declined the research step/);
  assert.ok(logs.some((m) => /couldn't record failed-attempt usage: disk full/.test(m)));
});

test('a script that fails its checks logs exactly one failed attempt', async (t) => {
  const usage = require('../src/presenter/usage');
  const before = (await usage.readFailedAttempts(tmpOut)).length;
  t.mock.method(writer, 'research', async (niche, { onResponse }) => {
    onResponse({ usage: { input_tokens: 700, output_tokens: 70 }, content: [] });
    return { brief: 'b', searchedUrls: new Set(['https://reuters.com/a']) };
  });
  t.mock.method(writer, 'writeScript', async () => rawScript({ script: 'Too short.' }));
  await assert.rejects(presenter.createPresenterVideo({ niche: 'ai', render: false, log: () => {} }), /^Error: Script failed checks: .*words/);
  const failed = await usage.readFailedAttempts(tmpOut);
  assert.equal(failed.length, before + 1);
  assert.match(failed.at(-1).reason, /^script is 2 words/);
  assert.equal(failed.at(-1).usage.claude.input_tokens, 700);
});

test('createPresenterVideo forDate files the run under the slot date but researches with today', async (t) => {
  const today = new Date('2026-09-24T15:00:00Z');
  t.mock.method(writer, 'research', async (niche, { now }) => {
    assert.equal(now.toISOString().slice(0, 10), '2026-09-24'); // real date for the news search
    return { brief: 'TOPIC: Ahead of time', searchedUrls: new Set(['https://reuters.com/a']) };
  });
  t.mock.method(writer, 'writeScript', async () => rawScript({ topic: 'Ahead of time' }));
  const { runDir } = await presenter.createPresenterVideo({
    niche: 'auto', render: false, now: today, forDate: new Date('2026-09-26T12:00:00Z'), log: () => {},
  });
  const { nicheForDate } = require('../src/presenter/niches');
  assert.equal(path.basename(runDir), `2026-09-26-${nicheForDate(new Date('2026-09-26T12:00:00Z'))}-ahead-of-time`);
});
