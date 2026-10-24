---
tags: [project, roblox, overnight]
---
# Sproutling Isles: Overnight Runs

The owner asked (2026-10-24, before sleeping) for repeated runs that compare the game with similar
Roblox games, find where it's lacking and implement the difference, about hourly. A session cron
job (`7 * * * *`, session-only, expires after 7 days) runs one gap per run. Part budget: 100,000
(map + EditGround). Shop prices stay as they are. Original content only.

## Runs (newest first)

### Run 1, 2026-10-24 ~05:00: Monster Journal
- **Compared with:** Fisch (bestiaries per region are its main long-term collection layer), Grow a Garden (simple loop + collection chase).
- **Gap:** no collection log for the 21 monster kinds across the wilds and four elemental dungeons.
- **Built:** Monster Journal (N / button): regions, element tags, defeat counts, mastery bars; +25 Dew per discovery, +150 Dew and XP per mastery (25 defeats, 3 for bosses), one-time Dew + crate per completed region. `Shared/Journal`, `server/JournalService`, `client/Journal`. Commit `8907b1f`.
- **Test in Studio:** kill a slime, check the toast and the journal entry; kill 25 slimes for mastery; check the region reward pays once.

## Ideas queue (for later runs)
- Weather-driven crop mutations shown on Greenhollow plants (garden sims' biggest hook).
- Daily goals / quests board with streaks.
- Ambient sound hooks (birdsong in Greenhollow, surf at Saltmere, lava rumble).
- Fishing at Saltmere pier.
- Pet/companion perks tied to gardening.
