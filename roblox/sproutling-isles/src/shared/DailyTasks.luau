--!strict
-- Daily Tasks: three small goals a day, picked for each player from the pool below (only tasks
-- their level can reach). Each pays Dew and XP; finishing all three adds a crate, and every
-- fifth full day in a row a better one. New tasks at midnight UTC. DailyService runs them.

local DailyTasks = {}

export type Task = {
	id: string,
	text: string, -- %d is the target
	stat: string, -- State.track stat, or "kill" / "kill:<element>" (Shared/Combat elements)
	target: number,
	dew: number,
	minLevel: number?,
}

DailyTasks.Pool = {
	{ id = "plant", text = "Plant %d seeds in your garden house", stat = "plant", target = 8, dew = 250 },
	{ id = "harvest", text = "Harvest %d Sproutlings", stat = "harvest", target = 6, dew = 300 },
	{ id = "sell", text = "Sell %d Sproutlings", stat = "sell", target = 8, dew = 300 },
	{ id = "hunt", text = "Defeat %d monsters anywhere", stat = "kill", target = 25, dew = 350 },
	{ id = "quest", text = "Complete %d quest", stat = "quest", target = 1, dew = 400 },
	{ id = "travel", text = "Fast travel by waystone %d times", stat = "travel", target = 2, dew = 200 },
	{ id = "crate", text = "Open %d crate", stat = "crate", target = 1, dew = 200 },
	{ id = "shadow", text = "Defeat %d shadow monsters (Crypt skeletons, gloom bats)", stat = "kill:shadow", target = 10, dew = 400 },
	{ id = "earth", text = "Defeat %d earth monsters (golems, rockmites, beetles)", stat = "kill:earth", target = 10, dew = 500, minLevel = 8 },
	{ id = "fire", text = "Defeat %d fire monsters in the Emberdeep Caldera", stat = "kill:fire", target = 12, dew = 700, minLevel = 20 },
	{ id = "water", text = "Defeat %d water monsters at Saltmere or the Tidewrack Grotto", stat = "kill:water", target = 12, dew = 800, minLevel = 25 },
} :: { Task }

DailyTasks.ById = {} :: { [string]: Task }
for _, t in DailyTasks.Pool do
	DailyTasks.ById[t.id] = t
end

DailyTasks.Count = 3
DailyTasks.XPPerDew = 0.5
DailyTasks.AllDoneCrate = "silver"
DailyTasks.StreakCrate = "gold" -- every StreakEvery full days in a row
DailyTasks.StreakEvery = 5

-- The day number (UTC) a time falls in: tasks change when it does.
function DailyTasks.day(t: number): number
	return math.floor(t / 86400)
end

return DailyTasks
