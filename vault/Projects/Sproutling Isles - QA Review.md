---
tags: [qa, roblox]
project: "[[Sproutling Isles]]"
reviewed: 2026-09-23
reviewer: qa-tester
build: branch claude/roblox-popular-game-trends-6u7sie, roblox/sproutling-isles/
status: pre-play-test (static review only)
---
# Sproutling Isles - QA Review (before the first Studio play-test)

Code review of [[Sproutling Isles]] before its first Roblox Studio session.
**None of this has been run in Roblox.** Studio isn't available in the sandbox, so every finding comes from
reading and tracing the code. Things that depend on engine behaviour I couldn't check are marked **(unverified)**.

## Re-review (2026-09-26)

Re-reviewed the 2026-09-23 fix commit (`6cfd97a`, branch `claude/roblox-popular-game-trends-6u7sie`) by reading the current
code in an isolated worktree (`/tmp/sproutling-qa`, removed after review; nothing on that branch was edited). Studio is
still not available in the sandbox, so this is still a static review — nothing below was play-tested.

**Tooling: all pass, no regressions.**
- `cargo install rojo/lune/selene --locked` succeeded (Rojo 7.7.0, lune 0.10.5, selene 0.31.0).
- `selene src tools` → 0 errors, 0 warnings, 0 parse errors (same as 2026-09-23).
- `rojo build` → succeeds.
- `lune run tools/bake-map build/SproutlingIsles.rbxlx` → **1,209 parts**, same count as the original review, no error.
- A fresh `rojo build` + bake produced a working tree with **no `git diff`** against the committed `build/SproutlingIsles.rbxlx`, so the committed build is still current.

**Blocker / Majors — verdicts:**
- **B1 confirmed fixed.** `PlotService.claim()` now does `prompt:SetAttribute("OnlyUser", nil)` then `ExceptUser = id` for every snatch prompt (`src/server/PlotService.luau:397-401`); `release()` sets snatch prompts back to `OnlyUser=nil, ExceptUser=nil, Active=false` (`:431-435`), matching `init()`. Client `refreshPrompt` (`src/client/init.client.luau:342-354`) treats `only == nil` as "no restriction" and hides the prompt only for the excepted (owner) user — so every non-owner now sees "Snatch!". Logic is internally consistent.
- **M1 confirmed fixed.** Distance check at `SnatchService.luau:134-139` (`(root.Position - padPart.Position).Magnitude > prompt.MaxActivationDistance + Config.SnatchReachSlack`). Token-bucket speed check in `movedLegally` (`:221-237`) and the 0.2s poll loop (`:248-268`) fails the carry via `finish(player, false, "moved too fast")` when the budget goes negative. `Config.CarryMaxSpeedFactor=1.3`, `CarryBurstSeconds=2.5` exist in `Config.luau:33-34`. Also credits a "server teleport" grace window (gate-eject) so legitimate pushes aren't flagged — reasonable.
- **M2 confirmed fixed.** `SnatchService.luau:154-157`: `Prompts.create(root, "Bonk thief!", ..., 0, Enum.KeyCode.R)`, `bonk.GamepadKeyCode = Enum.KeyCode.ButtonY`, `bonk.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow`. Distinct key and AlwaysShow means it can no longer lose to the victim's own E prompts.
- **M3 confirmed fixed.** `ProgressionService.rebirth()` calls `SnatchService.forfeitCarriesFrom(player)` (`ProgressionService.luau:40`) before the wipe. `forfeitCarriesFrom` sets `carry.forfeited = true` for every in-flight carry targeting that victim (`SnatchService.luau:211-218`); `finish()` then skips returning the Sproutling to the (now-wiped) victim when `carry.forfeited` (`:87-91`), and a successful carry still pays the thief. No dupe path spotted.
- **M4 confirmed fixed.** `ShopService.rollStock` now also sets `session.data.stock` and `session.data.stockEpoch = ShopService.nextRestockAt()` (`ShopService.luau:48-52`). `ShopService.loadStock` (`:56-70`) reuses the saved stock only if `session.data.stockEpoch == ShopService.nextRestockAt()`, otherwise rerolls. Rejoin-to-reroll is closed.
- **M5 confirmed fixed.** `MonetizationService.processReceipt` returns `NotProcessedYet` when `not session.persist and not RunService:IsStudio()` (`MonetizationService.luau:116-119`), before granting anything — so a non-saving live session no longer grants-then-loses. `luckUntil` is saved: `session.data.luckUntil = session.luckUntil` in the `LuckBoost` handler (`:83`) and restored on join, `luckUntil = tonumber(data.luckUntil) or 0` (`init.server.luau:104`).
- **M6 confirmed fixed.** `Config.StudioDisableShield = true` (`Config.luau:80`); `init.server.luau:90-92` sets `shield = 0` when `data.shieldForfeited or (Config.StudioDisableShield and RunService:IsStudio())`. Studio sessions no longer need a manual Config edit to test snatching — **the T2 test plan's manual "temporary Config edit" step for the shield (setup step 2, `NewPlayerShieldSeconds = 0`) is no longer necessary**; noted below.

