---
tags: [memory, log]
---
# Session Log

Newest first. One entry per working session. Use [[Session Log Entry]] as the template.

---

## 2026-09-26: hourly run — Config.EventTimeOffset Studio test hook built
**Device:** cloud Routine · **Branch:** `claude/roblox-popular-game-trends-6u7sie` (via roblox-engineer, isolated worktree) · **Agents used:** roblox-engineer

**What was done**
- Delegated the top queue item to roblox-engineer, following the exact spec last run's qa-tester pass
  wrote (in [[Sproutling Isles - QA Review]]'s "Hollow Harvest QA pass" section): add
  `Config.EventTimeOffset = 0`, add an `Events.now()` helper gated on `RunService:IsStudio()`, and
  swap all 11 real-time call sites that gate Hollow Harvest's phase from raw `os.time()` to
  `Events.now()` (9 in `EventService.luau`, 1 each in `PlotService.luau` and `PondService.luau`).
- Pushed `04a3211`. Before recording this done I read the actual diff myself (not just the agent's
  report): all 11 sites confirmed swapped correctly, `EventService.luau` has zero `os.time()` calls
  left, and the other `os.time()` calls left untouched in `PlotService.luau`/`PondService.luau` are
  genuinely unrelated (shield/lock/growth timers) — not a missed site. No require cycle
  (`Config.luau` requires nothing). `selene`/`rojo build`/`lune bake-map` all clean, 1241 parts
  unchanged from baseline. Confirmed CI green on the pushed commit (run #87) via a follow-up check.
- This closes the gap flagged last run as a build-blocker: nobody could Studio-test any part of
  Hollow Harvest before its real 17 Oct start until this hook existed. The full phase-by-phase test
  plan already written in the QA note can now actually be run — still needs the owner's Studio
  access, which this sandbox doesn't have.
- 1 task this run (build + my own review + CI check took most of the run); stopping.

## 2026-09-26: hourly run — Hollow Harvest QA pass finds a real Studio-testing blocker
**Device:** cloud Routine · **Branch:** `main` (read-only review of `claude/roblox-popular-game-trends-6u7sie`) · **Agents used:** qa-tester

**What was done**
- Task 2 this run: qa-tester did the 3-part QA pass the Launch & Live Ops task list called for
  (event test plan, Starter Pack check, analytics once-only check).
- **Found a real gap, not just a nice-to-have:** `Config.EventTimeOffset` doesn't exist. There's
  an *older* task (from before Hollow Harvest was even built) that already called for this exact
  hook — it got missed during today's Halloween build. Without it, every one of the 11 places that
  gate Hollow Harvest's phase (`EventService.luau` ×9, `PlotService.luau`, `PondService.luau`) uses
  raw `os.time()`, so **nobody can Studio-test the Fog schedule, lanterns, stall, or the
  end-of-event conversion before mid-October** — the same month the owner's play-test is due.
  qa-tester wrote a precise fix (a `Config.EventTimeOffset` + `Events.now()` helper, Studio-only,
  mirroring the existing `StudioDisableShield` pattern) and a full test plan ready to run the
  moment it's built, with specific emphasis on re-verifying earlier today's Moonberry-conversion
  fix actually scales with balance rather than just "fires."
- Also confirmed: Starter Pack (m15) still grants Dew on every repeat purchase, unchanged by
  today's other work — not a regression, still an open owner decision. All 11 onboarding
  analytics once-only guards checked correct, no double-fire risk from today's Hollow Harvest or
  leaderboard additions; one documentation nit noted (not blocking).
- I spot-checked several of the file:line claims myself against the actual code (the Starter Pack
  handler, two of the onboarding guard sites) — all accurate. Merged the new task with the older,
  now-redundant `Config.Boosts + EventTimeOffset` task line so it's tracked once, not twice.
  Queued the `EventTimeOffset` build as the new top priority.

## 2026-09-26: hourly run — confirmed Frostbloom Festival numbers
**Device:** cloud Routine · **Branch:** `main` · **Agents used:** none (done directly)

**What was done**
- CI was green on both branches. Top queue item was the game-designer confirmation of last
  run's Frostbloom Festival numbers — read-only verification, handled directly rather than
  spinning up an agent.
- Independently re-checked all 3 species' payback arithmetic (180,000÷500=360,
  1,500,000÷1,800=833.33, 11,000,000÷7,000=1,571.43 — all correct) and their placement against
  the game's established curve — agreed with the reasoning, no changes needed.
- Checked two things the original payback note hadn't covered: confirmed the Day-1-free-Frostfawn
  vs. Stall-sells-the-same-species-from-day-1 isn't a design contradiction (the free grant only
  reaches players who claim that specific Advent day; the Stall covers latecomers); verified
  `Config.PlotCount = 8` and `SoilTilesPerPlot = 12` in the actual code to sanity-check the Snowman
  co-op tier thresholds are the right order of magnitude — left flagged for live tuning, same
  treatment as the earn-rate estimates, since a server's actual 24h hatch rate can't be confirmed
  without live population data.
