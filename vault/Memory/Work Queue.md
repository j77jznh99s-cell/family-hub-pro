---
tags: [memory, queue]
updated: 2026-09-26
---
# Work Queue

The hourly Routine works the **top unchecked items that aren't marked (owner)**, up to 3 per run (about one every 20 minutes). See [[Hourly Workflow]].
Add new items with an owner role. Keep the list in priority order.

## Queue (priority order)
- [ ] **roblox-engineer:** Sproutling Isles analytics recurring funnels (Store/Snatch/Rebirth/EventShop/Ad) + custom events (Hatch/SnatchStart/WeatherStart/etc.), spec sections 3b/3d in [[Sproutling Isles - Launch & Live Ops]] — follow-up to the onboarding/economy wrapper built 2026-09-26.
- [ ] **roblox-engineer:** Sproutling Isles leaderboards (income, rarest hatch).
- [ ] **game-designer:** m11 pond water surface (map art) and check the Halloween numbers.
- [ ] **roblox-engineer:** Hollow Harvest Halloween event (build by about 15 Oct; skip if launch slips past 24 Oct).
- [ ] **live-ops-manager:** full winter (Frostbloom) spec by 21 Nov.

## Waiting on the owner (runs skip these)
- [ ] (owner) Play-test Sproutling Isles in Studio; answer [[Decisions]] (Sproutling #1–4 block the next build; #20 product line).
- [ ] (owner) Create the 13 Robux items and share the IDs.
- [ ] (owner) Trading agent: OANDA setup (add `api-fxpractice.oanda.com` / `api-fxtrade.oanda.com` to network access, set `OANDA_ENV` and `OANDA_ACCOUNT_ID`).
- [ ] (owner) Clip Studio, Family Hub: say what's next (deploy? more features?).
- [ ] (owner) StarNet install and Gumroad account (see [[StarNet Automation]], [[Gumroad Digital Products]]).

## Needs you: costs money (runs add items here and send a push notification)
- (none yet)

## Run log (newest first; one line per hourly run)
- 2026-09-26: **CI-first task.** `main`'s CI had been red since 2026-09-23 (every push failing `storage.test.js`'s presigned-URL test — a mocking bug in `src/services/storage/s3.js`, unrelated to any of this session's vault-only pushes). Found the exact fix already on `claude/hourly-project-processing-ejbqs4` and ported it to `main` (`fd327a0`); 30/30 tests pass locally. See [[Clip Studio]] for detail.
- 2026-09-26: market-researcher re-checked Roblox rewarded-ads eligibility, Ads Manager pricing and the maturity questionnaire against Roblox's creator-docs GitHub mirror (direct create.roblox.com/devforum fetches are blocked in-sandbox). Found real corrections, not just re-confirmations: `ShowAdResult.ShowCompleted` not `Succeeded`, 3 extra eligibility requirements, Ads Manager bills as auto-bid/CPP not CPM/CPC, "new-creator ad credits" likely doesn't exist. Updated [[Sproutling Isles - Launch & Live Ops]] sections 1D/4/6 and ticked both tasks. 3/3 tasks done this run, stopping.
- 2026-09-26: market-researcher wrote the demand brief for all 3 Gumroad product lines (family printables, Roblox guides, spreadsheet/Notion templates) into [[Gumroad Digital Products]], with sources and an unverified-figures flag on anything from a blocked direct fetch. Deliberately did not pick one — [[Decisions]] #20 stays owner-pending.
- 2026-09-26: roblox-engineer built the Sproutling Isles analytics wrapper + 11-step onboarding funnel + economy source/sink logging (spec build notes 1-4), pushed `a136cba` to `claude/roblox-popular-game-trends-6u7sie`. selene/rojo/lune all clean. Not Studio-tested; recurring funnels + custom events queued as a follow-up.
- 2026-09-26: qa-tester re-reviewed the 2026-09-23 Sproutling Isles fixes in an isolated worktree (installed rojo/lune/selene fresh): tooling still clean (0 lint issues, build/bake unchanged), every claimed fix (B1, M1-M6, 14 minors) confirmed present and correct in code, still-open items confirmed still open. Updated [[Sproutling Isles - QA Review]] and ticked the task. 3/3 tasks done this run, stopping.
- 2026-09-26: qa-tester reviewed `claude/hourly-project-processing-ejbqs4` (Clip Studio) in an isolated worktree: 101+6+1 tests passed, CI steps reproduced except Docker build (sandbox limitation). 2 minor bugs found (no blockers). Added owner (merge decision) + app-engineer (fix) follow-ups in [[Clip Studio]].
- 2026-09-26: knowledge-keeper filled in [[Trading Agent]] from the repo's README/CHANGELOG (read-only, GitHub API, no clone). Added two owner follow-ups (OANDA setup; enable/skip the daily-paper.yml schedule).
- 2026-09-26 (setup test): worker session can clone and push to main.
- 2026-09-26: queue created from the project task lists (setup session).
