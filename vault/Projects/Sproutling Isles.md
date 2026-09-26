---
tags: [project, roblox, active]
status: build-1-untested
updated: 2026-09-23
---
# Sproutling Isles

Original Roblox **grow-and-snatch simulator**. Players plant seeds that hatch into Sproutlings
(plant-creatures that earn Dew every second), defend their greenhouse gate and snatch rivals' rare Sproutlings.

- **Design doc (source of truth):** [[Sproutling Isles - Design Doc]] (vault copy; the older Claude Doc snapshot: https://claude.ai/code/artifact/a3a37801-bd42-4d71-a221-69ce94bf62e6)
- **Code:** branch `claude/roblox-popular-game-trends-6u7sie`, folder `roblox/sproutling-isles/` (start with its `README.md`)
- **Playable file:** `roblox/sproutling-isles/build/SproutlingIsles.rbxlx` (map baked in)
- **Why this game:** [[Roblox Market Research 2026]]

## Status
| Area | State |
| --- | --- |
| Design doc | Done (8 sections + map render) |
| Core systems | Coded; QA review done and blocker + 6 majors fixed; lint clean; **not play-tested in Studio** |
| Robux items | Coded; IDs are 0 until created on the Creator Dashboard |
| Art | Placeholder; brief ready in [[Sproutling Isles - Art Brief]] |
| Trading, analytics, events, ads | Specs written ([[Sproutling Isles - Trading Spec]], [[Sproutling Isles - Launch & Live Ops]]); not built |

## Key numbers (full tables in the design doc and `src/shared/*.luau`)
- 13 species, Common → Secret; the Mossbun seed costs 10 Dew, pays 1 Dew/s and grows in 30 s.
- Weather every 5–8 min: Drizzle (Dewy x1.5), Thunderbloom (Charged x2), Starfall (Starry x3), Aurora (Prismatic x6); Golden x4 at 1% in any weather.
- Gate lock 60 s (90 s with a pass); snatch carry window 45 s; new-player shield 15 min.
- Rebirth 250k Dew (x4 each time), +50% Dew permanently.

## Tasks
Owners are agent roles from [[Team Roster]]; `owner` means the human. Owner decisions are collected in [[Decisions]].

- [ ] **owner:** play-test the `.rbxlx` in Studio using the test plan in [[Sproutling Isles - QA Review]] (Bonk is now **R**; the Studio shield is off automatically) and paste errors from the Output window
- [x] **qa-tester:** re-review the 2026-09-23 fixes and update the test plan — done 2026-09-26, all confirmed fixed, see [[Sproutling Isles - QA Review]]
- [ ] **owner:** answer the pending decisions in [[Decisions]] (snatching, Starter Pack, gate cooldown, pond payout, trading rules, launch dates and budget)
- [ ] **owner:** create 5 game passes + 8 dev products (steps in [[Sproutling Isles - Launch & Live Ops]]); **roblox-engineer:** paste the IDs into `Products.luau`
- [x] **game-designer:** art brief, see [[Sproutling Isles - Art Brief]]
- [x] **game-designer:** Trading Booths spec, see [[Sproutling Isles - Trading Spec]]
- [ ] **roblox-engineer:** build Trading Booths (spec section 10 checklist), after the owner's trading decisions
- [ ] **roblox-engineer:** analytics wrapper + events (spec in [[Sproutling Isles - Launch & Live Ops]]), needed before the beta
- [ ] **roblox-engineer:** leaderboards (income, rarest hatch)
- [ ] **roblox-engineer:** Hollow Harvest Halloween event (needs to be built by about 15 Oct; skip it if launch slips past 24 Oct)
- [x] **live-ops-manager:** launch checklist, beta plan, week 1–8 calendar, Halloween spec, ads plan, see [[Sproutling Isles - Launch & Live Ops]]
- [ ] **live-ops-manager:** full winter (Frostbloom) spec by 21 Nov
- [ ] **game-designer:** m11 pond water surface (map art), and check the Halloween numbers
- [ ] **market-researcher:** verify rewarded-ads eligibility and Ads Manager pricing; monthly trend refresh

## Bugs
Full details, file:line references and the Studio test plan are in [[Sproutling Isles - QA Review]] (2026-09-23, static review; nothing has been run in Studio yet).
- [x] **Blocker B1 (roblox-engineer, fixed 2026-09-23, not yet Studio-tested):** `claim()` now clears `OnlyUser` on snatch prompts. `release()` resets every prompt to its `init()` state.
- [x] **Major M1-M6 (roblox-engineer, fixed 2026-09-23, not yet Studio-tested):**
  - M1: the server checks the thief's distance to the pad when the snatch fires, and runs a token-bucket speed check during the carry (`Config.CarryMaxSpeedFactor`, `CarryBurstSeconds`).
  - M2: Bonk uses R (gamepad Y) with `AlwaysShow`.
  - M3: a rebirth voids the return of carries in progress (`SnatchService.forfeitCarriesFrom`).
  - M4: shop stock and its restock window are saved.
  - M5: live non-saving sessions return `NotProcessedYet`, and `luckUntil` is saved.
  - M6: `Config.StudioDisableShield` (Studio only).
- [x] **Minor, fixed:** m1, m2, m3, m4, m5, m7, m8, m9, m12, m13, m14, m16, m17, and m10 (toasts only).
- [ ] **Minor, open:**
  - m6: gate cooldown (owner/game-designer decision). The re-lock guard is added.
  - m10: pond payout amount (owner decision).
  - m11: walking on the pond (cosmetic; needs a hole in the grass slab or Terrain water).
  - m15: Starter Pack repeat purchases (owner decision).
  - m18: HUD overlap on iPhone (check on the phone).

## Gotchas for agents
- The cloud sandbox can't run Roblox Studio. Validate with `rojo build`, `lune run tools/bake-map` and `selene src tools`.
- Rojo, Lune and Selene are installed with `cargo install` (about 5 min). See [[Environment Setup]].
- `MapBuilder.luau` must stay free of Roblox services so Lune can run it.
