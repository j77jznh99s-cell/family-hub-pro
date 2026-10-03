---
tags: [research, roblox]
as_of: 2026-10-03
---
# Roblox Market Research 2026

Summary of the research that picked [[Sproutling Isles]]. **Caveat:** most source pages were blocked for
direct reading in the sandbox, so figures come from search-result summaries. Re-verify before quoting them publicly.

## Refresh 2026-10-03
CCU figures are third-party tracker estimates (RoVitals, sampled 3 Oct 2026 ~18:40–18:52 UTC), not Roblox data.

**What changed since 23 Sep**
- **Grow a Garden 2 has collapsed:** 3,092 CCU now, down 94.8% over 30 days, from a peak of 483,561 on 13 Aug [1]. The "450–500K sustained" line below is out of date.
- **Grow a Garden 1 is holding steady but small:** 24,795 CCU, down 15% over 30 days, peak 166,679 on 15 Aug [2].
- **Fish It is down too:** 76,123 CCU, down 22.6% over 30 days, tracked peak 204,077 on 23 Aug [3]. The tracker never recorded the "~840K" figure below, so treat that number as unverified.
- **New leader: Steal An Egg** (steal eggs → hatch and collect pets → upgrade your base; created 25 Jul 2026). It has 1.65M CCU and peaked at 14.27M on 19 Sep. It is down 20% week on week but up 168% over 30 days, and it ships an update almost every Saturday plus "admin abuse" live events [4][5, snippet-only]. The steal/collect-pets formula has replaced pure gardening as the hit genre.
- **Platform changes:**
  - (25 Sep) Passes and dev products can now be bought outside the game (Home/Shop), but only if the shop listing and `ProcessReceipt` are set up correctly. There is also a new refund/chargeback webhook [6].
  - (2 Oct) Ads Manager "Earnings" objective expanded to ~30K games. New Early Harm Detection gives 24h experiment monitoring. Web API rate limits tighten after 19 Oct. New Terms of Use take effect 1 Nov [7].
  - Roblox Plus now gives 1 free private server per game instead of unlimited (from 24 Sep) [9, snippet-only].
- **Roadmap (18 Sep):**
  - Late 2026: free trials of passes, relaxed Kids & Select thresholds, Wallet (daily real-currency payouts) [8].
  - Pre-roll video ads during loading are "coming soon", need no code, and Plus subscribers won't see them [9, snippet-only].
  - No DevEx-rate or discovery-algorithm changes were announced since 23 Sep. The age-check system (Kids <9 / Select 9–15 / 16+) is unchanged [10, snippet-only].
- **Halloween timing:**
  - Adopt Me's event started 3 Oct [11]. Dandy's World runs 2 Oct–6 Nov and Horse Life starts 9 Oct [12, snippet-only].
  - Roblox's Halloween Spotlight page says "Thu 23 Oct–Mon 3 Nov". 23 Oct 2026 is a Friday, so this is probably last year's page, and the 2026 dates are unconfirmed [13].
  - Last year Grow a Garden's Ghoul Garden ran as weekly parts over ~3 weeks [14, snippet-only].

**Implications for Sproutling Isles**
1. Gardening alone is fading (GAG2 lost ~95% of its players in about 6 weeks). Lead the store page and thumbnails with collecting and trading species and social play, not just farming. The game already has snatching (`SnatchService`), and the steal-and-collect loop is what's winning right now, so this argues for keeping snatching prominent when the owner settles its rules ([[Decisions]]).
2. Hollow Harvest on 17 Oct is about 2 weeks behind the big games, but it lands before any likely 2026 Spotlight (~22/23 Oct). Keep 17 Oct, and split the event into 2–3 weekly drops (17, 24, 31 Oct) instead of one release.
3. Set up shop listings and `ProcessReceipt` correctly before launch (10 Oct) so passes show up outside the game. Handle the refund webhook to revoke purchases that get charged back.
4. Use Early Harm Detection on any launch-week price or pass experiment. Since Earnings-objective ads now reach ~30K games, test a small ad budget only after the D1 retention numbers come in.
5. Plan a weekly update cadence (for example every Saturday) with short live "boost" events. That is the pattern of the current #1 game, and it feeds the 28-day retention signals that discovery ranks on.

