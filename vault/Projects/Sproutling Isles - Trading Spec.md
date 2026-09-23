---
tags: [project, roblox, spec, trading, phase-2]
project: "[[Sproutling Isles]]"
owner_role: game-designer
build_owner: roblox-engineer
status: ready-for-build
updated: 2026-09-23
---
# Sproutling Isles: Trading Booths (Phase 2 spec)

Build-ready spec for player-to-player trading. Back to [[Sproutling Isles]]. Art for the booths is in
[[Sproutling Isles - Art Brief]] section 8. None of this is built yet, and none of it has been play-tested.

## 1. Goals
1. **Rare items worth sharing.** A Golden Huge Thornix should be something you can show off, swap and chase.
   Trading gives rares a social value on top of their Dew/s.
2. **Retention.** Traders come back to finish sets and look for specific mutations. Trading between players is
   one of the monetisation patterns that works in the genre ([[Roblox Market Research 2026]]).
3. **Safe by design.** Trades happen in one server-controlled window. Nobody can be tricked with a "give first"
   deal, items can't be duplicated, and the snatch system can't be used to launder stolen items to another account.
4. **No pay-to-win drift.** Dew can't be traded, and Robux can't buy tradeable power beyond what already exists
   (seeds from the Starter Pack are already in the economy).

## 2. Player flow
1. Player A walks to a **Trading Booth** in Bloom Plaza and steps onto one of its two flower mats. The booth sign
   changes to "Waiting for a partner...".
2. Player B steps onto the other mat. Both players get a **Trade request** popup: "Trade with {B.DisplayName}
   (@{B.Name})?" with the buttons [Start trade] and [Not now].
3. When both press Start, the **Trade window** opens for both. Each player adds up to **4 slots** from their
   Sproutlings (pads or storage) and seeds (one species per slot, with a count).
4. Any change to either offer **un-readies both players**, highlights the changed slot, and locks the Ready
   button for 2 s.
5. When both press **Ready**, a **5 s countdown** starts ("Trading in 5..."). Either player can cancel. Any change
   or cancel stops the countdown and un-readies both.
6. At 0 the server re-checks everything and **swaps atomically**. Both players see a result card, their
   Sproutlings play `Happy` on their new pads, and both profiles are saved at once.
7. Either player walking off their mat (more than 6 studs away for over 1 s), dying, resetting or leaving
   **cancels** the trade. Nothing moves.

## 3. Rules
| Rule | Value | Config key (to add) |
| --- | --- | --- |
| Slots per side | 4 (a Sproutling = 1 slot; a seed stack of one species = 1 slot) | `TradeMaxSlots = 4` |
| Seed stack size | 1 up to the number owned (not counting seeds reserved), max 99 per slot | `TradeMaxSeedStack = 99` |
| Confirm | Both press Ready, then a 5 s countdown | `TradeCountdownSeconds = 5` |
| Ready lockout after any change | 2 s | `TradeReadyLockSeconds = 2` |
| Snatched items | Trade-locked for **10 min** after a successful snatch | `TradeLockAfterSnatchSeconds = 600` |
| Minimum playtime to trade | 15 min in total (the same as the new-player shield) | `TradeMinPlaySeconds = 900` |
| Cooldown between completed trades | 10 s per player (this also respects the DataStore rate for writing the same key) | `TradeCooldownSeconds = 10` |
| Mat radius | 6 studs, with a 1 s grace period | `TradeMatRadius = 6` |
| Request timeout | 30 s to press Start | `TradeRequestTimeoutSeconds = 30` |
| Idle timeout | Window closes after 180 s with no change | `TradeIdleTimeoutSeconds = 180` |
| Booths | 3 per server (8 players max) | `TradeBoothCount = 3` |
| Uneven-trade warning | Shown when one side's Dew/s is more than 3x the other's | `TradeUnevenRatio = 3` |
| Server announcement | When a Legendary or rarer, or a Prismatic, changes hands | `TradeAnnounceMinRarity = "Legendary"` |

