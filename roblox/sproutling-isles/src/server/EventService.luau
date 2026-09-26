-- Halloween "Hollow Harvest": the Spooky Fog scheduler, Wisp Lantern spawn/pickup/despawn, hatch
-- Moonberry bonuses, the Lantern Stall (3 kiosks, reusing the Seed Shop's Prompts.create pattern),
-- the plot skin equip toggle, and the end-of-event Moonberry -> Dew conversion.
-- See vault/Projects/Sproutling Isles - Launch & Live Ops.md, "Halloween event spec Hollow Harvest".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared.Events)
local Species = require(Shared.Species)
local Format = require(Shared.Format)

local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local Analytics = require(script.Parent.Analytics)
local Prompts = require(script.Parent.Prompts)
local WeatherService = require(script.Parent.WeatherService)

local EventService = {}

local cfg = Events.Halloween2026

----------------------------------------------------------------------------------------------
-- skin-change hook (7. PlotService applies data.skin on claim and whenever it's toggled here;
-- EventService does not require PlotService back, so there's no circular require)

local skinChangeCallbacks: { (State.Session) -> () } = {}

function EventService.onSkinChange(fn: (State.Session) -> ())
	table.insert(skinChangeCallbacks, fn)
end

local function fireSkinChange(session: State.Session)
	for _, fn in skinChangeCallbacks do
		local ok, err = pcall(fn, session)
		if not ok then
			warn("[EventService] onSkinChange callback failed:", err)
		end
	end
end

----------------------------------------------------------------------------------------------
-- economy helper

local function grantMoonberries(session: State.Session, amount: number, reason: string)
	session.data.event.berries += amount
	session.player:SetAttribute("Moonberries", session.data.event.berries)
	Analytics.source(session.player, "Event:" .. reason, amount, session.data.event.berries, "Moonberries")
end

----------------------------------------------------------------------------------------------
-- hatch bonus (called from PlotService's hatch branch, item 7)

function EventService.onHatch(player: Player, wasHaunted: boolean)
	if not Events.active(cfg, os.time()) then
		return
	end
	local session = State.get(player)
	if not session then
		return
	end
	local amount = if wasHaunted then cfg.hauntedHatchBonus else cfg.hatchBonus
	grantMoonberries(session, amount, if wasHaunted then "HauntedHatch" else "Hatch")
end

----------------------------------------------------------------------------------------------
-- Wisp Lanterns

local lanternFolder: Folder
local spawnPoints: { BasePart } = {}
-- one entry per lantern currently standing this Fog; `collected` is per-player so a player who
-- joins mid-Fog still sees (and can take) every lantern still standing, not just the ones nobody
-- has taken yet (per the spec's join-mid-Fog edge case).
type LanternEntry = { part: BasePart, prompt: ProximityPrompt, collected: { [number]: boolean } }
local activeLanterns: { LanternEntry } = {}

local function utcDay(now: number): number
	return now // 86400
end

local function onLanternTriggered(entry: LanternEntry, player: Player)
	local session = State.get(player)
	if not session or entry.collected[player.UserId] then
		return
	end
	-- exploit check: re-validate distance server-side (the spec's <= 12 studs), don't trust the
	-- prompt's own activation distance alone (see SnatchService's M1 pad-distance check for the
	-- same pattern in this codebase).
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - entry.part.Position).Magnitude > 12 then
		return
	end
	entry.collected[player.UserId] = true
	local now = os.time()
	local day = utcDay(now)
	local amount = cfg.lanternValue
	local dailyBonus = false
	if session.data.event.lanternDay ~= day then
		session.data.event.lanternDay = day
		amount += cfg.lanternDailyBonus
		dailyBonus = true
	end
	grantMoonberries(session, amount, "Lantern")
	Analytics.custom(player, "EventLantern", amount)
	if dailyBonus then
		State.notify(session, "+" .. amount .. " Moonberries (+" .. cfg.lanternDailyBonus .. " daily bonus!)", "#ffb347")
	else
		State.notify(session, "+" .. amount .. " Moonberries", "#ffb347")
	end
	-- "the client hides the lantern after pickup" (per-player only: everyone else can still take
	-- this same lantern). Reuses the existing Effect remote instead of adding a new one; the client
	-- only mutates its own local rendering, so this never affects other players' view of it.
	Net.Effect:FireClient(player, "LanternGone", entry.part)
end

local function makeLantern(position: Vector3): LanternEntry
	local p = Instance.new("Part")
	p.Name = "Lantern"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(2.2, 2.2, 2.2)
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 170, 60)
	p.Position = position + Vector3.new(0, 3, 0)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 60)
	light.Range = 16
	light.Parent = p
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Parent = p
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextStrokeTransparency = 0.3
	text.TextColor3 = Color3.fromRGB(255, 200, 120)
	text.Text = "Wisp Lantern"
	text.Parent = gui
	p.Parent = lanternFolder

	local prompt = Prompts.create(p, "Catch (+" .. cfg.lanternValue .. " Moonberries)", "Wisp Lantern")
	prompt.MaxActivationDistance = 12
	local entry: LanternEntry = { part = p, prompt = prompt, collected = {} }
	prompt.Triggered:Connect(function(player)
		onLanternTriggered(entry, player)
	end)
	return entry
