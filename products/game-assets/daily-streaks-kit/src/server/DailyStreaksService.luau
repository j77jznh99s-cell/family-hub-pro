-- Daily Streaks Kit: server. Loads and saves each player's tasks, counts progress, pays rewards
-- and keeps the client panel up to date. Your scripts only need:
--
--   local DailyStreaks = require(game.ServerScriptService.DailyStreaks.DailyStreaksService)
--   DailyStreaks.track(player, "collect", 1)
--
-- Remote (ReplicatedStorage.DailyStreaks.Remote):
--   server -> client: ("state", view) | ("open") | ("toast", text)
--   client -> server: ("refresh")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("DailyStreaks")
local Config = require(Shared:WaitForChild("Config"))
local Logic = require(Shared:WaitForChild("Logic"))

local byId = Logic.index(Config.Pool)

-- A tiny signal: handlers run in their own thread, so an error in one doesn't stop the kit.
local function newSignal()
	local handlers = {}
	local signal = {}
	function signal:Connect(fn)
		handlers[fn] = true
		return {
			Disconnect = function()
				handlers[fn] = nil
			end,
		}
	end
	function signal:_fire(...)
		for fn in handlers do
			task.spawn(fn, ...)
		end
	end
	return signal
end

local DailyStreaks = {}
DailyStreaks.TaskCompleted = newSignal() -- (player, taskDef)
DailyStreaks.AllCompleted = newSignal() -- (player, streak, isMilestone)

local levelProvider = function(player: Player): number
	return tonumber(player:GetAttribute(Config.LevelAttribute)) or 1
end

function DailyStreaks.setLevelProvider(fn: (Player) -> number)
	levelProvider = fn
end

local remote = Instance.new("RemoteEvent")
remote.Name = "Remote"
remote.Parent = Shared

local store = nil
if Config.SaveData then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DailyStreaks] DataStore unavailable, progress won't save: " .. tostring(result))
	end
end

local sessions = {} -- [Player] = { state, loaded, canSave, dirty, pending, lastRequest }

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function retry(fn)
	local lastErr
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(attempt * 2)
	end
	return false, lastErr
end

local function level(player: Player): number
	local ok, value = pcall(levelProvider, player)
	return if ok and tonumber(value) then tonumber(value) :: number else 1
end

local function today(player: Player, session)
	local day = Logic.day(os.time(), Config.ResetHourUTC)
	local state, changed =
		Logic.refresh(session.state, byId, Config.Pool, player.UserId, day, level(player), Config.TasksPerDay)
	session.state = state
	if changed then
		session.dirty = true
	end
	return state
end

local function push(player: Player)
	local session = sessions[player]
	if not session or not session.loaded then
		return
	end
	local state = today(player, session)
	local rows = {}
	for _, e in state.tasks do
		local def = byId[e.id]
		if def then
			table.insert(rows, {
				text = string.format(def.text, def.target),
				n = e.n,
				target = def.target,
				reward = def.reward,
				done = e.done,
			})
		end
	end
	remote:FireClient(player, "state", {
		tasks = rows,
		streak = state.streak,
		best = state.best,
		full = state.full,
		allDoneBonus = Config.AllDoneBonus,
		secondsLeft = Logic.secondsUntilReset(os.time(), Config.ResetHourUTC),
	})
end

local function toast(player: Player, text: string)
	remote:FireClient(player, "toast", text)
end

local function pay(player: Player, amount: number)
	if not Config.LeaderstatName or amount <= 0 then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(Config.LeaderstatName)
	if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
		value.Value += amount
	end
end

local function apply(player: Player, session, stat: string, amount: number)
	local state = today(player, session)
	local events, changed = Logic.progress(state, byId, stat, amount, Config.StreakMilestoneEvery)
	if not changed then
		return
	end
	session.dirty = true
	for _, ev in events do
		if ev.kind == "task" and ev.def then
			local def = ev.def
			pay(player, def.reward)
			toast(player, string.format("Task done: %s  +%d", string.format(def.text, def.target), def.reward))
			DailyStreaks.TaskCompleted:_fire(player, def)
		elseif ev.kind == "all" then
			local bonus = Config.AllDoneBonus + (if ev.milestone then Config.StreakMilestoneBonus else 0)
			pay(player, bonus)
			local days = if ev.streak == 1 then "1 day" else tostring(ev.streak) .. " days"
			toast(
				player,
				if ev.milestone
					then string.format("Streak milestone! %s in a row  +%d", days, bonus)
					else string.format("All daily tasks done! Streak: %s  +%d", days, bonus)
			)
			DailyStreaks.AllCompleted:_fire(player, ev.streak, ev.milestone)
		end
	end
	push(player)
