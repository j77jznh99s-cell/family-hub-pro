---
tags: [project, web-app]
updated: 2026-09-26
---
# Clip Studio

AI video clipper: upload a long video and get back AI-selected short clips (ffmpeg segmentation,
optional Whisper transcripts, Claude scoring, captions, download).

- **Code:** branch `claude/video-clip-detection-mvp-g18ggk` (the repo's current default branch), repo root (`src/`, `public/`, `tests/`).
- **State (from git history):** Phase 1 MVP and hardening done (2026-09-21); Phase 2 optional Postgres, Redis queue, S3, Whisper captions and Stripe billing added (2026-09-21).
- **Details:** the branch's `README.md`.
- **Newest code (found 2026-09-26):** branch `claude/hourly-project-processing-ejbqs4` has 32 more commits (23–24 Sep) from the
  hourly session: an **AI presenter** (trend research, sourced scripts, HeyGen digital-twin videos, captions, a weekly content
  calendar, `--fill-week`, a pre-posting check, spend tracking), deploy health check `/healthz?deep=1`, a security pass
  (constant-time tokens, failed-auth limit), and Node 22. Not merged into `claude/video-clip-detection-mvp-g18ggk` yet.
- **Pages from that session:** Clip Studio https://claude.ai/artifact/DkWmfS4mvKmSuHEuVsf29p · AI Presenter https://claude.ai/artifact/7rUQvzaSF1y57PPhGFRRfG · Project Home https://claude.ai/artifact/CSXkQRWHXxfADK8jCswZmf

## QA Review (2026-09-26)

Reviewed `claude/hourly-project-processing-ejbqs4` (29 commits ahead of `claude/video-clip-detection-mvp-g18ggk`,
not 32 as first noted — corrected count) in an isolated `git worktree` at `/tmp/clip-studio-qa`, checked out at
`origin/claude/hourly-project-processing-ejbqs4` HEAD `965a4a3`. Nothing merged, nothing pushed; the worktree was
removed after review (`git worktree remove`) and `main` was never touched other than this note.

**Environment:** Node v22.22.2 and npm 10.9.7 were already available in the sandbox — matches the branch's
`engines.node >=22` and the `Dockerfile`'s `node:22-bookworm-slim`, no mismatch. `ffmpeg`/`ffprobe` were not
preinstalled; `apt-get install ffmpeg` (matching the CI step) succeeded on retry after a transient mirror 404.
Local `postgresql` and `redis-server` packages were present but stopped; started both to reproduce CI's two
service containers.

**Tests — all passed:**
- `npm install`: 203 packages, 0 vulnerabilities.
- `npm test` (default SQLite + in-process queue, matches CI's first test step): **101/101 passed**, 0 failures, run twice for confirmation. Includes the new real-ffmpeg pipeline integration test (`tests/pipeline.integration.test.js`) and 12 new presenter/health/hardening test files.
- `DATABASE_URL=postgresql://... node --test tests/db.test.js` (Postgres driver, matches CI step): **6/6 passed**.
- `REDIS_URL=redis://... node --test tests/queue.test.js` (BullMQ/Redis driver, matches CI step): **1/1 passed**.
- `node --check src/server.js`: syntax OK (matches CI step).
- **Not verified:** `docker build -t clip-detection-mvp:ci .` (the CI's last step) — the sandbox's Docker daemon
  wouldn't start (`ulimit: error setting limit (Operation not permitted)`, then `dial unix /var/run/docker.sock:
  connect: no such file or directory`). This is a sandbox limitation, not evidence of anything wrong with the
  Dockerfile. The Dockerfile itself reads cleanly (Node 22, ffmpeg + fonts-dejavu-core, `npm install --omit=dev`,
  `NODE_ENV=production`, `CMD node src/server.js`) — unverified by an actual build.
- No live-credential smoke tests exist for HeyGen, Whisper, Stripe checkout, or live S3/AWS (README says so explicitly for the last three; the branch adds HeyGen to that list) — this QA pass didn't add any either; all of that stays unverified until a real key is used.

**CI (`.github/workflows/ci.yml`):** runs on every push/PR, spins up `postgres:16` and `redis:7` service
containers, installs ffmpeg, `npm ci`, `npm test`, then the Postgres- and Redis-driver test files with their
respective URLs set, `node --check src/server.js`, then a Docker build. This QA pass reproduced every step
except the final Docker build (see above) and got the same pass results CI should get.

**Bugs / findings (none are blockers — no failing test, no crash, no data-loss path found):**

1. **Minor — fragile disclaimer-dedup check, `src/presenter/writer.js:185` and `src/presenter/check.js:55`.**
   Both files check whether the script already contains the disclaimer by testing for the literal hardcoded
   substring `'not financial advice'`, rather than checking against `niche.disclaimer` itself (`src/presenter/niches.js:15,21`).
   It works today because both of the two disclaimer strings happen to contain that phrase, but if a disclaimer's
   wording ever changes without updating both hardcoded checks, `writer.js` would append the disclaimer a second
   time (or `check.js` would false-flag a compliant script as missing it). Owner: **app-engineer** — derive the
   check from `niche.disclaimer` instead of a hardcoded phrase.
2. **Minor, unverified — potential crash on malformed model output, `src/presenter/writer.js:185`.** `finalizeScript`
   calls `script.script.toLowerCase()` without a fallback; if `script.script` is ever `undefined` (Claude's
   structured-output schema marks it `required`, so this should not happen, but isn't guaranteed against every
   possible API response), this throws `TypeError` instead of surfacing the "problems" array already computed
   two lines above. No test exercises this path. Owner: **app-engineer** — guard with `(script.script || '')`.
3. **Unverified — model id `claude-opus-5` (`src/presenter/writer.js:8`, default `PRESENTER_MODEL`).** Not testable
   without an `ANTHROPIC_API_KEY`; flagging only because it's unverified, not because anything shows it's wrong.
4. **Cosmetic — vault note undercount.** The project note said "32 more commits"; actual count from
   `git log base..HEAD` is 29. Corrected above.

**Security pass, reviewed and looks sound (not exploited, but reasoning checked):**
- `tokensMatch` (`src/middleware/auth.js:6`) hashes both sides with SHA-256 before `crypto.timingSafeEqual`,
  which correctly avoids the length-mismatch throw that plain `timingSafeEqual` has on unequal-length inputs —
  good pattern, confirmed by `tests/authHardening.test.js`.
- `authFailureLimiter` only counts responses with `res.statusCode === 401` per IP (30/15 min, then 429) and is
  mounted on all of `/api/*` before the presenter/access-token checks — verified by the same test file
  (10 successes don't count, 3 failures then a 429 on the 4th).
- Stripe webhook route is mounted with `express.raw()` before `express.json()` and before the failure limiter,
  so Stripe's own signature check remains the sole gate there (not new to this branch, but re-verified it's
  still correct in context).
- `/healthz?deep=1` is intentionally unauthenticated (README says so) but is separately rate-limited to 20/min
  and its own tests (`tests/health.test.js`) confirm it never echoes secret values (e.g. `DATABASE_URL`) into
  the response, only fixed hints.
- Presenter run IDs from the URL (`GET /api/presenter/runs/:id`, `.../video`) are validated against
  `ID_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$/` plus an explicit `..` check (`src/presenter/runs.js:7-11`)
  before touching the filesystem — no path traversal found.
- Dashboard's presenter panel (`public/index.html`) escapes all user/model-derived text via `textContent`-based
  `escapeHtml` before inserting into the DOM; source links are additionally restricted server-side to `http(s)://`
  only (`src/presenter/runs.js:77-83`) — no XSS vector found in what was reviewed.
- Credit spend (`spendCreditIfAvailable` in both `src/db/sqlite.js:92` and `src/db/postgres.js:122`) is a single
  atomic `UPDATE ... WHERE credits > 0`, so concurrent uploads can't double-spend the same credit — no dupe race
  found (this logic predates this branch but was re-checked since it's adjacent to the new upload validation).

**Not reviewed in depth (out of scope for this pass, flagging for awareness):** `src/presenter/calendar.js`,
`src/presenter/weekly.js`, `src/presenter/usage.js`, `docs/ai-presenter.md` posting/disclosure guidance — these
have passing unit tests but weren't independently read line-by-line for logic bugs.

## CI fix on `main` (2026-09-26)
`main`'s CI (`.github/workflows/ci.yml`) had been red since 2026-09-23 — every push failed on
`tests/storage.test.js`'s `getServeInfo() returns a redirect with a presigned URL` test.
Root cause: `src/services/storage/s3.js` on `main` destructured `getSignedUrl` from
`@aws-sdk/s3-request-presigner` at require time; the test mocks `getSignedUrl` on the module
object, but the destructured reference had already captured the real function (module caching
meant this happened on the very first `require('../src/services/storage/s3')`, in an earlier
test) — so the real AWS SDK function ran and failed with `CredentialsProviderError` (no AWS
creds in CI). `claude/hourly-project-processing-ejbqs4` already carries the fix (`require` the
module as a namespace object, call `presigner.getSignedUrl(...)` instead of a destructured
const). Ported that exact fix to `main` (commit `fd327a0`); confirmed 30/30 tests pass locally
before pushing.

Same bug, same fix needed separately on **`claude/roblox-popular-game-trends-6u7sie`** (2026-09-26):
that branch forked from `main` before the fix and also carries this repo's Clip Studio code at
its root, so it inherited the identical red CI on every push this session made to it today
(`a136cba`, `21c68c3`, `6aece41`). Ported the same fix there too (commit `c5e7884`); 30/30 tests
pass locally. Any other branch forked from `main` before `fd327a0` likely needs the same port —
check CI before pushing to one.

## Tasks
- [x] **qa-tester:** review the hourly branch (tests, CI, bugs); the owner decides whether to merge it. Done 2026-09-26 — see QA Review above.
- [ ] **owner:** decide whether to merge `claude/hourly-project-processing-ejbqs4` into `claude/video-clip-detection-mvp-g18ggk` (all automated checks this session could run passed; Docker build step still unverified — see QA Review).
- [ ] **app-engineer:** fix the two minor findings above (fragile disclaimer-dedup string match in `writer.js`/`check.js`; missing `|| ''` guard in `writer.js:185`) before or shortly after merge.
- [ ] **owner:** confirm what's next for Clip Studio (deploy? pricing? more features?) so an agent can pick it up
