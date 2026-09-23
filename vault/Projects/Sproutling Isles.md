---
tags: [project, roblox, active]
status: build-1-untested
updated: 2026-09-23
---
# Sproutling Isles

Original Roblox **grow-and-snatch simulator**. Players plant seeds that hatch into Sproutlings
(plant-creatures that earn Dew every second), defend their greenhouse gate and snatch rivals' rare Sproutlings.

- **Design doc (source of truth for design):** https://claude.ai/code/artifact/a3a37801-bd42-4d71-a221-69ce94bf62e6
- **Code:** branch `claude/roblox-popular-game-trends-6u7sie`, folder `roblox/sproutling-isles/` (start with its `README.md`)
- **Playable file:** `roblox/sproutling-isles/build/SproutlingIsles.rbxlx` (map baked in)
- **Why this game:** [[Roblox Market Research 2026]]

## Status
| Area | State |
| --- | --- |
| Design doc | Done (8 sections + map render) |
| Core systems (plant/grow/hatch, pads, weather, snatch, shop, parade, pond, rebirth, daily, saving) | Coded, lint clean, **not play-tested in Studio** |
| Robux items | Coded; IDs are 0 until created on the Creator Dashboard |
| Art | Placeholder (Sproutlings built from primitive parts) |
| Trading, leaderboards, events, ads | Not started |

## Key numbers (full tables in the design doc and `src/shared/*.luau`)
- 13 species, Common → Secret; the Mossbun seed costs 10 Dew, pays 1 Dew/s and grows in 30 s.
- Weather every 5–8 min: Drizzle (Dewy x1.5), Thunderbloom (Charged x2), Starfall (Starry x3), Aurora (Prismatic x6); Golden x4 at 1% in any weather.
- Gate lock 60 s (90 s with a pass); snatch carry window 45 s; new-player shield 15 min.
- Rebirth 250k Dew (x4 each time), +50% Dew permanently.

## Tasks
Owners are agent roles from [[Team Roster]]; `owner` means the human.

- [ ] **owner:** play-test the `.rbxlx` in Studio (solo, then Test > 2 players) and paste any errors from the Output window
- [ ] **roblox-engineer:** fix play-test bugs, then **qa-tester** re-checks
- [ ] **owner:** decide snatching (core vs. opt-in toggle), see [[Decisions]]
- [ ] **owner:** create 5 game passes + 8 dev products; **roblox-engineer:** paste the IDs into `Products.luau`
- [ ] **game-designer:** art brief for the 13 Sproutlings + hatch animation + UI style guide
- [ ] **game-designer:** Trading Booths spec (phase 2) → **roblox-engineer** builds it
- [ ] **roblox-engineer:** leaderboards (income, rarest hatch)
- [ ] **live-ops-manager:** week 1–8 calendar details, Halloween event spec
- [ ] **live-ops-manager:** rewarded video ads + analytics events (funnel: first plant → first hatch → first purchase)
- [ ] **market-researcher:** monthly trend refresh; compare against competitors after launch

## Bugs
Full details, file:line references and the Studio test plan are in [[Sproutling Isles - QA Review]] (2026-09-23, static review; nothing has been run in Studio yet).
- [ ] **Blocker B1 (roblox-engineer):** Snatch prompts are hidden for everyone (`OnlyUser` stays 0; `PlotService.luau:453`, `claim()` never clears it). Fix this before the play-test.
- [ ] **Major M1-M6 (roblox-engineer):**
  - M1: snatch trusts the client's position.
  - M2: the Bonk prompt competes with E soil prompts.
  - M3: a snatched Sproutling survives rebirth.
  - M4: rejoining rerolls shop stock.
  - M5: paid items lost when saving is off, and Luck Boost isn't saved.
  - M6: the Studio shield blocks snatch testing.
- [ ] **Minor m1-m18:** see the review.

## Gotchas for agents
- The cloud sandbox can't run Roblox Studio. Validate with `rojo build`, `lune run tools/bake-map` and `selene src tools`.
- Rojo, Lune and Selene are installed with `cargo install` (about 5 min). See [[Environment Setup]].
- `MapBuilder.luau` must stay free of Roblox services so Lune can run it.