end

-- Count progress. Call it from any server script; amount defaults to 1.
function DailyStreaks.track(player: Player, stat: string, amount: number?)
	local n = amount or 1
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(stat) ~= "string" or type(n) ~= "number" then
		warn("[DailyStreaks] track(player, stat, amount) got bad arguments", player, stat, amount)
		return
	end
	local session = sessions[player]
	if not session then
		return
	end
	if not session.loaded then
		table.insert(session.pending, { stat = stat, n = n })
		return
	end
	apply(player, session, stat, n)
end

-- Read-only view of a player's state ({ day, tasks, streak, best, lastFull, full }), or nil.
function DailyStreaks.getState(player: Player)
	local session = sessions[player]
	return if session and session.loaded then today(player, session) else nil
end

-- Open the panel for a player (e.g. from your own NPC or menu).
function DailyStreaks.open(player: Player)
	push(player)
	remote:FireClient(player, "open")
end

local function save(player: Player, session)
	if not (store and session.canSave and session.loaded and session.dirty and session.state) then
		return
	end
	session.dirty = false
	local snapshot = session.state
	local ok, err = retry(function()
		store:UpdateAsync(key(player), function()
			return snapshot
		end)
	end)
	if not ok then
		session.dirty = true
		warn("[DailyStreaks] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

local function onPlayerAdded(player: Player)
	local session = { state = nil, loaded = false, canSave = store ~= nil, dirty = false, pending = {}, lastRequest = 0 }
	sessions[player] = session
	if store then
		local ok, data = retry(function()
			return store:GetAsync(key(player))
		end)
		if ok then
			session.state = data
		else
			-- don't overwrite good saved data with a fresh day if loading failed
			session.canSave = false
			warn("[DailyStreaks] load failed for " .. player.Name .. ", this session won't save: " .. tostring(data))
		end
	end
	if sessions[player] ~= session then
		return -- left while loading
	end
	session.loaded = true
	local pending = session.pending
	session.pending = {}
	for _, p in pending do
		apply(player, session, p.stat, p.n)
	end
	push(player)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	sessions[player] = nil
	if session then
		save(player, session)
	end
end

local function addBoard(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("DailyStreaksPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DailyStreaksPrompt"
	prompt.ActionText = "Daily tasks"
	prompt.ObjectText = "Task Board"
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		DailyStreaks.open(player)
	end)
end

local started = false
function DailyStreaks.start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end

	remote.OnServerEvent:Connect(function(player, action)
		local session = sessions[player]
		if action == "refresh" and session and os.clock() - session.lastRequest > 1 then
			session.lastRequest = os.clock()
			push(player)
		end
	end)

	for _, part in CollectionService:GetTagged(Config.BoardTag) do
		addBoard(part)
	end
	CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(addBoard)

	-- new tasks at the reset hour for everyone online
	task.spawn(function()
		local lastDay = Logic.day(os.time(), Config.ResetHourUTC)
		while true do
			task.wait(10)
			local day = Logic.day(os.time(), Config.ResetHourUTC)
			if day ~= lastDay then
				lastDay = day
				for player in sessions do
					push(player)
				end
			end
		end
	end)

	if Config.TrackPlaytime then
		task.spawn(function()
			while true do
				task.wait(60)
				for player, session in sessions do
					if session.loaded then
						DailyStreaks.track(player, "minutes", 1)
					end
				end
			end
		end)
	end

	-- autosave every 2 minutes
	task.spawn(function()
		while true do
			task.wait(120)
			for player, session in sessions do
				task.spawn(save, player, session)
			end
		end
	end)

	game:BindToClose(function()
		local remaining = 0
		for player, session in sessions do
			remaining += 1
			task.spawn(function()
				save(player, session)
				remaining -= 1
			end)
		end
		local startedAt = os.clock()
		while remaining > 0 and os.clock() - startedAt < 25 do
			task.wait(0.2)
		end
	end)

	if RunService:IsStudio() and not store then
		print("[DailyStreaks] running without saving (enable API access in Game Settings to test saving)")
	end
end

return DailyStreaks
