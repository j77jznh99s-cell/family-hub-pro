---
tags: [project, roblox]
status: built, not yet play-tested
updated: 2026-10-03
---
# Starling Heist

Brand-new original Roblox game, built from scratch on 2026-10-03 at the owner's request
("start from the beginning and build it completely fresh… follows what's popular right now and
the rules and regulations that Roblox set"). Sproutling Isles is untouched.

- **Code:** branch `claude/starling-heist` → `roblox/starling-heist/` (repo `j77jznh99s-cell/family-hub-pro`)
- **Docs in the code folder:** `README.md` (owner checklist), `docs/DESIGN.md`, `docs/COMPLIANCE.md`, `docs/TEST_PLAN.md`
- **CI:** `.github/workflows/starling-heist.yml` (Selene lint, Lune tests, Rojo build, uploads the `.rbxlx`)
- Trend basis: [[Roblox Market Research 2026]] (2026-10-03 refresh)

## The game in one paragraph
Space creatures called Starlings drift down the Comet Lane. Buy them with Stardust; they earn
Stardust per second on pads in your hideout (bank it at the Collector). Sneak into other
players' unlocked hideouts and carry their Starlings home. Defend with a laser-door lock and the
Bubble Blaster. Go Supernova (rebirth) for +50% income each time. 8 players per server, 36
species across 8 rarities, 6 mutations, 4 weather types, Spooky Season (10 Oct – 3 Nov 2026) and
weekly Saturday drops (17, 24, 31 Oct) that switch on by date.

## Rules followed (details in docs/COMPLIANCE.md)
- No paid random items (every lane purchase is a visible, known item), no trading.
- ProcessReceipt done properly (needed for Store-tab purchases outside the game since Sep 2026).
- Nothing sold for Robux protects from thieves or changes odds.
- Server-authoritative, rate-limited remotes, carry speed check, DataStore session lock.
- No player text input; all original names and art.

## Status / verification
- **Written and self-reviewed by reading only.** The PC has no Rojo/Selene/Lune, and GitHub pushes
  fail, so CI hasn't run yet. One real bug was caught in review (positioning models before welds
  are live) and fixed before commit.
- Not run in Roblox Studio yet.

## Tasks
- [ ] **owner:** decide Starling Heist vs. Sproutling Isles priority ([[Decisions]] #22)
- [ ] **owner:** sign in to GitHub on the PC (`gh auth login --web`) so the branch pushes and CI runs
- [ ] **owner:** play-test in Studio with `docs/TEST_PLAN.md` (2–3 players) and paste any Output errors here
- [ ] **owner:** set Max Players 8, fill in the Maturity & Compliance Questionnaire, create the 3 passes + 4 products, paste ids into `src/shared/Products.luau`, mark products Listed
- [ ] **qa-tester:** once CI runs, fix any lint/test/build failures it reports
- [ ] **roblox-engineer:** after the first play-test, add sounds, pad idle animation, and Badges (needs badge ids)
- [ ] **live-ops-manager:** plan the next 4 weekly drops (Nov) and a winter event, using the `releaseAt` / `Events` pattern
- [ ] **game-designer:** tune early-game pace after the first play-test (first 10 minutes)
