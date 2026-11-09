-- Tests for src/shared/Logic.luau. Run with the Luau CLI from the kit folder:
--   luau tests/Logic.spec.luau
-- (Logic uses no Roblox services, so it runs outside Studio.)

local Logic = require("../src/shared/Logic")

local passed, failed = 0, 0
local function check(name: string, cond: boolean)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL: " .. name)
	end
end

local pool = {
	{ id = "a", text = "A %d", stat = "a", target = 3, reward = 10 },
	{ id = "b", text = "B %d", stat = "b", target = 1, reward = 20 },
	{ id = "c", text = "C %d", stat = "c", target = 2, reward = 30 },
	{ id = "d", text = "D %d", stat = "d", target = 5, reward = 40, minLevel = 10 },
}
local byId = Logic.index(pool)

-- day and reset hour
check("day 0 at epoch", Logic.day(0) == 0)
check("day 1 at 86400", Logic.day(86400) == 1)
check("reset hour shifts the day", Logic.day(86400 + 3600, 2) == 0 and Logic.day(86400 + 7200, 2) == 1)
check("seconds until reset", Logic.secondsUntilReset(86400 - 5) == 5)
check("seconds until reset with offset", Logic.secondsUntilReset(3600 * 2 + 5, 2) == 86395)

-- rolling
local t1 = Logic.roll(pool, 12345, 100, 1, 3)
local t2 = Logic.roll(pool, 12345, 100, 1, 3)
check("roll gives 3 tasks", #t1 == 3)
check("roll is deterministic", t1[1].id == t2[1].id and t1[2].id == t2[2].id and t1[3].id == t2[3].id)
local seen = {}
local unique = true
for _, e in t1 do
	if seen[e.id] or e.id == "d" then
		unique = false
	end
	seen[e.id] = true
end
check("roll has no duplicates and respects minLevel", unique)
check("roll stops when the pool runs out", #Logic.roll(pool, 1, 1, 1, 10) == 3)
check("high level can get the level task", #Logic.roll(pool, 1, 1, 50, 10) == 4)
check("negative (Studio) user ids work", #Logic.roll(pool, -1, 100, 1, 3) == 3)

-- refresh and streaks
local s, changed = Logic.refresh(nil, byId, pool, 1, 100, 1, 3)
check("first refresh creates a day", changed and s.day == 100 and s.streak == 0 and #s.tasks == 3)
local same, changed2 = Logic.refresh(s, byId, pool, 1, 100, 1, 3)
check("same day keeps state", same == s or (not changed2 and same.day == 100))

local function finishAll(state)
	local events = {}
	for _, e in state.tasks do
		local ev = Logic.progress(state, byId, byId[e.id].stat, 99, 3)
		for _, x in ev do
			table.insert(events, x)
		end
	end
	return events
end

local events = finishAll(s)
local lastEvent = events[#events]
check("finishing all gives 3 task events and an all event", #events == 4 and lastEvent.kind == "all")
check("streak is 1 after first full day", s.streak == 1 and s.best == 1 and s.full and s.lastFull == 100)
local again = Logic.progress(s, byId, "a", 1, 3)
check("no events after the day is full", #again == 0)

local d2 = Logic.refresh(s, byId, pool, 1, 101, 1, 3)
check("next day keeps streak", d2.streak == 1 and not d2.full and d2.day == 101)
finishAll(d2)
check("streak 2", d2.streak == 2)
local d3 = Logic.refresh(d2, byId, pool, 1, 102, 1, 3)
local ev3 = finishAll(d3)
check("streak 3 is a milestone (every 3)", d3.streak == 3 and ev3[#ev3].milestone == true)

local skipped = Logic.refresh(d3, byId, pool, 1, 104, 1, 3)
check("missing a day resets the streak but keeps best", skipped.streak == 0 and skipped.best == 3)

-- progress details
local p = Logic.refresh(nil, byId, pool, 7, 200, 1, 3)
local target: string? = nil
for _, e in p.tasks do
	if e.id == "a" then
		target = "a"
	end
end
if target then
	local ev, ch = Logic.progress(p, byId, "a", 1, 5)
	check("partial progress changes but gives no event", ch and #ev == 0)
end
local evNone, chNone = Logic.progress(p, byId, "nothing", 1, 5)
check("unknown stat changes nothing", not chNone and #evNone == 0)
local evNeg, chNeg = Logic.progress(p, byId, "a", -5, 5)
check("negative amount is ignored", not chNeg and #evNeg == 0)
local evNan, chNan = Logic.progress(p, byId, "a", 0 / 0, 5)
check("NaN amount is ignored", not chNan and #evNan == 0)

-- bad saved data and removed tasks
check("garbage save is ignored", Logic.sanitize("oops") == nil and Logic.sanitize({ day = "x" }) == nil)
local old = { day = 300, tasks = { { id = "a", n = 1, done = false }, { id = "gone", n = 0, done = false } }, streak = 2, best = 4 }
local cleaned, ch3 = Logic.refresh(old, byId, pool, 1, 300, 1, 3)
check("removed task ids are dropped", ch3 and #cleaned.tasks == 1 and cleaned.best == 4)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