- Recorded the confirmation in [[Sproutling Isles - Launch & Live Ops]] and ticked the task in
  both that note and [[Sproutling Isles]].

---

## 2026-09-26: hourly run — Frostbloom Festival (winter event) spec written
**Device:** cloud Routine · **Branch:** `main` (vault-only) · **Agents used:** live-ops-manager

**What was done**
- CI was green on both branches; the only unblocked queue item was the full Frostbloom Festival
  spec (due 21 Nov, not urgent, but nothing else was available). live-ops-manager expanded the
  existing one-line outline into a full spec matching Hollow Harvest's level of detail: goal,
  9-step player flow, a weather/currency rules table (Snowglow + a New Bloom Fireworks weather),
  3 limited species (Frostfawn/Snowdrake/Aurorelle) with computed payback numbers, a 13-day Advent
  Gift calendar with an escalating reward schedule, a fully-designed new "Snowman" per-server
  co-op mechanic (resets daily at 00:00 UTC, with reasoning for why not event-long), the Frosted
  Greenhouse skin, Robux proposals, save-data shape, edge cases, UI text, KPIs, and a 12-item build
  list for roblox-engineer that explicitly flags `EventService.luau` likely needing a small
  refactor to support two concurrent scheduled weathers and two events' worth of save data.
- I independently re-verified the numbers rather than trusting the report: all 3 species' payback
  times (price ÷ dewPerSecond) check out exactly against the arithmetic shown, and land correctly
  relative to the base game's established curve and Hollow Harvest's own precedents. Also checked
  the Winter Bundle's "≈15% off" claim against the actual existing item prices (Luck Boost 49 +
  Instant Grow 39 + Dew Pouch 29 = 117, ÷99 ≈ 15.4% off) — it correctly reuses the exact same
  bundle composition as the already-proposed Week 7 Harvest Bundle rather than inventing new
  numbers. No bugs found; this is a planning document, not code, so the review focus was
  correctness of the numbers and internal consistency rather than a runtime failure mode.
- This is the first hourly-run task since the Hollow Harvest build where the game code branch
  wasn't touched — live-ops-manager doesn't have shell/git tools and correctly said so rather than
  guessing at the real `Events.luau`/`EventService.luau` structure; the build list flags this for
  roblox-engineer to confirm at build time (~Dec).
- Added the one follow-up the agent flagged but didn't have scope to write (game-designer
  numbers confirmation) plus 3 more already-unblocked tasks from [[Sproutling Isles - Launch &
  Live Ops]]'s own task list to [[Work Queue]], since it would otherwise have gone empty next run.

---

## 2026-09-26: hourly run — Hollow Harvest Halloween event built (and a real economy bug fixed)
**Device:** cloud Routine · **Branch:** `claude/roblox-popular-game-trends-6u7sie` (vault on `main`) · **Agents used:** roblox-engineer

**What was done**
- CI was green on both `main` and the roblox branch, so went straight to the top queue item: the
  full Hollow Harvest Halloween event, well ahead of its ~15 Oct deadline. This was a big,
  fully-specced build — briefed it as one task rather than splitting it, since the spec (goal,
  player flow, numbers, edge cases, UI text, a numbered build list) left little open to
  interpretation.
- roblox-engineer delivered: `spookyfog` weather + `haunted` mutation, 3 limited species
  (Pumpkit/Gourdgeist/Hollowisp — plus a legitimate side-fix: `Species.rollByRarity` now excludes
  `limited` species from its rarity-share math, closing a real leak risk), a UTC-clock Fog
  scheduler, Wisp Lantern spawn/pickup/despawn, the 3-kiosk Lantern Stall (reusing the Seed Shop's
  established pattern), the Haunted Greenhouse plot skin, end-of-event Moonberry→Dew conversion, a
  HUD chip, and the `EventShop`/`Event` analytics that an earlier task had deliberately deferred
  (commit `6f59f2f`).
- **Given the size (10 files, a new ~430-line `EventService.luau`), I read the entire diff myself
  before recording it** rather than trusting the agent's own report — this is the same discipline
  that caught the leaderboard bug two runs ago. Independently re-verified the 4 event UTC
  timestamps against `date -u` (all exact), traced every cross-module call
  (`EventService.onHatch`/`.onSkinChange`, the new `WeatherService.onStart`/`.onStop` hooks) to
  confirm the functions they call actually exist with the right signature, and confirmed
  `DataService.reconcile`'s generic backfill covers the new `data.event`/`skins`/`skin` fields for
  existing saves.
