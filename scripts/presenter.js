#!/usr/bin/env node
// Make one AI-presenter video.
//   npm run presenter                      # today's lane (rotates daily), full render
//   npm run presenter -- --niche markets   # pick a lane: ai | money | markets | food | auto
//   npm run presenter -- --script-only     # research + script, no HeyGen render
//   npm run presenter -- --overlay <runDir> # (re)burn callouts + captions onto a rendered video
//   npm run presenter -- --check <runDir|all> # pre-posting check: script rules, sources, disclaimers, files
//   npm run presenter -- --weekly-report     # last 7 days: calendar, pre-posting check, month's spend -> weekly-<date>.md
//   npm run presenter -- --usage             # Claude tokens/$, web searches and HeyGen time per run and per month
//   npm run presenter -- --demo              # no API keys: sample run folder with a placeholder video + text overlay
//   npm run presenter -- --calendar [--days 7] [--per-day 1] [--times 12:00,18:00]
//                                           # plan the week: lane + post time per slot, and what's done
//   npm run presenter -- --fill-week [--days 3] [--yes]
//                                           # list slots with no script yet; --yes writes them (script-only)
require('dotenv').config();
const fs = require('fs/promises');
const path = require('path');
const { createPresenterVideo, OUTPUT_DIR } = require('../src/presenter');
const calendar = require('../src/presenter/calendar');
const { burnText } = require('../src/presenter/overlay');

function parseArgs(argv) {
  const args = { niche: 'auto', render: true };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--niche') args.niche = argv[++i];
    else if (argv[i] === '--script-only') args.render = false;
    else if (argv[i] === '--overlay') args.overlay = argv[++i];
    else if (argv[i] === '--calendar') args.calendar = true;
    else if (argv[i] === '--fill-week') args.fill = true;
    else if (argv[i] === '--yes') args.yes = true;
    else if (argv[i] === '--demo') args.demo = true;
    else if (argv[i] === '--usage') args.usage = true;
    else if (argv[i] === '--weekly-report') args.weekly = true;
    else if (argv[i] === '--check') args.check = argv[++i] || 'all';
    else if (argv[i] === '--days') args.days = parseInt(argv[++i], 10);
    else if (argv[i] === '--per-day') args.perDay = parseInt(argv[++i], 10);
    else if (argv[i] === '--times') args.times = argv[++i];
    else if (argv[i] === '--help' || argv[i] === '-h') args.help = true;
    else throw new Error(`Unknown argument: ${argv[i]}`);
  }
  return args;
}

(async () => {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(
      'Usage: npm run presenter -- [--niche ai|money|markets|food|auto] [--script-only]\n' +
        '       npm run presenter -- --overlay <runDir>\n' +
        '       npm run presenter -- --demo\n' +
        '       npm run presenter -- --check <runDir|all>\n' +
        '       npm run presenter -- --usage\n' +
        '       npm run presenter -- --weekly-report\n' +
        '       npm run presenter -- --calendar [--days 7] [--per-day 1] [--times 12:00,18:00]\n' +
        '       npm run presenter -- --fill-week [--days 3] [--per-day 1] [--yes]'
    );
    return;
  }
  if (args.weekly) {
    const { buildWeeklyReport } = require('../src/presenter/weekly');
    const md = await buildWeeklyReport(OUTPUT_DIR, { times: process.env.PRESENTER_POST_TIMES });
    await fs.mkdir(OUTPUT_DIR, { recursive: true });
    const out = path.join(OUTPUT_DIR, `weekly-${new Date().toISOString().slice(0, 10)}.md`);
    await fs.writeFile(out, md, 'utf8');
    console.log(md);
    console.log(`Saved ${out}`);
    return;
  }
  if (args.usage) {
    const usage = require('../src/presenter/usage');
    console.log(usage.formatSummary(await usage.summarize(OUTPUT_DIR)));
    return;
  }
  if (args.check) {
    const check = require('../src/presenter/check');
    const results = args.check === 'all' ? await check.checkAll(OUTPUT_DIR) : [await check.checkRun(args.check)];
    console.log(check.formatResults(results));
    if (results.some((r) => !r.ok)) process.exitCode = 1;
    return;
  }
  if (args.demo) {
    const { createDemoRun } = require('../src/presenter/demo');
    const { captionedPath } = await createDemoRun({ outputDir: OUTPUT_DIR });
    console.log(`Done: ${captionedPath}`);
    return;
  }
  if (args.fill) {
    const fill = require('../src/presenter/fill');
    const pending = await fill.pendingSlots(OUTPUT_DIR, {
      days: args.days || 3,
      perDay: args.perDay || 1,
      times: args.times || process.env.PRESENTER_POST_TIMES,
    });
    console.log(fill.describe(pending));
    if (!pending.length) return;
    if (!args.yes) {
      console.log('\nDry run. Add --yes to write these scripts (research + script only, no HeyGen render).');
      return;
    }
    if (!process.env.ANTHROPIC_API_KEY) throw new Error('ANTHROPIC_API_KEY is not set - see docs/ai-presenter.md');
    const results = await fill.fillSlots(pending, { create: createPresenterVideo });
    console.log(`\nPre-posting check on the new scripts:\n${fill.summarize(results)}`);
    const done = results.filter((r) => r.ok).length;
    console.log(`\nWrote ${done} of ${results.length} script(s). Re-read each against the news before rendering: ` +
      'scripts written days ahead can go stale.');
    if (done < results.length || results.some((r) => r.review && !r.review.ok)) process.exitCode = 1;
    return;
  }
  if (args.calendar) {
    const slots = calendar.planWeek({
      days: args.days || 7,
      perDay: args.perDay || 1,
      times: args.times || process.env.PRESENTER_POST_TIMES,
    });
    const md = calendar.toMarkdown(await calendar.attachRuns(slots, OUTPUT_DIR));
    await fs.mkdir(OUTPUT_DIR, { recursive: true });
    const out = path.join(OUTPUT_DIR, 'calendar.md');
    await fs.writeFile(out, md, 'utf8');
    console.log(md);
    console.log(`Saved ${out}`);
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
