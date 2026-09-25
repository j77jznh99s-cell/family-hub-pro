---
tags: [memory]
updated: 2026-09-25
---
# Active Context

> Rewrite this note at the end of every session so it's true *now*. Keep it short.

## Current focus
**[[Sproutling Isles]]**: build 1 is fixed after the QA review (blocker + 6 majors + 14 minors).
The whole team plan is written. Everything now waits on the **owner's Studio play-test** and **decisions**.

**New:** [[StarNet Automation]]: the owner wants the agent team running as an automation system.
StarNet is a desktop app, so it needs the laptop. The plan was checked against StarNet's code on 2026-09-25
(no Claude sign-in: it needs an API key; spending caps start at *no limit*; start with vault-only rooms).

## Waiting on the owner
- [ ] Install StarNet on the laptop and answer decisions #16–17 (steps in [[StarNet Automation]]).
- [ ] Play-test `roblox/sproutling-isles/build/SproutlingIsles.rbxlx` in Studio, following the test plan in [[Sproutling Isles - QA Review]]. Paste any Output errors.
- [ ] Answer the 15 pending decisions in [[Decisions]]. #1–4 block the next build.
- [ ] Create the 13 Robux items (steps in [[Sproutling Isles - Launch & Live Ops]]) and share their IDs.

## Next up for agents (once the owner replies)
1. **roblox-engineer:** fix play-test bugs → **qa-tester** re-checks.
2. **roblox-engineer:** analytics wrapper (before the beta), then Trading Booths, then the Halloween event.
3. **market-researcher:** verify rewarded-ads eligibility and Ads Manager pricing.

## Timeline at risk
Beta 2–8 Oct and launch 10 Oct need a clean play-test by about 1 Oct. If launch slips past 24 Oct, skip Halloween.

## Key links
- Design doc: [[Sproutling Isles - Design Doc]] (vault copy is the working version)
- Laptop setup: [[Start Here - Laptop]]
- Code: branch `claude/roblox-popular-game-trends-6u7sie`, folder `roblox/sproutling-isles/`