**What can be traded:** Sproutlings (any rarity, mutation or size) and seeds (all 13 species, including Mythic and
Secret seeds).
**What can't be traded:** Dew, game passes, Robux products, streaks, rebirths, soil plants that are still growing.

**Gifts** (one side empty) are allowed but get an extra warning (see UI). **Booths only:** there are no remote
trade requests, so nobody can be spammed with requests.

### Scam guidance ("no Dew-for-item")
- There is no Dew slot, so a deal like "pay me Dew and I'll give you the item after" can't happen inside the game.
  The booth sign and the window footer both say: **"Trades are items only. If someone asks you to give first or to
  drop Dew, it's a trick."**
- The ready state is tied to an **offer version** (see section 6). A player can never confirm an offer they
  haven't seen.
- The window shows both the DisplayName and the @username, to prevent impersonation.
- Every slot shows the full name (mutation + Huge + species), rarity, Dew/s and sell value, so "fake Golden"
  claims don't work.

## 4. UI screens and text
Style tokens are in [[Sproutling Isles - Art Brief]] section 9.

**4.1 Booth sign (BillboardGui on each booth)**
- Idle: "Trading Booth {n}", with a line below: "Step on a mat to trade"
- One mat taken: "{Name} is waiting for a partner..."
- In use: "{A} ⇄ {B} are trading"
- Footer (always): "Items only. Never give first."

**4.2 Trade request popup (both players)**
- Title: "Trade with {DisplayName}?" Subtitle: "@{Name}"
- Buttons: [Start trade] (primary) / [Not now] (secondary)
- On timeout: toast "Trade request timed out."
- If not allowed: "You can trade after 15 minutes of play. {mm:ss} to go!" / "{Name} can't trade yet."

**4.3 Trade window** (landscape-first; takes 80% of the screen on a phone)
- Top: "You" (left) | "{DisplayName} @{Name}" (right). Under each: "Offer 2/4" plus the Dew/s total.
- Two columns of 4 slot cards. A card shows a viewport of the Sproutling (or a seed icon x count), the name in
  the rarity colour, a rarity pill, "+{n} Dew/s" and "Sells for {n}". Your own cards have an [x] to remove them.
- Inventory drawer (bottom), with tabs **Sproutlings** | **Seeds**, sorted by Dew/s (highest first).
  - Trade-locked cards are greyed out with a lock icon: "Just snatched! Tradeable in {m:ss}".
  - Seeds: tap a species, then use a [-] {count} [+] stepper and [Add].
- Status line (centre):
  - "Add items or wait for {Name}."
  - "{Name} changed their offer. Check it again!" (yellow; the changed slot flashes for 3 s)
  - "You're ready. Waiting for {Name}..." / "{Name} is ready!"
- Warnings (orange, above the buttons):
  - Uneven: "This trade looks uneven ({x} vs {y} Dew/s). Double-check before you confirm."
  - Gift: "You're getting nothing back. This is a gift."
  - Room: "{Name} doesn't have room for {n} more Sproutlings." / "You don't have room. Sell or free a pad first."
- Buttons: [Ready] (primary; shows "Ready in 2..." while locked out) / [Cancel] (danger)
- Footer: "Trades are items only. If someone asks you to give first or to drop Dew, it's a trick."

**4.4 Countdown overlay:** a big "Trading in 5... 4... 3... 2... 1..." over the window, with [Cancel]. Any change
shows "Countdown stopped: the offer changed."

**4.5 Result card:** "Trade complete!" with "You got:" and a list, then "You gave:" and a list. [Nice!] closes it.

**4.6 Cancel toasts (reason given to both players)**
| Reason | Text |
| --- | --- |
| Pressed cancel | "{Name} cancelled the trade." / "Trade cancelled." |
| Walked off | "Trade cancelled: {Name} left the booth." |
| Left the game | "Trade cancelled: {Name} left the game." |
| Item gone (snatched, sold) | "Trade cancelled: an item in the offer is gone." (to the owner: "Your {item} was snatched! Trade cancelled.") |
| No room at the swap | "Trade cancelled: not enough room for the new Sproutlings." |
| Idle | "Trade closed after 3 minutes with no changes." |
| Server shutting down | "Trade cancelled: the server is restarting." |
| Rate limit / invalid input | "Trade cancelled." (logged on the server) |

