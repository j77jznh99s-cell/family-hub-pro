// Turns "what's trending right now in <niche>" into a short, sourced, on-camera script.
// Two Claude calls: (1) research with live web search, (2) write the script as strict
// JSON against a schema. Kept separate so the script step works only from facts the
// research step actually found (and cited), not from the model's memory.
const Anthropic = require('@anthropic-ai/sdk');
const { NICHES } = require('./niches');

const MODEL = process.env.PRESENTER_MODEL || 'claude-opus-5';
// Server-side refusal fallback: a policy decline is retried on Anthropic's recommended
// fallback model inside the same call instead of failing the run.
const FALLBACK_BETA = 'server-side-fallback-2026-07-01';
const MAX_PAUSE_RESUMES = 4;

const AI_DISCLOSURE = 'Made with an AI avatar of me - script researched and fact-checked with AI.';

let client = null;
function getClient() {
  if (!client) client = new Anthropic();
  return client;
}

const RESEARCH_SYSTEM = `You research trending topics for a short-form informational video channel (TikTok, Reels, Shorts).
Use web search to find what is genuinely trending or newsworthy right now in the requested lane, then pick the ONE topic with the best mix of: broad current interest, a clear takeaway a viewer can learn in under a minute, and facts you can verify from reputable sources.
Avoid topics listed as recently covered. Avoid rumors, unverified leaks, and anything you can only find on one low-quality source.

Reply in plain text with:
TOPIC: one line
WHY NOW: one or two sentences on why it's trending this week
KEY FACTS: 3-6 bullet points, each with the specific number/date/name and the source URL it came from
ANGLE: the single most useful or surprising takeaway for a general audience`;

const SCRIPT_SYSTEM = `You write scripts for a presenter who speaks to camera in first person on a short-form informational channel.
Voice: confident, friendly, plain-spoken, like a smart friend explaining something - not a news anchor, no hype words ("insane", "game-changer"), no clickbait that the video doesn't pay off.
Structure: a hook in the first sentence that states the payoff; then the 2-4 most important facts in plain language; then one practical takeaway; end with a short, natural call to follow for more.
Length: 110-170 spoken words (about 45-70 seconds). Write for the ear: short sentences, numbers written the way they're said, no URLs, no emojis, no stage directions, no hashtags in the spoken script.
Accuracy: use ONLY facts present in the research brief. Do not add statistics, quotes or dates that aren't in the brief. If the brief hedges, hedge too.
Sources: list the URLs from the brief that support the facts you used.`;

const SCRIPT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['topic', 'title', 'hook', 'script', 'on_screen_text', 'description', 'hashtags', 'sources'],
  properties: {
    topic: { type: 'string', description: 'Short topic label' },
    title: { type: 'string', description: 'Post title, under 70 characters, no clickbait' },
    hook: { type: 'string', description: 'The first spoken sentence, verbatim from the script' },
    script: { type: 'string', description: 'The full spoken script, 110-170 words, starting with the hook' },
    on_screen_text: {
      type: 'array',
      items: { type: 'string' },
      description: '3-6 short text overlays (max ~6 words each) highlighting key facts, in order',
    },
    description: { type: 'string', description: 'Post caption, 1-3 sentences' },
    hashtags: { type: 'array', items: { type: 'string' }, description: '3-6 relevant hashtags without the # sign' },
    sources: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['title', 'url'],
        properties: { title: { type: 'string' }, url: { type: 'string' } },
      },
    },
  },
};

function assertNotRefused(response, step) {
  if (response.stop_reason === 'refusal') {
    const category = response.stop_details?.category || 'unspecified';
    throw new Error(`Claude declined the ${step} step (category: ${category})`);
  }
}

function textOf(response) {
  return response.content
    .filter((block) => block.type === 'text')
    .map((block) => block.text)
    .join('')
    .trim();
}

// Every URL the web search actually returned - used to reject script sources that
// weren't part of the research (i.e. made up or recalled from memory).
function searchResultUrls(contents) {
  const urls = new Set();
  for (const block of contents) {
    if (block.type === 'web_search_tool_result' && Array.isArray(block.content)) {
      for (const result of block.content) {
        if (result.url) urls.add(result.url);
      }
    }
  }
  return urls;
}

