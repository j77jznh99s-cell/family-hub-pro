---
tags: [memory, queue]
updated: 2026-09-26
---
# Work Queue

The hourly Routine works the **top unchecked items that aren't marked (owner)**, up to 3 per run (about one every 20 minutes). See [[Hourly Workflow]].
Add new items with an owner role. Keep the list in priority order.

## Queue (priority order)
- [ ] **knowledge-keeper:** document the `trading-agent` repo (github `j77jznh99s-cell/trading-agent`, branch `claude/hourly-project-processing-ejbqs4`): read its README and fill in [[Trading Agent]] (what it does, how to run it, tests, open tasks). Read only; never place trades.
- [ ] **qa-tester:** review Clip Studio's newest code on branch `claude/hourly-project-processing-ejbqs4` (AI presenter, calendar, security pass): run the tests, check CI, list bugs in [[Clip Studio]]. Don't merge; the owner decides.
- [ ] **qa-tester:** re-review the 2026-09-23 [[Sproutling Isles]] fixes and update the test plan in [[Sproutling Isles - QA Review]].
- [ ] **roblox-engineer:** Sproutling Isles analytics wrapper + events (spec in [[Sproutling Isles - Launch & Live Ops]]), needed before the beta.
- [ ] **market-researcher:** demand brief comparing the 3 Gumroad product lines (family printables, Roblox game-making guides, spreadsheet/Notion templates) with sources, so the owner can answer [[Decisions]] #20.
- [ ] **market-researcher:** verify Roblox rewarded-ads eligibility and Ads Manager pricing.
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
- 2026-09-26: queue created from the project task lists (setup session).