**Minor spot-checks — the brief asked for at least 5; all 14 claimed-fixed minors turned out to have clear before/after code, so all are checked below:**
- **m1 (double save on shutdown) confirmed fixed.** `onPlayerRemoving` now returns early `if not session or session.leaving` and sets `session.leaving = true` before any yield (`init.server.luau:138-142`), so `PlayerRemoving` and `BindToClose` can't both save.
- **m2 (autosave re-taking the lock) confirmed fixed.** Autosave loop skips `session.leaving` sessions (`init.server.luau:188`); `DataService.save`/`load` also added an `inFlight`/`released` per-user tracking set (`DataService.luau:31-33, 91-92, 131-134, 147-150`) that m3's fix also depends on.
- **m3 (stale data on fast rejoin) confirmed fixed.** `DataService.load` calls `waitIdle(player.UserId, 30)` before reading (`DataService.luau:91`), and `DataService.save` drops a write if `released[userId]` is already set (`:132-134`), so a fast rejoin can no longer read data older than an in-flight leave-save.
- **m4 (pad not refilled after snatch) confirmed fixed.** `finish()` calls `PlotService.refillPads(victimSession)` on a successful, non-forfeited carry (`SnatchService.luau:78-80`).
- **m5 (returned Sproutling could be deleted) confirmed fixed.** A failed-carry return now calls `PlotService.placeSprout(victimSession, carry.sprout, true)` with `force=true` when the victim's original pad is occupied (`SnatchService.luau:99`), and `placeSprout`'s `force` parameter lets storage exceed `MAX_STORAGE` instead of dropping the Sproutling (`PlotService.luau:226,234-239`).
- **m8 (shielded-pad Active check) confirmed fixed.** `PlotService.refreshSnatchable` now gates `Active` on `session.shieldUntil <= os.time()` as well as the lock (`PlotService.luau:140-143`), and the 1Hz tick calls it again when the shield actually expires (`:540-544`), so the prompt disappears/reappears without waiting for the client to hold and get rejected.
- **m9 (accidental rare sell) confirmed fixed.** Pad sell hold is `1` second for Rare-or-better, `0.4` otherwise (`PlotService.luau:112-113`, `RARE_OR_BETTER` table at `:22`). The Sell Stand now requires a second trigger within `SELL_CONFIRM_SECONDS = 5` if storage holds any Rare+ (`PlotService.sellStorage`, `:333-346`).
- **m13 (Dew sorts as text) confirmed fixed.** `leaderstats.Rebirths` (`IntValue`) is created before `Dew` (`StringValue`) specifically so Roblox's player list sorts by the numeric stat first (`init.server.luau:68-74`, comment references m13 directly).
- **m14 (stale comment) confirmed fixed.** `Products.luau:2-3` now reads "Items with id 0 still show in the in-game store, with a 'Set ID' button instead of a price, and can't be bought," matching the client behaviour.
- **m16 (pads above capacity keep earning) confirmed fixed.** `State.income` only sums pads where `tonumber(key) <= State.padCapacity(session)` (`State.luau:58-63`).
- **m17 (dupe on crash) confirmed fixed.** `saveBoth(thiefSession, victimSession)` is called right after a successful snatch (`SnatchService.luau:45-50, 81`), saving both profiles back-to-back so a crash between them is the only remaining window, and `DataService.save` serialises per player so an older write can't clobber a newer one.
- **m7 (shield returns after rejoin) confirmed fixed.** `thiefSession.data.shieldForfeited = true` is set at snatch time (`SnatchService.luau:179`) and persisted; `init.server.luau:90` checks `data.shieldForfeited` on join.
- **m12 (hatch spam during Drizzle) confirmed fixed.** `onSoil` only calls `Net.announce` for `ANNOUNCE_MUTATIONS` (starry/prismatic/golden), size ≥2, or `ANNOUNCE_RARITIES` (Legendary+) (`PlotService.luau:299-302`), so common Dewy hatches during Drizzle no longer spam the server.
- **m10 (silent no-op casts) partially fixed, as claimed (toasts only).** `PondService.cast` now toasts "The water is still settling..." during cooldown (`PondService.luau:73`) and the Sky Well toasts "...only answers players who have rebirthed" at rebirths=0 (`:115`). The payout-amount/comment mismatch ("minutes of income" vs ~15-45s, `:17-18`) is left as an explicit `TODO(game-designer/owner, QA m10)` — correctly still tracked as open, not silently dropped.

