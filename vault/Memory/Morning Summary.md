---
tags: [memory, summary]
updated: 2026-09-26
---
# Morning Summary

Written each day at about 7:45 am Eastern by the morning Routine (see [[Hourly Workflow]]). Newest at the top.

---

## 2026-09-26 (first morning summary)

**Done overnight/today**
- Sproutling Isles: re-confirmed all the 2026-09-23 bug fixes are genuinely in the code; built full
  analytics tracking, cross-server leaderboards, and the **entire Hollow Harvest Halloween event**
  (weather, 3 new creatures, a lantern hunt, a shop, a plot skin) — well ahead of its mid-October
  deadline. Wrote and confirmed the full winter event (Frostbloom Festival) spec too, for December.
- Caught and fixed **2 real bugs** while reviewing that work before recording it done: a leaderboard
  that would never have displayed anything, and a Halloween-event bug that would have paid every
  player the same flat amount regardless of how much event currency they'd earned.
- A QA pass on the Halloween event found the tool needed to test it in Studio before the real date
  was never actually built — flagged with an exact fix and queued as the next build task.
- Fixed CI that had been silently red on `main` since 23 Sep (unrelated to anything this session did).
- Clip Studio: QA'd the newest branch (all tests pass, 2 minor bugs found, not merged yet).
- Wrote a sourced demand brief comparing the 3 possible Gumroad product lines, and checked current
  Roblox ad rules/pricing (found a few things had actually changed since they were last written down).
- Documented the Trading Agent repo from its own README.

**New projects waiting for your OK**
- None started today — there was always an existing task available, so the "new project" option
  never came up.

**Needs you: costs money**
- Nothing flagged today. Two Robux items are *proposed* but not created (see below) — no money
  spent or requested yet.

**Needs you**
- **Play-test Sproutling Isles in Studio** — this now also covers the new Hollow Harvest Halloween
  event, but you can't fully test the event yet (see the EventTimeOffset note below); the core game
  can be tested now. [[Sproutling Isles - QA Review]] has the test plan.
- **Create the game's Robux items**, including two new proposed ones: Summon Spooky Fog (~149 R$)
  and a Winter Bundle (~99 R$, proposed for December).
- **Answer the pending decisions** in [[Decisions]] — snatching rules, launch date, trading, and
  #20: which Gumroad product line to start with (a sourced demand brief is ready to help).
- Trading agent: still blocked on OANDA network/account setup.
- Say what's next for Clip Studio and Family Hub (including whether to merge the QA'd branch).
- StarNet + Gumroad account setup, still needs the laptop.

**Next up**
- Build the `Config.EventTimeOffset` Studio-testing hook for Hollow Harvest — found missing today,
  blocks testing the event until it's built. Now the top of the queue.
- Smaller Sproutling Isles builds queued: a Codes redemption box, a launch-week badge tracker.
- Nothing built today has been run in Roblox Studio yet (not possible from this sandbox) — that's
  what your play-test unlocks.

---
