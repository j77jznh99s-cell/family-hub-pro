--!strict
-- Live-ops event configuration. Currently just the Halloween "Hollow Harvest" event; a winter
-- event would add a sibling table here later. See
-- vault/Projects/Sproutling Isles - Launch & Live Ops.md, "Halloween event spec Hollow Harvest".
--
-- All times are Unix UTC seconds, checked against os.time() (UTC on Roblox servers), so the event
-- starts and stops itself with no redeploy needed.

local RunService = game:GetService("RunService")

export type StallItem = {
	id: string,
	kind: "seed" | "skin",
	speciesId: string?, -- set when kind == "seed"
	skinId: string?, -- set when kind == "skin"
	price: number, -- Moonberries
	dailyCap: number?, -- nil = no daily cap
	fromPart: number, -- the event "part" (1, 2, ...) this unlocks in
}

export type EventConfig = {
	id: string,
	weatherId: string,
	part1At: number,
	part2At: number,
	witchingHourAt: number,
	endAt: number,
	fogEverySeconds: number,
	witchingFogEverySeconds: number,
	lanternCount: number,
	lanternValue: number,
	lanternDailyBonus: number,
	hatchBonus: number,
	hauntedHatchBonus: number,
	stall: { [string]: StallItem },
	stallOrder: { string },
}

local Config = require(script.Parent.Config)

local Events = {}

-- The real clock everywhere but Studio. Inside Studio, `Config.EventTimeOffset` (default 0) lets a
-- tester fast-forward past the event's real-world start/part/Witching-Hour/end boundaries without
-- waiting for the calendar. Live servers always ignore the offset.
function Events.now(): number
	return os.time() + (if RunService:IsStudio() then Config.EventTimeOffset else 0)
end

Events.Halloween2026 = {
	id = "halloween2026",
	weatherId = "spookyfog",

	-- Sat 17 Oct 2026 15:00 UTC (hand-checked: 20743 days after 1970-01-01, i.e. 56 years including
	-- 14 leap days [1972..2024] to reach 2026-01-01, +289 days to 17 Oct, +15:00 = 1,792,249,200s)
	part1At = 1792249200,
	-- Sat 24 Oct 2026 15:00 UTC (part1At + 7 days = +604,800s)
	part2At = 1792854000,
	-- Sat 31 Oct 2026 00:00 UTC
	witchingHourAt = 1793404800,
	-- Sun 1 Nov 2026 23:59 UTC
	endAt = 1793577540,

	fogEverySeconds = 20 * 60,
	witchingFogEverySeconds = 10 * 60,

	lanternCount = 10,
	lanternValue = 5,
	lanternDailyBonus = 20,
	hatchBonus = 1,
	hauntedHatchBonus = 5,

	stall = {
		pumpkit = { id = "pumpkit", kind = "seed", speciesId = "pumpkit", price = 60, dailyCap = 5, fromPart = 1 },
		gourdgeist = { id = "gourdgeist", kind = "seed", speciesId = "gourdgeist", price = 250, dailyCap = 2, fromPart = 2 },
		skin = { id = "skin", kind = "skin", skinId = "haunted", price = 400, dailyCap = nil, fromPart = 2 },
	},
	-- kiosk 1..3 order, matching MapBuilder's Lantern Stall Kiosk1/2/3 "Slot" attributes
	stallOrder = { "pumpkit", "gourdgeist", "skin" },
} :: EventConfig

-- Week 1 launch incentive: "Founding Gardener" badge + flag for anyone whose first-ever join
-- falls in Week 1. See vault/Projects/Sproutling Isles - Launch & Live Ops.md, Week 1 section,
-- and the launch calendar table ("Week 2 starts 17 Oct").
Events.FoundingGardenerWindow = {
	-- Sat 10 Oct 2026 00:00 UTC (public launch = Week 1 start). Hand-checked:
	-- `date -u -d "2026-10-10 00:00:00" +%s` -> 1791590400.
	startAt = 1791590400,
	-- Sat 17 Oct 2026 00:00 UTC (Week 2 starts, per the launch calendar table; end is exclusive,
	-- i.e. a join at exactly this instant counts as Week 2). Hand-checked:
	-- `date -u -d "2026-10-17 00:00:00" +%s` -> 1792195200.
	endAt = 1792195200,
}

-- Week 8 "Frostbloom Seedling" login-day teaser: a data-only tracker (no reward is granted here --
-- see init.server.luau's comment for why). See vault/Projects/Sproutling Isles - Launch &
-- Live Ops.md, Week 8 section.
Events.FrostbloomTeaserWindow = {
	-- Sat 28 Nov 2026 00:00 UTC (Week 8 start). Hand-checked:
	-- `date -u -d "2026-11-28 00:00:00" +%s` -> 1795824000.
	startAt = 1795824000,
	-- Fri 11 Dec 2026 23:59 UTC (the day before Frostbloom Festival Day 1, Sat 12 Dec; end is
	-- inclusive of this minute, per the spec's "through 11 Dec"). Hand-checked:
	-- `date -u -d "2026-12-11 23:59:00" +%s` -> 1797033540.
	endAt = 1797033540,
}
Events.FrostbloomTeaserDaysNeeded = 3

-- True from Part 1's start up to (not including) the end time.
function Events.active(config: EventConfig, now: number): boolean
	return now >= config.part1At and now < config.endAt
end

-- 1 before Part 2 starts, 2 from Part 2 onward (Witching Hour is still "part 2" for unlock checks).
function Events.part(config: EventConfig, now: number): number
	if now >= config.part2At then
		return 2
	end
	return 1
end

function Events.isWitchingHour(config: EventConfig, now: number): boolean
	return now >= config.witchingHourAt and now < config.endAt
end

function Events.fogIntervalSeconds(config: EventConfig, now: number): number
	return if Events.isWitchingHour(config, now) then config.witchingFogEverySeconds else config.fogEverySeconds
end

return Events
