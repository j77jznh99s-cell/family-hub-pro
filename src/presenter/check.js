// Pre-posting check for saved runs: re-applies the script rules (length, no URLs in
// speech, real sources, disclaimers, AI disclosure) and checks the files a post needs.
// Problems block posting; warnings are worth a look.
const fs = require('fs/promises');
const path = require('path');
const { NICHES } = require('./niches');
const { AI_DISCLOSURE, wordCount } = require('./writer');

async function readText(file) {
  try {
    return await fs.readFile(file, 'utf8');
  } catch {
    return null;
  }
}

async function exists(file) {
  return fs.access(file).then(() => true, () => false);
}

async function checkRun(runDir) {
  const problems = [];
  const warnings = [];
  const raw = await readText(path.join(runDir, 'script.json'));
  let script = null;
  try {
    script = raw && JSON.parse(raw);
  } catch {
    // reported below
  }
  if (!script) return { runDir, ok: false, problems: ['script.json missing or unreadable'], warnings };

  if (script.demo || path.basename(runDir).startsWith('demo-')) problems.push('demo run - not for posting');

  const words = wordCount(script.script || '');
  if (words < 90 || words > 200) problems.push(`script is ${words} words (want 110-170)`);
  if (/https?:\/\//i.test(script.script || '')) problems.push('spoken script contains a URL');

  const hosts = [];
  for (const src of script.sources || []) {
    try {
      const u = new URL(src.url);
      if (u.protocol === 'http:' || u.protocol === 'https:') hosts.push(u.hostname);
      else problems.push(`source is not a web link: ${src.url}`);
    } catch {
      problems.push(`malformed source URL: ${src.url}`);
    }
  }
  if (!hosts.length) problems.push('no sources');
  if (hosts.some((h) => /(^|\.)example\.(com|org|net)$/.test(h))) problems.push('placeholder source URL');

  const niche = NICHES[script.niche];
  if (!niche) warnings.push(`unknown lane "${script.niche}"`);
  if (niche && niche.disclaimer) {
    if (!/not financial advice/i.test(script.script || '')) problems.push('spoken script is missing the financial disclaimer');
    if (!(script.description || '').includes(niche.disclaimer)) problems.push('description is missing the disclaimer');
  }
  if (!(script.description || '').includes(AI_DISCLOSURE)) problems.push('description is missing the AI disclosure');

  const post = await readText(path.join(runDir, 'post.txt'));
  if (post === null) problems.push('post.txt missing');
  else if (!post.includes(AI_DISCLOSURE)) problems.push('post.txt is missing the AI disclosure');

  if (await exists(path.join(runDir, 'video.captioned.mp4'))) {
    // ready
  } else if (await exists(path.join(runDir, 'video.mp4'))) {
    warnings.push('no captioned video - run --overlay, or post the plain video');
  } else {
    problems.push('no video rendered yet');
  }
  if ((script.on_screen_text || []).length === 0) warnings.push('no on-screen callouts');

  return { runDir, ok: problems.length === 0, problems, warnings };
}

async function checkAll(outputDir) {
  let entries = [];
  try {
    entries = await fs.readdir(outputDir, { withFileTypes: true });
  } catch {
    return [];
  }
  const results = [];
  for (const e of entries.filter((x) => x.isDirectory()).sort((a, b) => a.name.localeCompare(b.name))) {
    if (await exists(path.join(outputDir, e.name, 'script.json'))) results.push(await checkRun(path.join(outputDir, e.name)));
  }
  return results;
}

function formatResults(results) {
  if (!results.length) return 'No runs to check.';
  return results
    .map((r) => {
      const head = `${r.ok ? 'OK  ' : 'FAIL'} ${path.basename(r.runDir)}`;
      const lines = [...r.problems.map((p) => `     x ${p}`), ...r.warnings.map((w) => `     ! ${w}`)];
      return [head, ...lines].join('\n');
    })
    .join('\n');
}

module.exports = { checkRun, checkAll, formatResults };
