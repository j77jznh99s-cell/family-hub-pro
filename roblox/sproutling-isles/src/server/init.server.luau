-- Sproutling Isles server bootstrap: builds the map if it isn't baked in, starts every
-- service, and manages the player lifecycle (load -> claim plot -> tick income -> save).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Species = require(Shared.Species)
local MapBuilder = require(Shared.MapBuilder)

local Net = require(script.Net)
local State = require(script.State)
local Analytics = require(script.Analytics)
local DataService = require(script.DataService)
local WeatherService = require(script.WeatherService)
local PlotService = require(script.PlotService)
local SnatchService = require(script.SnatchService)
local ShopService = require(script.ShopService)
local PondService = require(script.PondService)
local ProgressionService = require(script.ProgressionService)
local MonetizationService = require(script.MonetizationService)
local LeaderboardService = require(script.LeaderboardService)

local map = workspace:FindFirstChild("Map") or MapBuilder.Build(workspace)

WeatherService.init()
PlotService.init(map)
SnatchService.init()
ShopService.init(map)
PondService.init(map)
ProgressionService.init(map)
MonetizationService.init()
LeaderboardService.init(map)

----------------------------------------------------------------------------------------------
-- player lifecycle

local function onCharacter(session: State.Session, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character:WaitForChild("HumanoidRootPart", 10)
	humanoid.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed
	task.defer(PlotService.teleportHome, session)
	-- VIP name tag
	if session.passes.VIP then
		local head = character:WaitForChild("Head", 5)
		if head then
			local tag = Instance.new("BillboardGui")
			tag.Name = "VIPTag"
			tag.Size = UDim2.fromOffset(100, 24)
			tag.StudsOffset = Vector3.new(0, 2.6, 0)
			tag.MaxDistance = 80
			tag.Parent = head
			local text = Instance.new("TextLabel")
			text.BackgroundTransparency = 1
			text.Size = UDim2.fromScale(1, 1)
			text.Font = Enum.Font.FredokaOne
			text.TextScaled = true
			text.Text = "VIP"
			text.TextColor3 = Color3.fromRGB(255, 210, 60)
			text.TextStrokeTransparency = 0.2
			text.Parent = tag
		end
	end
end

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	-- Rebirths first so the player list sorts by it (Dew is a formatted string, which sorts as text; m13)
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	local dew = Instance.new("StringValue")
	dew.Name = "Dew"
	dew.Parent = stats
	stats.Parent = player
	local seeds = Instance.new("Folder")
	seeds.Name = "Seeds"
	seeds.Parent = player

	local data, persist, isNewSave = DataService.load(player)
	if not player.Parent then
		if persist then
			DataService.save(player, data, true)
		end
		return
	end

	-- 3a step 1 "Joined": only for a save that never existed before, so this never re-fires for a
	-- returning player (including ones who joined before the `onb` field existed).
	if isNewSave and not data.onb.Joined then
		data.onb.Joined = true
		Analytics.onboarding(player, "Joined")
	end

	local now = os.time()
	local shield = if data.playSeconds < Config.NewPlayerShieldSeconds then now + (Config.NewPlayerShieldSeconds - data.playSeconds) else 0
	if data.shieldForfeited or (Config.StudioDisableShield and RunService:IsStudio()) then
		shield = 0 -- m7: snatching gives the shield up for good; M6: Studio test switch
	end
	local session: State.Session = {
		player = player,
		data = data,
		persist = persist,
		plot = nil,
		selectedSeed = nil,
		stock = {},
		lockUntil = 0,
		shieldUntil = shield,
		carrying = nil,
		snatchReadyAt = 0,
		luckUntil = tonumber(data.luckUntil) or 0, -- M5: a paid Luck Boost survives rejoining
		pondReadyAt = 0,
		passes = {},
		joinedAt = now,
		dewRemainder = 0,
		incomeSinceLog = 0,
	}
	State.sessions[player] = session

	if not PlotService.claim(session) then
		-- servers are capped at 8 players (one per plot) in Game Settings; this is a safety net
		player:Kick("This garden island is full. Please join another server!")
		return
	end
	MonetizationService.loadPasses(session)
	ShopService.loadStock(session)
	State.syncAll(session)
	PlotService.renderPads(session)

	player.CharacterAdded:Connect(function(character)
		onCharacter(session, character)
	end)
	if player.Character then
		onCharacter(session, player.Character)
	end

	if not persist then
		State.notify(session, "Saving is off in this server (Studio without API access?). Progress won't be kept.", "#ffb070")
	end
	if data.totalDew == 0 then
		State.notify(session, "Welcome to Sproutling Isles! Walk to the brown soil and plant your free seeds.", "#a0ffa0")
	end
end

-- 3c Income Source event: batched, never per-tick (per-server analytics rate limits). Also
-- reports totalDew to the income leaderboard on the same batch, so that never writes per-tick either.
local function flushIncome(session: State.Session)
	local amount = session.incomeSinceLog or 0
	if amount > 0 then
		Analytics.source(session.player, "Income", amount, session.data.dew)
		session.incomeSinceLog = 0
		LeaderboardService.reportIncome(session.player, session.data.totalDew)
	end
end

local function onPlayerRemoving(player: Player)
	local session = State.get(player)
	if not session or session.leaving then
		return -- m1: PlayerRemoving and BindToClose both call this on shutdown; save once
	end
	session.leaving = true
	flushIncome(session)
	SnatchService.onLeaving(player)
	session.data.playSeconds += os.time() - session.joinedAt
	session.joinedAt = os.time()
	PlotService.release(session)
	if session.persist then
		DataService.save(player, session.data, true)
	end
	State.sessions[player] = nil
end

Net.SelectSeed.OnServerEvent:Connect(function(player, speciesId)
	local session = State.get(player)
	if session and type(speciesId) == "string" and Species.get(speciesId) then
		session.selectedSeed = speciesId
		player:SetAttribute("SelectedSeed", speciesId)
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- income tick
task.spawn(function()
	while true do
		task.wait(1)
		for _, session in State.sessions do
			-- carry fractions over so a 1.2 Dew/s garden really earns 1.2 per second
			local total = State.income(session) + session.dewRemainder
			local whole = math.floor(total)
			session.dewRemainder = total - whole
			if whole > 0 then
				State.addDew(session, whole) -- no reason: logged in the 5-min batch below, not per-tick
				session.incomeSinceLog = (session.incomeSinceLog or 0) + whole
			end
		end
	end
end)

-- batched income analytics: one Source event every 5 min (also flushed on leave, see flushIncome)
task.spawn(function()
	while true do
		task.wait(5 * 60)
		for _, session in State.sessions do
			flushIncome(session)
		end
	end
end)

-- autosave
task.spawn(function()
	while true do
		task.wait(Config.AutosaveSeconds)
		for player, session in State.sessions do
			if session.persist and not session.leaving then -- m2
				local now = os.time()
				session.data.playSeconds += now - session.joinedAt
				session.joinedAt = now
				task.spawn(DataService.save, player, session.data, false)
			end
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player in State.sessions do
		pending += 1
		task.spawn(function()
			onPlayerRemoving(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	-- also wait for saves started by PlayerRemoving (onPlayerRemoving returns early for those)
	while (pending > 0 or DataService.pendingSaves() > 0) and os.clock() < deadline do
		task.wait(0.2)
	end
end)
