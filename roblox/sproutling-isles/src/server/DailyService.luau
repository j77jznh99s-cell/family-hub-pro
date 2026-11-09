-- Daily Tasks (Shared/DailyTasks): rolls each player's three tasks for the day, counts progress
-- from State.track and EnemyService.onKill, pays each finished task once, a crate when all three
-- are done (a better one on every fifth full day in a row), and keeps the client up to date.
-- Saved in data.daily = { day, tasks = { { id, n, done } }, streak, lastFull }.
--
-- DailyTasks remote: server -> client ("state", daily, secondsUntilNewTasks) | ("open")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyTasks = require(Shared.DailyTasks)
local Combat = require(Shared.Combat)

local State = require(script.Parent.State)
local Prompts = require(script.Parent.Prompts)
local EnemyService = require(script.Parent.EnemyService)
local LevelService = require(script.Parent.LevelService)
local CrateService = require(script.Parent.CrateService)

local DailyService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local DailyRemote = Instance.new("RemoteEvent")
DailyRemote.Name = "DailyTasks"
DailyRemote.Parent = remotes

-- Today's tasks for a session, rolled fresh when the day has changed.
local function today(session: any): any
	local now = os.time()
	local day = DailyTasks.day(now)
	local d = session.data.daily
	if not d or d.day ~= day then
		local level = session.player:GetAttribute("Level") or 1
		local pool = {}
		for _, t in DailyTasks.Pool do
			if level >= (t.minLevel or 1) then
				table.insert(pool, t.id)
			end
		end
		local rng = Random.new(session.player.UserId * 7919 + day)
		local tasks = {}
		while #tasks < DailyTasks.Count and #pool > 0 do
			local id = table.remove(pool, rng:NextInteger(1, #pool))
			table.insert(tasks, { id = id, n = 0, done = false })
		end
		local old = d or {}
		-- a full day yesterday keeps the streak going; anything older resets it
		local streak = if old.lastFull == day - 1 then old.streak or 0 else 0
		d = { day = day, tasks = tasks, streak = streak, lastFull = old.lastFull, full = false }
		session.data.daily = d
	end
	return d
end

local function push(player: Player)
	local session = State.get(player)
	if session then
		local d = today(session)
		local untilNext = (DailyTasks.day(os.time()) + 1) * 86400 - os.time()
		DailyRemote:FireClient(player, "state", d, untilNext)
	end
end

local function progress(session: any, stat: string, n: number)
	local d = today(session)
	local changed = false
	for _, entry in d.tasks do
		local t = DailyTasks.ById[entry.id]
		if t and not entry.done and t.stat == stat then
			entry.n = math.min(t.target, entry.n + n)
			changed = true
			if entry.n >= t.target then
				entry.done = true
				State.addDew(session, t.dew, "Daily:" .. t.id)
				LevelService.addXP(session.player, math.floor(t.dew * DailyTasks.XPPerDew), "Daily")
				State.notify(session, string.format("Daily task done: %s! +%d Dew", string.format(t.text, t.target), t.dew), "#a0ffa0")
			end
		end
	end
	if changed and not d.full then
		local all = true
		for _, entry in d.tasks do
			if not entry.done then
				all = false
			end
		end
		if all then
			d.full = true
			d.streak = (d.streak or 0) + 1
			d.lastFull = d.day
			local special = d.streak % DailyTasks.StreakEvery == 0
			CrateService.give(session.player, if special then DailyTasks.StreakCrate else DailyTasks.AllDoneCrate)
			State.notify(session, string.format("All daily tasks done! A crate for you. Streak: %d day%s.%s", d.streak, if d.streak == 1 then "" else "s", if special then " Streak bonus: a golden crate!" else ""), "#ffd27a")
		end
	end
	if changed then
		push(session.player)
	end
end

function DailyService.init(map: Instance)
	State.onTrack(function(session, stat, n)
		progress(session, stat, n)
	end)
	EnemyService.onKill(function(player, kindId)
		local session = State.get(player)
		local kind = Combat.Enemies[kindId]
		if session and kind then
			progress(session, "kill", 1)
			if kind.element then
				progress(session, "kill:" .. kind.element, 1)
			end
		end
	end)
	-- task boards in the world open the window
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("TaskBoard") then
			local prompt = Prompts.create(d, "Daily tasks", "Task Board")
			prompt.Triggered:Connect(function(player)
				push(player)
				DailyRemote:FireClient(player, "open")
			end)
		end
	end
	local function onPlayer(player: Player)
		task.spawn(function()
			for _ = 1, 40 do
				if State.get(player) then
					break
				end
				task.wait(0.5)
			end
			push(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	-- roll over at midnight for anyone online
	task.spawn(function()
		local lastDay = DailyTasks.day(os.time())
		while true do
			task.wait(30)
			local day = DailyTasks.day(os.time())
			if day ~= lastDay then
				lastDay = day
				for _, p in Players:GetPlayers() do
					push(p)
				end
			end
		end
	end)
end

return DailyService
