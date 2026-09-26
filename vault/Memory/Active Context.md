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

Projects: [[Sproutling Isles]] (2026-09-23 fixes re-reviewed 2026-09-26, all confirmed in code; full analytics spec
built 2026-09-26 across two passes (`a136cba`, `e432cfd`); leaderboards built 2026-09-26 (`21c68c3`, a display bug
caught in review and fixed same day, `6aece41`); QA m11 (pond walkable) fixed 2026-09-26 (`397cc4e`); Halloween
species numbers checked against the game's payback curve, all consistent; **Hollow Harvest Halloween event fully
built 2026-09-26** (`6f59f2f`, well ahead of the 15 Oct deadline — a real economy bug caught in review and fixed
same day, `b8b34b4`: the end-of-event Dew conversion ignored the berries count); a QA pass then found `Config.
EventTimeOffset` — needed to Studio-test the event before its real 17 Oct start — had never been built (an
older task called for it, got missed); **built and pushed 2026-09-26 (`04a3211`), reviewed and confirmed
correct** — the full Hollow Harvest test plan can now actually be run, still needs the owner's Studio access;
**Week 5 Codes redemption system built 2026-09-26** (`63c3100`, reviewed and confirmed correct — one-time
per-player, free-tier rewards only, one placeholder demo code so far); **real Week 5 code list proposed
2026-09-26** (5 codes; reviewing it caught a real balance flag — one code, `GROWINGSTRONG`, proposed a free
evergreen Rare seed priced *above* the paid Starter Pack's own Rare seed; flagged in the vault with the exact
numbers and 2 fix options, queued as a game-designer task; the other 4 codes are clean and ready to implement
now); **Founding Gardener badge flag + Frostbloom Week 8 login tracker
built 2026-09-26** (`35ab411`; reviewing it independently re-verified all 4 UTC timestamps and caught a real
day-of-week error in a code comment — "Thu 11 Dec" should be "Fri 11 Dec"; the epoch value was already
correct — fixed same day, `bb7f395`; both features are data/flag-only, no reward UI, not Studio-tested,
months from their real dates); Frostbloom
Festival (winter event) got its full spec + game-designer number confirmation 2026-09-26 too (build closer to
Dec); ads eligibility & Ads Manager pricing re-verified 2026-09-26 with real corrections found; lint/build/bake
clean throughout; still waiting on the owner's first Studio play-test, which should now also cover Hollow Harvest
before 17 Oct (though full event testing needs the EventTimeOffset hook first)) · [[Clip Studio]]
(hourly branch QA'd 2026-09-26: 101+6+1 tests pass, 2 minor non-blocking bugs, owner decides merge; `main`'s CI was
separately found red since 2026-09-23 — unrelated pre-existing bug — fixed 2026-09-26 on `main` (`fd327a0`) and,
once found still red there too, on the Sproutling Isles branch (`c5e7884`) — any other branch forked from `main`
before the fix may need the same port, check CI before pushing) · [[Trading Agent]] (documented 2026-09-26 from
its README/CHANGELOG; blocked on OANDA setup) · [[Gumroad Digital Products]] (demand brief for all 3 product
lines written 2026-09-26, sourced; owner still picks one, [[Decisions]] #20) · [[StarNet Automation]] (plan ready,
needs the laptop) · [[Family Hub]] · [[Bybit Trading Bot]].

## Waiting on the owner
- [ ] Play-test Sproutling Isles in Studio ([[Sproutling Isles - QA Review]]); answer [[Decisions]] (#1–4 block the next build; #20 product line — see the 2026-09-26 demand brief in [[Gumroad Digital Products]]). Now also covers the Hollow Harvest Halloween event before 17 Oct — `Config.EventTimeOffset` is built (`04a3211`), so the full test plan in the QA note is ready to run.
- [ ] Create the 13 Robux items and share the IDs (includes a new "Summon Spooky Fog" dev product, ~149 R$, for Hollow Harvest).
- [ ] Trading agent: OANDA setup (network access + `OANDA_ENV`, `OANDA_ACCOUNT_ID`); also decide whether to enable the `daily-paper.yml` schedule.
- [ ] Install StarNet on the laptop; then the Gumroad account.
- [ ] Say what's next for Clip Studio and Family Hub — including whether to merge `claude/hourly-project-processing-ejbqs4` (QA'd clean, 2 minor bugs to fix either way).

## Timeline at risk
Beta 2–8 Oct and launch 10 Oct need a clean play-test by about 1 Oct. If launch slips past 24 Oct, skip Halloween.

## Key links
- Queue: [[Work Queue]] · Rule: [[Hourly Workflow]] · Summary: [[Morning Summary]]
- Laptop setup: [[Start Here - Laptop]]
