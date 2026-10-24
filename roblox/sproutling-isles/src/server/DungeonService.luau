-- Dungeons: teleports, room-by-room clearing, doors, chests and the boss, for every dungeon
-- DungeonBuilder made (The Hollow Crypt under the castle, The Deepdelve Mines under Gorrim's
-- camp). Each runs on its own:
--
-- One run per dungeon per server, shared by everyone inside. The first player through the
-- entrance portal wakes it: every room's monsters spawn and all doors close except the first.
-- Clearing a room raises the portcullis to the next. The treasure vault and the boss chest can
-- each be opened once per player per run. Killing the boss opens the exit portal; the dungeon
-- resets 2 minutes after that, or once it has been empty for a minute. A dungeon with a
-- MinLevel turns away players below it.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage:WaitForChild("Shared").Combat)

local State = require(script.Parent.State)
local Prompts = require(script.Parent.Prompts)
local EnemyService = require(script.Parent.EnemyService)
local LootService = require(script.Parent.LootService)

local DungeonService = {}

-- which dungeon each player is inside (by root folder name), so two dungeons never both claim them
local insideOf: { [Player]: string } = {}

local function teleport(player: Player, to: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if character and root then
		pcall(player.RequestStreamAroundAsync, player, to, 3) -- streaming: load the floor first
		character:PivotTo(CFrame.new(to))
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if player and humanoid and humanoid.Health > 0 then
		return player
	end
	return nil
end

-- Runs one dungeon: `root` is its folder (Map.Dungeon, Map.Mines); interior/portal are the
-- names DungeonBuilder gave its inside folder and its entrance portal.
local function run(root: Instance, interiorName: string, portalName: string)
	local title = root:GetAttribute("Title") or root.Name
	local minLevel = root:GetAttribute("MinLevel") or 1
	local crypt = root:WaitForChild(interiorName)
	local entrance = root:WaitForChild("Entrance")
	local entryPad = crypt:WaitForChild("EntryPad") :: BasePart
	local returnPoint = entrance:WaitForChild("ReturnPoint") :: BasePart
	local bossExit = crypt:WaitForChild("BossExit") :: BasePart

	local active = false
	local roomAlive: { [number]: number } = {}
	local roomCleared: { [number]: boolean } = {}
	local doors: { [number]: Model } = {}
	local doorHome: { [number]: CFrame } = {}
	local living: { any } = {}
	local opened: { [string]: { [number]: boolean } } = {}
	local inside: { [Player]: boolean } = {}
	local emptySince: number? = nil
	local resetAt: number? = nil
	local roomCount = 0

	local function tell(text: string, color: string?)
		for player in inside do
			local session = State.get(player)
			if session then
				State.notify(session, text, color)
			end
		end
	end

	local function setDoor(index: number, open: boolean, instant: boolean?)
		local door = doors[index]
		local home = doorHome[index]
		if not door or not home then
			return
		end
		local goal = if open then home + Vector3.new(0, 15, 0) else home
		local gate = door.PrimaryPart :: BasePart
		gate.CanCollide = not open
		if instant then
			door:PivotTo(goal)
			return
		end
		-- tween a CFrameValue and pivot the whole portcullis with it
		local value = Instance.new("CFrameValue")
		value.Value = door:GetPivot()
		value.Changed:Connect(function(cf)
			door:PivotTo(cf)
		end)
		local tween = TweenService:Create(value, TweenInfo.new(2, Enum.EasingStyle.Sine), { Value = goal })
		tween.Completed:Connect(function()
			value:Destroy()
		end)
		tween:Play()
	end

	local function roomName(index: number): string
		local rooms = crypt:FindFirstChild("Rooms")
		local f = rooms and rooms:FindFirstChild("Room" .. index)
		return f and f:GetAttribute("RoomName") or ("room " .. index)
	end

	local function clearRoom(index: number)
		if roomCleared[index] then
			return
		end
		roomCleared[index] = true
		if doors[index] then
			setDoor(index, true)
			if index > 0 then
				tell(roomName(index) .. " is clear. The way ahead opens...", "#c8b4ff")
			end
			-- an empty room beyond (the vault) clears as soon as its door opens
			local nextRoom = index + 1
			if (roomAlive[nextRoom] or 0) == 0 and nextRoom < roomCount - 1 then
				clearRoom(nextRoom)
			end
		end
	end

	local function bossDown(name: string)
		bossExit:SetAttribute("Active", true)
		bossExit.Transparency = 0.35
		tell(name .. " falls! The way out shimmers open. " .. title .. " resets in 2 minutes.", "#ffd27a")
		resetAt = os.clock() + 120
	end

	local function reset()
		for _, e in living do
			EnemyService.despawn(e)
		end
		table.clear(living)
		table.clear(roomAlive)
		table.clear(roomCleared)
		table.clear(opened)
		for index in doors do
			setDoor(index, false, true)
		end
		bossExit:SetAttribute("Active", false)
		bossExit.Transparency = 1
		active = false
		resetAt = nil
		emptySince = nil
	end

	local function wake()
		reset()
		active = true
		for _, spawn in (crypt:FindFirstChild("Spawns") :: Instance):GetChildren() do
			local room = spawn:GetAttribute("Room") :: number
			local kind = spawn:GetAttribute("Kind") :: string
			if room and kind then
				local isBoss = spawn:GetAttribute("Boss") == true or kind == "warden"
				roomAlive[room] = (roomAlive[room] or 0) + 1
				local enemy = EnemyService.spawn(kind, (spawn :: BasePart).CFrame.Position - Vector3.new(0, 0.5, 0), {
					respawn = false,
					leash = 45,
					onDeath = function(e)
						local i = table.find(living, e)
						if i then
							table.remove(living, i)
						end
						roomAlive[room] -= 1
						if isBoss then
							local def = Combat.Enemies[kind]
							bossDown(if def then def.name else "The guardian")
						end
						if roomAlive[room] <= 0 then
							clearRoom(room)
						end
					end,
				})
				table.insert(living, enemy)
			end
		end
		-- rooms with no monsters (the entry hall) open straight away
		clearRoom(0)
	end

	local function enter(player: Player)
		if inside[player] or insideOf[player] then
			return
		end
		local level = player:GetAttribute("Level") or 1
		if level < minLevel then
			local session = State.get(player)
			if session then
				State.notify(session, string.format("%s is too dangerous below level %d. You're level %d.", title, minLevel, level), "#ffb070")
			end
			return
		end
		if not active then
			wake()
		end
		inside[player] = true
		insideOf[player] = root.Name
		player:SetAttribute("InDungeon", true)
		teleport(player, entryPad.CFrame.Position + Vector3.new(0, 3, 0))
		local session = State.get(player)
		if session then
			State.notify(session, "You descend into " .. title .. "...", "#c8b4ff")
		end
	end

	local function leave(player: Player)
		if not inside[player] then
			return
		end
		inside[player] = nil
		insideOf[player] = nil
		player:SetAttribute("InDungeon", false)
		teleport(player, returnPoint.CFrame.Position + Vector3.new(0, 3, 0))
	end

	local rooms = crypt:FindFirstChild("Rooms") :: Instance
	for _, r in rooms:GetChildren() do
		if r.Name:match("^Room%d+$") then
			roomCount += 1
		end
	end
	for _, door in (crypt:WaitForChild("Doors") :: Instance):GetChildren() do
		local index = door:GetAttribute("Room") :: number
		if index and door:IsA("Model") then
			doors[index] = door
			doorHome[index] = door:GetPivot()
		end
	end

	local debounce: { [Player]: number } = {}
	local function touched(portal: BasePart, fn: (Player) -> ())
		portal.CanTouch = true
		portal.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if not player or os.clock() < (debounce[player] or 0) then
				return
			end
			if portal:GetAttribute("Active") == false then
				return
			end
			debounce[player] = os.clock() + 2
			fn(player)
		end)
	end
	touched(entrance:WaitForChild(portalName) :: BasePart, enter)
	touched(crypt:WaitForChild("ExitPortal") :: BasePart, leave)
	touched(bossExit, leave)

	-- chests: a prompt each, once per player per run, only after their room is reached
	for _, chest in (crypt:WaitForChild("Chests") :: Instance):GetChildren() do
		local kind = chest:GetAttribute("Chest") :: string
		local room = chest:GetAttribute("Room") :: number
		local base = chest:FindFirstChild("Base") :: BasePart
		if kind and base then
			local prompt = Prompts.create(base, "Open", if kind == "boss" then "Guardian's Hoard" else "Treasure Chest", 0.6)
			prompt.Triggered:Connect(function(player)
				if not inside[player] or not active then
					return
				end
				local session = State.get(player)
				local reachable = if kind == "boss" then bossExit:GetAttribute("Active") == true else roomCleared[room - 1] == true
				if not reachable then
					if session then
						State.notify(session, "It's sealed by dark magic. Clear the way first.", "#c8b4ff")
					end
					return
				end
				opened[kind] = opened[kind] or {}
				if opened[kind][player.UserId] then
					if session then
						State.notify(session, "You've already emptied this chest this run.", "#d8d8d8")
					end
					return
				end
				opened[kind][player.UserId] = true
				LootService.openChest(player, kind)
			end)
		end
	end

	reset()

	Players.PlayerRemoving:Connect(function(player)
		inside[player] = nil
		debounce[player] = nil
	end)
	-- dying inside sends you back to your plot; you're no longer "inside"
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			if inside[player] then
				inside[player] = nil
				insideOf[player] = nil
				player:SetAttribute("InDungeon", false)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end

	task.spawn(function()
		while true do
			task.wait(2)
			if active then
				local anyone = next(inside) ~= nil
				local t = os.clock()
				if anyone then
					emptySince = nil
				else
					emptySince = emptySince or t
				end
				if (emptySince and t - emptySince > 60) or (resetAt and t >= resetAt) then
					for player in inside do
						leave(player)
					end
					reset()
				end
			end
		end
	end)
end

function DungeonService.init(map: Instance)
	local found = false
	for _, def in { { "Dungeon", "Crypt", "CryptPortal" }, { "Mines", "Depths", "MinePortal" }, { "Emberdeep", "Caldera", "EmberPortal" } } do
		local root = map:FindFirstChild(def[1])
		if root then
			found = true
			task.spawn(run, root, def[2], def[3])
		end
	end
	if not found then
		warn("[DungeonService] no dungeons in the map; they are disabled")
	end
	Players.PlayerRemoving:Connect(function(player)
		insideOf[player] = nil
	end)
end

return DungeonService
