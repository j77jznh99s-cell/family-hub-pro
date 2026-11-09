--!strict
-- Daily Streaks Kit: pure task logic. It uses no Roblox services, so it runs in Studio and in the
-- standalone Luau CLI (see tests/Logic.spec.luau). The server module wraps it with saving and UI.

local Logic = {}

export type TaskDef = {
	id: string,
	text: string, -- %d is replaced by target
	stat: string, -- the name you pass to DailyStreaks.track(player, stat, amount)
	target: number,
	reward: number,
	minLevel: number?,
}

export type Entry = { id: string, n: number, done: boolean }

export type State = {
	version: number,
	day: number,
	tasks: { Entry },
	streak: number,
	best: number,
	lastFull: number?, -- the last day every task was finished
	full: boolean, -- every task finished today
}

export type Event = {
	kind: string, -- "task" or "all"
	def: TaskDef?,
	streak: number?,
	milestone: boolean?,
}

local DAY = 86400
local MOD = 2147483647

-- Day number for a UTC time. Tasks change when it changes (at resetHourUTC each day).
function Logic.day(t: number, resetHourUTC: number?): number
	return math.floor((t - (resetHourUTC or 0) * 3600) / DAY)
end

function Logic.secondsUntilReset(t: number, resetHourUTC: number?): number
	local offset = (resetHourUTC or 0) * 3600
	return (Logic.day(t, resetHourUTC) + 1) * DAY + offset - t
end

-- Small deterministic random generator (Park-Miller), so a player gets the same tasks all day on
-- every server, even if a save fails.
function Logic.rng(seed: number): (number, number) -> number
	local s = math.floor(seed) % MOD
	if s == 0 then
		s = 1
	end
	return function(lo: number, hi: number): number
		s = (s * 48271) % MOD
		return lo + s % (hi - lo + 1)
	end
end

function Logic.index(pool: { TaskDef }): { [string]: TaskDef }
	local byId = {}
	for _, def in pool do
		assert(byId[def.id] == nil, "DailyStreaks: duplicate task id " .. def.id)
		assert(def.target > 0, "DailyStreaks: task " .. def.id .. " needs a target above 0")
		byId[def.id] = def
	end
	return byId
end

-- Pick `count` different tasks the player's level can reach.
function Logic.roll(pool: { TaskDef }, userId: number, day: number, level: number, count: number): { Entry }
	local eligible: { string } = {}
	for _, def in pool do
		if level >= (def.minLevel or 1) then
			table.insert(eligible, def.id)
		end
	end
	local nextInt = Logic.rng(userId * 7919 + day * 104729 + 1)
	local tasks: { Entry } = {}
	while #tasks < count and #eligible > 0 do
		local id = table.remove(eligible, nextInt(1, #eligible)) :: string
		table.insert(tasks, { id = id, n = 0, done = false })
	end
	return tasks
end

-- Turn whatever came out of the DataStore into a clean State, or nil if it is unusable.
function Logic.sanitize(old: any): State?
	if type(old) ~= "table" or type(old.day) ~= "number" or type(old.tasks) ~= "table" then
		return nil
	end
	local tasks: { Entry } = {}
	for _, e in old.tasks do
		if type(e) == "table" and type(e.id) == "string" and type(e.n) == "number" then
			table.insert(tasks, { id = e.id, n = e.n, done = e.done == true })
		end
	end
	return {
		version = 1,
		day = old.day,
		tasks = tasks,
		streak = tonumber(old.streak) or 0,
		best = tonumber(old.best) or 0,
		lastFull = if type(old.lastFull) == "number" then old.lastFull else nil,
		full = old.full == true,
	}
end

-- Today's state. Rolls new tasks when the day has changed; a full day yesterday keeps the
-- streak, anything older resets it. Returns the state and whether it changed.
function Logic.refresh(
	old: any,
	byId: { [string]: TaskDef },
	pool: { TaskDef },
	userId: number,
	day: number,
	level: number,
	count: number
): (State, boolean)
	local prev = Logic.sanitize(old)
	if prev and prev.day == day then
		-- drop tasks whose definitions were removed from Config after they were rolled
		local kept: { Entry } = {}
		for _, e in prev.tasks do
			if byId[e.id] then
				table.insert(kept, e)
			end
		end
		local changed = #kept ~= #prev.tasks
		prev.tasks = kept
		return prev, changed
	end
	local streak, best, lastFull = 0, 0, nil
	if prev then
		best = prev.best
		lastFull = prev.lastFull
		if prev.lastFull == day - 1 then
			streak = prev.streak
		end
	end
	return {
		version = 1,
		day = day,
		tasks = Logic.roll(pool, userId, day, level, count),
		streak = streak,
		best = best,
		lastFull = lastFull,
		full = false,
	}, true
end

function Logic.allDone(state: State): boolean
	if #state.tasks == 0 then
		return false
	end
	for _, e in state.tasks do
		if not e.done then
			return false
		end
	end
	return true
end

-- Count `amount` of `stat`. Returns the events to reward and whether anything changed.
function Logic.progress(
	state: State,
	byId: { [string]: TaskDef },
	stat: string,
	amount: number,
	milestoneEvery: number
): ({ Event }, boolean)
	local events: { Event } = {}
	if amount ~= amount or amount <= 0 then -- NaN or nothing to add
		return events, false
	end
	local changed = false
	for _, e in state.tasks do
		local def = byId[e.id]
		if def and not e.done and def.stat == stat then
			e.n = math.min(def.target, e.n + amount)
			changed = true
			if e.n >= def.target then
				e.done = true
				table.insert(events, { kind = "task", def = def })
			end
		end
	end
	if changed and not state.full and Logic.allDone(state) then
		state.full = true
		state.streak += 1
		state.best = math.max(state.best, state.streak)
		state.lastFull = state.day
		table.insert(events, {
			kind = "all",
			streak = state.streak,
			milestone = milestoneEvery > 0 and state.streak % milestoneEvery == 0,
		})
	end
	return events, changed
end

return Logic
