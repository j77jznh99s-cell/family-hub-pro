--!strict
-- Every gameplay tunable lives here so designers can rebalance without touching systems code.

local Config = {}

Config.GameName = "Sproutling Isles"
Config.CurrencyName = "Dew"

-- New players
Config.StartingDew = 25
Config.StartingSeeds = { mossbun = 2 }
Config.NewPlayerShieldSeconds = 15 * 60 -- can't be snatched from during first 15 min of playtime

-- Plots
Config.PlotCount = 8
Config.SoilTilesPerPlot = 12 -- 4 x 3 grid
Config.BasePads = 8
Config.BonusPadsPass = 4 -- "Big Greenhouse" game pass

-- Gate lock (defence)
Config.LockSeconds = 60
Config.LockSecondsWithPass = 90

-- Snatching
Config.SnatchHoldSeconds = 1.5
Config.SnatchCarrySeconds = 45 -- thief must reach home within this time
Config.CarryWalkSpeed = 12
Config.SnatchCooldownSeconds = 20
-- Server-side anti-cheat for carries (the thief's client owns its character physics).
-- Horizontal speed is checked with a token bucket: the thief earns CarryWalkSpeed * CarryMaxSpeedFactor
-- studs of allowance per second, banked up to CarryBurstSeconds' worth, so lag spikes (no movement,
-- then a catch-up jump) don't trip it but sustained speed hacks or teleports do. Tuning is unverified.
Config.CarryMaxSpeedFactor = 1.3 -- 12 * 1.3 = 15.6 studs/s, below the default 16 walk speed
Config.CarryBurstSeconds = 2.5
Config.SnatchReachSlack = 6 -- extra studs allowed beyond the prompt's range when the snatch fires

-- Selling
Config.SellRatio = 0.6 -- sell value = seed price * ratio * mutation * size

-- Growth & weather
Config.WeatherEverySeconds = { 300, 480 } -- random gap between natural weather events
Config.WeatherDurationSeconds = 120
Config.GoldenChance = 0.01 -- mutation roll available in any weather
Config.HugeChance = 0.01
Config.HugeSize = 2.5

-- Shop restock (per player)
Config.RestockSeconds = 300

-- Pollen Parade conveyor
Config.ParadeSpawnSeconds = 6
Config.ParadeTravelSeconds = 32

-- Wishing Pond
Config.PondCooldownSeconds = 8
Config.PondBiteSeconds = 3

-- Rebirth: cost grows x4 per rebirth, each rebirth adds +50% permanent Dew
Config.RebirthBaseCost = 250_000
Config.RebirthCostGrowth = 4
Config.RebirthBonus = 0.5

-- Daily streak rewards, index = streak day (loops after 7)
Config.DailyRewards = {
	{ dew = 100 },
	{ dew = 250 },
	{ seed = "clovercub", count = 2 },
	{ dew = 1_000 },
	{ seed = "tulipaca", count = 2 },
	{ dew = 5_000 },
	{ seed = "mushroomph", count = 1 },
}
Config.DailyResetHours = 48 -- miss more than this and the streak restarts

-- Testing: set true to get every game pass perk while play-testing in Studio
Config.StudioTestPasses = false
-- Testing: turns off the new-player shield, but ONLY inside Roblox Studio (RunService:IsStudio()).
-- Studio sessions never save playtime, so without this every test player is shielded for 15 min.
-- Live servers ignore this flag.
Config.StudioDisableShield = true
-- Testing: seconds added to os.time() for Hollow Harvest / Frostbloom phase checks, ONLY inside
-- Roblox Studio (RunService:IsStudio()). Live servers ignore this. Lets qa-tester fast-forward to
-- Part 2, Witching Hour, or past the event's end without waiting for the real date.
Config.EventTimeOffset = 0

-- Week 1 launch incentive: "Founding Gardener" badge. 0 until the badge is created on the Creator
-- Dashboard -- same "IDs are 0 until you create..." convention as Products.luau. Badges.award()
-- no-ops (skips, no error) while this is 0. See Events.FoundingGardenerWindow for the join window.
Config.FoundingGardenerBadgeId = 0

-- Saving
Config.DataStoreName = "SproutlingIsles_v1"
Config.AutosaveSeconds = 60
Config.SessionLockSeconds = 90

-- Leaderboards (Week 5 live-ops: cross-server income + rarest-hatch boards in the Plaza).
-- See vault/Projects/Sproutling Isles - Launch & Live Ops.md, Week 5 -- the spec is just one
-- line ("in-world leaderboards: income, rarest hatch"), so these two numbers are design calls,
-- not sourced requirements; game-designer/owner can revise them.
Config.LeaderboardSize = 10 -- top N shown on the physical board
Config.LeaderboardRefreshSeconds = 180 -- how often the board re-queries the OrderedDataStores

return Config
