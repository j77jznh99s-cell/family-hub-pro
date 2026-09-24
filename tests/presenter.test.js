const { test } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');

const tmpOut = fs.mkdtempSync(path.join(os.tmpdir(), 'presenter-test-'));
process.env.PRESENTER_OUTPUT_DIR = tmpOut;

const { NICHES, ORDER, nicheForDate, resolveNiche } = require('../src/presenter/niches');
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
