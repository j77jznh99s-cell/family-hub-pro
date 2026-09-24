#!/usr/bin/env node
// Make one AI-presenter video.
//   npm run presenter                      # today's lane (rotates daily), full render
//   npm run presenter -- --niche markets   # pick a lane: ai | money | markets | food | auto
//   npm run presenter -- --script-only     # research + script, no HeyGen render
//   npm run presenter -- --overlay <runDir> # (re)burn callouts + captions onto a rendered video
require('dotenv').config();
const { createPresenterVideo } = require('../src/presenter');
const { burnText } = require('../src/presenter/overlay');

function parseArgs(argv) {
  const args = { niche: 'auto', render: true };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--niche') args.niche = argv[++i];
    else if (argv[i] === '--script-only') args.render = false;
    else if (argv[i] === '--overlay') args.overlay = argv[++i];
    else if (argv[i] === '--help' || argv[i] === '-h') args.help = true;
    else throw new Error(`Unknown argument: ${argv[i]}`);
  }
  return args;
}

(async () => {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log('Usage: npm run presenter -- [--niche ai|money|markets|food|auto] [--script-only] | --overlay <runDir>');
    return;
  }
  if (args.overlay) {
    console.log(`Done: ${await burnText(args.overlay, { log: console.log })}`);
    return;
  }
  const { runDir } = await createPresenterVideo(args);
  console.log(`Done: ${runDir}`);
})().catch((err) => {
  console.error(`[presenter] ${err.message}`);
  process.exit(1);
});