**Still open, confirmed still open (not fixed, as expected — owner/design decisions):**
- m6 gate re-lock cooldown: `PlotService.onLock` still only guards `PlotService.isLocked(session)` (`:366-367`), no cooldown added — matches "open."
- m11 pond walkable: `MapBuilder.luau:435` still bakes the Rim as a solid `CanCollide` disc (confirmed unchanged in the fresh bake) — matched "open" at the time of this re-review. **Fixed later the same day, `397cc4e`** — see the m11 entry above.
- m15 Starter Pack repeat purchases: `MonetizationService.luau:57-65` still grants 5,000 Dew on every purchase with a comment noting it's an owner decision — matches "open."
- m18 iPhone HUD overlap: unverified, needs the phone — correctly left open.

**Nothing found that was claimed fixed but isn't.** All B1/M1-M6 items and all 14 spot/full-checked minors are genuinely present and correct in the current code, with no new problems introduced. One process note, not a bug: the Studio-only manual Config edits in the test plan's Setup step 2 (`NewPlayerShieldSeconds = 0`) are now redundant given M6's automatic `StudioDisableShield`, but they're harmless if left in place. See the note added to the test plan Setup section below.

## Summary
- **Tooling passes.** `selene src tools` gives 0 errors, 0 warnings and 0 parse errors. `rojo build` succeeds. `lune run tools/bake-map` bakes 1,209 parts.
  A fresh build + bake is byte-identical to the committed `build/SproutlingIsles.rbxlx` once referent IDs are ignored, so the committed file is current.
- **Instance names are consistent.** Every name the services and the client look up (`Plots/PlotN/Soil|Pads|Gate/LockButton|SpawnPoint|Sign`, `Plaza/Seed Shop/Kiosks|RestockBoard`,
  `Sell Stand|Rebirth Shrine|Daily Gift|Sprout Supply/Anchor`, `Parade/Start|Finish|Items`, `Pond/CastSpot1-4`,
  `SkyGarden/LaunchPad|Landing|ReturnPad|SkyWell`, `Label/Text`) exists in the baked map. Plot attributes
  (`Index`, `ColorName`, `Inward`) survive the bake. There are no require cycles. `Format.number/time` behave correctly under Lune.