**4.7 Server announcement** (for Legendary or rarer, or Prismatic): "{A} traded {B} a {Prismatic Orchidragon}!"

## 5. Server authority and anti-dupe requirements
1. **The server owns everything.** The client only sends intents. Every intent is re-validated against live
   session data. The client never sends indexes, only Sproutling **uids** (`sprout.u`) and species ids.
2. **Validate on every change and again at the swap:** both sessions exist; both are on their mats; neither is
   `carrying`; each offered uid is currently in the owner's `pads` or `storage` and isn't trade-locked; each seed
   count is between 1 and owned (minus nothing else reserved); there are no duplicate uids; slots ≤ 4.
3. **Atomic swap.** Between the final validation and the last data change there must be **no yield** (no
   `task.wait`, no DataStore or network calls, no `:WaitForChild`). Remove everything from both sides first,
   then add to both sides, then do the rendering and syncing.
4. **Capacity check before the swap.** The free space after removal (free pads + `60 - #storage`) must be at
   least the number of incoming Sproutlings, for each side. Otherwise cancel with nothing moved.
5. **uid collisions.** If an incoming uid already exists in the receiver's inventory, generate a new one with
   `State.newUid()` before inserting it.
6. **Save both profiles immediately.** After the swap, run `DataService.save(player, data, false)` for both
   players in parallel. Retry each failure up to 3 times with 2 s, 4 s and 8 s gaps. If it still fails, log a
   warning and rely on autosave and the leave-save (the in-memory state is correct and the session lock stops
   other servers from loading stale data).
7. **Only on saving servers.** Both sessions must have `persist == true`. In Studio (not saving), trading is
   allowed only if `Config.StudioTestPasses` (or a new `StudioTestTrades`) is true.
8. **Session locks.** Reuse the existing DataService lock. Trading must not release a lock early. The 90 s lock
   plus the immediate save covers server-hopping right after a trade.
9. **Leaving mid-trade.** `TradeService.onLeaving(player)` runs **first** in `onPlayerRemoving` (before
   `SnatchService.onLeaving` and the save). If a trade is open or counting down, cancel it (nothing moved). If the
   swap has already happened, the normal leave-save stores it.
