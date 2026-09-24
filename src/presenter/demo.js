// Builds a sample run folder with no API keys: a canned script, a generated placeholder
// video (solid background + tone) and the real text-overlay pass on top. It exercises
// everything after the paid steps, so captions, callouts and the run folder layout can
// be checked before HeyGen or Anthropic keys are set up.
//
// Demo folders are named "demo-..." so they never count as a real calendar slot or as a
// recently covered topic.
const fs = require('fs/promises');
const path = require('path');
const { execFile } = require('child_process');
const { promisify } = require('util');
const ffmpeg = require('../services/ffmpeg');
const overlay = require('./overlay');
const { postText } = require('./index');

const execFileAsync = promisify(execFile);

// Talks about the pipeline itself, so the demo never states made-up facts about the world.
const DEMO_SCRIPT = {
  topic: 'Demo run',
  title: 'Presenter pipeline demo',
  hook: 'This is a test run of your AI presenter pipeline, with no real topic yet.',
  script:
    'This is a test run of your AI presenter pipeline, with no real topic yet. ' +
    'In a real run, the research step searches the web for what is trending in one of your four lanes, ' +
    'and the script step writes about a minute of speech using only facts it found and cited. ' +
    'Then your avatar reads it, and this same step burns the key facts in at the top ' +
    'and captions along the bottom, sized for a vertical phone video. ' +
    'Check that the text is easy to read and clear of the edges, then add your keys to make the real thing.',
  on_screen_text: ['Test run', 'Research with sources', 'About one minute', 'Captions burned in'],
  description: 'Demo of the presenter pipeline - not for posting.',
  hashtags: ['demo'],
  sources: [{ title: 'Placeholder - demo runs have no sources', url: 'https://example.com/demo' }],
  niche: 'ai',
  estimatedSeconds: 30,
  demo: true,
};

async function makePlaceholderVideo(outPath, { width = 1080, height = 1920, seconds = 12 } = {}) {
  await execFileAsync(
    ffmpeg.FFMPEG_PATH,
    [
      '-y',
      '-f', 'lavfi', '-i', `color=c=0x2a2a28:s=${width}x${height}:d=${seconds}:r=30`,
      '-f', 'lavfi', '-i', `sine=frequency=220:duration=${seconds}`,
      '-c:v', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-shortest', outPath,
    ],
    { maxBuffer: ffmpeg.MAX_BUFFER }
  );
  return outPath;
}

async function createDemoRun({ outputDir, now = new Date(), seconds = 12, log = console.log } = {}) {
  const stamp = now.toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const runDir = path.join(outputDir, `demo-${stamp}`);
  await fs.mkdir(runDir, { recursive: true });
  await fs.writeFile(path.join(runDir, 'research.md'), 'DEMO RUN - no research was done.\n', 'utf8');
  await fs.writeFile(path.join(runDir, 'script.json'), JSON.stringify(DEMO_SCRIPT, null, 2), 'utf8');
  await fs.writeFile(path.join(runDir, 'post.txt'), `DEMO - DO NOT POST\n\n${postText(DEMO_SCRIPT)}`, 'utf8');
  log(`[presenter] demo: generating a ${seconds}s placeholder video`);
  const videoPath = await makePlaceholderVideo(path.join(runDir, 'video.mp4'), { seconds });
  await fs.writeFile(
    path.join(runDir, 'render.json'),
    JSON.stringify({ demo: true, renderedAt: now.toISOString() }, null, 2),
    'utf8'
  );
  const captionedPath = await overlay.burnText(runDir, { log });
  return { runDir, videoPath, captionedPath };
}

module.exports = { createDemoRun, makePlaceholderVideo, DEMO_SCRIPT };