- **Found one real bug:** the end-of-event Dew conversion (`EventService.onJoin`) computed
  `math.max(100, floor(income * 5 * 60))` — completely independent of the player's actual
  Moonberry balance. Every player would have gotten the same flat ~5-minutes-of-income payout
  whether they had 1 berry or 10,000, defeating the entire point of the event currency. Confirmed
  against the spec's own worked example (37 berries → 12,400 Dew, which only holds with a
  `berries *` multiplier). Fixed directly (`b8b34b4`): added the missing multiplier, re-validated
  (`selene`/`rojo build`/`lune bake-map` clean, 1241 parts unchanged), pushed, confirmed green on
  GitHub Actions.
- Noted a few lower-severity items for the owner rather than blocking on them: Hollowisp reads
  "Pond only" as literally the Wishing Pond, not the Sky Well (an interpretation call); the sign's
  "cobweb decal" is a color-tint placeholder (no texture asset available offline); the Summon
  Spooky Fog Robux dev product isn't wired in (no product ID exists yet — queued for the owner).
- Recorded everything in [[Sproutling Isles]] and [[Sproutling Isles - Launch & Live Ops]]. Only 1
  task this run given its size; **not Studio-tested** — queued for the owner before 17 Oct.

---

## 2026-09-26: hourly run — pond fix (QA m11) + Halloween numbers confirmed
**Device:** cloud Routine · **Branch:** `claude/roblox-popular-game-trends-6u7sie` (vault on `main`) · **Agents used:** none (done directly)

**What was done**
- Checked CI on branches pushed today first (both green, no CI-first work needed), then took the
  top queue item: "game-designer: m11 pond water surface, and check the Halloween numbers."
  Handled it directly — read-only geometry analysis plus a one-line, well-understood code fix, not
  worth spinning up an agent for.
- **QA m11 (pond walkable):** traced the exact geometry in `MapBuilder.luau`'s `buildPond` — the
  Rim is a full 98-stud disc (not an actual ring), and with default `CanCollide=true` its top
  (y 0.8) sits just 0.25 studs under the visible water surface (y 1.05), so players could walk
  across the whole pond as if it were barely-covered solid ground. Chose `Rim.CanCollide = false`
  (matching `Water`) over the QA note's other option (reshape into a ring) since a ring needs a
  part shape the codebase's helpers don't build, for a cosmetic fix. Implemented, validated
  (`selene`/`rojo build`/`lune bake-map` clean, 1214 parts unchanged), pushed (`397cc4e`),
  confirmed green on GitHub Actions.
- **Halloween numbers:** checked the 3 limited species' payback times (price ÷ dewPerSecond)
  against [[Sproutling Isles - Design Doc]]'s existing payback curve by rarity tier. Pumpkit and
  Gourdgeist land cleanly inside their tier's existing range; Hollowisp runs ~11% above the single
  existing Mythic data point, judged acceptable given its much rarer acquisition method. Sanity-
  checked the Moonberry earn-rate estimate and stall-purchase pacing — both plausible, earn rate
  itself stays unverified (needs live measurement, as the note already flagged) rather than
  something a design review alone can confirm.
- Recorded both in [[Sproutling Isles - Launch & Live Ops]], [[Sproutling Isles - QA Review]] and
  [[Sproutling Isles]]. Only 1 task this run — the next queue item (Hollow Harvest, a large
  multi-file build not due until mid-October) is better started fresh with full runway.

---

## 2026-09-26: hourly run — analytics recurring funnels + custom events (run complete)
**Device:** cloud Routine · **Branch:** `claude/roblox-popular-game-trends-6u7sie` (vault on `main`) · **Agents used:** roblox-engineer

**What was done**
- Task 2 from [[Work Queue]] (after the CI port below): roblox-engineer wired the recurring
  funnels (3b) and custom events (3d) from the analytics spec that were deliberately scoped out
  of the earlier onboarding/economy build. Wired `Store` funnel step 4 only, `Snatch`
  (Grabbed/ReachedHome), `Rebirth` (CanAfford/Rebirthed); custom events `Hatch`/`HugeHatch`,
  `SnatchStart`/`SnatchResult`/`SnatchVictimLeft`, `GateLock`, `WeatherStart`/`WeatherSummonHatches`,
  `Rebirth`, `DailyClaim`, `PondCatch`, `StorageFull`/`NoSeeds`, `SessionEnd` (`e432cfd`).
  Correctly skipped `Store` steps 1-3, `EventShop` and `Ad` funnels — those need a client remote
  and two services (`EventService.luau`, `Ads.luau`) that don't exist yet; no stubs added.