10. **Shutdown.** `BindToClose` calls `TradeService.cancelAll("server")` before saving players.
11. **Busy locks while trading** (`session.trade ~= nil`):
    - Selling: pad sell and the Sell Stand are blocked if they'd touch an offered uid. Message: "That Sproutling
      is in a trade offer."
    - Planting: blocked if it would take seeds below the amount offered. Message: "Those seeds are in a trade
      offer."
    - Rebirth: blocked. Message: "Finish your trade first!"
    - Snatching *by* a trader is blocked (they're at the booth anyway). Snatching *from* a trader is **not**
      blocked, because that is part of the game's risk. If an offered item is snatched, the trade cancels.
12. **Rate limit.** At most 8 trade intents per second per player. Going over, or sending malformed input
    (wrong types, NaN, non-integer or negative counts, unknown ids), cancels the trade and logs it.
13. **Offer versioning.** Each trade has an `offerVersion` that goes up on every change. `ready` must carry the
    version the client displayed. If it doesn't match, it is ignored and the client gets a fresh snapshot.
14. **Hardening option (Phase 2.1, owner decision):** a trade ledger DataStore (`SproutlingIsles_Trades_v1`,
    with the tradeId as key) is written before the swap. It covers the small window where a hard server crash
    lands between the two profile saves. Until then, this crash window is a **known, accepted risk**. With
    immediate parallel saves it is very small, but not zero.

## 6. Data changes
**Session (in memory, `State.Session`)**
```
trade: {
  id: string,            -- HttpService GUID
  booth: number,
  side: "A" | "B",
  partner: Player,
} ?
```

**Trade object (TradeService, in memory)**
```
{ id, booth, players = {A, B}, offers = { A = {Slot}, B = {Slot} },
  ready = { A = false, B = false }, offerVersion = 0, readyLockUntil = { A = 0, B = 0 },
  countdownEndsAt = nil | serverTime, lastChangeAt, state = "request" | "open" | "countdown" | "done" | "cancelled" }
Slot = { kind = "sprout", uid = string } | { kind = "seed", id = speciesId, count = number }
```

**Saved profile (`DataService.defaultData`, reconciled for existing players)**
- `sprout.sn` (number, optional): the `os.time()` of the last successful snatch. Set in `SnatchService.finish`
  when `success`. The Sproutling is trade-locked while `os.time() - sn < TradeLockAfterSnatchSeconds`.
- `trades` (number, default 0): count of completed trades (for KPIs and future badges).
- `lastTradeAt` (number, default 0).
- `tradeLog` (array, max 20, newest first): `{ id, with = userId, t, gave = {labels}, got = {labels} }`. This is
  for support. Sproutling labels are `displayName` + uid.

**Remotes (`Net.luau`)**
- `TradeAction` (client to server): `(action: string, payload: table?)`. The actions are `respond {accept: bool}`,
  `add {kind, uid | id, count}`, `remove {slot}`, `ready {version}`, `unready`, `cancel`.
- `TradeUpdate` (server to client): a full snapshot `{ id, state, you = side, partner = {name, displayName},
  offers (resolved: display name, rarity, dew/s, sell value, mutation, size), ready, version, readyLockUntil,
  countdownEndsAt, warnings }`, or `{ state = "closed", reason }`.

## 7. Edge cases
| Case | Expected |
| --- | --- |
| A third player steps onto an occupied mat | Nothing. The sign shows it's in use. Only 2 mats per booth |
| One player stands on mats of two booths | Impossible (the mats are more than 12 studs apart); the first mat claimed wins |
| An offered pad Sproutling is snatched | Its uid is gone, so the trade cancels with the snatch message |
| A thief tries to trade the item they just snatched | Greyed out with "Tradeable in m:ss" |
| The thief is still carrying (not yet home) | Can't start a trade: "Finish your snatch first!" |
| An offered seed is planted | Blocked by the busy lock |
| A new Sproutling hatches or is caught at the pond during a trade | Allowed; it changes free capacity, which is re-checked at the swap |
| Storage is full on the receiving side | Room warning in the window; cancel at the swap if it's still full |
| Both sides are empty and both press Ready | Ready is disabled until at least one slot is filled |
| Gift (one side empty) | Allowed after the gift warning. The giver needs 15 min of playtime like everyone else |
| Same uid on both sides (extremely unlikely) | Collision check re-generates the uid for the receiver |
| Character resets or dies mid-trade | They're off the mat, so it cancels after the 1 s grace period |
| Weather or a Robux summon during a trade | No effect |
| Double-tap on Ready / a lagging client | The version check makes it idempotent |
| A player rejoins another server right after a trade | The session lock (up to 90 s) plus the immediate save prevent stale loads |
| The server shuts down during the countdown | Cancelled before saving; nothing moved |
| Studio with saving off | Trading disabled unless the test flag is on; toast "Trading needs saving on." |

## 8. Economy check (payback per tier)
Trading doesn't change seed prices or Dew/s, so the payback targets (10 s for Mossbun up to about 25 min for
Mythic) still hold for grown items. The risk is that **veterans feed new players** Mythic or Secret seeds and let
them skip tiers. Mitigations: the 15 min minimum playtime, no Dew transfers, and slot limits. We will watch the
KPI "share of Legendary+ owned by players under 1 h of playtime". If it goes over 10%, we can add a rule such as
"can only receive rarities up to 2 tiers above your best hatch" (not in v1).

## 9. KPIs (need analytics events; see the live-ops-manager task)
- The share of DAU who complete at least 1 trade per day. **Target 15 to 25%** in week 1 (unsourced; this is
  a design target).
