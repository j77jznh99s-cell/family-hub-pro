// Orchestrates one AI-presenter video: pick lane -> research trends -> write script ->
// render with HeyGen -> save everything (script, sources, caption, video) to one folder.
const fs = require('fs/promises');
const path = require('path');
const { NICHES, resolveNiche } = require('./niches');
const writer = require('./writer');
const heygen = require('./heygen');
const overlay = require('./overlay');

const OUTPUT_DIR =
  process.env.PRESENTER_OUTPUT_DIR || path.join(__dirname, '..', '..', 'data', 'presenter');

function slugify(text) {
  return String(text)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 50) || 'video';
}

// Topics from earlier runs, newest first, so research can steer away from repeats.
async function recentTopics(outputDir = OUTPUT_DIR, limit = 15) {
  let entries;
  try {
    entries = await fs.readdir(outputDir);
  } catch {
    return [];
  }
  const topics = [];
  for (const entry of entries.sort().reverse().slice(0, limit)) {
    try {
      const saved = JSON.parse(await fs.readFile(path.join(outputDir, entry, 'script.json'), 'utf8'));
      if (saved.topic) topics.push(saved.topic);
    } catch {
      // not a run folder, or an incomplete one - skip
    }
  }
  return topics;
}

function postText(script) {
  const tags = script.hashtags.map((h) => `#${h}`).join(' ');
  const sources = script.sources.map((s) => `- ${s.title}: ${s.url}`).join('\n');
  return `${script.title}\n\n${script.description}\n\n${tags}\n\nSources:\n${sources}\n`;
}

async function createPresenterVideo({ niche, render = true, now = new Date(), log = console.log } = {}) {
  const nicheKey = resolveNiche(niche, now);
  const cfg = heygen.heygenConfig();
  if (render) {
    const missing = heygen.missingConfig(cfg);
    if (missing.length) {
      throw new Error(`Missing ${missing.join(', ')} - see docs/ai-presenter.md, or run with --script-only`);
    }
  }

  log(`[presenter] lane: ${NICHES[nicheKey].label}`);
  const { brief, searchedUrls } = await writer.research(nicheKey, {
    recentTopics: await recentTopics(),
    now,
  });
  log('[presenter] research done, writing script');
  const raw = await writer.writeScript(nicheKey, brief);
  const { script, problems } = writer.finalizeScript(raw, nicheKey, searchedUrls);
  if (problems.length) {
    // Don't spend render credits on a script that failed its own checks.
    throw new Error(`Script failed checks: ${problems.join('; ')}`);
  }

  const runDir = path.join(OUTPUT_DIR, `${now.toISOString().slice(0, 10)}-${nicheKey}-${slugify(script.topic)}`);
  await fs.mkdir(runDir, { recursive: true });
  await fs.writeFile(path.join(runDir, 'research.md'), brief, 'utf8');
  await fs.writeFile(path.join(runDir, 'script.json'), JSON.stringify(script, null, 2), 'utf8');
  await fs.writeFile(path.join(runDir, 'post.txt'), postText(script), 'utf8');
  log(`[presenter] "${script.title}" (~${script.estimatedSeconds}s) -> ${runDir}`);

  if (!render) return { runDir, script };

  const videoId = await heygen.startVideo(cfg, { script: script.script, title: script.title });
  log(`[presenter] HeyGen rendering ${videoId}${cfg.test ? ' (test mode, watermarked)' : ''}`);
  const result = await heygen.waitForVideo(cfg, videoId, {
    onStatus: (status) => log(`[presenter] HeyGen status: ${status}`),
  });
  const videoPath = await heygen.downloadTo(result.videoUrl, path.join(runDir, 'video.mp4'));
  await fs.writeFile(
    path.join(runDir, 'render.json'),
    JSON.stringify({ videoId, ...result, renderedAt: new Date().toISOString() }, null, 2),
    'utf8'
  );
  log(`[presenter] saved ${videoPath}`);

  let captionedPath = null;
  if (process.env.PRESENTER_BURN_TEXT !== 'false') {
    let captionSrtPath;
    if (result.captionUrl) {
      try {
        captionSrtPath = await heygen.downloadTo(result.captionUrl, path.join(runDir, 'captions.srt'));
      } catch (err) {
        log(`[presenter] couldn't fetch HeyGen captions, estimating instead: ${err.message}`);
      }
    }
    try {
      captionedPath = await overlay.burnText(runDir, { captionSrtPath, log });
    } catch (err) {
      // The plain video is still usable; don't fail the run over the text pass.
      log(`[presenter] text overlay failed, keeping plain video: ${err.message}`);
    }
  }
  return { runDir, script, videoPath, captionedPath };
}

module.exports = { createPresenterVideo, recentTopics, postText, slugify };