- **1 blocker:** nobody can ever see a Snatch prompt, so the core snatching loop can't be played.
- **6 major** issues (exploits, a rebirth bypass, a shop reroll, lost purchases, and Studio test-ability).
- **18 minor** issues.
- Items the brief asked about that traced **clean**:
  - Parade purchases can't race (the `sold` flag and the spend run with no yield in between).
  - Pond cooldown is set before the wait.
  - A thief leaving mid-carry, or the victim leaving mid-carry, returns the Sproutling *before* the save.
  - The receipt de-dupe is correct.
  - Session-lock load and save logic is sound for normal server hops.
  - The daily streak math is correct.
  - The global restock clock is correct.
  - The income tick carries fractions correctly.

## Findings

### Blocker

**B1. Snatch prompts are hidden for every player, so snatching is impossible**
- Where: `src/server/PlotService.luau:453` sets `snatch:SetAttribute("OnlyUser", 0)`. `claim()` (`PlotService.luau:358-360`) only sets `ExceptUser` and never clears `OnlyUser`. `release()` (`:384`) sets it back to 0. The client (`src/client/init.client.luau:347`) hides any prompt whose `OnlyUser` isn't the local UserId.
- What happens: `OnlyUser` stays 0 on every snatch prompt, so `prompt.Enabled = false` on every client. Thieves never see "Snatch!". An exploiter can still fire it, because the server's `Enabled` stays true.
- Fix: in `claim()`, add `prompt:SetAttribute("OnlyUser", nil)` inside the `snatchPrompts` loop. Alternatively, don't set `OnlyUser` on snatch prompts in `init()` at all: `Active=false` already hides them on empty plots.
- Owner: roblox-engineer

### Major

