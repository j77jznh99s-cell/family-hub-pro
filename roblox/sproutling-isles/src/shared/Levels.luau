--!strict
-- Player levels: how much XP each level takes, where XP comes from, rank titles, and what each
-- level unlocks (vehicles from Shared/Vehicles, plus a reward crate every level).

local Vehicles = require(script.Parent.Vehicles)

local Levels = {}

Levels.Max = 60

-- XP needed to go from `level` to the next one.
function Levels.xpFor(level: number): number
	return math.floor(60 * level ^ 1.45 + 40)
end

-- XP for each activity.
Levels.Gain = {
	killPerDew = 2, -- a monster gives 2x its Dew reward in XP
	questPerDew = 0.6, -- a quest gives 60% of its Dew reward in XP
	arenaWave = 35, -- per wave survived, times the wave number
	hatch = 10, -- hatching a Sproutling in your garden
}

-- Rank titles shown with the level.
Levels.Ranks = {
	{ level = 1, title = "Wanderer" },
	{ level = 5, title = "Adventurer" },
	{ level = 10, title = "Pathfinder" },
	{ level = 18, title = "Hero of the Isles" },
	{ level = 26, title = "Champion" },
	{ level = 36, title = "Sky Warden" },
	{ level = 48, title = "Legend" },
	{ level = 60, title = "Mythic" },
}

function Levels.rank(level: number): string
	local title = Levels.Ranks[1].title
	for _, r in Levels.Ranks do
		if level >= r.level then
			title = r.title
		end
	end
	return title
end

-- The crate tier a level-up gives.
function Levels.crateFor(level: number): string
	if level % 10 == 0 then
		return "gold"
	elseif level % 5 == 0 then
		return "silver"
	end
	return "wood"
end

-- Lines describing what reaching `level` unlocks (for the level-up screen).
function Levels.unlocksAt(level: number): { string }
	local lines = {}
	for _, v in Vehicles.List do
		if v.level == level then
			table.insert(lines, string.format("%s (%s) at the %s", v.name, v.kind, v.shopName))
		end
	end
	for _, r in Levels.Ranks do
		if r.level == level and level > 1 then
			table.insert(lines, "New rank: " .. r.title)
		end
	end
	return lines
end

return Levels
