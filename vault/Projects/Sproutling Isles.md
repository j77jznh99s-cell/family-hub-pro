---
tags: [project, roblox, active]
status: build-1-untested
updated: 2026-09-26
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
| Trading, events, ads | Specs written ([[Sproutling Isles - Trading Spec]], [[Sproutling Isles - Launch & Live Ops]]); not built |
| Analytics | Wrapper + onboarding funnel + economy events (`a136cba`), then recurring funnels + custom events (`e432cfd`), built 2026-09-26; lint/build/bake clean; **not Studio-tested**. Store funnel steps 1-3, EventShop and Ad funnels deliberately skipped (need systems that don't exist yet: a client remote, `EventService.luau`, `Ads.luau`) |
| Leaderboards | Cross-server income + rarest-hatch boards built 2026-09-26 (`21c68c3`); a display bug found in review and fixed same day (`6aece41`); lint/build/bake clean; **not Studio-tested** |
| Hollow Harvest (Halloween event) | Fully built 2026-09-26 (`6f59f2f`): Spooky Fog, Wisp Lanterns, Lantern Stall, 3 limited species, plot skin, end-of-event conversion, plus the analytics it unlocked. An economy bug found in review and fixed same day (`b8b34b4`). Lint/build/bake clean (1241 parts); **not Studio-tested** |

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
- [x] **roblox-engineer:** analytics wrapper + onboarding funnel + economy events (spec section 3, build notes 1-4) — done 2026-09-26, commit `a136cba` on `claude/roblox-popular-game-trends-6u7sie`. `Analytics.luau` (pcall-wrapped), 11-step onboarding funnel (once per player ever), `reason` param on `State.addDew`/`spendDew` wired at every listed call site, income batched every 5 min + on leave. `selene`/`rojo build`/`lune bake-map` all clean. **Not Studio-tested**; `AnalyticsService` signatures unverified against live Creator Docs (no internet in sandbox) but every call is pcall-guarded.
- [x] **roblox-engineer:** analytics recurring funnels (spec 3b) and custom events (spec 3d) — done 2026-09-26, `e432cfd` on `claude/roblox-popular-game-trends-6u7sie` (based on `c5e7884`). Wired: `Store` funnel step 4 only, `Snatch` (Grabbed/ReachedHome, one GUID per carry), `Rebirth` (CanAfford once per tier/Rebirthed); custom events `Hatch`/`HugeHatch`, `SnatchStart`/`SnatchResult`/`SnatchVictimLeft`, `GateLock`, `WeatherStart`/`WeatherSummonHatches`, `Rebirth`, `DailyClaim`, `PondCatch`, `StorageFull`/`NoSeeds`, `SessionEnd`. Deliberately skipped: `Store` steps 1-3 (need a new `Net.StoreEvent` client remote), `EventShop`/`Ad` funnels (`EventService.luau`/`Ads.luau` don't exist yet) — no stubs added. Two documented interpretations where the spec didn't fully specify behavior: `GateLock`'s "thief nearby" = any other player within roughly one plot-width of the plot centre; `WeatherStart` for natural (non-summoned) weather is logged against an arbitrary online player since the event needs one and there's no summoner. I reviewed the full diff myself before recording this (after finding a real bug in the previous leaderboards task) — guarding logic (once-per-carry `SnatchResult`, once-per-tier `CanAfford`, the `reason`-string→result-bucket matching) checked correct against the actual code. `selene`/`rojo build`/`lune bake-map` clean (1214 parts, unchanged). **Not Studio-tested.**
- [ ] **owner:** when you play-test in Studio, also check the Output window for `[Analytics] ... failed:` warnings (expected if a signature is wrong — logged, not fatal) and confirm no gameplay errors from the new code.
- [x] **roblox-engineer:** leaderboards (income, rarest hatch) — done 2026-09-26, `21c68c3` on `claude/roblox-popular-game-trends-6u7sie`. Cross-server via `OrderedDataStoreService` (income = lifetime `totalDew`, updated on the existing 5-min analytics batch; rarest hatch = rarity/species order, written only on a new personal best), physical BillboardGui board in the Plaza near the Rebirth Shrine. No detailed spec existed beyond one line in [[Sproutling Isles - Launch & Live Ops]] (Week 5) — every placement/refresh-rate/scoring choice was the agent's own design call, flagged for game-designer/owner revision. `selene`/`rojo build`/`lune bake-map` clean (1214 parts).
- [x] **(caught in review, fixed same day) roblox-engineer:** the leaderboard boards as first pushed (`21c68c3`) would never have displayed anything — `MapBuilder.luau` nested the TextLabel inside an extra "Background" Frame, but `LeaderboardService.init`'s lookup is a non-recursive `FindFirstChild` chain expecting the TextLabel as a *direct* child of the BillboardGui (the established convention elsewhere in `MapBuilder.luau`). Fixed in `6aece41`: dropped the Frame, background properties moved onto the TextLabel directly. Re-validated clean.
- [x] **roblox-engineer:** Hollow Harvest Halloween event — done 2026-09-26, `6f59f2f` on `claude/roblox-popular-game-trends-6u7sie` (built well ahead of the ~15 Oct deadline). Implements the full spec: `spookyfog` weather + `haunted` mutation, 3 limited species (Pumpkit/Gourdgeist/Hollowisp — also fixed a real pre-existing-pattern bug while adding them, `Species.rollByRarity` didn't exclude `limited` species from its rarity-share math, which could have leaked them into the Pollen Parade/Wishing Pond outside their intended acquisition paths), a UTC-clock Fog scheduler (hand-verified against `date -u` — all 4 event timestamps exact), Wisp Lantern spawn/pickup/despawn with server distance validation, the 3-kiosk Lantern Stall (reusing the Seed Shop's kiosk pattern, daily caps, Part 2 gating), the Haunted Greenhouse plot skin (recolor-only, same collision), end-of-event Moonberry→Dew conversion, a Moonberries/Fog-countdown HUD chip, and the `EventShop` funnel + `Event`/`EventShop` economy events + `EventLantern` custom event that were explicitly deferred from the earlier analytics task (since `EventService.luau` didn't exist yet). **I reviewed the full diff line-by-line before recording this** (10 files, ~430-line new `EventService.luau`) and found one real bug: the end-of-event Dew conversion formula omitted the berries-count multiplier entirely, so every player would have gotten the same flat payout (~5 min of income) regardless of whether they had 1 or 10,000 Moonberries — completely defeating the currency's purpose. Fixed directly (`b8b34b4`): added the missing `berries *` factor, confirmed against the spec's own worked example (37 berries → 12,400 Dew ⟺ ~1.12 Dew/s income). Documented interpretations to flag for game-designer/owner: Hollowisp's "Pond only" read as the literal Wishing Pond, not the Sky Well; the sign's "cobweb decal" is a color-tint placeholder (no texture asset available offline); a Robux "Summon Spooky Fog" dev product wasn't added (no product ID exists yet, owner creates it per the launch checklist). `selene`/`rojo build`/`lune bake-map` clean (1241 parts, up from 1214). **Not Studio-tested** — needs a full playtest per the test plan in the commit message (fast-forwarding time to confirm the schedule, lantern collection, stall caps, skin equip, and the now-fixed conversion math).
- [x] **live-ops-manager:** launch checklist, beta plan, week 1–8 calendar, Halloween spec, ads plan, see [[Sproutling Isles - Launch & Live Ops]]
- [ ] **live-ops-manager:** full winter (Frostbloom) spec by 21 Nov
- [x] **game-designer:** m11 pond water surface, and check the Halloween numbers — done 2026-09-26. m11 fixed (`397cc4e`, `Rim.CanCollide = false` so players wade in the pond instead of walking across it dry — see [[Sproutling Isles - QA Review]]). Halloween species/Moonberry numbers checked against the game's payback curve, all consistent (Hollowisp runs ~11% above the one existing Mythic reference point, judged fine given its rarer acquisition); earn-rate estimate stays unverified pending live measurement — see [[Sproutling Isles - Launch & Live Ops]].
- [x] **market-researcher:** verify rewarded-ads eligibility and Ads Manager pricing — done 2026-09-26, see [[Sproutling Isles - Launch & Live Ops]] section 4 caution box and section 6 note (corrections found, not just re-confirmed; sources listed there)
- [ ] **market-researcher:** monthly trend refresh (not part of the 2026-09-26 ads-verification pass; still open)

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
- [x] **Minor, fixed:** m1, m2, m3, m4, m5, m7, m8, m9, m11 (2026-09-26, `397cc4e`), m12, m13, m14, m16, m17, and m10 (toasts only).
- [ ] **Minor, open:**
  - m6: gate cooldown (owner/game-designer decision). The re-lock guard is added.
  - m10: pond payout amount (owner decision).
  - m15: Starter Pack repeat purchases (owner decision).
  - m18: HUD overlap on iPhone (check on the phone).

## Gotchas for agents
- The cloud sandbox can't run Roblox Studio. Validate with `rojo build`, `lune run tools/bake-map` and `selene src tools`.
- Rojo, Lune and Selene are installed with `cargo install` (about 5 min). See [[Environment Setup]].
- `MapBuilder.luau` must stay free of Roblox services so Lune can run it.