**M1. Snatch trusts the client's position: teleport or speed hacks give instant steals**
- Where: `src/server/SnatchService.luau:69-101` (no distance check between the thief and the pad), `:175` (success = the thief's HumanoidRootPart is inside their own plot), `:132` (slowdown is only `WalkSpeed`).
- What happens: the thief's client owns its character's physics. An exploiter can set their own WalkSpeed locally and ignore the carry slowdown, or teleport home the moment the carry starts, so the 45 s window and the bonk counter-play never matter. It's also undocumented whether the engine checks ProximityPrompt distance on the server, so don't rely on it **(unverified)**.
- Fix:
  1. In `onSnatch`, reject the trigger if `(root.Position - padPart.Position).Magnitude > MaxActivationDistance + 4`.
  2. In the 0.2 s carry loop, remember the last position and fail the carry if the thief moved faster than about `CarryWalkSpeed * 1.5` (with some slack for falling).
  3. Require a minimum carry time of about distance ÷ `CarryWalkSpeed`.
- Owner: roblox-engineer

**M2. The Bonk prompt probably loses out to the victim's own soil prompts (unverified)**
- Where: `SnatchService.luau:110` creates Bonk with key E and the default `Exclusivity` (OnePerButton). The victim's soil prompts ("Plant seed" / "Hatch!") also use E and sit right on the thief's escape route: soil is between the greenhouse and the gate.
- What happens: with OnePerButton, only one E prompt shows at a time. A victim chasing through their own soil may see "Plant seed" instead of "Bonk thief!" and plant a seed instead of bonking.
- Fix: `bonk.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow`, a distinct key (for example `Enum.KeyCode.R`), and possibly a larger `MaxActivationDistance`. Check it in the 2-player test (step T2-6).
- Owner: roblox-engineer

**M3. You can keep a Sproutling through a rebirth**
- Where: `src/server/ProgressionService.luau:28-43` only blocks rebirth if *you* are carrying. `SnatchService.luau:56-64` (`finish`) returns the Sproutling to the victim's pads whenever a carry fails.
- What happens: a friend snatches your best Sproutling, you rebirth (pads and storage are wiped), then you bonk the friend or they reset. The Sproutling comes back into your fresh post-rebirth garden. That's one free carry-over per rebirth.
- Fix: add `SnatchService.cancelCarriesFrom(victim)` and call it before the wipe (the Sproutling returns, then gets wiped). Or refuse the rebirth while any carry targets you ("Get your Sproutling back first!").
- Owner: roblox-engineer

**M4. Leaving and rejoining rerolls the shop stock**
- Where: `src/server/init.server.luau:113` calls `ShopService.rollStock` on every join. Stock lives only in the session (`ShopService.luau:39-50`) and isn't saved.
- What happens: a player can leave and rejoin to reroll for rare seeds. That skips the 5-minute restock and makes the paid **Restock Shop** product pointless.
- Fix: save `stock` and the restock epoch (`nextRestockAt`) in `data`. Reroll on join only if the epoch has changed.
- Owner: roblox-engineer

**M5. Paid items get lost when saving is off or the player leaves**
- Where: `src/server/MonetizationService.luau:117`. When `session.persist` is false, the purchase is granted and `PurchaseGranted` is returned without any save.
- What happens: in a live server, `persist=false` happens when the DataStore load failed six times. Anything bought in that session is gone on leave. Separately, **Luck Boost** (`:78-81`) only sets `session.luckUntil`, which isn't saved, so a disconnect or server hop throws away the rest of a paid 15 minutes.
- Fix: in live servers (not `RunService:IsStudio()`), return `NotProcessedYet` when `not session.persist`. Save `luckUntil` in `data` (it's absolute Unix time, so it survives hops).
- Owner: roblox-engineer

**M6. Snatching and rebirth can't be tested in Studio as-is**
- Where: `init.server.luau:87` and `Config.luau:12`. In Studio, `persist=false`, so `playSeconds` is always 0 and **every test player gets the 15-minute new-player shield**. Rebirth needs 250k Dew (`Config.luau:52`).
- What happens: in a 2-player test, the first snatch attempt just says "X is new here and shielded" (once B1 is fixed).
- Fix: add a Studio-only quick-test switch, like `StudioTestPasses`. For example `Config.StudioQuickTest = true` would set the shield to 0 and the starting Dew to 300k when `RunService:IsStudio()`. Until that exists, use the temporary Config edits in the test plan below.
- Owner: roblox-engineer

### Minor

**m1. Players are saved twice on shutdown**
- Where: `init.server.luau:132-145` and `:192-200`. On shutdown, both `PlayerRemoving` and `BindToClose` call `onPlayerRemoving`.
- What happens: `State.sessions[player]` is only cleared *after* the save yields, so each player is saved twice. The second write may hit the per-key write throttle.
- Fix: clear the session (or set `session.leaving = true`) before the first yield, and return early if it's already set.

**m2. An autosave can re-take the save lock after a player leaves**
- Where: `init.server.luau:186` with `DataService.luau:107`.
- What happens: an autosave that started just before the player left can land *after* the release save and write the lock back. The player's next join then waits about 25 s before it takes over.
- Fix: skip autosave for leaving sessions and track saves in flight per player.

**m3. A fast rejoin to the same server can load stale data**
- Where: `DataService.luau:70`. A lock owned by the same job counts as free.
- What happens: if a player rejoins *the same* server before their leave-save finishes, the load can return the previous autosave. That rolls back up to 60 s. If they were snatched from in that window, the Sproutling could exist twice. The window is small and I didn't reproduce it.
- Fix: keep a `savingUserIds` set and have `load` wait for it to clear.

**m4. Pads aren't refilled after a successful snatch**
- Where: `SnatchService.luau:48-51`.
- What happens: the victim's emptied pad isn't filled from storage (only selling calls `refillPads`), so the victim silently loses income.
- Fix: call `PlotService.refillPads(victimSession)` when the carry succeeds.

**m5. A returned Sproutling can be deleted**
- Where: `SnatchService.luau:62`. The `placeSprout` return value is ignored.
- What happens: if the victim's pads and storage (60) are full when a Sproutling comes back, it's deleted.
- Fix: let returns go past `MAX_STORAGE`.

**m6. The gate lock has no cooldown or re-lock guard**
- Where: `PlotService.luau:323-336`.
- What happens: `onLock` doesn't check `isLocked` and there's no cooldown. An owner standing at the button can re-lock the moment it opens, forever.
- This is a design call: see the decisions section below. Owner: game-designer, then roblox-engineer.

**m7. Rejoining brings back the new-player shield after a snatch**
- Where: snatching clears the shield (`SnatchService.luau:128`), but the shield is recalculated from `playSeconds` on join (`init.server.luau:87`).
- What happens: a player can snatch, rejoin, and be shielded again.
- Fix: save a `shieldForfeited` flag.

**m8. Thieves see Snatch on shielded players' pads**
- Where: `PlotService.luau:104`.
- What happens: a thief holds for 1.5 s and only then gets "shielded" (UX).
- Fix: include `victim.shieldUntil <= now` in the `Active` check, and refresh it when the shield expires.

**m9. It's easy to sell a rare Sproutling by accident**
- Where: `PlotService.luau:445` and `ShopService.luau:191`.
- What happens: Sell is a 0.4 s hold on F with no confirmation. The Sell Stand sells *all* stored Sproutlings at once, rares included.
- Fix: a longer hold (1 s) for Rare and above, and a confirmation or rarity filter at the Sell Stand.

**m10. Casting at the pond sometimes does nothing, with no message**
- Where: `PondService.luau:71-73`. Casting during the cooldown does nothing. The Sky Well does nothing when rebirths are 0 (`:110`).
- Also, the comment at `:17` says Dew pays "minutes of income", but `:83` pays about 15-45 s.
- Fix: add toasts. Fix the comment or the number (game-designer to decide which).

**m11. Players can walk across the pond — fixed 2026-09-26 (`397cc4e`)**
- Where: `MapBuilder.luau` `buildPond`. The pond Rim is a solid 98-stud disc whose top (y 0.8) sits under the water surface (y 1.05). This was checked in the baked map: Rim `CanCollide=true`, size 1.2x98x98.
- Cosmetic.
- Fix chosen (game-designer decision): `Rim.CanCollide = false`, matching `Water`. A player who goes in now sinks to `PondBed` (top y -1.5, ~2.5 studs under the surface) for a shallow wade, rather than the ring option — building an actual ring/annulus needs a part shape this codebase's `part()`/`cylinder()` helpers don't support, for a purely cosmetic bug. `selene`/`rojo build`/`lune bake-map` clean, part count unchanged (1214). **Not Studio-tested** (visual result unconfirmed).

**m12. Hatch announcements will spam everyone during Drizzle**
- Where: `PlotService.luau:277`. *Any* mutation is announced to the whole server, and Drizzle gives Dewy on 30% of hatches.
- Fix: announce only Starry, Prismatic and Golden, Huge, or Legendary and above.

**m13. The player list sorts Dew as text**
- Where: `init.server.luau:67`. Dew in leaderstats is a `StringValue`, so the player list sorts it as text ("9K" ranks above "10M").
- Cosmetic. Fix: put Rebirths first, or use a NumberValue.

**m14. Comment disagrees with the store UI**
- Where: `Products.luau:3` says items with id 0 are hidden. The client actually shows them with a "Set ID" button (`init.client.luau:292`).
- Fix: update the comment.

**m15. The one-time Starter Pack can be bought again**
- Where: `MonetizationService.luau:54-62`. The client hides it after purchase, but the server still grants 5,000 Dew on repeat purchases.
- Fine either way. Just decide whether it's intended.

**m16. Pads above capacity keep earning**
- Where: `State.luau:55`. `State.income` counts all 12 pads regardless of capacity, so if a Big Greenhouse pass is lost or refunded, pads 9-12 keep earning.
- This is an edge case.

**m17. Dupe if a server crashes or a victim's save fails after a snatch**
- Where: autosaves for the thief and the victim aren't atomic.
- What happens: if the thief's profile saves but the victim's doesn't (crash or save failure), the Sproutling exists twice.
- Fix: save both profiles right after a successful snatch.

**m18. The HUD may overlap iPhone controls (unverified)**
- Where: `init.client.luau:193-210` (hotbar: 620 px wide at the bottom, `ScrollingFrame` is Active) and `:116-121` (toast column 380x300 at the bottom right).
- What happens: on a landscape iPhone (about 844x390 pt), these likely overlap the thumbstick zone and the jump button, and the toast column can reach up to the Store/Home buttons.
- Check it on the phone (step T1-14).

Owner for m1-m5 and m7-m18: roblox-engineer. For m6: game-designer, then roblox-engineer.

## Manual Studio test plan (for the owner)

### Setup
1. Open `roblox/sproutling-isles/build/SproutlingIsles.rbxlx` in Studio and open **View > Output**.
2. Temporary Config edits in `ReplicatedStorage > Shared > Config`. **Undo all of these before publishing.**
   - `StudioTestPasses = true`
   - `NewPlayerShieldSeconds = 0` (M6) — **2026-09-26: no longer needed.** `Config.StudioDisableShield = true` now zeroes the shield automatically in Studio (`init.server.luau:90-92`), confirmed on the code. Leave `NewPlayerShieldSeconds` alone unless you want to double-check the automatic path; the manual edit is now redundant, not wrong.
   - `StartingDew = 300000` (only for the rebirth test)
3. **2026-09-26 re-review note:** B1, M2 and M6 were re-checked on the code (see the Re-review section above) and should now make the T2 snatch steps (T2-2 "Snatch!" prompt visible, T2-6 Bonk prompt via R) work as written on the first Studio play-test. This is still **unverified in Studio** — confirm it on the actual play-test.
4. If the place is published and **Enable Studio Access to API Services** is on, Studio writes to the *real* DataStore. For these tests, leave it **off**. You'll get the "Saving is off" toast, which is expected.
5. Check **Workspace > StreamingEnabled**. The build doesn't set it, and it should be **false** (unverified). If it's true, note that in your report.

### T1 - Solo (press Play)
| # | Do | Expect / look for |
| --- | --- | --- |
| 1 | Press Play and watch Output for 10 s | No red errors. Especially watch for `attempt to index nil`, `Infinite yield possible`, and anything from `PlotService`, `ShopService` or `Client`. |
| 2 | Watch where you spawn | You land briefly at the plaza, then get moved inside the **Red plot** facing the gate. The sign reads "<you>'s Garden". Toasts: "Saving is off..." and "Welcome...". |
| 3 | HUD | Top-left shows **300K Dew** (or 25) and +0 Dew/s. The hotbar shows Mossbun x2. Store and Home buttons are top-right. |
| 4 | Walk to a brown soil tile and press E | "Plant seed" is shown. Planting uses 1 Mossbun, a bud appears with a 30 s timer, and the prompt disappears while it grows. |
| 5 | Wait 30 s, then press E ("Hatch!") | A "Hatched Mossbun!" popup. A Sproutling stands on pad 1 facing the gate with its name and "+1 Dew/s". Dew goes up by 1 per second. |
| 6 | Near the pad, hold F | "Sell for N" appears, where N is about 4-9 (0.6 x 10 x size 0.8-1.5). Selling removes the Sproutling and adds Dew. **No "Snatch!" prompt should appear for you.** |
| 7 | Walk to the Seed Shop (north edge of the plaza) | Each kiosk shows name, price and "xN" or "SOLD OUT". Only one Buy prompt shows at a time. Buying lowers the count, and the restock board counts down. |
| 8 | Stand by the Pollen Parade belt (south of the plaza) | Crates move west to east and disappear at the end. Buying one gives a seed, and the crate vanishes for everyone. |
| 9 | Press **Lock gate** at the button just inside your gate | The laser curtain shows, the button turns green, and the label counts "LOCKED 90s" (with the test passes on). At 0: toast "Your gate is OPEN again" and the prompt returns. |
| 10 | Daily Gift stall (south-west of the plaza) | The first claim gives "Day 1 gift". A second claim says "Next gift in 20h 00m". |
| 11 | Wishing Pond (far north on the avenue) | A bobber appears, and 3 s later a Dew or seed toast. Casting again within 8 s does nothing (m10). Walking toward the pond's centre should now make you sink into the water (wade on the PondBed) rather than walk across it dry (m11, fixed 2026-09-26 — confirm this actually looks right in Studio). |
| 12 | Rebirth Shrine (west side of the plaza), hold 1.5 s with 300K Dew | "REBIRTH 1!". Pads and soil clear, Dew resets to the starting amount, and the shrine label shows 1M. |
| 13 | Launch pad on the avenue at z = 240 (south) | Takes you to the Sky Garden. The Sky Well works. The white pad brings you back. Before rebirth it should show "opens after your first Rebirth". |
| 14 | Store button, Home button, and on iPhone if possible | The store lists 8 products and 5 passes marked "Set ID" (or "Owned" with test passes). Home draws a green beam to your plot. On the phone: check whether the hotbar or toasts block the thumbstick or jump button (m18). |
| 15 | Wait about 2.5-4 min for the first weather | A banner and particles appear, the sky tints, and growth speeds up. Remaining timers on growing plants drop faster. |

### T2 - Two players (Test > Clients and Servers > 2 players)
| # | Do | Expect / look for |
| --- | --- | --- |
| 1 | Both clients load | Player1 gets the Red plot and Player2 the Orange plot. Each sees only their own soil, Sell and Lock prompts. |
| 2 | P1 hatches a Sproutling. P2 walks into P1's greenhouse | P2 sees **"Snatch!"** on P1's pad (hold 1.5 s). P2 sees no Sell prompt. |
| 3 | P2 snatches | The Sproutling floats above P2's head. P2 walks slower and the status line shows a 45 s countdown. P1 gets a red popup and toast. P1's pad is empty. |
| 4 | P2 walks home into the Orange plot | Success: server-wide announcement and a Sproutling on P2's pad. P2's snatch cooldown is 20 s. |
| 5 | Repeat, but P2 waits 45 s outside | "Snatch failed: too slow". The Sproutling goes back to P1's same pad. |
| 6 | Repeat, and P1 chases P2 **through P1's soil area**, then press **R** (not E — M2 moved Bonk off E, confirmed 2026-09-26) | Check that P1 sees **"Bonk thief!"** and not "Plant seed" (M2), and that R bonks even while standing on a soil tile. Bonking returns the Sproutling. |
| 7 | Repeat, and P2 resets mid-carry | "the thief fell" and the Sproutling returns. |
| 8 | P1 locks the gate while P2 is inside | P2 is pushed out to the gate. The Snatch prompts disappear, and P2 gets "That gate is locked!" if they try. |
| 9 | Mid-carry, close P2's window (the thief leaves) | The Sproutling returns to P1. Then do it the other way round: P1 leaves mid-carry, and P2 gets "owner left". Check Output for errors. |
| 10 | Stop the test | No errors in Output during shutdown (m1: two saves per player is expected until it's fixed). |

**What to send back:** every red or yellow line from Output (copy the full text with the script name and line),
plus which step numbers failed.

## Owner decisions surfaced
- **Gate lock:** should there be a cooldown after the lock expires, so re-locking isn't instant (m6)?
- **Pond Dew payout:** is it "minutes of income" or about 30 s (m10)?
- **Starter Pack:** should repeat purchases be refused, or keep granting 5,000 Dew (m15)?