end

local function spawnLanterns()
	if #spawnPoints == 0 then
		return
	end
	-- shuffle a copy of the spawn points, then take up to lanternCount of them (Fisher-Yates)
	local shuffled = table.clone(spawnPoints)
	for i = #shuffled, 2, -1 do
		local j = State.rng:NextInteger(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	for i = 1, math.min(cfg.lanternCount, #shuffled) do
		table.insert(activeLanterns, makeLantern(shuffled[i].Position))
	end
end

local function despawnLanterns()
	for _, entry in activeLanterns do
		entry.prompt:Destroy()
		entry.part:Destroy()
	end
	table.clear(activeLanterns)
end

local function onWeatherStart(w, _byPlayer: Player?)
	if w.id == cfg.weatherId and Events.active(cfg, os.time()) then
		spawnLanterns()
	end
end

local function onWeatherStop(w)
	if w.id == cfg.weatherId then
		despawnLanterns()
	end
end

----------------------------------------------------------------------------------------------
-- Fog scheduler: fires once per interval-slot boundary on the UTC clock (:00/:20/:40, or every 10
-- min during Witching Hour), so multiple servers agree without any cross-server coordination.

local function fogScheduler()
	local lastSlot: number? = nil
	while true do
		task.wait(1)
		local now = os.time()
		if Events.active(cfg, now) then
			local interval = Events.fogIntervalSeconds(cfg, now)
			local slot = now // interval
			if slot ~= lastSlot then
				lastSlot = slot
				WeatherService.start(cfg.weatherId)
			end
			ReplicatedStorage:SetAttribute("EventActive", true)
			ReplicatedStorage:SetAttribute("NextFogAt", (slot + 1) * interval)
		else
			lastSlot = nil
			ReplicatedStorage:SetAttribute("EventActive", false)
			ReplicatedStorage:SetAttribute("NextFogAt", 0)
		end
	end
end

----------------------------------------------------------------------------------------------
-- Lantern Stall (3 kiosks: Pumpkit, Gourdgeist, Haunted Greenhouse skin)

local kioskLabels: { [string]: TextLabel } = {}

local function stallBuyCount(session: State.Session, itemId: string): number
	local rec = session.data.event.stallBuys[itemId]
	if not rec or rec.day ~= utcDay(os.time()) then
		return 0
	end
	return rec.n
end

local function stallRecordBuy(session: State.Session, itemId: string)
	local day = utcDay(os.time())
	local rec = session.data.event.stallBuys[itemId]
	if not rec or rec.day ~= day then
		rec = { day = day, n = 0 }
		session.data.event.stallBuys[itemId] = rec
	end
	rec.n += 1
end

local function itemDisplayName(item): string
	if item.kind == "seed" then
		local species = Species.get(item.speciesId)
		return species and species.name or item.speciesId
	end
	return "Haunted Greenhouse"
end

local function buyStallItem(item, player: Player)
	local session = State.get(player)
	if not session then
		return
	end
	local now = os.time()
	local funnelId = HttpService:GenerateGUID(false)
	Analytics.funnel(player, "EventShop", funnelId, 1, "Opened")

	if now >= cfg.endAt then
		State.notify(session, "Hollow Harvest is over. See you next year!", "#ffb070")
		return
	end
	if not Events.active(cfg, now) then
		State.notify(session, "The Lantern Stall opens with Hollow Harvest on 17 Oct.", "#ffb070")
		return
	end
	local part = Events.part(cfg, now)
	if part < item.fromPart then
		State.notify(session, itemDisplayName(item) .. " unlocks in Part 2 (24 Oct).", "#ffb070")
		return
	end

	if item.kind == "skin" and session.data.skins[item.skinId] then
		-- already owned: this kiosk becomes an equip/unequip toggle instead of a sale
		session.data.skin = if session.data.skin == item.skinId then "" else item.skinId
		session.player:SetAttribute("Skin", session.data.skin)
		fireSkinChange(session)
		State.notify(session, if session.data.skin == item.skinId then "Haunted Greenhouse skin equipped!" else "Haunted Greenhouse skin unequipped.", "#c9a0ff")
		return
	end

	if item.dailyCap and stallBuyCount(session, item.id) >= item.dailyCap then
		State.notify(session, itemDisplayName(item) .. " limit reached for today (" .. item.dailyCap .. "/day). Resets at 00:00 UTC.", "#ffb070")
		return
	end
	if session.data.event.berries < item.price then
		State.notify(session, "Not enough Moonberries for " .. itemDisplayName(item) .. " (" .. item.price .. ")", "#ff8080")
		return
	end

	session.data.event.berries -= item.price
	session.player:SetAttribute("Moonberries", session.data.event.berries)
	Analytics.sink(player, "EventShop:" .. item.id, item.price, session.data.event.berries, "Moonberries")
	stallRecordBuy(session, item.id)

	if item.kind == "seed" then
		-- M: limited seeds go straight to the seed inventory (never onto pads), same as
		-- ShopService.buySeed, so a full greenhouse/storage never blocks a stall purchase.
		State.addSeeds(session, item.speciesId, 1)
		State.notify(session, "Got a " .. itemDisplayName(item) .. " seed!", "#ffb347")
	else
		session.data.skins[item.skinId] = true
		session.data.skin = item.skinId
		session.player:SetAttribute("Skin", session.data.skin)
		fireSkinChange(session)
		State.notify(session, "Unlocked and equipped the Haunted Greenhouse skin!", "#c9a0ff")
	end
	Analytics.funnel(player, "EventShop", funnelId, 2, "Bought")
end

local function refreshStallLabels()
	local now = os.time()
	for id, item in cfg.stall do
		local text = kioskLabels[id]
		if text then
			if now >= cfg.endAt then
				text.Text = "See you\nnext year!"
			elseif not Events.active(cfg, now) then
				text.Text = itemDisplayName(item) .. "\nopens 17 Oct"
			elseif Events.part(cfg, now) < item.fromPart then
				text.Text = itemDisplayName(item) .. "\nunlocks Part 2"
			else
				local capText = if item.dailyCap then (" (" .. item.dailyCap .. "/day)") else ""
				text.Text = itemDisplayName(item) .. "\n" .. item.price .. " berries" .. capText
			end
		end
	end
end

local function initStall(stallModel: Instance)
	local kiosks = stallModel:FindFirstChild("Kiosks")
	if not kiosks then
		warn("[EventService] Lantern Stall has no Kiosks folder; stall disabled")
		return
	end
	for _, kiosk in kiosks:GetChildren() do
		local itemId = kiosk:GetAttribute("Slot")
		local item = itemId and cfg.stall[itemId]
		if item then
			local prompt = Prompts.create(kiosk, "Buy " .. item.price .. " Moonberries", itemDisplayName(item))
			prompt.MaxActivationDistance = 8
			prompt.Triggered:Connect(function(player)
				buyStallItem(item, player)
			end)
			local gui = Instance.new("BillboardGui")
			gui.Name = "StallLabel"
			gui.Size = UDim2.fromOffset(150, 60)
			gui.StudsOffset = Vector3.new(0, 3.2, 0)
			gui.MaxDistance = 45
			gui.LightInfluence = 0
			gui.Parent = kiosk
			local text = Instance.new("TextLabel")
			text.Name = "Text"
			text.BackgroundTransparency = 1
			text.Size = UDim2.fromScale(1, 1)
			text.Font = Enum.Font.FredokaOne
			text.TextScaled = true
			text.TextStrokeTransparency = 0.3
			text.TextColor3 = Color3.fromRGB(255, 200, 120)
			text.Parent = gui
			kioskLabels[item.id] = text
		end
	end
	refreshStallLabels()
	task.spawn(function()
		while true do
			task.wait(5)
			refreshStallLabels()
		end
	end)
end

----------------------------------------------------------------------------------------------
-- join / end-of-event conversion

-- Called once per join, after PlotService.renderPads so State.income reflects this player's real
-- pads (the conversion rate is "5 min of current income").
function EventService.onJoin(session: State.Session)
	local player = session.player
	player:SetAttribute("Moonberries", session.data.event.berries)
	player:SetAttribute("Skin", session.data.skin or "")
	local now = os.time()
	if now >= cfg.endAt and session.data.event.berries > 0 then
		local berries = session.data.event.berries
		local dew = math.max(100, math.floor(State.income(session) * 5 * 60))
		session.data.event.berries = 0
		player:SetAttribute("Moonberries", 0)
		State.addDew(session, dew, "Event:Conversion")
		State.notify(session, "Hollow Harvest is over! Your " .. berries .. " Moonberries became " .. Format.number(dew) .. " Dew.", "#ffb347")
	end
end

----------------------------------------------------------------------------------------------

function EventService.init(map: Instance)
	WeatherService.onStart(onWeatherStart)
	WeatherService.onStop(onWeatherStop)

	lanternFolder = Instance.new("Folder")
	lanternFolder.Name = "Lanterns"
	lanternFolder.Parent = workspace

	local island = map:FindFirstChild("Island")
	local spots = island and island:FindFirstChild("LanternSpawns")
	if spots then
		for _, child in spots:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(spawnPoints, child)
			end
		end
	end
	if #spawnPoints == 0 then
		warn("[EventService] no LanternSpawn points found; Wisp Lanterns disabled")
	end

	local plaza = map:FindFirstChild("Plaza")
	local stallModel = plaza and plaza:FindFirstChild("Lantern Stall")
	if stallModel then
		initStall(stallModel)
	else
		warn("[EventService] no Lantern Stall found in the map; event shop disabled")
	end

	task.spawn(fogScheduler)
end

return EventService