**Sources (all accessed 2026-10-03)**
[1] rovitals.com/game/97598239454123 · [2] rovitals.com/game/126884695634066 · [3] rovitals.com/game/121864768012064 ·
[4] rovitals.com/game/107778070777162 · [5] bloxswaps.com/blog/steal-an-egg-update-schedule; sportskeeda.com/roblox-news/break-and-steal-an-egg-admin-abuse-time ·
[6] devforum.roblox.com/t/weekly-recap-september-21-25-2026/4894110 (posted 1 Oct) · [7] devforum.roblox.com/t/weekly-recap-september-28%E2%80%93october-2-2026/4910267 (3 Oct) ·
[8] devforum.roblox.com/t/creator-roadmap-2026-fall-update/4880208 (18 Sep) · [9] devforum.roblox.com/t/rdc26-what-we-announced/4865880; about.roblox.com/newsroom/2026/09/rdc-2026-the-world-needs-more-play ·
[10] biometricupdate.com/202601/roblox-rolls-out-facial-age-estimation-for-chat-access-globally · [11] theclick.gg/adopt-me-halloween-2026 (2 Oct) ·
[12] dandys-world-robloxhorror.fandom.com/wiki/2026_Halloween_Event; horse-life-wiki-roblox.fandom.com/wiki/Halloween_Event_2026 · [13] roblox.com/spotlight/halloween-spotlight ·
[14] gamerant.com/grow-a-garden-complete-halloween-event-ghoul-garden-guide-cauldron-progress-jack-o-lantern-halloween-mutations

## Bottom line
1. **Best overall bet:** collect → grow → trade simulators with a social or PvP twist (Grow a Garden 1 & 2, Steal a Brainrot, Fish It).
2. **Higher-ceiling bet:** original, higher-fidelity **18+** games (shooters, co-op survival or action) for the 42% DevEx boost and "Standout Games" placement.
3. **Avoid:** straight meme clones, plain obbies (low revenue per player), pay-to-win.

## Platform facts (2026)
- Discovery now ranks on retention over 28 days (day 1, days 2–7, days 8–28): playtime, play days, co-play, spend days, Robux spent. Averaged per user.
- DAU among 18+ players +32% YoY; US players aged 18–34 +50%; 18+ players spend over 50% more than under-18s.
- From 2026-06-08: DevEx +42% on US 18+ spend in eligible "novel" R15 games.
- Q2 2026: revenue about $1.5B (+36%), bookings about $1.56B (+8%); age checks cost about 20M DAU over 6 months.
- Creators earned about $1.7B over the 12 months to June 2026; the top 10 averaged about $65.7M each, the median about $1,500.
- 28% of the top 100 games by hours played (Aug 2026) had launched within the previous 90 days.

## Genre leaders (third-party trackers, Aug–Sep 2026)
| Game | Genre | Signal |
| --- | --- | --- |
| Grow a Garden 2 | grow sim | about 450–500K CCU sustained, launched 2026-06-12 |
| Fish It | fishing/collect | about 840K CCU (Sep 2026) |
| Steal a Brainrot | steal-and-defend tycoon | about 190K CCU normally, huge event spikes |
| 99 Nights in the Forest | co-op survival horror | about 180–360K CCU |
| Rivals | FPS | est. $8–15M/month |

## Monetization patterns that work
Starter pack for the first purchase · income-scaled currency packs · server-wide boosts (weather) ·
cosmetics > power · rewarded video with generous rewards · trading between players for long-term value.

## Sources
Roblox newsroom (discovery update June 2026; DevEx 18+ April 2026), Roblox DevForum retention post,
Gaming Amigos (Q2 2026), Dexerto (creator earnings), GAMES.GG (Grow a Garden 2), MaxPower (Fish It).
Full links are in the design doc's Sources section.
