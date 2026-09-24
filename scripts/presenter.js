#!/usr/bin/env node
// Make one AI-presenter video.
//   npm run presenter                      # today's lane (rotates daily), full render
//   npm run presenter -- --niche markets   # pick a lane: ai | money | markets | food | auto
//   npm run presenter -- --script-only     # research + script, no HeyGen render
require('dotenv').config();
const { createPresenterVideo } = require('../src/presenter');

function parseArgs(argv) {
  const args = { niche: 'auto', render: true };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--niche') args.niche = argv[++i];
    else if (argv[i] === '--script-only') args.render = false;
    else if (argv[i] === '--help' || argv[i] === '-h') args.help = true;
    else throw new Error(`Unknown argument: ${argv[i]}`);
  }
  return args;
}

(async () => {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log('Usage: npm run presenter -- [--niche ai|money|markets|food|auto] [--script-only]');
    return;
  }
  const { runDir } = await createPresenterVideo(args);
  console.log(`Done: ${runDir}`);
})().catch((err) => {
  console.error(`[presenter] ${err.message}`);
  process.exit(1);
});