async function research(nicheKey, { recentTopics = [], now = new Date() } = {}) {
  const niche = NICHES[nicheKey];
  const messages = [
    {
      role: 'user',
      content:
        `Today is ${now.toISOString().slice(0, 10)}. Lane: ${niche.label}.\n` +
        `Look for: ${niche.searchFocus}.\n` +
        (recentTopics.length
          ? `Recently covered (pick something different): ${recentTopics.join('; ')}.\n`
          : '') +
        'Research and pick one topic.',
    },
  ];

  const allContent = [];
  let response;
  for (let attempt = 0; attempt <= MAX_PAUSE_RESUMES; attempt++) {
    response = await getClient().beta.messages.create({
      model: MODEL,
      max_tokens: 16000,
      betas: [FALLBACK_BETA],
      fallbacks: 'default',
      system: RESEARCH_SYSTEM,
      tools: [{ type: 'web_search_20260209', name: 'web_search', max_uses: 8 }],
      messages,
    });
    assertNotRefused(response, 'research');
    allContent.push(...response.content);
    // A long server-side search turn can pause; hand the partial turn back to resume it.
    if (response.stop_reason !== 'pause_turn') break;
    messages.push({ role: 'assistant', content: response.content });
  }
  if (response.stop_reason === 'pause_turn') {
    throw new Error('Research did not finish after several resumes');
  }

  const brief = textOf(response);
  if (!brief) throw new Error('Research returned no brief');
  return { brief, searchedUrls: searchResultUrls(allContent), model: response.model };
}

async function writeScript(nicheKey, brief) {
  const niche = NICHES[nicheKey];
  const response = await getClient().beta.messages.create({
    model: MODEL,
    max_tokens: 16000,
    betas: [FALLBACK_BETA],
    fallbacks: 'default',
    system: SCRIPT_SYSTEM,
    output_config: { format: { type: 'json_schema', schema: SCRIPT_SCHEMA } },
    messages: [
      {
        role: 'user',
        content:
          `Lane: ${niche.label}.\n` +
          (niche.disclaimer ? `This lane needs a brief spoken disclaimer near the end: "${niche.disclaimer}"\n` : '') +
          `Research brief:\n\n${brief}`,
      },
    ],
  });
  assertNotRefused(response, 'script');
  if (response.stop_reason === 'max_tokens') throw new Error('Script response was cut off (max_tokens)');
  return JSON.parse(textOf(response));
}

function wordCount(text) {
  return (text.match(/\S+/g) || []).length;
}

// Checks the model's output against the rules the prompt asked for and fills in the
// parts that must never be left to the model (disclaimers, AI disclosure).
function finalizeScript(raw, nicheKey, searchedUrls) {
  const niche = NICHES[nicheKey];
  const problems = [];
  const script = { ...raw, niche: nicheKey };

  const words = wordCount(script.script || '');
  if (words < 90 || words > 200) problems.push(`script is ${words} words (want 110-170)`);
  if (/https?:\/\//i.test(script.script || '')) problems.push('script contains a URL');

  // Sources must come from this run's web search, not from the model's memory.
  script.sources = (script.sources || []).filter(
    (s) => /^https?:\/\//.test(s.url) && (!searchedUrls || searchedUrls.size === 0 || searchedUrls.has(s.url))
  );
  if (script.sources.length === 0) problems.push('no sources that match the web search results');

  if (niche.disclaimer && !script.script.toLowerCase().includes('not financial advice')) {
    script.script = `${script.script.trim()} ${niche.disclaimer}`;
  }

  script.hashtags = (script.hashtags || []).map((h) => h.replace(/^#/, '').replace(/\s+/g, ''));
  const disclaimerLine = niche.disclaimer ? `\n\n${niche.disclaimer}` : '';
  script.description = `${(script.description || '').trim()}${disclaimerLine}\n\n${AI_DISCLOSURE}`;
  script.estimatedSeconds = Math.round((wordCount(script.script) / 150) * 60);

  return { script, problems };
}

module.exports = {
  research,
  writeScript,
  finalizeScript,
  searchResultUrls,
  wordCount,
  SCRIPT_SCHEMA,
  AI_DISCLOSURE,
  MODEL,
};
