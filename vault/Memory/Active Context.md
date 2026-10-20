---
tags: [memory]
updated: 2026-10-20
---
# Active Context

> Rewrite this note at the end of every session so it's true *now*. Keep it short.

## Current focus
**Hourly workflow is PAUSED (owner, 2026-09-27 ~15:04 UTC).** The "Hourly project work (worker)" Routine
(`trig_012vmVxmbAkxxY59wCnKaG1J`) is disabled — it will not fire until the owner re-enables it. The morning-summary
Routine (~7:45 am Eastern, writes [[Morning Summary]] + one push notification) is untouched and still runs.
When resumed: works one task from [[Work Queue]] following [[Hourly Workflow]]; new projects may be started
(max one a day, original, waiting for the owner's OK).

**[[Work Queue]] has been empty since ~21:45 UTC on 2026-09-26**, still empty as of this morning summary
(0 unblocked items; every dormant project checked and confirmed owner-gated). Each empty hour just re-checks
CI and the queue, then logs a one-line "nothing changed" and stops — no more speculative work is being added
to `tools/audit-economy.luau` (it's feature-complete at 4 sections, see below). Next real progress needs the
owner to unblock something.

**2026-10-08: [[Knowledge Graph]] built** (`tools/knowledge-graph/`, workspace-level, not tied to one
project) — owner sent a VPS-agent tutorial video, asked to implement it; found it was already
researched and recommended against ([[Decisions]] #21), so proposed alternatives and owner chose the
graph-only route instead. Nodes/edges, file-based, git-tracked, no server/cost. 9/9 new tests pass,
seeded with real project data. See [[Active Context#Waiting on the owner]] below for the ask.

Projects: [[Sproutling Isles]] (2026-09-23 fixes re-reviewed 2026-09-26, all confirmed in code; full analytics spec
built 2026-09-26 across two passes (`a136cba`, `e432cfd`); leaderboards built 2026-09-26 (`21c68c3`, a display bug
caught in review and fixed same day, `6aece41`); QA m11 (pond walkable) fixed 2026-09-26 (`397cc4e`); Halloween
species numbers checked against the game's payback curve, all consistent; **Hollow Harvest Halloween event fully
built 2026-09-26** (`6f59f2f`, well ahead of the 15 Oct deadline — a real economy bug caught in review and fixed
same day, `b8b34b4`: the end-of-event Dew conversion ignored the berries count); a QA pass then found `Config.
EventTimeOffset` — needed to Studio-test the event before its real 17 Oct start — had never been built (an
older task called for it, got missed); **built and pushed 2026-09-26 (`04a3211`), reviewed and confirmed
correct** — the full Hollow Harvest test plan can now actually be run, still needs the owner's Studio access;
**Week 5 Codes system fully built and populated 2026-09-26** (`63c3100` system + `da077ea` the real 5-code
list — `SPROUT1K`, `MISSEDBLOOM`, `LUCKYGARDEN`, `GROWINGSTRONG`, `SEEDSTASH` — all free-tier only; a real
balance flag was caught in review along the way (`GROWINGSTRONG`'s Rare seed originally priced above the paid
Starter Pack's own Rare seed) and resolved same day by swapping species, before it shipped; not Studio-tested
yet); **dev tool `tools/audit-economy.luau` built out in 4 parts, 2026-09-26** (`d1dcc75` species payback
report → `f9e0031` auto-checks `Codes.luau`'s free rewards against the paid catalogue's floor → `e10e86b`
reports `Products.luau`'s Dew-per-Robux rates → `b3ffc86` steady-state Dew/hour per species; all 4 commits
reviewed, math hand-verified, CI green — treated as feature-complete for now); **Founding
Gardener badge flag + Frostbloom Week 8 login tracker
built 2026-09-26** (`35ab411`; reviewing it independently re-verified all 4 UTC timestamps and caught a real
day-of-week error in a code comment — "Thu 11 Dec" should be "Fri 11 Dec"; the epoch value was already
correct — fixed same day, `bb7f395`; both features are data/flag-only, no reward UI, not Studio-tested,
months from their real dates); **a whole-day QA re-review 2026-09-26 caught one more real bug**: the
Founding Gardener/Frostbloom window checks used raw `os.time()` instead of the `Events.now()` hook built for
`Config.EventTimeOffset`, so the Studio fast-forward trick didn't work on those two features — fixed same
day, `75c0dc2`, one line, reviewed and CI green; Frostbloom
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

**NEW 2026-10-03: [[Starling Heist]]**, a brand-new Roblox steal-and-collect game, built from scratch on request
(branch `claude/starling-heist`, folder `roblox/starling-heist/`). Complete code, tests, CI and docs, but **not yet
run in Studio or CI** (no Roblox tools on the PC, pushes failing). Owner: pick launch priority ([[Decisions]] #22).

**2026-10-03 market refresh** ([[Roblox Market Research 2026]]): Grow a Garden 2 lost ~95% of its players; the
new #1 is a steal/collect-pets game; big games' Halloween events began 2–9 Oct. Suggests leading with collecting/
trading/snatching, weekly Hollow Harvest drops, and checking outside-game purchases before launch (tasks added).
Outside-game purchases: fixed 2026-10-03 20:00 (`01d455f`, local only, not linted or Studio-tested); refund webhook is an owner decision.
QA-reviewed 2026-10-06 18:00: sound; one older lost-purchase bug fixed (`c0e934c`, re-save before confirming a repeat receipt); 2 minors + stale `.rbxlx` filed for roblox-engineer.
2026-10-10 20:45: both minors fixed (`16171a1`, local only, not linted): receipt wait 90 s, saves for one player never overlap. Owner: OK the leave-save "write anyway after 120 s" fallback (see [[Sproutling Isles]] tasks).
2026-10-15 10:21: last known receipts edge case fixed (`60c49d0`, local only, not linted): a receipt is no longer confirmed when the leave-save skipped its write because another server owns the profile.
2026-10-19 10:56: qa-tester reviewed `16171a1`/`60c49d0`; one blocker fixed (`b918340`, local only, not linted): a fast rejoin could load before a queued leave-save and its later saves/receipts then reported success unsaved. Owner: BindToClose waits 25 s but a leave-save may wait 120 s (see [[Sproutling Isles]] tasks).
Weekly drops: checked 2026-10-06 — already built that way (17 Oct / 24 Oct / Witching Hour 31 Oct), no change needed.
2026-10-16 20:10: Roblox's 2026 Halloween event reported as "The Hollow" from Thu 22 Oct (fan/news sources only, unverified); no code change, optional Part 2 teaser 22 Oct; Witching Hour now worded "Friday 30 Oct night (US)". Hollow Harvest starts 17 Oct (tomorrow) on the real clock even if launch slips.

## Waiting on the owner
- [ ] **Starling Heist:** `gh auth login --web` on the PC so the branch pushes and CI runs; then play-test with
  `roblox/starling-heist/docs/TEST_PLAN.md`; then the publishing checklist in its README.
- [ ] **Approve the Claude Code add-ons** (2026-10-16): PonyTail + Agent Skills (recommended), OmniRoute declined. Steps in [[Claude Code Add-ons]]. **Graphify is done** (installed 2026-10-16, graph in `graphify-out/`; owner says laptop install done too).
- [ ] **Run the Sproutling Isles Studio play-test** ([[Sproutling Isles - QA Review]]) — polished and
  re-verified 2026-10-03 (zero code drift since last review; stale citations and a week-old date
  table fixed), ready to pull on the laptop and run with no known blockers left on this end.
- [ ] video-analyst: first real attempt (`youtu.be/FwOTs4UxQS4`, 2026-09-27) failed — Descript's importer got back an HTML page, not a media file. Confirm the video's public/accessible, or send the file as a direct upload instead. See [[Video Analyst Runs]]. **Note for next time:** a direct-link upload to Dropbox (file-level share link, `dl=1`, and specifically the `dl.dropboxusercontent.com` host — `www.dropbox.com` with `dl=1` still returned an HTML page) worked cleanly on 2026-10-08 for a 53MB video when the chat's own upload limit (~30MB) was the blocker.
- [ ] Try the new [[Knowledge Graph]] (`tools/knowledge-graph/cli.js`) in a real session and say whether the node/edge schema fits how you actually want to query things — built and tested 2026-10-08 but only seeded with my own placeholder data so far.
- [ ] **Set up Obsidian on iPhone** per [[Start Here - iPhone]] (written 2026-10-08, unverified — no iOS device in the sandbox to test the Working Copy → Obsidian folder-picker step). Confirm it actually works, then this note's "not verified" can be cleared.
- [ ] Say whether to wire the new [[#Key links|Command Deck]] hub artifact (built 2026-09-27 on request) into the hourly routine for periodic refresh, or leave it as refresh-on-request.
- [ ] Play-test Sproutling Isles in Studio ([[Sproutling Isles - QA Review]]); answer [[Decisions]] (#1–4 block the next build; #20 product line — see the 2026-09-26 demand brief in [[Gumroad Digital Products]]). Now also covers the Hollow Harvest Halloween event before 17 Oct — `Config.EventTimeOffset` is built (`04a3211`), so the full test plan in the QA note is ready to run.
- [ ] Create the 13 Robux items and share the IDs (includes a new "Summon Spooky Fog" dev product, ~149 R$, for Hollow Harvest).
- [ ] Trading agent: OANDA setup (network access + `OANDA_ENV`, `OANDA_ACCOUNT_ID`); also decide whether to enable the `daily-paper.yml` schedule.
- [ ] StarNet itself (the local pixel-art station) is still on hold, separate from the VPS-agent idea declined 2026-10-08; if you want to revisit StarNet specifically, the next step is just the Gumroad account.
- [ ] **Family Hub: build and test the new Catch-Up Recorder** (`0f097d3`, 2026-10-07, cloud) — `swift test` for the new logic tests, then Xcode on a real iPhone. Completely unverified until you do. See [[Family Hub]] for exact steps. Also still open: what's next for Family Hub overall (TestFlight? App Store?).
- [ ] Family Hub (local PC runs): reviewed 2026-10-03 (`5b87ea8`, 5 bugs fixed) + widget ✓ race fixed 2026-10-06 (`b64728a`, `Store.update`) + edit sheet no longer undoes a widget ✓ (`a25463d`) + old/newer data files always load (`88472e2`); none compiled or pushed — run `swift test` on a Mac and answer 3 product questions in [[Family Hub]]. Local and GitHub branches merged 2026-10-14 (`1a32998`, local only); new: pick how to delete people now that the Catch-up swipe likely replaced swipe-to-delete. 2026-10-15 13:00: Catch-Up transcripts are now saved before summarising (no key / failed summary no longer loses them) and ticked follow-ups persist (`9a3e9cb`, local only, not compiled); 2 small owner questions in [[Family Hub]]. 2026-10-17 22:34: a catch-up's profile note can no longer be added twice when reopened (`ad6ee49`, local only, not compiled).
- [ ] Bybit bot: risk gate hardened 2026-10-03 (`84b1ec0`) and the Bybit client now throws on missing/blank exchange numbers 2026-10-06 (`b9e9225`), and so do the monitoring scripts (`a9f70ea`, 16:00); `position-check` tracks hedge-mode legs by symbol+side (`47c409d`, 20:00); 2026-10-14 all tests finally run on the PC (Node installed): all pass; the gate now logs a `submitting` audit entry before every exchange write and refuses new entries if it can't (`5c34a45`; gate 69/69, scripts 46/46). 2026-10-15 22:00: audit entries now share an `attempt_id`, and timeouts/network errors say "outcome unknown, check before resubmitting" instead of "rejected" (`df80168`; gate 97/97). 2026-10-18 13:48: MCP SDK bumped to ^1.32.1, `npm audit` now 0 (`c240454`; all tests pass). Not pushed. Still confirm paper vs live status; optional: OK treating Bybit codes 10000/10016 as "outcome unknown".
- [ ] Say what's next for Clip Studio and Family Hub — including whether to merge `claude/hourly-project-processing-ejbqs4` (QA'd clean). Its 2 minor bugs were fixed 2026-10-03 on `claude/clip-studio-presenter-fixes` (`207fbba`, built on top of it; tests not run, not pushed) — merge that branch instead to get both. 2026-10-06: calendar/weekly/usage reviewed on that branch (`3798e7f`, 4 small fixes), and early-failure spend now logged (`b51d8e1`, 17:00); 2026-10-10: a repeat run no longer overwrites the earlier run's folder, and bad `--days`/`--per-day` now error out (`cd43c65`). 2026-10-15: tests finally run on the PC (Node 24): 114/119 pass, 3 skipped (no ffmpeg), 2 DB/queue files can't load (`better-sqlite3` has no Node 24 Windows build; environment only), so all those presenter fixes are verified. 2026-10-16 17:00: `better-sqlite3` bumped to 12.x and caption burn-in fixed for Windows paths (`bb3f1d3`); full suite now 125/125 on the PC with ffmpeg, nothing skipped (local only). 2026-10-18 21:48: one shared `PRESENTER_PER_DAY` setting for calendar, fill-week, weekly report and dashboard (`8fb8502`, 126/126, local only). 2 timing decisions for you in [[Clip Studio]] (QA Review 2 #3, #4).

## Timeline at risk
**The original plan has now fully slipped** (as of 2026-10-10, the originally planned public-launch date):
the 2–8 Oct beta window passed with no play-test done, and today's launch date passed with it. The owner is
the only one who can run the play-test (Roblox Studio access). This needs an explicit owner decision — new
beta/launch dates, or another path forward — not something a session can resolve on its own. If launch slips
past 24 Oct, skip Halloween.

## Key links
- Queue: [[Work Queue]] · Rule: [[Hourly Workflow]] · Summary: [[Morning Summary]]
- Laptop setup: [[Start Here - Laptop]]
- Command Deck (owner-facing status hub, built 2026-09-27, snapshot not live): https://claude.ai/artifact/DJDjGkTBnytfu5eUoV8TnP
