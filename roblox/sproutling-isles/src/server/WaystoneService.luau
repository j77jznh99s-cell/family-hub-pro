-- Waystones (Shared/Waystones): fast-travel checkpoints.
--
-- Each waystone's prompt attunes it the first time (a little XP) and opens the travel window.
-- From a waystone, travel to any attuned waystone is free and instant; from the world map it
-- works anywhere, once a minute. Not from inside a dungeon or during an arena trial. Attuned
-- waystones are saved in data.waystones; the client gets the list (and the map cooldown) after
-- every change, and a "flash" when it arrives.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Waystones = require(Shared.Waystones)

local State = require(script.Parent.State)
local Prompts = require(script.Parent.Prompts)
local LevelService = require(script.Parent.LevelService)
local VehicleService = require(script.Parent.VehicleService)

local WaystoneService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local WaystoneRemote = Instance.new("RemoteEvent")
WaystoneRemote.Name = "Waystone"
-- client -> server: ("travel", id, fromMap)
-- server -> client: ("state", { [id] = true }, seconds until map travel is ready) | ("open", nearId) | ("arrive", name)
WaystoneRemote.Parent = remotes

local stones: { [string]: { pos: Vector3, name: string } } = {}
local mapReadyAt: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}

local function attuned(player: Player): { [string]: boolean }?
	local session = State.get(player)
	if not session then
		return nil
	end
	session.data.waystones = session.data.waystones or {}
	return session.data.waystones
end

local function push(player: Player)
	local list = attuned(player)
	if list then
		WaystoneRemote:FireClient(player, "state", list, math.max(0, (mapReadyAt[player] or 0) - os.clock()))
	end
end

local function notify(player: Player, text: string, color: string?)
	local session = State.get(player)
	if session then
		State.notify(session, text, color)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The attuned waystone the player is standing at, if any.
local function nearStone(player: Player): string?
	local root = rootOf(player)
	if not root then
		return nil
	end
	for id, s in stones do
		if (root.Position - s.pos).Magnitude < 16 then
			return id
		end
	end
	return nil
end

local function travel(player: Player, id: any, fromMap: any)
	local list = attuned(player)
	local target = typeof(id) == "string" and stones[id]
	local root = rootOf(player)
	if not list or not target or not root or busy[player] then
		return
	end
	if not list[id] then
		notify(player, "You haven't attuned that waystone yet. Find it and touch it first.", "#ffb070")
		return
	end
	if player:GetAttribute("InDungeon") or player:GetAttribute("ArenaWave") then
		notify(player, "The waystones can't reach you here.", "#ffb070")
		return
	end
	local here = nearStone(player)
	if not here then
		if fromMap ~= true then
			return
		end
		local now = os.clock()
		if now < (mapReadyAt[player] or 0) then
			notify(player, string.format("Your travel magic is recharging (%ds). Waystones themselves have no wait.", math.ceil((mapReadyAt[player] or 0) - now)), "#bfe3ff")
			return
		end
		mapReadyAt[player] = now + Waystones.MapCooldown
	end
	busy[player] = true
	VehicleService.dismiss(player)
	task.delay(0.6, function()
		busy[player] = nil
		local character = player.Character
		local r = rootOf(player)
		if character and r then
			local to = target.pos + Vector3.new(5, 4, 5)
			pcall(player.RequestStreamAroundAsync, player, to, 3)
			character:PivotTo(CFrame.new(to))
			r.AssemblyLinearVelocity = Vector3.zero
			WaystoneRemote:FireClient(player, "arrive", target.name)
			local session = State.get(player)
			if session then
				State.track(session, "travel")
			end
		end
		push(player)
	end)
end

function WaystoneService.init(map: Instance)
	for _, d in map:GetDescendants() do
		local id = d:GetAttribute("Waystone")
		if d:IsA("BasePart") and typeof(id) == "string" and Waystones.ById[id] then
			local name = Waystones.ById[id].name
			stones[id] = { pos = d.Position, name = name }
			local prompt = Prompts.create(d, "Use waystone", name, 0.3)
			prompt.MaxActivationDistance = 14
			prompt.Triggered:Connect(function(player)
				local list = attuned(player)
				if not list then
					return
				end
				if not list[id] then
					list[id] = true
					local count = 0
					for _ in list do
						count += 1
					end
					notify(player, string.format("Waystone attuned: %s! (%d of %d)", name, count, #Waystones.List), "#9fe0ff")
					LevelService.addXP(player, Waystones.AttuneXP, "Waystone")
				end
				push(player)
				WaystoneRemote:FireClient(player, "open", id)
			end)
		end
	end
	WaystoneRemote.OnServerEvent:Connect(function(player, action, id, fromMap)
		if action == "travel" then
			travel(player, id, fromMap)
		end
	end)
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
	Players.PlayerRemoving:Connect(function(player)
		mapReadyAt[player] = nil
		busy[player] = nil
	end)
end

return WaystoneService