- After finding a real display bug in the previous task's leaderboard work, I read this whole
  diff line-by-line before recording it (not just the agent's report): checked the once-per-carry
  `SnatchResult` guard, the once-per-tier `CanAfford` guard, the `reason`-string→result-bucket
  matching against the actual `finish()` call sites, and that every new field/function referenced
  (`ProgressionService.rebirthCost`, `State.income`, `MapBuilder.PlotSize`, `info.cx/cz`) really
  exists with the signature used. No bugs found this time — validated correct.
- `selene`/`rojo build`/`lune bake-map` clean, part count unchanged (1214). Not Studio-tested.
- Recorded in [[Sproutling Isles]] and ticked the task.

## 2026-09-26: hourly run — ported the S3/CI fix to the roblox branch (CI-first task)
**Device:** cloud Routine · **Branch:** `claude/roblox-popular-game-trends-6u7sie` (vault on `main`) · **Agents used:** none (done directly)

**What was done**
- On load, checked CI on branches pushed today (per [[Hourly Workflow]]'s "CI first" rule) and
  found `claude/roblox-popular-game-trends-6u7sie` still red on its 3 most recent pushes
  (`a136cba`, `21c68c3`, `6aece41`) — the same `s3.js`/`getSignedUrl` mocking bug fixed on `main`
  last run (`fd327a0`), inherited because this branch forked from `main` before that fix and also
  carries the Clip Studio code at repo root.
- Ported the identical fix in an isolated worktree, ran `npm ci && npm test` locally first (30/30
  pass), then pushed (`c5e7884`) — verified green on GitHub Actions before moving on.
- Recorded it in [[Clip Studio]] and [[Work Queue]], with a note that any other branch forked
  from `main` before `fd327a0` likely needs the same port.

---

## 2026-09-26: hourly run — Sproutling Isles leaderboards (+ a bug I caught in review)
**Device:** cloud Routine · **Branch:** `claude/roblox-popular-game-trends-6u7sie` (vault on `main`) · **Agents used:** roblox-engineer

**What was done**
- Task 2 from [[Work Queue]] (after the CI fix below): roblox-engineer built cross-server income
  and rarest-hatch leaderboards (`21c68c3`) — `OrderedDataStoreService`-backed, a physical board
  in the Plaza, income piggybacking the existing 5-min analytics batch, hatch score written only
  on a new personal best. Only a one-line spec existed ([[Sproutling Isles - Launch & Live Ops]]
  Week 5), so every placement/scoring/refresh-rate choice was the agent's own documented call.
- Before recording this as done, I read the actual diff (not just the report) and found a real
  bug: `MapBuilder.luau`'s new board-building code nested the TextLabel inside an extra
  "Background" Frame, but `LeaderboardService.init` looks up the label with a **non-recursive**
  `FindFirstChild` chain that assumes the TextLabel is a *direct* child of the BillboardGui — the
  established convention everywhere else in that file. As shipped, both boards would have shown
  their baked-in "Loading..." text forever, no matter how the data refreshed underneath.
- Fixed it myself directly (small, well-understood, no need for another agent round-trip):
  dropped the Frame, moved the background color/transparency onto the TextLabel itself (`6aece41`,
  pushed to the same branch). Re-ran `selene`/`rojo build`/`lune bake-map` — all clean, same part
  count (1214).
- Recorded both the feature and the fix in [[Sproutling Isles]]. Not Studio-tested (not available
  in this sandbox) — flagged for the owner's play-test.

## 2026-09-26: hourly run — fixed red CI on main (CI-first task)
**Device:** cloud Routine · **Branch:** `main` · **Agents used:** none (done directly)

**What was done**
- On load, checked CI on branches this session had pushed to (per [[Hourly Workflow]]'s "CI first"
  rule) and found `main` itself red: the last 3 vault-only pushes this session made had all failed
  CI, unnoticed until now. Root cause: `src/services/storage/s3.js` destructured `getSignedUrl`
  from `@aws-sdk/s3-request-presigner` at require time; `tests/storage.test.js` mocks it on the
  module object, but the destructured reference had already captured the real function (module
  caching — `s3.js` gets `require`d once, in an earlier test), so the real AWS SDK function ran
  and failed with `CredentialsProviderError` (no AWS creds in CI). This has been failing on every
  push to `main` since 2026-09-23, unrelated to anything this session did.
- `claude/hourly-project-processing-ejbqs4` already carries the fix (require the presigner module
  as a namespace object, call `presigner.getSignedUrl(...)`). Ported that exact fix to `main`
  rather than re-deriving one. Ran `npm ci && npm test` locally first: 30/30 pass (test 26 is the
  one that was failing) — pushed only after confirming green locally (commit `fd327a0`).
- Recorded the root cause and fix in [[Clip Studio]] and the run log in [[Work Queue]].

---

## 2026-09-26: hourly run — verified Roblox ads eligibility & pricing (3/3, run complete)
**Device:** cloud Routine · **Branch:** `main` · **Agents used:** market-researcher

**What was done**
- Task 3 from [[Work Queue]]: market-researcher re-checked the "unverified" rewarded-video-ads and Ads
  Manager claims in [[Sproutling Isles - Launch & Live Ops]]. Direct fetches to create.roblox.com/devforum
  are blocked in-sandbox, but the agent found and read Roblox's own creator-docs source repo on GitHub
  (`github.com/Roblox/creator-docs`) — close to primary, not just a search summary.
- Real corrections found, not just re-confirmation: the API success check is `Enum.ShowAdResult.ShowCompleted`
  (not `Succeeded` as previously written), eligibility has 3 more requirements than noted (two-step verification,
  no free-form user creation, questionnaire must be *approved* not just submitted), Ads Manager bills as
  auto-bid/Cost-Per-Play rather than CPM/CPC/CPI, and "new-creator ad credits" turned up no evidence and should
  be treated as likely not existing. The `ExperienceIneligible` bug is confirmed real and apparently still open.
- Updated [[Sproutling Isles - Launch & Live Ops]] (sections 1D, 4, 6, task list, sources) and ticked the
  matching tasks in both that note and [[Sproutling Isles]]. I reviewed the diff before committing.
- This was the 3rd task this run — stopping per [[Hourly Workflow]]'s cap.

## 2026-09-26: hourly run — Gumroad product-line demand brief
**Device:** cloud Routine · **Branch:** `main` · **Agents used:** market-researcher

**What was done**
- Task 2 from [[Work Queue]]: market-researcher wrote a sourced demand brief comparing the 3 candidate
  Gumroad product lines (family printables, Roblox game-making guides, spreadsheet/Notion templates) into
  [[Gumroad Digital Products]] (`## Demand brief (2026-09-26)`), for the owner to weigh against the tentative
  recommendation in [[Decisions]] #20. Correctly declined to re-decide it — flagged every unverified figure
  (most direct marketplace fetches were blocked by the sandbox's egress proxy; used WebSearch summaries instead)
  and checked the vault for actual team experience in each line (found: Family Hub streak concepts for
  printables, a full Sproutling Isles build/QA log for guides, nothing for spreadsheets/Notion).
- I reviewed the diff before committing — well-sourced, appropriately hedged, doesn't overstate confidence.
- Ticked the market-researcher task in [[Gumroad Digital Products]]; the product-line pick itself stays
  under "Waiting on the owner".

## 2026-09-26: hourly run — built Sproutling Isles analytics wrapper
**Device:** cloud Routine · **Branch:** `claude/roblox-popular-game-trends-6u7sie` (vault stays on `main`) · **Agents used:** roblox-engineer

**What was done**
- Task 1 from [[Work Queue]]: roblox-engineer built build notes 1-4 of the analytics spec
  ([[Sproutling Isles - Launch & Live Ops]] section 3) — a pcall-wrapped `Analytics.luau` facade over
  `AnalyticsService`, the 11-step onboarding funnel fired once per player ever (`data.onb` +
  a new `DataService.load` `isNew` flag), an optional `reason` param on `State.addDew`/`spendDew`,
  and economy Source/Sink logging wired at every listed call site (income batched every 5 min and
  on leave, sells, daily gift, pond casts, IAP, rebirth, seed purchases).
- Worked in an isolated worktree, validated with `selene`/`rojo build`/`lune bake-map` (all clean,
  1,209 parts unchanged), then pushed directly to the project branch (commit `a136cba`) — vault's
  `main` was untouched by the agent.
- I reviewed the diff myself (Analytics.luau, DataService's isNew logic, the income batching) before
  recording it: guards look correct (Joined can't re-fire for returning players, even ones who
  joined before the `onb` field existed; income truly batched, not per-tick).
- Recurring funnels (3b) and custom events (3d) were explicitly left out of scope — added as a
  follow-up task in [[Work Queue]]. **Not Studio-tested** (not available in this sandbox); the
  `AnalyticsService` signatures are unverified against live Creator Docs, but every call is
  pcall-guarded so a wrong signature can't break gameplay, only fail to log.
- Ticked the task and updated the Status table in [[Sproutling Isles]].

---

## 2026-09-26: hourly run — re-reviewed Sproutling Isles fixes (3/3 tasks, run complete)
**Device:** cloud Routine · **Branch:** `main` · **Agents used:** qa-tester

**What was done**
- Task 3 from [[Work Queue]]: qa-tester re-reviewed the 2026-09-23 fix commit on `claude/roblox-popular-game-trends-6u7sie`
  in an isolated worktree, installing rojo/lune/selene fresh (not preinstalled). Tooling still clean: `selene` 0
  errors/warnings, `rojo build` succeeds, `lune bake-map` still 1,209 parts, fresh build+bake matches the committed
  `.rbxlx` with no diff.
- Checked every claimed fix against the actual code (not just the commit message): blocker B1 and majors M1-M6, plus
  all 14 claimed-fixed minors (more than the 5 requested). **All confirmed genuinely fixed**, no new bugs spotted.
  Still-open items (m6, m11, m15, m18) confirmed still open, as expected (owner/design decisions or need a phone/Studio).
- Updated [[Sproutling Isles - QA Review]] with a dated re-review section and a test-plan note that the shield Config
  edit is now redundant (M6 handles it automatically) and Bonk is R, not E. Ticked the task in [[Sproutling Isles]].
- This was the 3rd task this run — stopping per [[Hourly Workflow]]'s 3-tasks-per-run cap.

## 2026-09-26: hourly run — QA'd Clip Studio's hourly branch
**Device:** cloud Routine · **Branch:** `main` · **Agents used:** qa-tester

**What was done**
- Task 2 from [[Work Queue]]: qa-tester reviewed `claude/hourly-project-processing-ejbqs4` (29 commits ahead of
  the mainline branch) in an isolated `git worktree`, never touching `main`'s working tree or pushing/merging
  anything. Reproduced every CI step it could (Postgres/Redis service containers, ffmpeg, `npm test`, driver
  tests, syntax check): **101+6+1 tests passed.** Docker build step unverified (sandbox has no working Docker
  daemon — not a code issue).
- Found 2 minor, non-blocking bugs (a fragile hardcoded-string disclaimer check, a missing `|| ''` guard) and
  reviewed the security pass (constant-time tokens, failed-auth limiter, path-traversal-safe run IDs, atomic
  credit spend) — all looked sound.
- Wrote the full QA report into [[Clip Studio]] (`## QA Review (2026-09-26)`), ticked the review task, added
  follow-ups: owner (merge decision), app-engineer (fix the two minor bugs).

## 2026-09-26: hourly run — documented Trading Agent
**Device:** cloud Routine · **Branch:** `main` · **Agents used:** none (done directly; task was read-only research)

**What was done**
- Task 1 from [[Work Queue]]: added the `trading-agent` repo to this session read-only (`add_repo`), read its
  `README.md` and `CHANGELOG.md` via the GitHub API (no clone needed), and rewrote [[Trading Agent]] with how to
  run it, its risk controls, the daily alert, and test/CI status (191 tests; CI on Python 3.10/3.12/3.13 + ruff).
- Added two owner follow-ups: OANDA setup (already tracked) and whether to enable the `daily-paper.yml` schedule.
- Ticked the item in [[Work Queue]] and logged it.

---

## 2026-09-26 (evening): hourly workflow restarted
**Device:** phone · **Branch:** `claude/working-automation-system-al8rz1` → synced to `main` · **Agents used:** none

**Owner asked:** go back to the hourly workflow plan, keep working on projects, make new ones based on our work, and send a morning summary.

**What was done**
- Found the old plan: session `session_01HkUDBZ…` ran a 20-minute loop on 23–25 Sep (Clip Studio AI presenter, a `trading-agent` repo,
  artifact pages). Its queue was in a temp file (gone), it's blocked on OANDA setup, and it is very large (~758k tokens), so it isn't resumed.
- Wrote [[Hourly Workflow]] (the standing rule), seeded [[Work Queue]], created [[Morning Summary]] and [[Trading Agent]],
  and recorded the hourly branch's Clip Studio work in [[Clip Studio]]. Added the workflow to `CLAUDE.md`.
- Created two Routines: hourly work (fresh session each hour) and the morning summary (~7:45 am Eastern).

**Not verified**
- [[Trading Agent]] is written from Routine records, not the code (first queue item fixes that).
- The first hourly run hasn't happened yet.

- Owner then asked for the cheapest setup, no direct charges, payment alerts, and a 20-minute pace. Routines can't run more often than hourly,
  so each hourly run now does up to 3 tasks (~20 min each). Added "Keep it cheap" and "costs money → notify" rules, set cheaper models
  for knowledge-keeper (Haiku) and market-researcher, live-ops-manager, product-maker (Sonnet), and test-fired the hourly Routine.

- Test result: fresh-session Routines start without the repo and pushed nothing (~$2 wasted), so they were deleted. Created a
  dedicated worker session (Sonnet 5, repo attached); its setup test pushed to `main` (~$0.19). New Routines "Hourly project work (worker)"
  (hourly, 3 tasks per run) and "Morning summary (worker)" (7:45 am ET) now wake that session. First real run fired 04:36 UTC.

**Next:** see [[Active Context]].

---

## 2026-09-26 (later): Gumroad selling plan
**Device:** phone · **Branch:** `claude/working-automation-system-al8rz1` → synced to `main` · **Agents used:** none

**Owner asked:** go ahead with Gumroad; make all products original and put that at the start.

**What was done**
- Wrote [[Gumroad Digital Products]] with the **originality rule as section 1**, then costs, starter product lines, setup, crew workflow with an originality checklist, and guardrails.
- Added the rule to the `CLAUDE.md` house rules (StarNet agents load `CLAUDE.md`), a new `product-maker` agent, and a row in [[Team Roster]].
- Checked Gumroad fees (10% + $0.50 direct, 30% via Discover) and API product creation (recent, docs conflicting, so the owner publishes by hand).

**Not verified**
- Gumroad's own API docs were blocked from the sandbox; API facts come from search results and GitHub.

**Decisions:** Gumroad first; all products original. Pending: #20 first product line.

**Next:** see [[Active Context]].

---

## 2026-09-26: StarNet models and safety caps chosen
**Device:** phone · **Branch:** `claude/working-automation-system-al8rz1` → synced to `main` · **Agents used:** none

**Owner asked:** pick the model that's most effective for each job.

**What was done**
- Chose per agent/job: Haiku 4.5 (knowledge-keeper summaries), Sonnet 5 (market research), Opus 5 (design, on demand only).
- Applied the safety defaults: $1 per run, Night Shift off for week 1. Recorded in [[Decisions]] and [[StarNet Automation]].
- Owner then asked not to overwork it: added a "Keep it lean" section (medium effort, 25-step and 2-agent limits, caching on), checked in StarNet's code.
- Owner asked Claude to set them: added `starnet/station-settings.json` (a StarNet import file with the $5/day and $1/run caps). The step and agent limits and each agent's model can't be imported, so they stay a 2-minute manual step.
- Verified the import file against StarNet's importer (valid; per-day cap is soft, per-run cap is hard). Checked online selling: Shopify, Gumroad, Lemon Squeezy, print-on-demand, Stripe/PayPal/Square are supported; Etsy is manual only; eBay, Amazon, Facebook Marketplace, Poshmark and Mercari have no integration. Waiting on the owner: what they sell and where. Owner said "anything on the available platforms": recommended Gumroad digital products first, print-on-demand later (decision #19).

**Next:** see [[Active Context]].

---

## 2026-09-25 (latest): StarNet brain and budget decided
**Device:** phone · **Branch:** `claude/working-automation-system-al8rz1` → synced to `main` · **Agents used:** none

**Owner decided:** Anthropic API key; $5/day, paid from the prepaid deposit already in the Anthropic Console.

**What was done**
- Recorded both in [[Decisions]] and added the setup steps to [[StarNet Automation]] (keep Console auto-reload off).
- New pending decision #18: which Claude model (with 2026 prices). #17 narrowed to the per-run cap and Night Shift.

**Next:** see [[Active Context]].

---

## 2026-09-25 (later): StarNet plan checked against its source code
**Device:** phone · **Branch:** `claude/working-automation-system-al8rz1` → synced to `main` · **Agents used:** none

**Owner asked:** back-test the StarNet information and review it several times for the best result.

**What was done**
- Pass 1: checked every claim in [[StarNet Automation]] against StarNet's code (not its README). Found 5 errors:
  no Claude sign-in (API key only), budget caps default to no limit, agents need the repo added as a project,
  the Roblox code isn't on `main`, and scheduled jobs can't write or run commands.
- Rewrote the note: real object names (SHELF, DISH, CORE, WORKBENCH), a permissions table, a phased layout
  (vault-only first), and job setup steps.
- Pass 2: re-checked the new claims. Added that `CLAUDE.md` only loads for project chats and jobs with the repo as
  their working folder, and that Telegram must be connected before a job can send to it.
- Corrected decisions #16–17.

**Not verified**
- StarNet still wasn't run (the sandbox blocks outside code; it's a desktop app). Menu names come from the code.

**Next:** see [[Active Context]].

---

## 2026-09-25: StarNet automation setup
**Device:** phone · **Branch:** `claude/working-automation-system-al8rz1` → synced to `main` · **Agents used:** none

**Owner asked:** "start this working automation system" (screenshot of the StarNet Reel by androo.agi).

**What was done**
- Found StarNet's official open-source repo (github.com/androoAGI/starnet, MIT, v0.12.4) and read its README and install guide.
- Wrote [[StarNet Automation]]: laptop install steps, a station layout that maps the [[Team Roster]] to rooms, first scheduled jobs, and safety rules.
- Added pending decisions #16–17 (brain and budget) to [[Decisions]], and linked the note from [[00 Home]].

**Not verified**
- StarNet was not run: the cloud sandbox blocks running outside code, and it's a Windows/macOS desktop app. It must be installed on the laptop.

**Next:** see [[Active Context]].

---

## 2026-09-23 (evening): moved everything into the vault for the laptop
**Device:** phone · **Branch:** `claude/roblox-popular-game-trends-6u7sie` → synced to `main`

**Owner asked:** move all the information into the Obsidian files, to continue on the laptop.

**What was done**
- Exported the Claude design doc into [[Sproutling Isles - Design Doc]] (now the working copy) and added the map image in `vault/Attachments/`.
- Added [[Start Here - Laptop]] (download or clone, open in Obsidian, optional Obsidian Git sync, continuing with Claude, playing the game).
- Linked both from [[00 Home]], [[Sproutling Isles]] and [[Active Context]].

**Next:** see [[Active Context]].

---

## 2026-09-23 (later): first agent team run
**Device:** phone · **Branch:** `claude/roblox-popular-game-trends-6u7sie` (+ `main`) · **Agents used:** qa-tester, game-designer, live-ops-manager, roblox-engineer

**Owner asked:** "Let's get started" with the agent and memory setup.

**What was done**
- Created the `main` branch with `CLAUDE.md`, `vault/` and `.claude/agents/`, and added branch rules to `CLAUDE.md`. The owner changed the default-branch setting, but GitHub still reported the old default at the last check.
- qa-tester: [[Sproutling Isles - QA Review]] found 1 blocker (nobody could see snatch prompts), 6 majors and 18 minors, and wrote a Studio test plan.
- roblox-engineer fixed the blocker, all 6 majors and 14 minors (anti-cheat speed and reach checks, Bonk moved to R, rebirth-during-snatch, saved shop stock and luck, Studio shield off, save ordering). Lint is clean and the place was rebuilt and baked.
- game-designer: [[Sproutling Isles - Art Brief]] and [[Sproutling Isles - Trading Spec]].
- live-ops-manager: [[Sproutling Isles - Launch & Live Ops]] (checklist, beta, analytics spec, ads, weeks 1–8, Halloween "Hollow Harvest", marketing).
- Collected 15 pending owner decisions, with recommendations, in [[Decisions]].

**Not verified**
- Still nothing run in Roblox Studio. The anti-cheat thresholds (1.3x speed, 2.5 s burst) are estimates.
- Roblox menu paths, the ads API and platform limits in the new notes were written from memory or search summaries.

**Next:** see [[Active Context]].

---

## 2026-09-23: Roblox research → design doc → Sproutling Isles build → memory system
**Device:** phone (Claude app, cloud session) · **Branch:** `claude/roblox-popular-game-trends-6u7sie`

**Owner asked**
1. Which Roblox games to build, based on 2026 trends in engagement and spending, with in-depth research.
2. A game design doc for the top pick, built directly for Roblox Studio, with a map that uses several games as reference and is completely original.
3. How to continue on a laptop; whether GitHub or Obsidian could hold shared knowledge.
4. A setup where agents keep memory, know their job, and work on their own.

**What was done**
- Research, summarised in [[Roblox Market Research 2026]]. Top pick: a collect/grow/trade simulator with a social twist.
- Design doc "Sproutling Isles — Game Design Doc" in Claude Docs (link in [[Sproutling Isles]]).
- Built `roblox/sproutling-isles/` (Rojo + Luau): the map, all core systems, saving and monetization code. The map is baked into `build/SproutlingIsles.rbxlx`. Lint is clean and the map preview has been rendered.
- Created this vault, `CLAUDE.md` and the agent team in `.claude/agents/`.

**Not verified**
- The game has not been run inside Roblox Studio (not available in the cloud sandbox).
- The research figures come from search summaries; most source pages were blocked for direct reading.

**Next:** see [[Active Context]].
