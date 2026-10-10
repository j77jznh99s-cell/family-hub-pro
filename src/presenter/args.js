// Command-line parsing for scripts/presenter.js, kept here so it can be unit tested
// without running the script. Bad values throw; the script prints the message and exits 1.
const { MAX_DAYS, MAX_PER_DAY } = require('./calendar');

// A whole number from `min` to `max`. "0", "abc", "2.5", "3x" or a missing value are
// errors rather than a quiet fall back to the default.
function parseCount(flag, value, { min = 1, max }) {
  const text = value === undefined ? '' : String(value).trim();
  const n = /^\d+$/.test(text) ? Number(text) : NaN;
  if (!Number.isInteger(n) || n < min || n > max) {
    throw new Error(`${flag} must be a whole number from ${min} to ${max}${text ? `, got "${text}"` : ''}`);
  }
  return n;
}

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
    else if (argv[i] === '--days') args.days = parseCount('--days', argv[++i], { max: MAX_DAYS });
    else if (argv[i] === '--per-day') args.perDay = parseCount('--per-day', argv[++i], { max: MAX_PER_DAY });
    else if (argv[i] === '--times') args.times = argv[++i];
    else if (argv[i] === '--help' || argv[i] === '-h') args.help = true;
    else throw new Error(`Unknown argument: ${argv[i]}`);
  }
  return args;
}

module.exports = { parseArgs, parseCount };