- Completed trades per trading player per day; median time from open to completion.
- Cancel rate by reason (target: under 40% cancelled overall; under 5% "item gone").
- D1 and D7 retention of traders vs non-traders.
- Rarity mix traded; the share of Legendary+ owned by players with under 1 h of playtime (see section 8).
- Reports, scams and dupes: **target 0 confirmed dupes**. `tradeLog` supports investigations.
- Analytics events: `trade_request`, `trade_open`, `trade_ready`, `trade_complete {slotsA, slotsB, maxRarity}`,
  `trade_cancel {reason}`.

## 10. Build checklist for roblox-engineer
1. **`src/shared/Config.luau`**: add the `Trade*` keys from section 3 (plus `StudioTestTrades = false`). The
   game-designer owns these numbers; the engineer adds them in the same PR.
2. **`src/shared/MapBuilder.luau`**: `buildTradeBooths(plaza)` builds 3 booths as `Plaza/TradeBooths/Booth{n}`
   with the parts `MatA`, `MatB` (5-stud discs, 8 studs apart, facing each other) and `Sign`. Suggested centres:
   (-38, -30), (38, -30), (0, 52). **Check the clearance** against the lamps (radius 60), the Daily Gift and Sprout
   Supply stalls (±32, 44) and the spawn (0, 24). Keep it free of services so it still runs under Lune, then
   re-run `lune run tools/bake-map`.
3. **`src/server/Net.luau`**: add the `TradeAction` and `TradeUpdate` RemoteEvents.
4. **`src/server/State.luau`**: add `trade: any?` to `Session`. Add helpers: `findSprout(session, uid)` returning
   (location, key or index), `removeSprout(session, uid)`, `freeCapacity(session)`, `reservedSeeds(session, id)`.
5. **`src/server/TradeService.luau`** (new): mat watching (a 0.25 s loop), the request/open/countdown state
   machine, validation, offer versioning, the atomic swap, parallel saves with retries, announcements, `tradeLog`,
   `onLeaving`, `cancelAll`, rate limiting.
6. **`src/server/DataService.luau`**: `defaultData` gets `trades`, `lastTradeAt` and `tradeLog`. Add
   `saveWithRetry(player, data)`.
7. **`src/server/SnatchService.luau`**: on success set `sprout.sn = os.time()`. Block starting a snatch while
   `session.trade`. When a pad Sproutling is removed, notify `TradeService.onItemGone(victim, uid)`.
8. **`src/server/PlotService.luau`**: guard `onSell`, `sellStorage` and `onSoil` with the busy locks from
   section 5.11. `placeSprout` stays the single insertion path for received Sproutlings.
9. **`src/server/ProgressionService.luau`**: block rebirth while `session.trade`.
10. **`src/server/init.server.luau`**: require `TradeService` and call `init(map)`. Call `TradeService.onLeaving`
    first in `onPlayerRemoving`, and `TradeService.cancelAll("server")` first in `BindToClose`. Add `trade = nil`
    to the session table.
11. **`src/client/init.client.luau`** (or a new `src/client/TradeUI.luau`): the request popup, the trade window,
    the inventory drawer, the countdown, the result card and the toasts from section 4. Tap targets 48 px or more.
    Send `ready` with the displayed version.
12. **Analytics**: fire the events from section 9 (coordinate with live-ops-manager).
13. **Validation**: `selene src tools` and `rojo build` must pass. Then hand over to **qa-tester** with the test
    plan: two-player Studio test of a normal trade, a gift, a change during the countdown, walking off, leaving
    mid-countdown, snatching an offered item, a full-storage receiver, a snatched-item lock, a spammed remote, and
    a server shutdown during the countdown. All of this still needs a play-test in Studio.

## 11. Out of scope (later)
Cross-server trading, a trade history screen, a "trade hub" place, value guides, trading Dew or passes, the
ledger hardening (section 5.14, unless the owner wants it in v1).
