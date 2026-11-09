-- The Arena: wave-survival trials in the city's colosseum.
--
-- Anyone at the arena gate can start a trial. Everyone standing on the arena floor when it
-- starts fights together; each wave brings more and tougher monsters (a boss every fifth wave).
-- Clearing a wave pays Dew and XP, with crates on every fifth and tenth wave. The trial ends
-- when no fighter is left alive on the floor; each fighter's best wave goes on the leaderboard.
-- Fighters see their wave and the monsters left through the ArenaWave / ArenaLeft attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Levels = require(Shared.Levels)

local State = require(script.Parent.State)
local Prompts = require(script.Parent.Prompts)
local EnemyService = require(script.Parent.EnemyService)
local LevelService = require(script.Parent.LevelService)
local CrateService = require(script.Parent.CrateService)
local LeaderboardService = require(script.Parent.LeaderboardService)

local ArenaService = {}

local centre: Vector3 = Vector3.zero
local radius = 30
local running = false
local wave = 0
local fighters: { [Player]: boolean } = {}
local alive: { any } = {}

local function notify(player: Player, text: string, color: string?)
	local session = State.get(player)
	if session then
		State.notify(session, text, color)
	end
end

local function onFloor(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local flat = Vector3.new(root.Position.X - centre.X, 0, root.Position.Z - centre.Z)
	return flat.Magnitude <= radius + 4 and math.abs(root.Position.Y - centre.Y) < 25
end

local function tellFighters(text: string, color: string?)
	for player in fighters do
		notify(player, text, color)
	end
end

local function setHud()
	for player in fighters do
		player:SetAttribute("ArenaWave", wave)
		player:SetAttribute("ArenaLeft", #alive)
	end
end

local function kindsFor(w: number): { string }
	if w <= 2 then
		return { "slime" }
	elseif w <= 4 then
		return { "slime", "goblin" }
	elseif w <= 6 then
		return { "goblin", "wolf" }
	elseif w <= 8 then
		return { "wolf", "skeleton" }
	elseif w <= 11 then
		return { "skeleton", "golem", "bat" }
	end
	return { "golem", "wisp", "skeleton" }
end

local function spawnWave()
	wave += 1
	local kinds = kindsFor(wave)
	local count = math.min(2 + wave, 12)
	local function add(kind: string, i: number)
		local a = i * 2.39996 + wave
		local d = radius * (0.35 + (i % 3) * 0.2)
		local pos = centre + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local enemy = EnemyService.spawn(kind, pos, {
			respawn = false,
			leash = radius + 10,
			onDeath = function(e)
				local index = table.find(alive, e)
				if index then
					table.remove(alive, index)
				end
				setHud()
			end,
		})
		table.insert(alive, enemy)
	end
	for i = 1, count do
		add(kinds[(i - 1) % #kinds + 1], i)
	end
	if wave % 10 == 0 then
		add("warden", 99)
	elseif wave % 5 == 0 then
		add("golem", 97)
		add("golem", 98)
	end
	setHud()
	tellFighters(string.format("Wave %d! %d foes enter the arena.", wave, #alive), "#ff9a7a")
end

local function finish()
	for _, e in alive do
		EnemyService.despawn(e)
	end
	table.clear(alive)
	local reached = math.max(0, wave - 1)
	for player in fighters do
		player:SetAttribute("ArenaWave", nil)
		player:SetAttribute("ArenaLeft", nil)
		local session = State.get(player)
		if session then
			session.data.arenaBest = math.max(session.data.arenaBest or 0, reached)
			LeaderboardService.reportStat(player, "arena", session.data.arenaBest)
			State.notify(session, string.format("The trial is over. You survived %d waves (best: %d).", reached, session.data.arenaBest), "#ffd27a")
		end
	end
	table.clear(fighters)
	running = false
	wave = 0
end

local function waveCleared()
	for player in fighters do
		local session = State.get(player)
		if session and onFloor(player) then
			State.addDew(session, 15 * wave, "Arena")
			LevelService.addXP(player, Levels.Gain.arenaWave * wave, "Arena")
			if wave % 10 == 0 then
				CrateService.give(player, "gold")
			elseif wave % 5 == 0 then
				CrateService.give(player, "silver")
			end
			State.notify(session, string.format("Wave %d cleared! +%d Dew", wave, 15 * wave), "#a0ffa0")
		end
	end
end

-- Everyone standing on the floor joins (at the start and before every later wave).
local function recruit()
	for _, player in Players:GetPlayers() do
		if not fighters[player] and onFloor(player) then
			fighters[player] = true
			notify(player, "You join the trial!", "#ffd27a")
		end
	end
end

local function start(by: Player)
	if running then
		notify(by, string.format("A trial is already running (wave %d). Step onto the floor to join the next wave!", wave), "#d8d8d8")
		return
	end
	running = true
	wave = 0
	-- warn everyone near the arena, then gather whoever is on the floor
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - centre).Magnitude < radius * 4 then
			notify(player, "An arena trial begins in 8 seconds! Step onto the sand to fight.", "#ffd27a")
		end
	end
	task.spawn(function()
		task.wait(8)
		recruit()
		if next(fighters) == nil then
			running = false
			notify(by, "Nobody was on the arena floor, so the trial was called off.", "#d8d8d8")
			return
		end
		spawnWave()
		while running do
			task.wait(1)
			for player in fighters do
				if not player.Parent or not onFloor(player) then
					fighters[player] = nil
					player:SetAttribute("ArenaWave", nil)
					player:SetAttribute("ArenaLeft", nil)
				end
			end
			if next(fighters) == nil then
				finish()
				break
			end
			if #alive == 0 then
				waveCleared()
				tellFighters("Next wave in 6 seconds...", "#ffd27a")
				task.wait(6)
				recruit()
				if running and next(fighters) ~= nil then
					spawnWave()
				end
			end
		end
	end)
end

function ArenaService.init(map: Instance)
	local gate: BasePart? = nil
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("ArenaCenter") then
				centre = d.Position - Vector3.new(0, 0.5, 0)
				radius = d:GetAttribute("ArenaRadius") or radius
			elseif d:GetAttribute("ArenaGate") then
				gate = d
			end
		end
	end
	if not gate then
		warn("[ArenaService] no arena gate in the map; trials are disabled")
		return
	end
	local prompt = Prompts.create(gate, "Start a trial", "The Arena", 0.8)
	prompt.MaxActivationDistance = 14
	prompt.Triggered:Connect(start)
end

return ArenaService
