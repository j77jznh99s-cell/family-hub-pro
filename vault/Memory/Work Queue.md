---
tags: [memory, queue]
updated: 2026-09-26
---
# Work Queue

The hourly Routine works the **top unchecked items that aren't marked (owner)**, up to 3 per run (about one every 20 minutes). See [[Hourly Workflow]].
Add new items with an owner role. Keep the list in priority order.

## Queue (priority order)
- [ ] **live-ops-manager:** full winter (Frostbloom) spec by 21 Nov.

## Waiting on the owner (runs skip these)
- [ ] (owner) Play-test Sproutling Isles in Studio; answer [[Decisions]] (Sproutling #1–4 block the next build; #20 product line).
- [ ] (owner) Create the 13 Robux items and share the IDs.
- [ ] (owner) Create a "Summon Spooky Fog" dev product (proposed 149 R$) and share the ID for the Hollow Harvest event.
- [ ] (owner) Studio playtest of the Hollow Harvest Halloween event before 17 Oct (fast-forward time to check the Fog schedule, lanterns, stall, skin, and end-of-event conversion) — Studio isn't available in the sandbox, so this needs the owner.
- [ ] (owner) Trading agent: OANDA setup (add `api-fxpractice.oanda.com` / `api-fxtrade.oanda.com` to network access, set `OANDA_ENV` and `OANDA_ACCOUNT_ID`).
- [ ] (owner) Clip Studio, Family Hub: say what's next (deploy? more features?).
- [ ] (owner) StarNet install and Gumroad account (see [[StarNet Automation]], [[Gumroad Digital Products]]).

## Needs you: costs money (runs add items here and send a push notification)
- (none yet)

## Run log (newest first; one line per hourly run)
- 2026-09-26: roblox-engineer built the full Hollow Harvest Halloween event (`6f59f2f`) — Spooky Fog, Wisp Lanterns, 3 limited species, Lantern Stall, plot skin, end-of-event conversion, plus the analytics it unlocked (10 files, ~430-line new EventService.luau). Reviewed the whole diff line-by-line myself (dates hand-verified against `date -u`, cross-module calls checked, reconcile-backfill checked) and found one real bug: the Dew conversion formula dropped the berries-count multiplier entirely, so every player got the same flat payout regardless of balance. Fixed directly (`b8b34b4`), re-validated, CI green. 1 task this run (large scope); stopping.
- 2026-09-26: did the "game-designer: m11 + Halloween numbers" task directly (no agent needed — read-only analysis + a small, well-understood code fix). Confirmed the Halloween species' payback numbers against the base game's curve (all consistent). Diagnosed and fixed QA m11 (pond Rim walkable under the water surface) myself: `Rim.CanCollide = false`, `397cc4e`, validated clean, CI green. Only unblocked item was Halloween-event-adjacent, so did just this 1 task and stopped rather than jump to the bigger, deadline-sensitive Hollow Harvest build without more runway.
- 2026-09-26: roblox-engineer wired Sproutling Isles analytics recurring funnels (Store/Snatch/Rebirth) + custom events (Hatch, Snatch*, GateLock, Weather*, Rebirth, DailyClaim, PondCatch, StorageFull/NoSeeds, SessionEnd), `e432cfd`. EventShop/Ad funnels and Store steps 1-3 deliberately skipped (dependencies don't exist yet). I reviewed the full diff before recording — no bugs found this time (unlike last run's leaderboard bug). 2 tasks this run (CI port + funnels/events); stopping.
- 2026-09-26: **CI-first task.** The same pre-existing S3-mocking CI bug fixed on `main` last run was still red on `claude/roblox-popular-game-trends-6u7sie` (that branch forked before the fix, and also carries the Clip Studio code). Ported the identical fix (`c5e7884`); 30/30 tests pass locally. See [[Clip Studio]].
- 2026-09-26: roblox-engineer built Sproutling Isles leaderboards (cross-server income + rarest hatch, `21c68c3`). Reviewing the diff myself before recording found a real display bug (TextLabel nested wrong for the lookup code to ever find it — boards would have stayed on "Loading..." forever); fixed and re-validated directly (`6aece41`). 2 tasks this run (CI fix + leaderboards); stopping given the CI investigation's extra time.
- 2026-09-26: **CI-first task.** `main`'s CI had been red since 2026-09-23 (every push failing `storage.test.js`'s presigned-URL test — a mocking bug in `src/services/storage/s3.js`, unrelated to any of this session's vault-only pushes). Found the exact fix already on `claude/hourly-project-processing-ejbqs4` and ported it to `main` (`fd327a0`); 30/30 tests pass locally. See [[Clip Studio]] for detail.
- 2026-09-26: market-researcher re-checked Roblox rewarded-ads eligibility, Ads Manager pricing and the maturity questionnaire against Roblox's creator-docs GitHub mirror (direct create.roblox.com/devforum fetches are blocked in-sandbox). Found real corrections, not just re-confirmations: `ShowAdResult.ShowCompleted` not `Succeeded`, 3 extra eligibility requirements, Ads Manager bills as auto-bid/CPP not CPM/CPC, "new-creator ad credits" likely doesn't exist. Updated [[Sproutling Isles - Launch & Live Ops]] sections 1D/4/6 and ticked both tasks. 3/3 tasks done this run, stopping.
- 2026-09-26: market-researcher wrote the demand brief for all 3 Gumroad product lines (family printables, Roblox guides, spreadsheet/Notion templates) into [[Gumroad Digital Products]], with sources and an unverified-figures flag on anything from a blocked direct fetch. Deliberately did not pick one — [[Decisions]] #20 stays owner-pending.
- 2026-09-26: roblox-engineer built the Sproutling Isles analytics wrapper + 11-step onboarding funnel + economy source/sink logging (spec build notes 1-4), pushed `a136cba` to `claude/roblox-popular-game-trends-6u7sie`. selene/rojo/lune all clean. Not Studio-tested; recurring funnels + custom events queued as a follow-up.
- 2026-09-26: qa-tester re-reviewed the 2026-09-23 Sproutling Isles fixes in an isolated worktree (installed rojo/lune/selene fresh): tooling still clean (0 lint issues, build/bake unchanged), every claimed fix (B1, M1-M6, 14 minors) confirmed present and correct in code, still-open items confirmed still open. Updated [[Sproutling Isles - QA Review]] and ticked the task. 3/3 tasks done this run, stopping.
- 2026-09-26: qa-tester reviewed `claude/hourly-project-processing-ejbqs4` (Clip Studio) in an isolated worktree: 101+6+1 tests passed, CI steps reproduced except Docker build (sandbox limitation). 2 minor bugs found (no blockers). Added owner (merge decision) + app-engineer (fix) follow-ups in [[Clip Studio]].
- 2026-09-26: knowledge-keeper filled in [[Trading Agent]] from the repo's README/CHANGELOG (read-only, GitHub API, no clone). Added two owner follow-ups (OANDA setup; enable/skip the daily-paper.yml schedule).
- 2026-09-26 (setup test): worker session can clone and push to main.
- 2026-09-26: queue created from the project task lists (setup session).
