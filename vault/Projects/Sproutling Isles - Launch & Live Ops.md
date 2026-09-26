---
tags: [project, roblox, live-ops, launch, monetization, analytics]
project: "[[Sproutling Isles]]"
owner_role: live-ops-manager
status: draft
updated: 2026-09-26
---
# Sproutling Isles: Launch & Live Ops

Launch checklist, soft-launch plan, analytics spec, rewarded ads, the week 1–8 calendar (with the Halloween
event spec) and marketing for [[Sproutling Isles]]. Background: [[Roblox Market Research 2026]]. Roles: [[Team Roster]].

> [!warning] Read before acting
> - **Build 1 has not been play-tested in Studio.** Nothing here should go public until the play-test and fixes are done.
> - **Roblox menu names change often.** The click paths below were written from memory and are **unverified**. If a label differs, look for the nearest match.
> - **All KPI targets are our own goals, not sourced benchmarks.**
> - **Anything that spends or earns real money** (prices, new Robux items, ad budgets, paid creator deals) is a **proposal** and sits under [[#Waiting on the owner]].

## Contents
1. [[#1. Pre-launch checklist]]
2. [[#2. Soft-launch plan (closed beta)]]
3. [[#3. Analytics event spec]]
4. [[#4. Rewarded video ads plan]]
5. [[#5. Week 1–8 live-ops calendar]] (includes [[#Halloween event spec "Hollow Harvest"]] and [[#Winter event outline "Frostbloom Festival"]])
6. [[#6. Marketing]]
7. [[#KPI dashboard]] · [[#Fairness review of the current store]] · [[#Waiting on the owner]] · [[#Tasks created by this note]]

## Timeline at a glance (suggested, depends on the play-test)
| When | What | Retention window it serves |
| --- | --- | --- |
| Now to Thu 1 Oct | Studio play-test, fixes, Creator Dashboard setup (section 1) | none yet |
| Fri 2 Oct to Thu 8 Oct | Closed beta (section 2) | day 1 and early days 2–7 |
| **Sat 10 Oct** | Public launch = Week 1 | day 1 |
| Sat 17 Oct to Sun 1 Nov | Halloween event "Hollow Harvest" (Weeks 2–4) | days 2–7 and 8–28 of the launch cohort |
| Sat 7 Nov | The launch cohort reaches day 28. First full KPI review. | 8–28 |
| Sat 12 Dec to Sun 3 Jan | Winter event "Frostbloom Festival" (outline) | 8–28 for the October cohorts, and day 1 for holiday newcomers |

If launch slips past **Sat 24 Oct**, skip Halloween (a 1-week event is not worth the build cost) and move the Week 5 plan forward.

---

## 1. Pre-launch checklist
Tick these in order. "CH" means Creator Hub (create.roblox.com, then **Creations**, then click the Sproutling Isles experience).

### A. Before touching the dashboard
- [ ] Play-test passes: solo and **Test > Clients and Servers > 2 players** in Studio, with no red errors in Output (see [[Sproutling Isles]] tasks).
- [ ] Decide on snatching: core or opt-in (see [[Decisions]]). This changes the description, the thumbnails and the maturity answers.
- [ ] Decide **who owns the experience**: your personal account or a Roblox **Community** (group). A group makes it easier to add co-creators later and to split payouts. Hard to change after launch.
- [ ] Publish the place: in Studio, **File > Publish to Roblox As…**, create a new experience called **Sproutling Isles**, choose the owner (you or the group), then **Create**.

### B. Game Settings in Studio (Home tab > **Game Settings**)
- [ ] **Security** tab: turn on **Enable Studio Access to API Services** so saving (DataStores) works while testing in Studio. Leave **Allow HTTP Requests** off (not needed). Click **Save**.
- [ ] **Places** tab: click the **⋯** next to the start place, then **Edit**. Set **Max Players = 8** (matches `Config.PlotCount = 8`, one plot per player). Click **Save**.
  - Also check in CH: **Places > (start place) > Configure / Access**, where the field may be called **Server size**. It must be 8 there too.
- [ ] **Permissions** tab: leave the experience **Private** until section 2 or launch day.
- [ ] **Monetization** tab: leave **Paid Access** off (free to play).

### C. Basic settings in CH (**Configure > Basic Settings**; some fields may be under **Configure > Audience**)
- [ ] **Genre:** Simulation. If a subgenre is offered, pick **Incremental Simulator** (or **Tycoon** if that's the closest match).
- [ ] **Devices:** Computer ✔, Phone ✔, Tablet ✔. **Console: off** until someone tests with a gamepad. **VR: off**.
- [ ] **Language:** English. Turn on **automatic translation** if offered (it is free and helps discovery abroad).
- [ ] **Social features:** leave text chat on. Voice chat is not needed.

### D. Maturity & Compliance questionnaire (CH > **Audience > Maturity & Compliance**)
- [ ] Answer honestly. What the game has: cartoon creatures, a **steal-and-run mechanic** (snatching), a **"Bonk thief!"** prompt with no weapon, blood or damage effect, paid random-outcome items (**Luck Boost** and weather summons raise the odds of mutations), and text chat.
  - Expected result: **Minimal** or **Mild** (unverified). If any question asks about "paid random items" or loot boxes, answer **yes** for Luck Boost and the summons. Being honest protects the game from takedowns.
  - The experience must **not** end up 17+/restricted. Rewarded ads need an unrestricted game (see section 4).
- [ ] Click **Submit**. The rating appears on the experience page.

> [!note] Verified 2026-09-26 (market-researcher), via the GitHub mirror of Roblox's creator-docs (`content-maturity.md`)
> The questionnaire has **14 content categories** — Violence, Blood, Fear, Crude Humor, Unplayable Gambling, Strong Language, Romantic Themes, Alcohol, Social Hangout, Free-Form User Creation, Sensitive Issues, **Paid Random Items**, **Paid Item Trading**, and Media Sharing & AI Interaction. Two of those apply directly here: **Paid Random Items** (Luck Boost, weather summons — answer yes, as this note already says) and **Paid Item Trading** (the planned [[Sproutling Isles - Trading Spec|Trading Booths]] feature, once built, will also need a "yes" here even though it's earn-only trading, since the category is about exchanging *purchased* items, not payment). Labels run N/A → Minimal → Mild → Moderate → Restricted; rewarded ads (section 4) require the questionnaire to be **completed and approved**, not merely "not Restricted."

### E. Private servers (CH > **Monetization > Private Servers**, or **Configure > Access**)
- [ ] Turn on **Allow Private Servers**.
- [ ] Price: **proposal: 50 Robux/month** (a common low price that lets friends play without strangers snatching). *Real money → owner decides.* "Free" is also an option: it grows co-play, which counts toward discovery ranking.

### F. Game passes: 5 in total (CH > **Monetization > Passes**)
For each pass: **Create a Pass**, upload the icon, enter the name and description, click **Create Pass**. Then open the pass, go to **Sales**, turn on **Item for Sale**, enter the price and click **Save Changes**. Copy the ID (the number in the page URL, or **⋯ > Copy Asset ID**) into the table below. **roblox-engineer** pastes the IDs into `roblox/sproutling-isles/src/shared/Products.luau`.

Icon rules for every item: 512×512 PNG, one bold object on a flat or soft-gradient background, readable at 64 px, **no Robux symbol, no price and little or no text**. Keep the set consistent (same background style per category). Placeholder icons are fine for the beta; final icons come from the **game-designer** art brief.

| ✔ | Key (code) | Name | Price (R$) | Description to paste | Icon idea | Pass ID |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | `DoubleDew` | 2x Dew | 249 | Double all Dew income, forever. | A dew drop with "2x" in a leaf badge | |
| [ ] | `BigGreenhouse` | Big Greenhouse | 199 | +4 display pads for more Sproutlings. | A glass greenhouse with 4 extra glowing pads | |
| [ ] | `SturdyGate` | Sturdy Gate | 99 | Gate lock lasts 90s instead of 60s. | A gate with a thick green laser and a padlock | |
| [ ] | `LuckyRod` | Lucky Rod | 149 | Double rare catches at the Wishing Pond. | A fishing rod with a four-leaf bobber | |
| [ ] | `VIP` | VIP | 149 | Golden VIP name tag and +10% Dew. | A gold name tag with a leaf crown | |

### G. Developer products: 8 in total (CH > **Monetization > Developer Products**)
For each: **Create a Developer Product**, upload the icon, enter the name, description and price, click **Create Developer Product**, then copy the **Product ID**.

| ✔ | Key (code) | Name | Price (R$) | Description to paste | Icon idea | Product ID |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | `StarterPack` | Starter Pack | 49 | One-time: 2 Mushroomph seeds + 5,000 Dew. | A gift crate with a red-capped seed peeking out | |
| [ ] | `DewSmall` | Dew Pouch | 29 | 15 minutes of your current income (min 500 Dew). | A small drawstring pouch of dew drops | |
| [ ] | `DewLarge` | Dew Barrel | 249 | 3 hours of your current income (min 20,000 Dew). | An overflowing wooden barrel of dew | |
| [ ] | `InstantGrow` | Instant Grow | 39 | Every seed in your soil finishes growing now. | A sprout with speed lines and a clock | |
| [ ] | `LuckBoost` | Luck Boost (15 min) | 49 | Double mutation chances on your hatches. | A clover with sparkles and "x2" | |
| [ ] | `RestockNow` | Restock Shop | 25 | Instantly re-roll your seed shop stock. | A shop sign with circular refresh arrows | |
| [ ] | `SummonStarfall` | Summon Starfall | 199 | Starts a server-wide Starfall. Everyone cheers your name. | A purple night sky with falling stars | |
| [ ] | `SummonAurora` | Summon Aurora | 399 | Starts a server-wide Aurora (Prismatic x6 hatches). | Green and pink aurora ribbons over a Sproutling | |

- [ ] Send all 13 IDs in one message. **roblox-engineer** pastes them in and rebuilds, then **qa-tester** does a test purchase of each item in Studio (Studio purchases are free test purchases).
- [ ] If CH offers **regional pricing** for passes and products, decide whether to turn it on (*owner*, unverified feature).

### H. Icon, thumbnails and video (CH > **Configure > Places / Thumbnails**, or the experience's **Media** section)
- [ ] **Experience icon:** 512×512. A close-up of one cute Sproutling (Mossbun or a Prismatic hatch) mid-hatch with sparkles and a bright background. **No text.** It must read at 150 px on a phone.
- [ ] **Thumbnails:** 1920×1080, upload 3 to 5. Order:
  1. A Prismatic or Golden hatch burst with the player cheering (the "rare hatch" moment).
  2. A thief carrying a Sproutling overhead while the owner chases ("SNATCH IT!" as a short overlay is fine).
  3. A full greenhouse of mutated Sproutlings under an Aurora sky.
  4. The weather board: "AURORA! x6".
  5. A (Halloween) Spooky Fog scene, added on 17 Oct.
- [ ] If offered, turn on **thumbnail personalization / experiments** to A/B test the icon and thumbnail 1 against alternatives (unverified feature name).
- [ ] **Optional:** a 15–30 s trailer video (reuse the TikTok clips from section 6).
- [ ] Final art depends on the game-designer art pass. Beta thumbnails can be screenshots of the placeholder art.

### I. Experience description (CH > **Configure > Basic Settings > Description**)
- [ ] Paste this (edit it if snatching becomes opt-in):

```
🌱 Grow Sproutlings. Hatch rares. Snatch the best ones!

Plant seeds that hatch into Sproutlings: cute plant creatures that earn Dew for you every second.
Wait for WEATHER: Drizzle, Thunderbloom, Starfall and the rare Aurora can mutate your hatches into Dewy, Charged, Starry or PRISMATIC (x6)!

🔒 Lock your gate to protect your garden.
🏃 Sneak into rival greenhouses, grab a Sproutling and run home before they bonk you!
🎣 Fish the Wishing Pond for secret seeds.
🌈 13 species from Common to Secret, plus Golden and Huge mutations.
♻️ Rebirth for permanent Dew boosts.
🎁 Daily rewards: come back every day for bigger gifts.

Updates every Saturday! Like and favorite so you don't miss new weather and events.
#grow #garden #simulator #pets #steal #tycoon #rare #weather #mutation
```
- [ ] Keywords are in plain words in the text. Do not keyword-stuff or name other games (house rule: original only).
- [ ] Drop the emoji if they show as boxes on the page.

### J. Social links (CH > **Configure > Social Links**)
- [ ] A Roblox **Community** (group) for announcements and a group-only reward later.
- [ ] **Discord** server (13+ rules, a moderation bot, and #bugs, #trades and #clips channels). *Optional at launch. Only do it if someone can moderate it.*
- [ ] **YouTube** and **TikTok** channels for clips (section 6), if the link types are offered (unverified list).

### K. Analytics (CH > **Analytics**)
- [ ] Nothing to switch on for the built-in dashboards (**Retention, Engagement, Monetization, Acquisition**). Bookmark them.
- [ ] **Funnels, Economy and Custom events** dashboards fill in after **roblox-engineer** ships section 3. Check that data appears within about 24 h of the beta starting.
- [ ] Add the KPI table ([[#KPI dashboard]]) to a weekly review. **live-ops-manager** writes a KPI review every Monday.

### L. Launch day (Sat 10 Oct)
- [ ] CH > **Configure > Basic Settings > Privacy / Visibility: Public**.
- [ ] Post the announcement (Week 1 copy below) in the group, Discord and socials.
- [ ] Watch **Analytics > Performance / Errors** for the first 2 hours. If DataStore or server errors spike, go back to Private (the rollback plan).
- [ ] Keep `Config.StudioTestPasses = false` (**qa-tester** checks this before publishing).

---

## 2. Soft-launch plan (closed beta)

**Goal:** confirm that the first session hooks players and that they come back the next day, before paying for any ads.

| Item | Plan |
| --- | --- |
| Dates | Fri 2 Oct to Thu 8 Oct (7 days, so D1 and a partial D7 can be read) |
| Size | **40–80 unique players**. Aim for at least 30 who play on 2+ days. That is still too small for precise stats, so treat the results as directional. |
| Access | The experience stays **Private**. Testers join through a **free private server link**, or you add them as friends. Alternatively make the experience public for 7 days with no ads and no promotion (a "quiet public" soft launch) if Roblox limits private access. |
| Server mix | Run at least **3 play sessions with 6–8 players each** at set times, so snatching and weather are tested with full servers. Solo tests don't test the core social loop. |
| Recruit from | 1) Friends and family (roughly 10). 2) Small Roblox Discords that allow playtest posts, such as dev and testing communities (check their rules). 3) The DevForum "Playtesting" or "Cool Creations" style categories (verify current category names). 4) A TikTok or Short: "help test my new Roblox game". |
| Incentive (free, not Robux) | A **"Founding Gardener"** in-game badge and title, plus a cosmetic greenhouse flag once live. No gameplay power. |
| Feedback | A 5-question Google Form: 1) Most fun moment? 2) Most confusing moment? 3) Did snatching feel fair? (1–5) 4) Would you come back tomorrow? 5) Anything broken? |

### What to measure
- **D1 retention** (built-in Retention dashboard).
- **Average session length** (Engagement dashboard).
- **Onboarding funnel drop-off**: the step where the most players quit (section 3).
- **Snatch health**: snatch attempts per session, the snatch success rate, the bonk rate, and the share of victims who **quit within 2 minutes of being snatched** (new custom event `SnatchVictimLeft`).
- **Economy**: time to first Epic, time to first rebirth, and Dew sources versus sinks.
- **Store**: which items get looked at and which get bought (test purchases in private servers are real Robux, so don't expect many).
- **Crashes and errors**: the Output logs in the Errors dashboard.

### Go / no-go for public launch
| Metric | Go | Fix first (no-go) |
| --- | --- | --- |
| D1 retention | **≥ 30%** | < 30%: fix onboarding at the biggest funnel drop, then retest for 3 days |
| Avg session length | **≥ 15 min** | < 15 min: add early goals (quests / first Epic path), faster first weather |
| Onboarding: reached "first hatch" | ≥ 85% of new players | < 85%: tutorial arrows / planting prompt clarity |
| Snatch-victim quits within 2 min | ≤ 15% of victims | > 15%: extend new-player shield, cap snatches per victim, or opt-in PvP |
| Data loss / duplication bugs | 0 known | any: **hard no-go** |
| "Would come back tomorrow" (survey) | ≥ 60% yes | lower: read the free-text answers |

If D1 is between 25% and 30% and the session length is 15 min or more, the owner may choose to launch anyway without paid ads, fix things during Week 1 and re-measure. *That is the owner's decision.*

---

## 3. Analytics event spec
**Owner of build: roblox-engineer.** Uses Roblox `AnalyticsService` (server-side). The method signatures below are from memory and **must be checked against the current Creator Docs** before building (unverified):
- `AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName, customFields?)`
- `AnalyticsService:LogFunnelStepEvent(player, funnelName, funnelSessionId?, step, stepName, customFields?)`
- `AnalyticsService:LogEconomyEvent(player, flowType, currencyType, amount, endingBalance, transactionType, itemSku?, customFields?)`
- `AnalyticsService:LogCustomEvent(player, eventName, value?, customFields?)`
- Custom fields: **up to 3** keys, `Enum.AnalyticsCustomFieldKeys.CustomField01..03`. Keep values short and low-cardinality (rarity names, not UIDs).
- There are **per-server rate limits**. Never log per-second income. Batch it (see below).

### Build notes
1. Create **`src/server/AnalyticsService.luau`** (name it `Analytics.luau` to avoid clashing with the Roblox service name). It should be a thin wrapper with `Analytics.onboarding(player, stepName)`, `Analytics.funnel(...)`, `Analytics.source(...)`, `Analytics.sink(...)` and `Analytics.custom(...)`, all inside `pcall`, so a failed log never breaks gameplay.
2. Store `data.onb = { [stepName] = true }` in the save (`DataService.defaultData` + `reconcile`) so onboarding steps fire **once per player, ever**. Only fire onboarding for players whose save was new this session (DataService should return or flag "new player").
3. Add an optional `reason: string` argument to `State.addDew` and `State.spendDew` (`src/server/State.luau`). Economy logging goes there, so every source and sink is covered in one place.
4. Income ticks (`init.server.luau`, around line 167) accumulate into `session.incomeSinceLog` and log **one** Source event every 5 minutes and on leave.

### 3a. Onboarding funnel (`LogOnboardingFunnelStepEvent`), once per player
| Step | stepName | Fires in | Exact spot |
| --- | --- | --- | --- |
| 1 | `Joined` | `init.server.luau` | `onPlayerAdded`, after `DataService.load` succeeds and the save is new |
| 2 | `PlotClaimed` | `PlotService.luau` | `PlotService.claim` returns true |
| 3 | `FirstPlant` | `PlotService.luau` | `onSoil`, the plant branch (`session.data.soil[key] = {...}`) |
| 4 | `FirstHatch` | `PlotService.luau` | `onSoil`, the hatch branch, after `placeSprout` succeeds |
| 5 | `FirstSeedBought` | `ShopService.luau` | `buySeed` success (and the parade crate buy, around line 127) |
| 6 | `FirstSell` | `PlotService.luau` | `onSell` or `PlotService.sellStorage` |
| 7 | `FirstWeatherHatch` | `PlotService.luau` | hatch while `WeatherService.current()` is not nil |
| 8 | `FirstGateLock` | `PlotService.luau` | `onLock` |
| 9 | `FirstPondCast` | `PondService.luau` | `cast` |
| 10 | `FirstDailyClaim` | `ProgressionService.luau` | `claimDaily` success (this is the day-2 marker) |
| 11 | `FirstPurchase` | `MonetizationService.luau` | `processReceipt` grant, or `PromptGamePassPurchaseFinished` with purchased = true |

The brief's core funnel is **first plant → first hatch → first purchase**, which is steps 3 → 4 → 11. Roblox shows drop-off between each step.

### 3b. Recurring funnels (`LogFunnelStepEvent`)
| funnelName | Steps | Fires in | Session id |
| --- | --- | --- | --- |
| `Store` | 1 `StoreOpened` → 2 `ItemViewed` → 3 `PromptShown` → 4 `Purchased` | 1–3: the client asks the server through a new remote `Net.StoreEvent` (rate-limited, max 1/s). 4: `MonetizationService.luau` | a GUID created when the store opens |
| `Snatch` | 1 `Grabbed` → 2 `ReachedHome` (or the funnel ends) | `SnatchService.luau` `onSnatch` → `finish(success=true)` | a GUID per carry |
| `Rebirth` | 1 `CanAfford` → 2 `Rebirthed` | `ProgressionService.luau` (fire step 1 the first time Dew ≥ `rebirthCost` in each rebirth tier; check in the income tick) | `"rb" .. rebirthCount` |
| `EventShop` (Halloween+) | 1 `Opened` → 2 `Bought` | `EventService.luau` | a GUID per shop open |
| `Ad` (when ads ship) | 1 `Offered` → 2 `Clicked` → 3 `Completed` → 4 `Rewarded` | `AdService` wrapper `Ads.luau` | a GUID per offer |

### 3c. Economy events (`LogEconomyEvent`)
Currency `"Dew"` (and `"Moonberries"` during Halloween, `"Snowdrops"` in winter). Use `Enum.AnalyticsEconomyFlowType.Source/Sink`. The transaction types below are Roblox's enum names as remembered (**verify**).

| Flow | reason / itemSku | transactionType | Fires in |
| --- | --- | --- | --- |
| Source | `Income` (5-min batch) | Gameplay | `init.server.luau` income loop |
| Source | `Sell:<speciesId>` | Gameplay | `PlotService.luau` `onSell`, `sellStorage` (sku `SellStorage`) |
| Source | `Daily:<day>` | TimedReward | `ProgressionService.luau` `claimDaily` |
| Source | `Pond` | Gameplay | `PondService.luau` `cast` (Dew catches, line 84) |
| Source | `IAP:<productKey>` | IAP | `MonetizationService.luau` handlers (StarterPack, DewSmall, DewLarge) |
| Source | `AdReward:<key>` | Gameplay (or an ad-specific type if one exists) | `Ads.luau` |
| Source | `Event:<reward>` | Gameplay | `EventService.luau` |
| Sink | `Seed:<speciesId>` | Shop | `ShopService.luau` `buySeed`, parade crate |
| Sink | `Rebirth` (the Dew reset) | Gameplay | `ProgressionService.luau` `rebirth` |
| Sink | `EventShop:<itemId>` (Moonberries) | Shop | `EventService.luau` |

### 3d. Custom events (`LogCustomEvent`)
| eventName | value | CustomField01 / 02 / 03 | Fires in |
| --- | --- | --- | --- |
| `Hatch` | species order (1–13+) | rarity / mutation or "none" / weather id or "clear" | `PlotService.luau` `onSoil` hatch branch |
| `HugeHatch` | size | rarity / mutation / — | same place, when `z >= 2` |
| `SnatchStart` | 1 | rarity grabbed / victim owns Sturdy Gate ("y"/"n") / — | `SnatchService.luau` `onSnatch` |
| `SnatchResult` | seconds carried | result `success` / `bonked` / `fell` / `timeout` / `full` / rarity / — | `SnatchService.luau` `finish` |
| `SnatchVictimLeft` | seconds since stolen | rarity lost / — / — | `init.server.luau` `onPlayerRemoving` if they were snatched from in the last 120 s (store `session.lastStolenAt`) |
| `GateLock` | lock seconds | had a thief nearby? ("y"/"n") / — / — | `PlotService.luau` `onLock` |
| `WeatherStart` | 1 | weather id / `natural` or `summon` / — | `WeatherService.luau` `start` |
| `WeatherSummonHatches` | hatches server-wide during that summon | weather id / — / — | `WeatherService.luau` `stop` (count hatches while a summon is active: proves summons benefit everyone) |
| `Rebirth` | new rebirth count | — | `ProgressionService.luau` `rebirth` |
| `DailyClaim` | streak day | — | `ProgressionService.luau` `claimDaily` |
| `PondCatch` | 1 | loot type / rarity / has Lucky Rod ("y"/"n") | `PondService.luau` `cast` |
| `StorageFull` | 1 | — | `PlotService.luau` `onSoil`, the "greenhouse and storage are full" branch (a friction signal) |
| `NoSeeds` | Dew balance | — | `PlotService.luau` `onSoil`, the "no seeds" branch (a friction signal; can mean soft-lock) |
| `SessionEnd` | minutes played | rebirths / income bucket (`<10`, `<100`, `<1k`, `<10k`, `10k+`) / — | `init.server.luau` `onPlayerRemoving` |
| `EventLantern` | Moonberries gained | — | `EventService.luau` |

### Acceptance (for qa-tester)
- Each onboarding step fires exactly once for a fresh save, and never again for a returning save.
- No analytics call can error gameplay: test with `AnalyticsService` calls forced to throw.
- The Analytics dashboards show events within 24 h of the beta (this can only be checked live, not in the sandbox).

---

## 4. Rewarded video ads plan
> [!caution] Re-checked 2026-09-26 (market-researcher) — mostly confirmed, some corrections; still not confirmed in Studio
> **Method:** sandbox blocks direct fetches to roblox.com and devforum.roblox.com, so this was checked via web search plus one working path: the GitHub mirror of Roblox's own docs repo, `github.com/Roblox/creator-docs` (raw file `content/en-us/production/promotion/rewarded-video-ads.md`), which is a primary-ish source (it's the source for create.roblox.com's docs) even though the *live* create.roblox.com page couldn't be opened directly. DevForum claims below are still search-result summaries only, not opened pages.
>
> **Confirmed/refined against the creator-docs mirror (as of 2026-09-26):**
> - Eligibility is **broader than the old note said**: besides 13+/ID-verified creator, public+unrestricted experience, and ≥2,000 unique visitors/month, the docs also require **two-step verification enabled** on the account, **no free-form user creation** in the experience, and a **completed *and approved*** Maturity & Compliance Questionnaire (not just "not Restricted" — an unsubmitted or pending questionnaire blocks ads outright). Sproutling Isles has no free-form creation, so that part is fine.
> - API shape is right but one detail was wrong: the success check is **`Enum.ShowAdResult.ShowCompleted`**, not `ShowAdResult.Succeeded` as previously written. Flow per the docs: client calls `AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)` to gate the button; on click, the server calls `AdService:CreateAdRewardFromDevProductId(productId)` then `AdService:ShowRewardedVideoAdAsync(player, reward)` inside `pcall`; the client-side event checks `result == Enum.ShowAdResult.ShowCompleted`; **the actual reward grant happens through the normal `MarketplaceService.ProcessReceipt` callback** for that dev product ID (confirms the note's "verify whether ad rewards come through ProcessReceipt" — yes, they do).
> - There's a previously-unlisted method, **`AdService:RegisterAdOpportunityAsync(button, placementId)`**, for tracking how often a player had the chance to see the ad button vs. how often they actually watched — worth wiring in for the `Ad` funnel (section 3b).
> - The **`ExperienceIneligible`** report is real and still looks unresolved: a DevForum bug report dated 29 Jul 2026 describes `GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)` returning `Enum.AdAvailabilityResult.ExperienceIneligible` for a live experience the Creator Hub dashboard listed as fully eligible (all-green checklist). Related open bug reports found in the same search: `GetAdAvailabilityNowAsync()` "permanently freezes after second call," and `GetCampaignEligibilityAsync()` returning "Request failed." Read together, this looks like **general AdService flakiness on Roblox's side**, not something we can code around — budget extra buffer time in Week 5 and don't be surprised if the availability check misbehaves even once the 2k-visitor bar is cleared.
> - The **"opened to all ads-eligible creators 18 Feb 2026"** date is unchanged from before: still only a search-result summary (the DevForum announcement thread itself couldn't be opened), but two independent searches converged on the same date, so confidence is moderate, not certain.
> - **So ads will not work in the closed beta. Earliest realistic date is still Week 3–5, after 2k monthly visitors** — this conclusion holds.
>
> Sources are listed at the bottom (updated).

### Principles
- **Always opt-in.** A player taps a clearly labelled "▶ Watch ad" button. No forced or interstitial ads.
- **Rewards are about time, not power over others.** An ad never gives snatch advantages, gate time, or anything that affects another player.
- **Generous but below the paid version,** so ads don't cannibalize Robux sales (for example, a 5-min Luck Boost from an ad versus 15 min for 49 R$).
- **Never during** the first 10 minutes of a player's first session, while carrying or being snatched from, or during the first 60 s of a weather event.

### Placements
Each reward needs its **own developer product** (the ad reward is tied to a dev product ID, unverified). Create them as "Ad reward" products that are hidden from the in-game store. *Creating products is owner work; see [[#Waiting on the owner]].*

| # | Placement (where the button appears) | Reward | Paid equivalent | Per-player cap | Retention window / KPI |
| --- | --- | --- | --- | --- | --- |
| 1 | **Luck kiosk** by the soil, and the weather banner when a natural weather starts | Luck Boost **5 min** | 15 min for 49 R$ | 3 / day | day 1 and days 2–7 / hatches per session |
| 2 | **Soil tile** with more than 2 min left to grow ("Grow this now") | Instantly finish **one** tile | all tiles for 39 R$ | 5 / day | day 1 / session length |
| 3 | **Seed shop** when stock is empty or bad | Free restock | 25 R$ | 3 / day | day 1 / seeds bought |
| 4 | **Dew kiosk** | **10 min** of current income (min 200 Dew) | 15 min for 29 R$ | 2 / day | days 2–7 / time to first Epic |
| 5 | **Daily streak saver**, shown when the streak would reset (missed more than 48 h) | Keep the streak | none | 1 / 7 days | days 8–28 / D7 and play days |
| 6 | Halloween: **event shop** | +15 Moonberries | none (earn-only currency) | 2 / day | days 2–7 / event participation |

**Global caps:** at most **8 ads per player per day**, a **3-minute cooldown** between ads, and caps reset at 00:00 UTC. Store the counts in `data.ads = { day = <utc day>, n = <count>, byKey = {...}, lastAt = <time> }`.

### What to build (roblox-engineer, after eligibility is confirmed)
- `src/server/Ads.luau`: availability check, caps, the `ShowRewardedVideoAdAsync` call inside `pcall`, the grant on success only, and analytics (the `Ad` funnel plus an Economy Source).
- Ad-reward products must be handled in `MonetizationService.processReceipt` (verify whether ad rewards come through ProcessReceipt or a separate callback).
- The client button shows only when the server says an ad is available **and** the cap isn't hit. Hide it entirely otherwise (no greyed-out nagging).

### KPIs for ads
Ad opt-in rate (target ≥ 20% of DAU, our goal), completions per DAU, **payer conversion must not fall** more than 10% relative to the 2 weeks before ads (the cannibalization check), and D7 change for players who used the streak saver.

---

## 5. Week 1–8 live-ops calendar
Updates go live **Saturdays** (suggested 10:00 US Eastern, when US kids and teens are free; the owner can change this). Announcements are posted in-game (a join message and a board by spawn), in the group and on Discord.
Every week also includes: a Monday KPI review (**live-ops-manager**), bug fixes (**roblox-engineer**), and 2–3 clips (section 6).

### Overview
| Wk | Date (Sat) | Theme | Main KPI target (our goals) |
| --- | --- | --- | --- |
| 1 | 10 Oct | Launch: "First Bloom" | D1 ≥ 30%, avg session ≥ 15 min |
| 2 | 17 Oct | Halloween part 1: Spooky Fog | D2–7 play days ≥ 2.2 per new player; event participation ≥ 60% DAU |
| 3 | 24 Oct | Halloween part 2: Gourdgeist + Haunted Greenhouse | D7 ≥ 10% |
| 4 | 31 Oct | Halloween finale: Witching Hour | spend days: payers with 2+ purchase days ≥ 25% of payers |
| 5 | 7 Nov | Leaderboards + Codes + (ads if eligible) | launch-cohort D28 ≥ 4%; days 8–28 play days ≥ 3 |
| 6 | 14 Nov | "Bloom Rush" + Trading Booths beta (if built) | co-play: sessions with a friend ≥ 25% |
| 7 | 21 Nov | Harvest Festival (US Thanksgiving 26 Nov) | DAU up vs Week 6; payer conversion ≥ 2% |
| 8 | 28 Nov | Winter teaser + Frostbloom countdown | D7 of the Nov cohorts ≥ 10%; favorites +20% |

### Week 1: Launch, "First Bloom" (Sat 10 Oct)
- **Content:** the public launch with everything in build 1, plus beta fixes.
- **Event mechanics:** **Launch Weekend** (Sat 10 to Mon 12 Oct 23:59 UTC). Natural weather comes twice as often: set `Config.WeatherEverySeconds = {150, 240}` behind a date check (**roblox-engineer**: add a `Config.Boosts` table with start and end UTC times so boosts turn off by themselves). **Founding Gardener** badge for anyone who joins in Week 1 (a free badge, if within Roblox's free badge allowance).
- **Items/prices:** the store as listed in section 1 (no changes). The Starter Pack is featured on the first store open.
- **Announcement:** "🌱 Sproutling Isles is OPEN! Launch weekend: weather comes 2x as often. Hatch a Prismatic before Monday, and grab the Founding Gardener badge this week only!"
- **KPI:** D1 ≥ 30%, avg session ≥ 15 min, onboarding "first hatch" ≥ 85%, crash-free sessions ≥ 99%.

### Week 2: Halloween part 1, Spooky Fog (Sat 17 Oct)
- **Content:** "Hollow Harvest" starts (full spec below): Spooky Fog weather, the **Haunted** mutation, **Moonberries** currency, the Wisp Lantern hunt, the Lantern Stall event shop with **Pumpkit** (Epic), and a Halloween map decor pass.
- **Items/prices:** new **Summon Spooky Fog** dev product at **149 R$** (*proposal, owner decides*). No other new Robux items.
- **Announcement:** "🎃 HOLLOW HARVEST has begun! Spooky Fog rolls in every 20 minutes. Catch Wisp Lanterns for Moonberries, hatch HAUNTED Sproutlings (x3) and adopt the limited Pumpkit before 1 Nov!"
- **KPI:** event participation (collected at least 1 lantern) ≥ 60% of DAU; days 2–7 play days ≥ 2.2 per new player.

### Week 3: Halloween part 2 (Sat 24 Oct)
- **Content:** unlock **Gourdgeist** (Legendary) and the **Haunted Greenhouse** plot skin in the event shop, plus the **Hollowisp** (Mythic) in the pond during Fog. Leaderboards ship if they are ready (a separate task).
- **Items/prices:** none new (event items are Moonberries only).
- **Announcement:** "👻 Part 2! The Gourdgeist has sprouted and the Haunted Greenhouse is in the Lantern Stall. Fish the pond during Spooky Fog and a Hollowisp might bite..."
- **KPI:** D7 ≥ 10%; ≥ 30% of event players buy at least one Moonberry item.

### Week 4: Halloween finale, Witching Hour (Sat 31 Oct)
- **Content:** Sat 31 Oct to Sun 1 Nov: **Witching Hour**, when Spooky Fog comes every **10 minutes** instead of 20. The event ends **Sun 1 Nov 23:59 UTC**. Leftover Moonberries convert to Dew (1 Moonberry = 5 min of the player's income, min 100 Dew). Event species stay forever and are **never sold again in 2026**.
- **Items/prices:** none new. *Optional proposal:* a 20%-off Summon Spooky Fog for the finale weekend (*owner*).
- **Announcement:** "🕯️ WITCHING HOUR: Spooky Fog every 10 minutes all weekend! Hollow Harvest ends Sunday night. Last chance for Pumpkit, Gourdgeist and the Haunted Greenhouse!"
- **KPI:** spend days (payers with 2+ purchase days ≥ 25% of payers); peak CCU above the Week 2 peak.

### Week 5: Leaderboards, Codes and ads (Sat 7 Nov)
- **Content:** in-world **leaderboards** (income, rarest hatch) and a **Codes** box (**roblox-engineer**, new task). Codes give only free-tier rewards (Dew, common/rare seeds, a 5-min Luck Boost), never paid-only items. **Rewarded ads** go live if eligibility is confirmed (section 4). A balance patch based on 4 weeks of economy data (**game-designer** proposes, **live-ops-manager** reviews).
- **Items/prices:** the ad-reward products (hidden, *owner creates*). No price changes.
- **Announcement:** "🏆 Leaderboards are here! Are you the richest gardener on the server? Redeem code SPROUT1K for free Dew (Codes button, top left)."
- **KPI:** **first 28-day review of the launch cohort:** D28 ≥ 4%; days 8–28 play days ≥ 3; the ad opt-in rate if live.

### Week 6: Bloom Rush (Sat 14 Nov)
- **Content:** **Trading Booths beta** if the phase 2 spec and build are done. If not, **Bloom Rush weekend**: all growth ×1.5 Sat to Sun (a `Config.Boosts` entry) plus a **server hatch milestone**: when the server's players together hatch 500 Sproutlings, everyone gets a free 10-min Luck Boost (announced with a progress bar at the top of the screen). This drives co-play without PvP pressure.
- **Items/prices:** none.
- **Announcement:** "🌸 BLOOM RUSH! Everything grows 1.5x faster this weekend. Hatch 500 as a server to unlock free Luck for everyone!"
- **KPI:** co-play (sessions with a friend in the server) ≥ 25%; sessions per DAU ≥ 1.5.

### Week 7: Harvest Festival (Sat 21 Nov, US Thanksgiving Thu 26 Nov)
- **Content:** **Harvest Moon** weather (a reskin of Drizzle: growth ×2 plus a *Golden* chance of 3% instead of 1%) runs Thu 26 to Sun 29 Nov. **Gratitude gifts:** once per day a player can gift one **free** seed they own (Common–Rare only) to another player in the server, and both get +50 Dew. Gifting uses only earned items.
- **Items/prices:** *Proposal:* a **Harvest Bundle** at **99 R$** (Luck Boost 15 min + Instant Grow + a Dew Pouch, worth 117 R$ at list prices, so about 15% off; on sale Thu to Mon only). Or no bundle. *Owner decides; this is a new real-money item.*
- **Announcement:** "🍂 Harvest Festival! Harvest Moon weather Thu to Sun: 3% Golden hatches! Gift a seed to a friend and you both get Dew."
- **KPI:** payer conversion ≥ 2% of DAU over the week; gifts sent per DAU ≥ 0.3.

### Week 8: Winter teaser (Sat 28 Nov)
- **Content:** light snow on the map (visual only), a countdown board to **Frostbloom Festival (Sat 12 Dec)**, and a **"Frostbloom Seedling" teaser**: log in on 3 days before 12 Dec to earn a free Frostfawn seed on day 1 of the event (drives days 2–7 play days for the November cohorts).
- **Items/prices:** none.
- **Announcement:** "❄️ Something is growing under the snow... Frostbloom Festival starts 12 Dec. Log in 3 days before then to get a FREE Frostfawn seed!"
- **KPI:** D7 of the November cohorts ≥ 10%; favorites +20% vs Week 7.

---

### Halloween event spec "Hollow Harvest"
*Spec format: goal · player flow · rules · numbers · edge cases · UI text · KPIs · build list. The numbers are **proposals for game-designer to confirm** against payback-time rules.*

**Goal:** give the launch cohort a reason to return every day in days 2–7 and 8–28 (appointment Fog, daily lanterns, a two-part unlock), create rare-hatch and snatch moments worth clipping, and do it without new power-for-Robux.

**Dates (UTC):** Part 1 Sat 17 Oct 15:00 → Part 2 Sat 24 Oct 15:00 → Witching Hour Sat 31 Oct 00:00 → end Sun 1 Nov 23:59. All times are driven by `os.time()` against config, so no redeploy is needed to start or stop it.

**Player flow**
1. On join, a banner says "🎃 Hollow Harvest" with a countdown to the next Spooky Fog.
2. Fog arrives: the sky darkens purple, fog thickens, and **Wisp Lanterns** appear around the island.
3. The player runs around touching lanterns to earn **Moonberries**, while their seeds keep growing. Hatches during Fog can come out **Haunted** (x3).
4. The player spends Moonberries at the **Lantern Stall** (a new booth near spawn) on limited seeds and the plot skin.
5. The limited Sproutlings earn Dew like any other and **can be snatched**, which is high drama and makes good clips. Gates work as usual.

**Rules and numbers**
| Thing | Value |
| --- | --- |
| New weather `spookyfog` | name "Spooky Fog", `growthSpeed = 1.5`, `mutation = "haunted"`, `mutationChance = 0.2`, `naturalWeight = 0` (never random outside the event), sky `Color3.fromRGB(70, 40, 100)`, announce "Spooky Fog creeps in... hatches may turn HAUNTED (x3)! Catch the Wisp Lanterns!" |
| New mutation `haunted` | name "Haunted", `multiplier = 3`, color `Color3.fromRGB(150, 90, 255)` |
| Fog schedule | Every **20 min** on the UTC clock (:00, :20, :40), lasting the usual 120 s (`Config.WeatherDurationSeconds`). During Witching Hour, every **10 min**. The scheduled Fog **replaces** whatever weather is running. Natural weather keeps its normal timer in between. |
| Wisp Lanterns | **10 per Fog**, spawned at random points from a list of `LanternSpawn` parts on the **shared** island (never inside plots). Each lantern is collectible **once per player** (per-player: the server checks a set; the client hides the lantern after pickup). It gives **+5 Moonberries**. Lanterns despawn when the Fog ends. |
| Hatch bonus | +1 Moonberry per hatch during the event, +5 for a Haunted hatch |
| Daily first-Fog bonus | +20 Moonberries for the first Fog lantern each UTC day (a days 2–7 lever) |
| Expected earn rate | about 60–90 Moonberries per 20 min of active play (**estimate, unverified**; qa-tester measures it) |
| Summon Spooky Fog (Robux) | Starts a Fog right away for the whole server (like Starfall), spawns lanterns for **everyone**. Proposed 149 R$, *owner decides*. It never gives the buyer extra lanterns. |

**Limited species** (add to `Species.luau` with `stockChance = 0` and a new field `limited = "halloween2026"`; `price` is the Dew reference value used for sell value)
| id | Name | Rarity | Price (Dew ref) | growSeconds | dewPerSecond | Payback | How to get | Look (placeholder parts) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `pumpkit` | Pumpkit | Epic | 150,000 | 420 | 380 | about 395 s | Lantern Stall: **60 Moonberries**, max 5/day | orange body, dark green leaf, topper `Cap` (pumpkin lid) |
| `gourdgeist` | Gourdgeist | Legendary | 1,200,000 | 780 | 1,500 | 800 s | Lantern Stall from Part 2: **250 Moonberries**, max 2/day | pale green-white body, purple leaf, topper `Flame` (ghost wisp) |
| `hollowisp` | Hollowisp | Mythic | 10,000,000 | 1,500 | 6,000 | about 1,667 s | **Pond only, during Spooky Fog, from Part 2:** 0.5% per cast (1% with Lucky Rod, which is PvE only) | near-black body, glowing violet leaf, topper `Crystal` |

> [!note] Halloween numbers confirmed 2026-09-26 (game-designer)
> **Payback math (price ÷ dewPerSecond) checks against the base game's curve.** [[Sproutling Isles - Design Doc]]'s
> species table gives payback times of 10 s (Mossbun, Common) up to 25 min = 1,500 s (Moonpetal Wisp, Mythic), with
> the two existing Epic species at 273–400 s and the two existing Legendary species at 600–909 s. All three
> Halloween species land inside or right at the edge of their tier's existing range:
> - **Pumpkit (Epic, ~395 s)** — sits inside the existing Epic range (273–400 s). Fits cleanly.
> - **Gourdgeist (Legendary, 800 s)** — sits inside the existing Legendary range (600–909 s). Fits cleanly.
> - **Hollowisp (Mythic, ~1,667 s)** — about 11% above the only existing Mythic reference point (Moonpetal Wisp,
>   1,500 s), rather than inside a range (there's just one prior data point at this tier). Given Hollowisp's
>   acquisition is far rarer than Moonpetal Wisp's (0.5%/cast, pond-only, Part 2+, vs. Moonpetal Wisp's already-rare
>   parade/pond odds) and its price is a Dew *reference* value, not a real purchase, an above-curve payback for the
>   hardest-to-get item is defensible. **No change needed** — leaving as proposed.
> - The three stated paybacks (395 s / 800 s / 1,667 s) are themselves arithmetically correct for the listed
>   price/dewPerSecond pairs (checked: 150,000÷380, 1,200,000÷1,500, 10,000,000÷6,000).
>
> **Moonberry earn rate (60–90 per 20-min Fog) is a plausible estimate, still unverified as labelled.** At most 10
> lanterns × 5 = 50 Moonberries per Fog from lanterns alone, plus 1 (or 5 for Haunted) per hatch during that window
> — reaching 60–90 needs roughly 2–8 hatches in 20 min of active play, which is achievable given Mossbun's 30 s
> grow time. Left as an estimate for qa-tester to measure live, per the existing note — not something a design
> review alone can confirm.
> **Stall pacing looks affordable at the stated caps.** ~2 hours of active daily play (≈6 Fog cycles) at 60–90
> Moonberries each is roughly 360–540/day — enough for the 5/day Pumpkit cap (300) or a chunk of the 2/day
> Gourdgeist cap (500), and the 400-Moonberry Haunted Greenhouse skin within a day or two of dedicated play. No
> cap changes recommended.
>
> **Separately (not a number, a bug):** while checking the pond area for QA m11 (below), found and fixed a real
> walkability bug — see the [[Sproutling Isles - QA Review]] m11 entry and commit `397cc4e`.

**Plot skin: "Haunted Greenhouse"** (cosmetic only)
- Costs **400 Moonberries**, in the Lantern Stall from Part 2. It is **earn-only**, never sold for Robux.
- Look: purple-tinted glass, pumpkin lanterns on the gate posts, a cobweb decal over the sign, and a green glow on the soil. It is only a recolor or swap of named plot parts; the collision shape stays the same (so it can't hide Sproutlings or block thieves).
- Saved as `data.skins.haunted = true` and `data.skin = "haunted"`. An Equip/Unequip toggle sits in the Lantern Stall and later in a settings menu. The skin stays forever after the event.

**Data and save changes** (`DataService.defaultData` + `reconcile`)
- `data.event = { id = "halloween2026", berries = 0, lanternDay = 0, stallBuys = { [itemId] = { day, n } } }`
- `data.skins = {}`, `data.skin = ""`
- At the end: on the first join after the end time, convert `berries` to Dew (1 = 5 min of income, min 100) and notify: "Hollow Harvest is over! Your 37 Moonberries became 12,400 Dew." Then zero the berries.

**Edge cases**
- A player joins mid-Fog: they get the lanterns still standing, not the ones others took (collection is per player, so every lantern is available to them).
- A player leaves while carrying a snatched Pumpkit: existing `SnatchService.onLeaving` logic applies (it returns to the victim).
- A summon during a scheduled Fog: extends it (the existing stacking rule) and spawns **no** second lantern wave, to avoid farm exploits.
- Summoning Aurora during Fog replaces the Fog (existing rule). Lanterns despawn. That's acceptable: announce "The Aurora burned away the fog!"
- Daily purchase caps reset at 00:00 UTC.
- Storage is full when claiming a stall seed: seeds go to the seed inventory, not pads, so there is no issue.
- Clock skew across servers: the schedule uses `os.time()` UTC. Servers may differ by a few seconds, which is fine.
- After the event: event weather weight goes back to 0, the stall closes (the booth shows "See you next year!"), and existing limited seeds can still be planted.
- Exploit check: Moonberry grants happen only on the server. Lantern touch is validated by the server's distance check (≤ 12 studs from the lantern position).

**UI text**
- HUD chip: "🎃 Moonberries: 125 · Next Fog in 12:40"
- Lantern pickup: "+5 Moonberries" (floating text); first lantern of the day: "+20 daily bonus!"
- Stall: title "Lantern Stall", buttons "Adopt Pumpkit (60 🫐)", "Adopt Gourdgeist (250 🫐)", "Haunted Greenhouse (400 🫐)", cap message "Come back tomorrow for more (5/5 today)".
- Haunted hatch shout: "{name} hatched a HAUNTED {species}!"

**KPIs:** event participation ≥ 60% DAU; days 2–7 play days ≥ 2.2 for players who joined 10–24 Oct; ≥ 30% of event players buy at least one stall item; ≥ 10% own the skin by the end; `SnatchVictimLeft` rate not higher than before the event.

**Build list for roblox-engineer** (qa-tester reviews after)
1. `src/shared/Weather.luau`: add the `spookyfog` type and the `haunted` mutation.
2. `src/shared/Species.luau`: add 3 species with the `limited` field. Check that `ShopList` excludes them (`stockChance = 0` already does this).
3. New `src/shared/Events.luau`: event config (id, start, part-2, witching and end UTC times, the fog interval, lantern count and values, stall items with price and daily cap).
4. New `src/server/EventService.luau`: the Fog scheduler (calls `WeatherService.start("spookyfog")`), lantern spawn, pickup and despawn, Moonberry grants, stall purchases, end-of-event conversion, and analytics (section 3).
5. `src/server/WeatherService.luau`: expose a hook or signal for weather start and stop so EventService can spawn and despawn lanterns. Make sure `pickNatural` skips `naturalWeight = 0`.
6. `src/server/PondService.luau`: add Hollowisp to the loot table when the event is in Part 2 and Fog is active.
7. `src/server/PlotService.luau`: apply the equipped skin when a plot is claimed and when a player equips it. Grant Moonberries on hatch.
8. `src/shared/MapBuilder.luau`: add the Lantern Stall booth near spawn and 25–30 `LanternSpawn` marker parts on the shared island (keep it free of Roblox services, per the gotcha).
9. `src/client/init.client.luau`: the Fog visuals (tween `Lighting.FogEnd` or `Atmosphere.Density` while `Weather == "spookyfog"`), the HUD chip, the stall UI, lantern hide-on-pickup and the skin toggle.
10. `src/server/MonetizationService.luau` + `src/shared/Products.luau`: the `SummonSpookyFog` handler (only after the owner approves and creates the product).
11. Studio test hook: `Config.EventTimeOffset` (seconds added to `os.time()` for event checks) so qa-tester can jump to Part 2, Witching Hour and the end.

---

### Winter event outline "Frostbloom Festival"
*Spec format: goal · player flow · rules and numbers · limited species · Advent Gifts · Snowman co-op · plot skin · Robux items · data/save · edge cases · UI text · KPIs · build list — matching [[#Halloween event spec "Hollow Harvest"]]'s level of detail. The species, stall and Advent numbers below are proposals for **game-designer to confirm** against payback-time rules, the same way Hollow Harvest's were (new task added at the bottom of this note).*

**Goal:** give the launch cohort's days 8–28 window a long (23-day), escalating reason to return daily through the holidays (Advent Gifts) and to cooperate server-wide without any PvP pressure (the Snowman), while giving December newcomers — the seasonal traffic spike Roblox sees every year — the same kind of strong day-1 hook that worked for Hollow Harvest (a free Epic species, handed out immediately). Ties to: days 8–28 play days ≥ 4 for the October cohorts, and the holiday-newcomer D1 target below.

**Dates (UTC):** Part 1 Sat 12 Dec 15:00 → Part 2 Sat 19 Dec 15:00 → "New Bloom" finale Thu 31 Dec 00:00 → end Sun 3 Jan 23:59. *The 15:00 start times for Part 1 and Part 2 are an assumption (the outline only gave dates) — copied from Hollow Harvest's own 15:00 UTC convention for consistency; flag for game-designer/owner if a different hour is wanted.* All times are driven by `os.time()` against config, same as Hollow Harvest, so no redeploy is needed to start or stop it.

**Player flow**
1. On join during the event, a banner shows "❄️ Frostbloom Festival" with a countdown to the next Snowglow, plus a separate Fireworks countdown once New Bloom begins.
2. Snowglow arrives: the sky pales to icy blue-white, snow effects thicken, and **Snow Globes** appear around the shared island.
3. The player runs around touching globes to earn **Snowdrops**, while their seeds keep growing. Hatches during Snowglow can come out **Frosted** (x3.5).
4. Once per UTC day (12–24 Dec), the player claims that day's **Advent Gift** from a 13-box calendar UI — escalating from small Dew grants up to seeds, Snowdrops and Luck minutes.
5. The player spends Snowdrops at the **Snowdrop Stall** (a new booth near spawn, reusing the Lantern Stall's kiosk pattern) on the limited seeds (Frostfawn from day 1, Snowdrake from Part 2) and the Frosted Greenhouse skin.
6. Server-wide, every hatch (anyone's, while the event is active) fills the shared **Snowman** meter. Hitting a tier gives everyone online in that server a free, fair boost and visibly builds the Snowman near spawn. The meter resets at 00:00 UTC.
7. On 31 Dec, **Fireworks** weather runs every 10 minutes for 24 hours (**Sparkling** x4) as the New Bloom finale.
8. The limited Sproutlings earn Dew like any other and **can be snatched** — the same high-drama, clip-worthy moments as Hollow Harvest. Gates work as usual.
9. After the event ends (Sun 3 Jan 23:59 UTC), leftover Snowdrops convert to Dew, the Stall closes and the Snowman stops accumulating; already-hatched limited species and the skin stay forever.

**Rules and numbers**
| Thing | Value |
| --- | --- |
| New weather `snowglow` | name "Snowglow", `growthSpeed = 1.25`, `mutation = "frosted"`, `mutationChance = 0.2`, `naturalWeight = 0`, sky `Color3.fromRGB(210, 235, 255)`, announce "Snowglow drifts in... hatches may turn FROSTED (x3.5)! Grab the Snow Globes!" |
| New weather `fireworks` | name "Fireworks", `growthSpeed = 1.5`, `mutation = "sparkling"`, `mutationChance = 0.25`, `naturalWeight = 0`, sky `Color3.fromRGB(20, 20, 45)` (client also tweens in firework particle bursts — cosmetic only, a client build item), announce "Fireworks light up the sky! Hatches may turn SPARKLING (x4) — New Bloom day only!" |
| New mutation `frosted` | name "Frosted", `multiplier = 3.5`, color `Color3.fromRGB(190, 230, 255)` |
| New mutation `sparkling` | name "Sparkling", `multiplier = 4`, color `Color3.fromRGB(255, 215, 120)` |
| Snowglow schedule | Every **20 min** on the UTC clock (:00, :20, :40), 120 s duration (`Config.WeatherDurationSeconds`), from Part 1 start through the event end — **paused** during the 24 h Fireworks window (see below) and resuming its normal schedule right after. Replaces whatever weather is running, same stacking rule as Spooky Fog. |
| Fireworks schedule | Every **10 min**, **31 Dec 00:00 UTC → 31 Dec 23:59 UTC only** (24 h). For that day, Fireworks fully takes Snowglow's scheduled slots (both keep `naturalWeight = 0` outside their own windows); Snowglow resumes at 1 Jan 00:00 UTC. |
| Snow Globes | **10 per Snowglow cycle**, spawned at random `SnowGlobeSpawn` points on the shared island (never inside plots — reuses the Wisp Lantern spawn pattern and per-player, once-per-cycle collection rule). **+5 Snowdrops** each. Despawn when Snowglow ends. |
| Hatch bonus | +1 Snowdrop per hatch during Snowglow or Fireworks, **+5** for a Frosted hatch, **+8** for a Sparkling hatch (New Bloom day only — a bigger one-day bonus to make the finale feel special) |
| Daily first-Snowglow bonus | **+20 Snowdrops** for the first globe collected each UTC day (a days 2–7 and 8–28 lever, mirrors Hollow Harvest's daily first-Fog bonus) |
| Expected earn rate | about **60–90 Snowdrops per 20 min** of active play (**estimate, unverified**; qa-tester measures it live) — same derivation as Hollow Harvest: 10 globes × 5 = 50 from globes alone, plus roughly 2–8 hatches' worth of bonus in that window |
| Summon Snowglow (Robux) | Starts Snowglow right away for the whole server, spawns globes for **everyone**. Proposed **149 R$**, *owner decides*. Never gives the buyer extra globes — same fairness rule as Summon Spooky Fog. |

**Limited species** (add to `Species.luau` with `stockChance = 0` and `limited = "winter2026"`; `price` is the Dew reference value used for sell value, same convention as Hollow Harvest)
| id | Name | Rarity | Price (Dew ref) | growSeconds | dewPerSecond | Payback | How to get | Look (placeholder parts) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `frostfawn` | Frostfawn | Epic | 180,000 | 420 (7 min) | 500 | 360 s | **Free:** Advent Day 1 (Sat 12 Dec) for everyone who claims that day's gift, including Week-8 teaser qualifiers (see Advent Gifts below — this *is* the teaser payoff, not a second grant). Also in the **Snowdrop Stall** from day 1: **60 Snowdrops**, max 5/day | pale blue-white body, dark navy eyes, topper `Antler` (a small forked icy-blue crystal — new topper part, art-brief task) |
| `snowdrake` | Snowdrake | Legendary | 1,500,000 | 720 (12 min) | 1,800 | ≈ 833 s | **Snowdrop Stall from Part 2 (Sat 19 Dec):** **250 Snowdrops**, max 2/day | deep teal body with a frost-white belly stripe, glowing cyan eyes, topper `Wing` (a pair of translucent pale-blue crystal shard wings — new topper part) |
| `aurorelle` | Aurorelle | Mythic | 11,000,000 | 1,500 (25 min) | 7,000 | ≈ 1,571 s | **Pond only, during Snowglow, from event start** (not Part-2 gated, unlike Hollowisp): 0.6% per cast (1.1% with Lucky Rod, PvE only) | near-white pearlescent body, faint lavender-pink tint, glowing violet eyes, topper `Halo` (a thin rotating ring of light — new topper part) |

> [!note] Frostbloom payback math (live-ops-manager, 2026-09-26) — confirmed by game-designer 2026-09-26, see the confirmation note right below this one.
> **Payback math (price ÷ dewPerSecond), checked against [[Sproutling Isles - Design Doc]]'s base curve and against the two Hollow Harvest reference points already on the books:**
> - **Frostfawn (Epic, 180,000 ÷ 500 = 360 s)** — sits inside the base Epic range (Thornix 60,000÷220 ≈ 273 s to Bloomingo 180,000÷450 = 400 s) and next to Pumpkit's 395 s. Fits cleanly.
> - **Snowdrake (Legendary, 1,500,000 ÷ 1,800 ≈ 833.3 s)** — sits inside the base Legendary range (Sunfloof 600,000÷1,000 = 600 s to Orchidragon 2,000,000÷2,200 ≈ 909.1 s) and close to Gourdgeist's 800 s. Fits cleanly.
> - **Aurorelle (Mythic, 11,000,000 ÷ 7,000 ≈ 1,571.4 s)** — the base game has only one Mythic reference point (Moonpetal Wisp, 7,500,000÷5,000 = 1,500 s), and Hollow Harvest set a second, above-curve one (Hollowisp, ≈ 1,667 s, justified there by much rarer acquisition). Aurorelle's ≈ 1,571 s lands **between those two existing Mythic points**, which fits its acquisition: rarer than Moonpetal Wisp (pond-only during a scheduled weather, not shop/parade odds) but less rare than Hollowisp (available from event start, not gated to Part 2, and at slightly better odds — 0.6%/1.1% vs. 0.5%/1%). No change needed on this reasoning, but **not yet confirmed by game-designer** — flagged as a new task below, the same way Hollow Harvest's numbers were confirmed after the fact.
> - Arithmetic re-checked: 180,000÷500=360; 1,500,000÷1,800=833.33; 11,000,000÷7,000=1,571.43.
> **Stall pacing looks affordable at the stated caps**, by the same math Hollow Harvest used: ~2 h of active daily play (≈ 6 Snowglow cycles) at 60–90 Snowdrops each is roughly 360–540/day — enough for the 5/day Frostfawn cap (300) or most of the 2/day Snowdrake cap (500), and the 500-Snowdrop Frosted Greenhouse skin within a day or two of dedicated play. Given the event runs 23 days (much longer than Hollow Harvest's), this is if anything more comfortable, not less. No cap changes recommended, pending the same live measurement caveat as Hollow Harvest's earn-rate estimate.

> [!note] Frostbloom numbers confirmed 2026-09-26 (game-designer)
> Re-checked the arithmetic above independently (180,000÷500=360, 1,500,000÷1,800=833.33,
> 11,000,000÷7,000=1,571.43 — all correct) and the reasoning for where each species sits relative to
> the established curve and to Hollow Harvest's own precedents — agree with all three placements,
> no changes needed. Also checked two things the payback note didn't cover:
> - **The Day-1 free Frostfawn vs. the Stall selling the same species from day 1 (60 Snowdrops) is
>   intentional, not a redundancy bug:** the free grant only reaches players who actually claim
>   the Day 1 Advent gift (i.e. log in 12 Dec); the Stall listing exists for anyone who joins the
>   event late, or who was offline that specific day. Both paths coexist correctly.
> - **Snowman tier thresholds (100/250/450/700 hatches/server/day) are the right order of magnitude**
>   for 8 plots × 12 soil tiles (`Config.PlotCount = 8`, `Config.SoilTilesPerPlot = 12`, both verified
>   in code) sustaining that hatch rate over a 24 h UTC day — a server with even moderate turnover
>   easily clears Tier 1-2, and Tier 4 (700) is a meaningful stretch goal, not a guarantee. This
>   still can't be fully confirmed without live population data (a server's hatch rate depends on
>   how many different players cycle through it over 24 h, not just 8 concurrent ones) — **left
>   flagged as an estimate needing live tuning**, the same treatment Hollow Harvest's own earn-rate
>   estimate got. If early live data shows Tier 4 never clears (or clears trivially), lower (or
>   raise) all 4 thresholds proportionally rather than redesigning the curve.
> Stall pacing and payback math: no changes. Snowman thresholds: keep as proposed, watch live data
> once the event is closer to build.

**Advent Gifts** (free-tier only, no paid-only items — house rule against pay-to-win)
One gift claimable per UTC calendar day, 12–24 Dec. Missing a day loses it by default; it can be recovered **once** with the streak-saver rewarded ad (placement 5 in section 4), if ads are live by then — no other catch-up, so the calendar stays a genuine daily-return lever.
| Day | Date (UTC) | Reward |
| --- | --- | --- |
| 1 | Sat 12 Dec | **Free Frostfawn seed** (Epic) — the Week-8 teaser payoff for everyone who logs in that day |
| 2 | Sun 13 Dec | 500 Dew |
| 3 | Mon 14 Dec | 5-min Luck Boost |
| 4 | Tue 15 Dec | 1 free **Lilypadger** seed (Rare, base roster) |
| 5 | Wed 16 Dec | 20 Snowdrops |
| 6 | Thu 17 Dec | 1,500 Dew |
| 7 | Fri 18 Dec | 10-min Luck Boost |
| 8 | Sat 19 Dec (Part 2) | 40 Snowdrops |
| 9 | Sun 20 Dec | 1 free **Thornix** seed (Epic, base roster) |
| 10 | Mon 21 Dec | 5,000 Dew |
| 11 | Tue 22 Dec | 15-min Luck Boost |
| 12 | Wed 23 Dec | 60 Snowdrops |
| 13 | Thu 24 Dec | 10,000 Dew + 25 Snowdrops (capstone) |

Design note: Days 4 and 9 deliberately gift **base-roster** seeds (already Dew-purchasable, so no new power), not Snowdrake or Aurorelle — this keeps those two limited species' own earn paths (Stall, pond) meaningful instead of diluting them with free copies.

**The Snowman co-op mechanic** (new — not covered by Hollow Harvest)
- **Accumulation:** every hatch, by any player, on any server, while the event is active, adds 1 point to that **server's own** Snowman meter (a simple server-memory counter — no DataStore, same pattern as the Week 6 Bloom Rush "500 hatches" milestone).
- **Tiers and boosts** (all time/flair, never power over another player — per [[Sproutling Isles - Design Doc]] pillar 5, "Pay for time and flair, never for power over others," which applies just as much to free server rewards):
  | Tier | Threshold (hatches, that server that day) | Boost for everyone online in that server |
  | --- | --- | --- |
  | 1 — Snowball | 100 | Free 5-min Luck Boost |
  | 2 — Body | 250 | Free 10-min Luck Boost, Snowman visibly grows a body |
  | 3 — Scarf & face | 450 | A free Snowglow starts immediately in that server (a mini, no-cost weather window for everyone) |
  | 4 — Frosty (finished) | 700 | +15 Snowdrops each, Snowman is fully built (decorative only) for the rest of that UTC day |
- **Reset:** **per server, daily at 00:00 UTC.** Chosen over "for the whole event" because Roblox server instances don't reliably survive 23 days (servers recycle as players come and go), so a single persistent meter would make some servers hit Tier 4 early and others never reach it — inconsistent and unfair-feeling. A daily reset instead gives every server, every day, the same repeatable co-op goal — a stronger days 8–28 lever, and matches the ephemeral, session-scoped precedent Bloom Rush already set. Thresholds above are sized for a single 8-player server (`Config.PlotCount = 8`) in one UTC day, not a full weekend like Bloom Rush's 500.
- Not saved per player; a `SnowmanTierUp` analytics custom event (server id / tier / hatches-that-day) records each tier-up for KPI tracking, since there's no per-player field for it.
- Progress shows as a bar near the top of the screen (same UI pattern as Bloom Rush), plus the physical Snowman model near spawn/the plaza gaining accessory parts per tier.

**Plot skin: "Frosted Greenhouse"** (cosmetic only, parallel to Hollow Harvest's Haunted Greenhouse)
- Costs **500 Snowdrops**, in the Snowdrop Stall. **Earn-only**, never sold for Robux.
- Look: icy pale-blue tinted glass, a snowflake decal on the sign, icicles hanging from the gate posts, a faint white-blue glow on the soil. Only a recolor/swap of the same named plot parts as the base and Haunted skins — the collision shape stays identical, so it can't hide Sproutlings or block thieves.
- Saved as `data.skins.frosted = true` (extends the existing `data.skins` table from Hollow Harvest — no new top-level save field needed) and `data.skin = "frosted"`. Same Equip/Unequip toggle. Stays forever after the event.

**Robux items** (*proposals, real money → owner decides*)
| Item | Contents | Price | Notes |
| --- | --- | --- | --- |
| Summon Snowglow | Starts Snowglow for the whole server right now, spawns globes for everyone | **149 R$** (proposed) | Same fairness rule as Summon Spooky Fog — never extra pickups for the buyer alone |
| Winter Bundle | **Luck Boost 15 min + Instant Grow (1 tile) + Dew Pouch** — time items only, no gamepass, no exclusive cosmetic | **99 R$** (proposed) | List value of the 3 items separately is 117 R$ (49+39+29), so ≈ 15% off — same discount pattern as the Week 7 Harvest Bundle proposal, for consistency |

**Data and save changes** (`DataService.defaultData` + `reconcile`)
- `data.winterEvent = { id = "winter2026", snowdrops = 0, globeDay = 0, stallBuys = { [itemId] = { day, n } }, advent = { claimedDays = {} } }`
- `data.skins.frosted = false` (extends the existing `data.skins` table added for Hollow Harvest — do not create a second top-level skins table)
- The Snowman counter/tier state is **not saved** (server-memory only — see above).
- At the end: on the first join after the end time, convert `snowdrops` to Dew (1 = 5 min of income, min 100 Dew — same formula as Hollow Harvest's Moonberry conversion) and notify, e.g. "Frostbloom Festival is over! Your 84 Snowdrops became 25,200 Dew." Then zero `snowdrops`. Any Advent day not claimed by the event's end is lost — no late claims.

**Edge cases**
- A player joins mid-Snowglow: they get the globes still standing, not the ones others took (per-player collection, same as Wisp Lanterns).
- A snatch during the event: existing `SnatchService.onLeaving` logic applies to Frostfawn/Snowdrake/Aurorelle like any other Sproutling — the drama is intended, same rule as Hollow Harvest.
- Fireworks' 24 h window (31 Dec 00:00–23:59 UTC) fully replaces Snowglow's scheduled slots for that day only; Snowglow resumes its normal 20-min schedule from 1 Jan 00:00 UTC. Both windows sit inside the overall event window (ends 3 Jan 23:59 UTC), so there's no overlap with the event's own end.
- Summoning Snowglow during a scheduled Snowglow: extends it, no second globe wave (same anti-farm rule as Hollow Harvest's Fog summons). **Summoning Snowglow during Fireworks is a new interaction Hollow Harvest never had** (it never ran two limited weathers in the same event) — flagged for roblox-engineer to decide against the actual stacking code: most likely it should simply extend Fireworks with no globe wave, matching the existing "special weather beats a summon of a different type" precedent (Aurora over Fog), rather than replacing Fireworks with Snowglow.
- Daily Stall caps and the Advent Gift both reset/advance at 00:00 UTC. An Advent day's gift is claimable only from its calendar date onward; if missed, it's lost unless recovered once with the streak-saver ad, per the outline — no other catch-up.
- Storage full when claiming a Stall seed or an Advent seed day: seeds go to the seed inventory, not pads, so there's no issue (same as Hollow Harvest).
- Clock skew across servers: the schedule and all resets use `os.time()` UTC, same tolerance as Hollow Harvest.
- After the event: winter weather weights go back to 0, the Snowdrop Stall closes ("Frostbloom is over — see you next winter!"), the Snowman stops accumulating, and already-obtained limited seeds/skins can still be planted/worn forever, same rule as Hollow Harvest.
- Exploit check: Snowdrop grants happen only on the server; globe touch is validated by the same ≤ 12-stud server distance check as Wisp Lanterns.

**UI text**
- HUD chip: "❄️ Snowdrops: 140 · Next Snowglow in 08:15"
- Globe pickup: "+5 Snowdrops" (floating text); first globe of the day: "+20 daily bonus!"
- Advent Gift claim toast: "🎄 Day 6: +1,500 Dew! Come back tomorrow for Day 7."
- Snowman tier-up announcement (server-wide), e.g. Tier 2: "⛄ The server Snowman grew a body! Free 10-min Luck Boost for everyone online!"; Tier 4: "⛄ FROSTY IS COMPLETE! Everyone online gets +15 Snowdrops!"
- Stall: title "Snowdrop Stall", buttons "Adopt Frostfawn (60 ❄️)", "Adopt Snowdrake (250 ❄️)" (Part 2), "Frosted Greenhouse (500 ❄️)", cap message "Come back tomorrow for more (5/5 today)".
- Frosted hatch shout: "{name} hatched a FROSTED {species}!"; Sparkling hatch shout (New Bloom): "{name} hatched a SPARKLING {species}!"

**KPIs:** event participation (collected ≥ 1 globe) ≥ 65% of DAU; Advent Gift claim rate ≥ 50% of DAU claim at least 5 of the 13 days; Snowman reaches at least Tier 2 on ≥ 70% of server-days during the event (new custom event `SnowmanTierUp`); days 8–28 play days ≥ 4 for the October launch cohort (joined 10–31 Oct); holiday-newcomer D1 ≥ 30% (joined 12 Dec–3 Jan); ≥ 30% of event players buy at least one Stall item; ≥ 15% own the Frosted Greenhouse skin by event end (higher bar than Hollow Harvest's 10%, since the event is longer and the skin costs more); spend days (payers with 2+ purchase days ≥ 25% of payers) over the event; `SnatchVictimLeft` rate not higher than baseline.

**Build list for roblox-engineer** (planning only — build closer to 12 Dec; qa-tester reviews after)
> Note: this session has no shell/git access to the `claude/roblox-popular-game-trends-6u7sie` branch where the code lives (only this vault note was read/edited), so the exact shape of `Events.luau` and `EventService.luau` below is **inferred**, not verified, from this doc's own earlier wording ("a new `Events.luau` entry alongside `Events.Halloween2026`") and from the Halloween build's description in [[Sproutling Isles]]'s task log. **roblox-engineer must confirm the real file structure before coding.**
1. `src/shared/Weather.luau`: add the `snowglow` and `fireworks` weather types and the `frosted`/`sparkling` mutations.
2. `src/shared/Species.luau`: add Frostfawn/Snowdrake/Aurorelle with `limited = "winter2026"`, `stockChance = 0`. Confirm the `rollByRarity` limited-species exclusion fixed during the Hollow Harvest build generalizes to a second `limited` value and isn't hardcoded to `"halloween2026"`.
3. `src/shared/Events.luau`: add a second event config alongside the existing Halloween entry (event id, all 4 phase UTC timestamps, the Snowglow **and** Fireworks schedules/mutation config, snow-globe count/value, the 13-entry Advent Gift table, Snowman tier thresholds, Stall items/prices/caps).
4. `src/server/EventService.luau`: **this likely needs a small refactor, not just a second copy-pasted block** — reasoning: Hollow Harvest's build hard-codes a single scheduled weather and a single `data.event`/Moonberries shape; winter needs **two** scheduled weathers running in the same event (Snowglow + Fireworks), a different currency (Snowdrops) with its own save shape, and two entirely new subsystems Halloween never had (the Advent calendar and the Snowman). Recommend: (a) generalize the weather scheduler to accept a *list* of scheduled weathers per event, (b) key event save data by event id (e.g. `data.events[eventId]`) rather than a single hardcoded `data.event`, so Halloween's and winter's data don't collide, and (c) decide whether Advent/Snowman logic lives in `EventService.luau` or new sibling files (`AdventService.luau` / `SnowmanService.luau`) if the file would otherwise grow too large — a code-architecture call for roblox-engineer, not decided here.
5. `src/server/WeatherService.luau`: extend the existing start/stop hook to support two scheduled event weathers in parallel (Snowglow 20-min + Fireworks 10-min on 31 Dec only), not just the single-weather scheduler Hollow Harvest used.
6. `src/server/PondService.luau`: add Aurorelle to the loot table whenever Snowglow is active (available from event start, unlike Hollowisp's Part-2 gate).
7. `src/server/PlotService.luau`: apply/equip the Frosted skin (extends `data.skins`), grant Snowdrops on hatch, feed the Snowman counter.
8. `src/shared/MapBuilder.luau`: the Snowdrop Stall booth, 25–30 `SnowGlobeSpawn` marker parts, and a Snowman model near spawn/the plaza with swappable accessory parts for its 4 tiers (keep it free of Roblox services, per the existing gotcha).
9. `src/client/init.client.luau`: Snowglow/Fireworks visuals, the HUD chip, the Stall UI, the 13-box Advent calendar UI (claimed/claimable/locked states), the Snowman progress bar and tier-up announcement, and the skin toggle.
10. `src/server/MonetizationService.luau` + `src/shared/Products.luau`: `SummonSnowglow` and `WinterBundle` handlers (only after the owner approves and creates the products).
11. Studio test hook: extend `Config.EventTimeOffset` to also jump to Part 2 / New Bloom / the Fireworks window / the end for winter, and to fast-forward UTC-day rollovers for Advent Gift and Snowman-reset testing.
12. Analytics (section 3): add a `SnowmanTierUp` custom event and an `AdventClaim` custom/economy event, following the existing pattern — the `EventShop` funnel and `Event`/`EventShop` economy events from Hollow Harvest should be directly reusable for the Snowdrop Stall.

---

## 6. Marketing

### Sponsored ads (Roblox Ads Manager). *All tiers spend real money, so the owner decides.*
Rule: **don't pay for traffic until the public D1 is ≥ 30% and the average session is ≥ 15 min.** Paid players who churn teach the discovery algorithm that the game retains badly (it ranks on 28-day retention).

| Tier | Budget (proposal) | When | What it buys / tests |
| --- | --- | --- | --- |
| 0 | $0 | Weeks 1–2 | Organic only: clips, creators, the group. Establish a baseline. |
| 1 (test) | **$50–100** over 5–7 days | Week 2 or 3, during Halloween (seasonal creatives work better, unverified) | 3 creatives (hatch, snatch, Fog). Pick the winner by cost per play and **D1 of ad-sourced players** (Acquisition dashboard). |
| 2 (scale) | **$300–500** over 2 weeks | After Tier 1 if the ad-sourced D1 is ≥ 25% and payer conversion is ≥ 1.5% | Scale the best creative. Run on event weekends. |
| 3 (push) | **$1,000+** per event | Winter event, only if Tier 2 paid back ≥ 50% of its spend in Robux within 28 days (DevEx math, *owner check*) | A full event launch push. |

Also consider the **search/home sponsored** placements and any new-creator ad credits Roblox may offer (unverified; check Ads Manager).

> [!note] Verified 2026-09-26 (market-researcher) — Ads Manager pricing model, via search summaries and the GitHub mirror of Roblox's creator-docs (`content/en-us/production/promotion/ads-manager.md`); the live create.roblox.com/devforum pages themselves could not be opened directly, so treat this as high-but-not-first-hand confidence.
> - **Billing is not CPM/CPC/CPI.** Roblox Ads Manager uses **automated bidding**: you set a budget and a duration and Roblox's system finds the bid that gets the best performance at the lowest cost. Performance is reported as **Cost-Per-Play (CPP)** — total spend ÷ number of plays. (One older search summary quoted "$0.10–0.50 per click" and "$1–5 CPM" for "Sponsored Experiences" / "Immersive Ads," which may be a third-party estimate rather than Roblox's own billing unit — flagged as lower confidence and possibly describing a different, older product.)
> - **Budget type:** either a **Daily Budget** (max spend per day) or a **Lifetime Budget** (max spend for the whole campaign) — this matches how this plan's tiers are already structured ("$50–100 over 5–7 days" reads as a Lifetime Budget with a set duration), so **the $0 / $50–100 / $300–500 / $1,000+ tier structure is compatible with how the product actually bills**, no correction needed there.
> - **Minimum spend is very low:** the docs describe "1 ad credit" as the minimum to run a campaign at all. 1 Ad Credit ≈ 285 Robux (per a separate search result), so roughly $3 at typical Robux pricing — nowhere near a $50–100 floor. This is good news: Tier 1 ($50–100) is a deliberate choice, not a forced minimum, and a smaller test is technically possible if the owner wants to spend even less before committing to Tier 1.
> - **Payment:** credit/debit card (auto-charges at spending thresholds), Ad Credits bought by converting Robux (any account 13+), or group revenue for group-owned experiences.
> - **Placements confirmed:** a campaign is shown automatically in **both the Home page and search results** — this directly confirms the "search/home sponsored" line, no longer purely a guess. Separately, a 2026 CES announcement mentions a new **"Homepage Feature"**, described as a premium ad unit placed directly on the Roblox homepage — this looks like a newer, likely higher-tier/higher-cost placement distinct from the standard auto-placement above; not enough detail found to say if or how it fits our budget tiers.
> - **New-creator ad credits:** search turned up **no evidence of a free ad-credit program for new creators** in 2026. What exists is just the ability for any 13+ account to convert Robux into Ad Credits (i.e., access, not a freebie). Treat the plan's "new-creator ad credits" line as **not confirmed / likely does not exist** rather than merely unverified — I'd remove the assumption unless the owner finds a specific promo in the live Ads Manager UI.

### TikTok / YouTube Shorts clip ideas (9:16, 10–25 s, hook in the first second, captions on)
1. **"0.5% chance..."**: the hatch countdown, a slow-mo reveal of a **Prismatic** Sproutling, and the server shout message.
2. **Last-second bonk:** a thief carrying a Legendary at 2 s left on the timer gets bonked at the gate. Text: "he was SO close 😭".
3. **Gate locks in their face:** the thief sprints in and the laser gate snaps shut.
4. **"I summoned an Aurora for the whole server"**: everyone's hatches go Prismatic and chat goes wild. This shows summons are generous.
5. **Rags to riches:** a 20-s time-lapse from 2 Mossbuns to a full Mythic greenhouse and a rebirth.
6. **Huge Golden reveal**: a size-2.5 golden hatch dwarfing the player.
7. **Spooky Fog lantern rush** (Halloween): first-person run through the fog grabbing lanterns while a Haunted hatch pops.
8. **"Rate my greenhouse"**: viewers comment their best Sproutling, and the reply video is a follow-up.
9. **Revenge snatch:** get robbed, then snatch it back in the next clip (a two-part series drives follows).
- Capture on the laptop with the Roblox recorder or OBS. Use a private server with friends for staged moments. **Blur other players' usernames** unless they agreed.
- Cross-project idea: run gameplay recordings through [[Clip Studio]] to auto-find hatch and snatch highlights (a new task for **app-engineer**, if the owner wants it).
- Cadence: 3 clips a week at launch, 5 a week during events. Post the same clip to TikTok, Shorts and Instagram Reels.

### Creator outreach
- **Targets:** 20–30 small Roblox creators (**1k–50k followers**) who cover grow and collect simulators, on YouTube, TikTok and Twitch. Small creators are more likely to reply and their audiences convert better (unverified rule of thumb).
- **Offer (free):** early access to updates a day before release in a private server, a **creator code** that gives their viewers free Dew and seeds (Codes system, Week 5), and a shout-out on the in-game board.
- **Pitch DM (short):** "Hi {name}! I made Sproutling Isles, an original Roblox game where you grow plant creatures, wait for weather mutations and snatch rivals' rares. Our Halloween update drops 17 Oct. Want early access and a personal code for your viewers? No strings attached."
- **Paid sponsorships:** *proposal only* ($25–150 per short video from micro-creators). **Owner decides.** Creators must disclose (#ad), and don't work with creators who appear to be under 13.
- **Don't** reward players in-game for likes, favorites or follows (possible policy risk, unverified), and never promise items for spending.

---

## KPI dashboard
The weekly review (Mondays, **live-ops-manager**) reads from CH Analytics plus the section 3 events. The targets are our own goals, not sourced benchmarks.

| KPI | Window | Target | Source |
| --- | --- | --- | --- |
| D1 retention | day 1 | ≥ 30% | Retention |
| D7 retention | days 2–7 | ≥ 10% | Retention |
| D28 retention | days 8–28 | ≥ 4% | Retention |
| Play days per new player (first 7 days) | days 2–7 | ≥ 2.2 | Retention / Engagement |
| Avg session length | day 1 | ≥ 15 min | Engagement |
| Onboarding: first hatch | day 1 | ≥ 85% | Funnels |
| Onboarding: first purchase | day 1 → 28 | ≥ 2% of new players | Funnels |
| Payer conversion (daily) | all | ≥ 2% | Monetization |
| ARPDAU | all | track the trend; no target until 2 weeks of data | Monetization |
| Spend days per payer | days 8–28 | ≥ 1.5 | Monetization |
| Co-play share | all | ≥ 25% | Engagement |
| Snatch-victim 2-min quit rate | day 1 | ≤ 15% | Custom `SnatchVictimLeft` |

## Fairness review of the current store
- **Fair (no effect on other players):** 2x Dew, Big Greenhouse, VIP (+10%), Dew Pouch/Barrel, Instant Grow, Restock, Starter Pack, and Lucky Rod (pond is PvE). These pay for time and flair, which fits the pillar.
- **Fair and social:** the weather summons help **everyone** in the server. Track `WeatherSummonHatches` to prove it.
- **Watch:** **Luck Boost** is paid odds on random outcomes. It's fine for fairness because it doesn't affect others, but answer honestly in the maturity questionnaire (paid random items).
- **Watch:** **Sturdy Gate** (90 s vs 60 s lock) is a **defensive** edge in PvP. It doesn't help its owner take anything from others, so I rate it acceptable. If the beta shows thieves quitting because paid gates are "always locked", cap the gap (for example, 75 s) or make it a cooldown reduction instead. *That would be a price/perk change, so the owner decides.*
- **Bug-risk note:** the description says "One-time" for the Starter Pack, but the code grants 5,000 Dew on **every** purchase (the seeds only once). The client should hide the product once `StarterBought` is set. **qa-tester** should verify this (untested).

## Waiting on the owner
- [ ] Create the 5 passes and 8 developer products with the names, descriptions and prices in section 1 F–G, and send the 13 IDs.
- [ ] Private server price: **50 R$/month** or free?
- [ ] Experience owner: personal account or a group (Community)?
- [ ] Regional pricing on or off (if offered)?
- [ ] New Robux item **Summon Spooky Fog, 149 R$** (Halloween). Also a finale 20% discount: yes or no?
- [ ] **Harvest Bundle 99 R$** (Week 7): yes, no, or a different price?
- [ ] Winter proposals: **Summon Snowglow 149 R$**, **Winter Bundle**.
- [ ] Rewarded ads: approve the plan in section 4, then create the hidden ad-reward dev products once eligible.
- [ ] Sponsored ads budget: Tier 1 **$50–100** test in Week 2–3? (No spend before the go-thresholds are met.)
- [ ] Paid creator sponsorships ($25–150 per video): yes or no?
- [ ] Launch date **Sat 10 Oct** (closed beta 2–8 Oct): OK?
- [ ] Sturdy Gate: keep as is, and revisit after the beta data?

## Tasks created by this note
- [ ] **roblox-engineer:** analytics wrapper + all events in section 3 (a prerequisite for the beta)
- [ ] **roblox-engineer:** `Config.Boosts` time-boxed boosts (launch weekend, Bloom Rush) + `Config.EventTimeOffset` test hook
- [x] **roblox-engineer:** Hollow Harvest build list (section 5) — done 2026-09-26, well ahead of the 15 Oct deadline. Full build (weather/mutation, 3 species, Fog scheduler, lanterns, Lantern Stall, plot skin, end-of-event conversion, HUD, analytics) — see [[Sproutling Isles]] for detail and the one bug found and fixed in review (`6f59f2f` + `b8b34b4`). **Not Studio-tested.**
- [ ] **owner:** create a "Summon Spooky Fog" dev product (proposed 149 R$) and give roblox-engineer the ID to wire in — not built yet since the ID doesn't exist.
- [ ] **owner:** Studio playtest of the Hollow Harvest event before 17 Oct (not possible from the sandbox) — fast-forward time to confirm the Fog schedule, lantern collection/despawn, stall purchases and caps, the Haunted Greenhouse skin equip, and the end-of-event Moonberry conversion (now fixed to scale with balance).
- [ ] **roblox-engineer:** Codes system (free-tier rewards only) for Week 5
- [ ] **roblox-engineer:** rewarded ads `Ads.luau`, after the owner approves and eligibility is confirmed
- [ ] **roblox-engineer:** Founding Gardener badge + Week 8 teaser login tracker
- [x] **game-designer:** confirm the Halloween numbers against the payback rules — done 2026-09-26, see the note above the limited-species table. All 3 species check out against the base game's payback curve (Hollowisp runs ~11% above the single existing Mythic reference point, judged defensible given its much rarer acquisition). Stall caps look affordable at the earn-rate estimate. Earn rate itself stays unverified (needs live measurement, as already flagged).
- [x] **game-designer:** confirm the Frostbloom Festival numbers against the payback rules — done 2026-09-26, see the confirmation note above. All 3 species' payback times confirmed correct and well-placed; Snowman tier thresholds are the right order of magnitude for `Config.PlotCount = 8` × `SoilTilesPerPlot = 12` but left flagged for live tuning, same treatment as the earn-rate estimates.
- [ ] **game-designer:** icons for the 13 store items + experience icon and thumbnails (part of the art brief)
- [ ] **qa-tester:** event test plan using `EventTimeOffset` (start, Part 2, Witching Hour, end conversion), Starter Pack repeat purchase check, analytics once-only check
- [x] **live-ops-manager:** full Frostbloom Festival spec — done 2026-09-26, well ahead of the 21 Nov deadline. Full spec in [[#Winter event outline "Frostbloom Festival"]]: goal, 9-step player flow, weather/currency rules table, 3 limited species with computed payback numbers (Frostfawn ≈360s, Snowdrake ≈833s, Aurorelle ≈1,571s — all land inside or between the existing tier ranges; game-designer confirmation still needed, new task below), the 13-day Advent Gift schedule, a fully-designed new "Snowman" server co-op mechanic (per-server, resets daily at 00:00 UTC), the Frosted Greenhouse skin, Robux proposals (Summon Snowglow 149 R$, a Winter Bundle spelled out at 99 R$ for time items only), save shape, edge cases, UI text, KPIs and a 12-item build list for roblox-engineer (flags that `EventService.luau` likely needs a small refactor to support 2 events, not just a copy-pasted block — reasoning given). Live-ops-manager could not access the code branch this session (no shell/git tool, code lives on `claude/roblox-popular-game-trends-6u7sie`), so the exact `Events.luau`/`EventService.luau` shape is flagged as inferred, not verified. Weekly KPI reviews from launch: still open, starts once the game is live.
- [x] **market-researcher:** check current Roblox ads eligibility, the Ads Manager pricing model and the maturity questionnaire wording before launch — done 2026-09-26. Rewarded-ads eligibility bar confirmed plus 3 new criteria found (two-step verification, no free-form user creation, questionnaire must be *approved* not just submitted); one API detail corrected (`ShowAdResult.ShowCompleted`, not `Succeeded`); `ExperienceIneligible` confirmed as a real, apparently still-open bug. Ads Manager confirmed as auto-bid/CPP billing (not CPM/CPC/CPI), tiers in this note are compatible with Lifetime Budget billing, minimum spend is far below Tier 1, "new-creator ad credits" found no evidence and should be treated as not confirmed. Maturity questionnaire: 14 categories confirmed, including Paid Item Trading (relevant to the Trading Booths feature, not just Luck Boost). See section 4 caution box, section 6 note and section 1D note for detail and sources. The 18 Feb 2026 "opened to all eligible creators" date is still only a search-summary claim (devforum.roblox.com is blocked in-sandbox), not independently verified from the primary announcement page.
- [ ] **app-engineer (optional, owner call):** Clip Studio preset for Roblox hatch and snatch highlights

## Sources (ads section)
Re-checked 2026-09-26 (market-researcher). This sandbox blocks direct fetches to roblox.com and devforum.roblox.com; the entries marked "(opened)" were read in full via the GitHub mirror of Roblox's own creator-docs repo (`github.com/Roblox/creator-docs`), which is close to primary since it's the source for create.roblox.com. Everything else is a search-result summary only — the page itself was not opened.

- [Rewarded video ads, Roblox Creator Hub docs](https://create.roblox.com/docs/production/promotion/rewarded-video-ads) — content opened via [github.com/Roblox/creator-docs mirror](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/promotion/rewarded-video-ads.md) (opened)
- [Ads Manager, Roblox Creator Hub docs](https://create.roblox.com/docs/production/promotion/ads-manager) — content opened via [github.com/Roblox/creator-docs mirror](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/promotion/ads-manager.md) (opened)
- [Content maturity and compliance, Roblox Creator Hub docs](https://create.roblox.com/docs/production/promotion/content-maturity) — content opened via [github.com/Roblox/creator-docs mirror](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/promotion/content-maturity.md) (opened)
- [DevForum: Rewarded Video ads are now available to all ads eligible creators](https://devforum.roblox.com/t/rewarded-video-ads-are-now-available-to-all-ads-eligible-creators/4063278) — search summary only; 18 Feb 2026 date not independently confirmed by opening the thread
- [DevForum bug report: ExperienceIneligible despite eligibility](https://devforum.roblox.com/t/rewarded-video-ads-cannot-be-shown-in-my-live-experience-the-api-returns-experienceineligible-but-the-creator-hub-says-it-is-eligible/4763102) — search summary only, dated 29 Jul 2026 per the summary
- [DevForum: GetAdAvailabilityNowAsync() permanently freezes after second call](https://devforum.roblox.com/t/adservicegetadavailabilitynowasync-permanently-freezes-after-second-call/4755444) — search summary only
- [DevForum: AdService:GetCampaignEligibilityAsync() always returns "Request failed"](https://devforum.roblox.com/t/adservicegetcampaigneligibilityasync-always-returns-with-error-request-failed/4848517) — search summary only
- [GM Market: Roblox Rewarded Video Ads in 2026](https://gmmarket.me/community/post/roblox-rewarded-video-ads-in-2026-who-can-enable-them-how-to-integrate-and-what) — search summary only, egress to this domain is blocked in-sandbox
- [BLOXG: Complete Guide to Roblox Advertising (2026)](https://bloxg.com/guides/roblox-ads-guide) — search summary only, egress blocked
- [Gamebiz Consulting: Roblox Ad Monetization Guide 2026](https://www.gamebizconsulting.com/blog/roblox-ad-monetization-guide-2026) — search summary only, egress blocked
- [rbxrate: Roblox Ad Credit Calculator](https://rbxrate.com/ad-credit-calculator/) — search summary only, used for the "~285 Robux per Ad Credit" figure
