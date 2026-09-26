-- Plot ownership, planting, hatching, display pads, selling from pads and the gate lock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Species = require(Shared.Species)
local SproutModel = require(Shared.SproutModel)
local Format = require(Shared.Format)
local MapBuilder = require(Shared.MapBuilder)

local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local Analytics = require(script.Parent.Analytics)
local Prompts = require(script.Parent.Prompts)
local WeatherService = require(script.Parent.WeatherService)
local LeaderboardService = require(script.Parent.LeaderboardService)

local PlotService = {}

local MAX_STORAGE = 60
local SELL_CONFIRM_SECONDS = 5
local RARE_OR_BETTER = { Rare = true, Epic = true, Legendary = true, Mythic = true, Secret = true }
local ANNOUNCE_MUTATIONS = { starry = true, prismatic = true, golden = true }
local ANNOUNCE_RARITIES = { Legendary = true, Mythic = true, Secret = true }

local sellConfirmUntil: { [Player]: number } = {}

type PlotInfo = {
	model: Model,
	index: number,
	cx: number,
	cz: number,
	inward: number,
	owner: Player?,
	soilPrompts: { ProximityPrompt },
	sellPrompts: { ProximityPrompt },
	snatchPrompts: { ProximityPrompt },
	lockPrompt: ProximityPrompt,
	plantVisuals: { [number]: BasePart },
	padVisuals: { [number]: Model },
}

local plots: { PlotInfo } = {}
local plotByModel: { [Model]: PlotInfo } = {}

----------------------------------------------------------------------------------------------
-- geometry

local function worldPoint(info: PlotInfo, u: number, y: number, v: number): Vector3
	return Vector3.new(info.cx + info.inward * u, y, info.cz + v)
end

function PlotService.isInside(plot: Model, position: Vector3): boolean
	local info = plotByModel[plot]
	if not info then
		return false
	end
	local half = MapBuilder.PlotSize / 2
	return math.abs(position.X - info.cx) <= half and math.abs(position.Z - info.cz) <= half + 2
end

function PlotService.gateOutside(plot: Model): CFrame
	local info = plotByModel[plot]
	local pos = worldPoint(info, MapBuilder.PlotSize / 2 + 10, 4, 0)
	return CFrame.lookAt(pos, pos + Vector3.new(info.inward, 0, 0))
end

function PlotService.info(plot: Model): PlotInfo?
	return plotByModel[plot]
end

----------------------------------------------------------------------------------------------
-- visuals

-- MapBuilder labels are BillboardGui "Label" > TextLabel "Text".
local function labelOf(part: Instance?): TextLabel?
	local gui = part and part:FindFirstChild("Label")
	return gui and gui:FindFirstChild("Text") :: TextLabel?
end

local function setSign(info: PlotInfo)
	local label = labelOf(info.model:FindFirstChild("Sign"))
	if label then
		local colorName = info.model:GetAttribute("ColorName")
		label.Text = if info.owner then info.owner.DisplayName .. "'s Garden" else colorName .. " plot - unclaimed"
	end
end

local function clearPads(info: PlotInfo)
	for _, model in info.padVisuals do
		model:Destroy()
	end
	table.clear(info.padVisuals)
end

