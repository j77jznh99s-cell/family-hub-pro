---
tags: [memory]
updated: 2026-09-26
---
# Active Context

> Rewrite this note at the end of every session so it's true *now*. Keep it short.

## Current focus
**Hourly workflow is on (from 2026-09-26).** A cloud Routine runs every hour, 24/7, and works one task from
[[Work Queue]] following [[Hourly Workflow]]. At about 7:45 am Eastern a second Routine writes [[Morning Summary]]
and sends a push notification. New projects may be started (max one a day, original, waiting for the owner's OK).

Projects: [[Sproutling Isles]] (2026-09-23 fixes re-reviewed 2026-09-26, all confirmed in code; analytics wrapper +
onboarding funnel + economy events built 2026-09-26 (`a136cba`); leaderboards built 2026-09-26 (`21c68c3`, a
display bug caught in review and fixed same day, `6aece41`); ads eligibility & Ads Manager pricing re-verified
2026-09-26 with real corrections found; lint/build/bake clean throughout; still waiting on the owner's first
Studio play-test) · [[Clip Studio]] (hourly branch QA'd 2026-09-26: 101+6+1 tests pass, 2 minor non-blocking bugs,
owner decides merge; `main`'s CI was separately found red since 2026-09-23 — unrelated pre-existing bug — and
fixed 2026-09-26, `fd327a0`) · [[Trading Agent]] (documented 2026-09-26 from its README/CHANGELOG; blocked on
OANDA setup) · [[Gumroad Digital Products]] (demand brief for all 3 product lines written 2026-09-26, sourced;
owner still picks one, [[Decisions]] #20) · [[StarNet Automation]] (plan ready, needs the laptop) ·
[[Family Hub]] · [[Bybit Trading Bot]].

## Waiting on the owner
- [ ] Play-test Sproutling Isles in Studio ([[Sproutling Isles - QA Review]]); answer [[Decisions]] (#1–4 block the next build; #20 product line — see the 2026-09-26 demand brief in [[Gumroad Digital Products]]).
- [ ] Create the 13 Robux items and share the IDs.
- [ ] Trading agent: OANDA setup (network access + `OANDA_ENV`, `OANDA_ACCOUNT_ID`); also decide whether to enable the `daily-paper.yml` schedule.
- [ ] Install StarNet on the laptop; then the Gumroad account.
- [ ] Say what's next for Clip Studio and Family Hub — including whether to merge `claude/hourly-project-processing-ejbqs4` (QA'd clean, 2 minor bugs to fix either way).

## Timeline at risk
Beta 2–8 Oct and launch 10 Oct need a clean play-test by about 1 Oct. If launch slips past 24 Oct, skip Halloween.

## Key links
- Queue: [[Work Queue]] · Rule: [[Hourly Workflow]] · Summary: [[Morning Summary]]
- Laptop setup: [[Start Here - Laptop]]