function PlotService.renderPads(session: State.Session)
	local plot = session.plot
	local info = plot and plotByModel[plot]
	if not info then
		return
	end
	clearPads(info)
	local capacity = State.padCapacity(session)
	local mult = State.multiplier(session)
	for pad = 1, 12 do
		local padPart = info.model.Pads:FindFirstChild("Pad" .. pad) :: BasePart
		padPart.Transparency = if pad <= capacity then 0 else 0.7
		local sprout = session.data.pads[tostring(pad)]
		info.sellPrompts[pad]:SetAttribute("Active", sprout ~= nil)
		if sprout then
			local species = Species.get(sprout.s)
			-- longer hold for Rare and better so they aren't sold by accident
			info.sellPrompts[pad].HoldDuration = if species and RARE_OR_BETTER[species.rarity] then 1 else 0.4
			local model = SproutModel.build(sprout, true)
			local top = padPart.Position + Vector3.new(0, padPart.Size.X / 2, 0)
			model:PivotTo(CFrame.lookAt(top, top + Vector3.new(info.inward, 0, 0)))
			local incomeLabel = model:FindFirstChild("Income", true) :: TextLabel?
			if incomeLabel then
				incomeLabel.Text = "+" .. Format.number(SproutModel.income(sprout) * mult) .. " Dew/s"
			end
			model.Parent = info.model
			info.padVisuals[pad] = model
			info.sellPrompts[pad].ObjectText = SproutModel.displayName(sprout)
			info.sellPrompts[pad].ActionText = "Sell for " .. Format.number(State.sellValue(sprout))
			info.snatchPrompts[pad].ObjectText = SproutModel.displayName(sprout) .. (species and (" (" .. species.rarity .. ")") or "")
		end
	end
	PlotService.refreshSnatchable(session)
	session.player:SetAttribute("Stored", #session.data.storage)
	State.syncDew(session)
end

-- Snatch prompts only show (for other players) on filled pads while the gate is open and the
-- owner's new-player shield has run out. The server re-checks all of this on trigger anyway.
function PlotService.refreshSnatchable(session: State.Session)
	local info = session.plot and plotByModel[session.plot]
	if not info then
		return
	end
	local open = not PlotService.isLocked(session) and session.shieldUntil <= os.time()
	for pad = 1, 12 do
		info.snatchPrompts[pad]:SetAttribute("Active", open and session.data.pads[tostring(pad)] ~= nil)
	end
end

local function plantVisual(info: PlotInfo, tile: number): BasePart
	local existing = info.plantVisuals[tile]
	if existing then
		return existing
	end
	local soil = info.model.Soil:FindFirstChild("Soil" .. tile) :: BasePart
	local bud = Instance.new("Part")
	bud.Name = "Plant"
	bud.Shape = Enum.PartType.Ball
	bud.Anchored = true
	bud.CanCollide = false
	bud.CanQuery = false
	bud.Material = Enum.Material.Grass
	bud.Position = soil.Position + Vector3.new(0, 1, 0)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Parent = bud
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Parent = gui
	bud.Parent = info.model
	info.plantVisuals[tile] = bud
	return bud
end

local function updateSoil(info: PlotInfo, session: State.Session?)
	local now = os.time()
	for tile = 1, Config.SoilTilesPerPlot do
		local plant = session and session.data.soil[tostring(tile)]
		local prompt = info.soilPrompts[tile]
		if not plant then
			local visual = info.plantVisuals[tile]
			if visual then
				visual:Destroy()
				info.plantVisuals[tile] = nil
			end
			prompt.ActionText = "Plant seed"
			prompt:SetAttribute("Active", session ~= nil)
		else
			local species = Species.get(plant.s)
			local remaining = plant.ready - now
			local progress = math.clamp(1 - remaining / plant.total, 0, 1)
			local bud = plantVisual(info, tile)
			local size = 1 + progress * 3
			local soil = info.model.Soil:FindFirstChild("Soil" .. tile) :: BasePart
			bud.Size = Vector3.new(size, size, size)
			bud.Position = soil.Position + Vector3.new(0, 0.6 + size / 2, 0)
			bud.Color = species and species.leaf or Color3.new(0, 1, 0)
			local text = (bud :: any).Info.Text :: TextLabel
			if remaining <= 0 then
				bud.Material = Enum.Material.Neon
				text.Text = (species and species.name or "?") .. " - READY!"
				text.TextColor3 = Color3.fromRGB(255, 240, 120)
				prompt.ActionText = "Hatch!"
				prompt:SetAttribute("Active", true)
			else
				bud.Material = Enum.Material.Grass
				text.Text = (species and species.name or "?") .. " " .. Format.time(remaining)
				text.TextColor3 = Color3.new(1, 1, 1)
				prompt:SetAttribute("Active", false)
			end
		end
	end
end

----------------------------------------------------------------------------------------------
-- actions

-- Puts a Sproutling on the first free pad, or into storage. Returns false if everything is full.
-- `force` lets storage go past MAX_STORAGE (used when a stolen Sproutling comes home, so it is never deleted).
function PlotService.placeSprout(session: State.Session, sprout, force: boolean?): boolean
	for pad = 1, State.padCapacity(session) do
		if not session.data.pads[tostring(pad)] then
			session.data.pads[tostring(pad)] = sprout
			PlotService.renderPads(session)
			return true
		end
	end
	if #session.data.storage >= MAX_STORAGE and not force then
		return false
	end
	table.insert(session.data.storage, sprout)
	session.player:SetAttribute("Stored", #session.data.storage)
	return true
end

-- Moves the best stored Sproutlings onto any empty pads.
function PlotService.refillPads(session: State.Session)
	table.sort(session.data.storage, function(a, b)
		return SproutModel.income(a) > SproutModel.income(b)
	end)
	local changed = false
	for pad = 1, State.padCapacity(session) do
		if not session.data.pads[tostring(pad)] and #session.data.storage > 0 then
			session.data.pads[tostring(pad)] = table.remove(session.data.storage, 1)
			changed = true
		end
	end
	if changed then
		PlotService.renderPads(session)
	end
end

local function chooseSeed(session: State.Session): string?
	local selected = session.selectedSeed
	if selected and (session.data.seeds[selected] or 0) > 0 then
		return selected
	end
	for _, species in Species.List do
		if (session.data.seeds[species.id] or 0) > 0 then
			return species.id
		end
	end
	return nil
end

local function onSoil(info: PlotInfo, tile: number, player: Player)
	local session = State.get(player)
	if not session or info.owner ~= player then
		return
	end
	local key = tostring(tile)
	local plant = session.data.soil[key]
	if not plant then
		local seedId = chooseSeed(session)
		if not seedId then
			State.notify(session, "You have no seeds! Buy some at the Seed Shop or the Pollen Parade.", "#ffb070")
			-- 3d NoSeeds: a friction signal (this can mean a soft-lock); value is the Dew balance
			Analytics.custom(player, "NoSeeds", session.data.dew)
			return
		end
		local species = Species.get(seedId) :: Species.Species
		State.addSeeds(session, seedId, -1)
		session.data.soil[key] = { s = seedId, ready = os.time() + species.growSeconds, total = species.growSeconds }
		updateSoil(info, session)
		if not session.data.onb.FirstPlant then
			session.data.onb.FirstPlant = true
			Analytics.onboarding(player, "FirstPlant")
		end
	elseif plant.ready <= os.time() then
		local activeWeather = WeatherService.current()
		local wasWeather = activeWeather ~= nil
		local sprout = { s = plant.s, m = WeatherService.rollMutation(session), z = WeatherService.rollSize(), u = State.newUid() }
		if not PlotService.placeSprout(session, sprout) then
			State.notify(session, "Your greenhouse and storage are full! Sell some Sproutlings first.", "#ff8080")
			-- 3d StorageFull: a friction signal
			Analytics.custom(player, "StorageFull", 1)
			return
		end
		session.data.soil[key] = nil
		updateSoil(info, session)
		if not session.data.onb.FirstHatch then
			session.data.onb.FirstHatch = true
			Analytics.onboarding(player, "FirstHatch")
		end
		if wasWeather and not session.data.onb.FirstWeatherHatch then
			session.data.onb.FirstWeatherHatch = true
			Analytics.onboarding(player, "FirstWeatherHatch")
		end
		local species = Species.get(sprout.s) :: Species.Species
		LeaderboardService.reportHatch(player, session, species)
		WeatherService.registerHatch()
		-- 3d Hatch / HugeHatch. species order comes from Species.luau's load-order index.
		Analytics.custom(player, "Hatch", (species :: any).order, { species.rarity, sprout.m or "none", if activeWeather then activeWeather.id else "clear" })
		if sprout.z >= 2 then
			Analytics.custom(player, "HugeHatch", sprout.z, { species.rarity, sprout.m or "none" })
		end
		Net.Effect:FireClient(player, "Hatch", { name = SproutModel.displayName(sprout), rarity = species.rarity, mutation = sprout.m, size = sprout.z })
		-- only the exciting ones go server-wide (Dewy/Charged are common during weather)
		if (sprout.m and ANNOUNCE_MUTATIONS[sprout.m]) or sprout.z >= 2 or ANNOUNCE_RARITIES[species.rarity] then
			Net.announce(player.DisplayName .. " hatched a " .. SproutModel.displayName(sprout) .. "!", "#ffe070")
		end
	end
end

local function onSell(info: PlotInfo, pad: number, player: Player)
	local session = State.get(player)
	if not session or info.owner ~= player then
		return
	end
	local sprout = session.data.pads[tostring(pad)]
	if not sprout then
		return
	end
	session.data.pads[tostring(pad)] = nil
	local value = State.sellValue(sprout)
	State.addDew(session, value, "Sell:" .. sprout.s)
	if not session.data.onb.FirstSell then
		session.data.onb.FirstSell = true
		Analytics.onboarding(player, "FirstSell")
	end
	State.notify(session, "Sold " .. SproutModel.displayName(sprout) .. " for " .. Format.number(value) .. " Dew", "#a0ffa0")
	PlotService.renderPads(session)
	PlotService.refillPads(session)
end

function PlotService.sellStorage(session: State.Session)
	local total = 0
	for _, sprout in session.data.storage do
		total += State.sellValue(sprout)
	end
	local count = #session.data.storage
	if count == 0 then
		State.notify(session, "Nothing in storage. Sproutlings go to storage when your pads are full.")
		return
	end
	-- selling Rare+ Sproutlings needs a second trigger within a few seconds
	local rares = 0
	for _, sprout in session.data.storage do
		local species = Species.get(sprout.s)
		if species and RARE_OR_BETTER[species.rarity] then
			rares += 1
		end
	end
	local player = session.player
	if rares > 0 and (sellConfirmUntil[player] or 0) < os.clock() then
		sellConfirmUntil[player] = os.clock() + SELL_CONFIRM_SECONDS
		State.notify(session, "Storage has " .. rares .. " Rare or better Sproutling(s). Use the Sell Stand again within " .. SELL_CONFIRM_SECONDS .. "s to sell all " .. count .. ".", "#ffb070")
		return
	end
	sellConfirmUntil[player] = nil
	table.clear(session.data.storage)
	State.addDew(session, total, "SellStorage")
	if not session.data.onb.FirstSell then
		session.data.onb.FirstSell = true
		Analytics.onboarding(player, "FirstSell")
	end
	session.player:SetAttribute("Stored", 0)
	State.notify(session, "Sold " .. count .. " stored Sproutlings for " .. Format.number(total) .. " Dew", "#a0ffa0")
end

local function setGateVisual(info: PlotInfo, locked: boolean)
	local laser = info.model.Gate:FindFirstChild("Laser") :: BasePart
	laser.Transparency = if locked then 0.35 else 1
	local button = info.model.Gate:FindFirstChild("LockButton") :: BasePart
	button.Color = if locked then Color3.fromRGB(80, 220, 120) else Color3.fromRGB(255, 80, 80)
end

-- 3d GateLock's "had a thief nearby?" field: any other online player within roughly one plot's
-- width of this plot's centre, at the moment of locking. Not an exact definition from the spec
-- (there's no existing "nearby" concept to reuse); documented as an interpretation.
local NEARBY_THIEF_RADIUS = MapBuilder.PlotSize / 2 + 20

local function hasNearbyThief(info: PlotInfo, owner: Player): boolean
	for _, other in Players:GetPlayers() do
		if other ~= owner then
			local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(info.cx, 0, info.cz)).Magnitude <= NEARBY_THIEF_RADIUS then
				return true
			end
		end
	end
	return false
end

local function onLock(info: PlotInfo, player: Player)
	local session = State.get(player)
	if not session or info.owner ~= player then
		return
	end
	if PlotService.isLocked(session) then
		return -- already locked (prompt should be hidden; guards a stale client)
	end
	local seconds = if session.passes.SturdyGate then Config.LockSecondsWithPass else Config.LockSeconds
	session.lockUntil = os.time() + seconds
	Analytics.custom(player, "GateLock", seconds, { if hasNearbyThief(info, player) then "y" else "n" })
	if not session.data.onb.FirstGateLock then
		session.data.onb.FirstGateLock = true
		Analytics.onboarding(player, "FirstGateLock")
	end
	info.lockPrompt:SetAttribute("Active", false)
	PlotService.refreshSnatchable(session)
	setGateVisual(info, true)
	State.notify(session, "Gate locked for " .. seconds .. "s. Nobody can snatch from you!", "#80ff80")
end

function PlotService.isLocked(session: State.Session): boolean
	return session.lockUntil > os.time()
end

----------------------------------------------------------------------------------------------
-- ownership

function PlotService.claim(session: State.Session): boolean
	for _, info in plots do
		if not info.owner then
			info.owner = session.player
			session.plot = info.model
			local id = session.player.UserId
			info.model:SetAttribute("OwnerUserId", id)
			for _, prompt in info.soilPrompts do
				prompt:SetAttribute("OnlyUser", id)
			end
			for _, prompt in info.sellPrompts do
				prompt:SetAttribute("OnlyUser", id)
			end
			for _, prompt in info.snatchPrompts do
				-- everyone but the owner may see these (B1: OnlyUser must be cleared or nobody sees them)
				prompt:SetAttribute("OnlyUser", nil)
				prompt:SetAttribute("ExceptUser", id)
			end
			info.lockPrompt:SetAttribute("OnlyUser", id)
			info.lockPrompt:SetAttribute("Active", true)
			setSign(info)
			setGateVisual(info, false)
			session.player:SetAttribute("PlotColor", info.model:GetAttribute("ColorName"))
			PlotService.renderPads(session)
			PlotService.refillPads(session)
			updateSoil(info, session)
			if not session.data.onb.PlotClaimed then
				session.data.onb.PlotClaimed = true
				Analytics.onboarding(session.player, "PlotClaimed")
			end
			return true
		end
	end
	return false
end

function PlotService.release(session: State.Session)
	local info = session.plot and plotByModel[session.plot]
	if not info then
		return
	end
	info.owner = nil
	info.model:SetAttribute("OwnerUserId", 0)
	-- back to the same state init() leaves them in
	for _, list in { info.soilPrompts, info.sellPrompts } do
		for _, prompt in list do
			prompt:SetAttribute("OnlyUser", 0)
			prompt:SetAttribute("ExceptUser", nil)
			prompt:SetAttribute("Active", false)
		end
	end
	for _, prompt in info.snatchPrompts do
		prompt:SetAttribute("OnlyUser", nil)
		prompt:SetAttribute("ExceptUser", nil)
		prompt:SetAttribute("Active", false) -- hidden for everyone while unclaimed
	end
	info.lockPrompt:SetAttribute("OnlyUser", 0)
	info.lockPrompt:SetAttribute("Active", false)
	sellConfirmUntil[session.player] = nil
	clearPads(info)
	updateSoil(info, nil)
	setGateVisual(info, false)
	for pad = 9, 12 do
		(info.model.Pads:FindFirstChild("Pad" .. pad) :: BasePart).Transparency = 0.7
	end
	setSign(info)
	local lockLabel = labelOf(info.model.Gate.LockButton)
	if lockLabel then
		lockLabel.Text = "LOCK"
	end
	session.plot = nil
end

function PlotService.teleportHome(session: State.Session)
	local character = session.player.Character
	local plot = session.plot
	if not character or not plot then
		return
	end
	local spawnPoint = plot:FindFirstChild("SpawnPoint") :: BasePart
	character:PivotTo(spawnPoint.CFrame + Vector3.new(0, 3, 0))
end

----------------------------------------------------------------------------------------------

function PlotService.init(map: Instance)
	for _, model in map.Plots:GetChildren() do
		local index = model:GetAttribute("Index")
		local cx, cz, inward = MapBuilder.plotPlacement(index)
		local info: PlotInfo = {
			model = model,
			index = index,
			cx = cx,
			cz = cz,
			inward = inward,
			owner = nil,
			soilPrompts = {},
			sellPrompts = {},
			snatchPrompts = {},
			lockPrompt = nil :: any,
			plantVisuals = {},
			padVisuals = {},
		}
		for tile = 1, Config.SoilTilesPerPlot do
			local prompt = Prompts.create(model.Soil:FindFirstChild("Soil" .. tile), "Plant seed", "Soil")
			prompt:SetAttribute("OnlyUser", 0)
			prompt:SetAttribute("Active", false)
			prompt.Triggered:Connect(function(player)
				onSoil(info, tile, player)
			end)
			info.soilPrompts[tile] = prompt
		end
		for pad = 1, 12 do
			local padPart = model.Pads:FindFirstChild("Pad" .. pad)
			local sell = Prompts.create(padPart, "Sell", "", 0.4, Enum.KeyCode.F)
			sell:SetAttribute("OnlyUser", 0)
			sell:SetAttribute("Active", false)
			sell.Triggered:Connect(function(player)
				onSell(info, pad, player)
			end)
			info.sellPrompts[pad] = sell
			local snatch = Prompts.create(padPart, "Snatch!", "", Config.SnatchHoldSeconds)
			-- no OnlyUser here: Active=false hides it until an owner claims the plot (see claim())
			snatch:SetAttribute("Active", false)
			info.snatchPrompts[pad] = snatch
		end
		local lock = Prompts.create(model.Gate.LockButton, "Lock gate", "Gate")
		lock:SetAttribute("OnlyUser", 0)
		lock:SetAttribute("Active", false)
		lock.Triggered:Connect(function(player)
			onLock(info, player)
		end)
		info.lockPrompt = lock
		table.insert(plots, info)
		plotByModel[model] = info
	end
	table.sort(plots, function(a, b)
		return a.index < b.index
	end)

	-- 1 Hz: growth, weather speed-up, lock expiry
	task.spawn(function()
		while true do
			local dt = task.wait(1)
			local speed = WeatherService.growthSpeed()
			for _, info in plots do
				local session = info.owner and State.get(info.owner)
				if session then
					if speed > 1 then
						for _, plant in session.data.soil do
							plant.ready -= (speed - 1) * dt
						end
					end
					if session.lockUntil > 0 and session.lockUntil <= os.time() then
						session.lockUntil = 0
						setGateVisual(info, false)
						info.lockPrompt:SetAttribute("Active", true)
						PlotService.renderPads(session)
						State.notify(session, "Your gate is OPEN again. Go lock it!", "#ff9090")
					end
					if session.shieldUntil > 0 and session.shieldUntil <= os.time() then
						session.shieldUntil = 0
						session.player:SetAttribute("ShieldUntil", 0)
						PlotService.refreshSnatchable(session)
					end
					local lbl = labelOf(info.model.Gate.LockButton)
					if lbl then
						lbl.Text = if PlotService.isLocked(session) then "LOCKED " .. (session.lockUntil - os.time()) .. "s" else "OPEN - LOCK"
					end
				end
				updateSoil(info, session)
			end
		end
	end)

	-- 4 Hz: push intruders out of locked gardens
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, info in plots do
				local session = info.owner and State.get(info.owner)
				if session and PlotService.isLocked(session) then
					for _, other in Players:GetPlayers() do
						local root = other ~= info.owner and other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root and PlotService.isInside(info.model, root.Position) then
							local otherSession = State.get(other)
							if otherSession then
								otherSession.serverMovedAt = os.clock() -- not a speed hack (see SnatchService)
								otherSession.serverMovedTo = PlotService.gateOutside(info.model).Position
							end
							other.Character:PivotTo(PlotService.gateOutside(info.model))
						end
					end
				end
			end
		end
	end)
end

function PlotService.snatchPrompt(plot: Model, pad: number): ProximityPrompt
	return plotByModel[plot].snatchPrompts[pad]
end

function PlotService.allPlots(): { PlotInfo }
	return plots
end

return PlotService
