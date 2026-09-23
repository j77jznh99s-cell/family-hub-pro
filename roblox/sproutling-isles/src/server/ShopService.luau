-- Seed Shop kiosks with per-player timed restocks, the Sell Stand, and the Pollen Parade belt.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Species = require(Shared.Species)
local Format = require(Shared.Format)

local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local Prompts = require(script.Parent.Prompts)
local PlotService = require(script.Parent.PlotService)

local ShopService = {}

-- Total weight per rarity for the Pollen Parade (sums to 100).
local PARADE_WEIGHTS = {
	Common = 55,
	Uncommon = 27,
	Rare = 12,
	Epic = 4.5,
	Legendary = 1.3,
	Mythic = 0.17,
	Secret = 0.03,
}

----------------------------------------------------------------------------------------------
-- stock

-- Restocks happen on a global 5-minute clock so every player sees the same countdown.
function ShopService.nextRestockAt(): number
	local now = os.time()
	return now - (now % Config.RestockSeconds) + Config.RestockSeconds
end

function ShopService.rollStock(session: State.Session)
	local stock = {}
	for _, species in Species.ShopList do
		if State.rng:NextNumber() < species.stockChance then
			stock[species.id] = State.rng:NextInteger(species.stockRange[1], species.stockRange[2])
		else
			stock[species.id] = 0
		end
	end
	session.stock = stock
	session.player:SetAttribute("Stock", HttpService:JSONEncode(stock))
end

local function buySeed(species: Species.Species, player: Player)
	local session = State.get(player)
	if not session then
		return
	end
	local left = session.stock[species.id] or 0
	if left <= 0 then
		State.notify(session, species.name .. " is sold out. Restock in " .. Format.time(ShopService.nextRestockAt() - os.time()), "#ffb070")
		return
	end
	if not State.spendDew(session, species.price) then
		State.notify(session, "Not enough Dew for " .. species.name .. " (" .. Format.number(species.price) .. ")", "#ff8080")
		return
	end
	session.stock[species.id] = left - 1
	player:SetAttribute("Stock", HttpService:JSONEncode(session.stock))
	State.addSeeds(session, species.id, 1)
	if not session.selectedSeed then
		session.selectedSeed = species.id
		player:SetAttribute("SelectedSeed", species.id)
	end
end

----------------------------------------------------------------------------------------------
-- parade

local function spawnParadeCrate(parade: Model)
	local species = Species.rollByRarity(PARADE_WEIGHTS, State.rng)
	local start = (parade:FindFirstChild("Start") :: BasePart).Position
	local finish = (parade:FindFirstChild("Finish") :: BasePart).Position

	local crate = Instance.new("Part")
	crate.Name = "Crate_" .. species.id
	crate.Size = Vector3.new(3.4, 3.4, 3.4)
	crate.Anchored = true
	crate.CanCollide = false
	crate.Material = Enum.Material.WoodPlanks
	crate.Color = Species.RarityColors[species.rarity]
	crate.CFrame = CFrame.new(start)
	local top = Instance.new("Part")
	top.Name = "Seed"
	top.Shape = Enum.PartType.Ball
	top.Size = Vector3.new(1.8, 1.8, 1.8)
	top.Anchored = true
	top.CanCollide = false
	top.Material = Enum.Material.Neon
	top.Color = species.leaf
	top.CFrame = crate.CFrame * CFrame.new(0, 2.4, 0)
	top.Parent = crate

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 50)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Parent = crate
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.RichText = true
	text.TextStrokeTransparency = 0.3
	text.TextColor3 = Species.RarityColors[species.rarity]
	text.Text = species.name .. " seed\n" .. Format.number(species.price) .. " Dew"
	text.Parent = gui

	local prompt = Prompts.create(crate, "Buy " .. Format.number(species.price), species.name .. " seed (" .. species.rarity .. ")")
	prompt.MaxActivationDistance = 12
	local sold = false
	prompt.Triggered:Connect(function(player)
		local session = State.get(player)
		if sold or not session then
			return
		end
		if not State.spendDew(session, species.price) then
			State.notify(session, "Not enough Dew for " .. species.name .. " (" .. Format.number(species.price) .. ")", "#ff8080")
			return
		end
		sold = true
		State.addSeeds(session, species.id, 1)
		State.notify(session, "Got a " .. species.name .. " seed from the Pollen Parade!", "#ffe070")
		if table.find({ "Legendary", "Mythic", "Secret" }, species.rarity) then
			Net.announce(player.DisplayName .. " grabbed a " .. species.rarity .. " " .. species.name .. " seed from the Parade!", "#ffe070")
		end
		crate:Destroy()
	end)

	crate.Parent = parade:FindFirstChild("Items")
	if table.find({ "Legendary", "Mythic", "Secret" }, species.rarity) then
		Net.announce("A " .. species.rarity .. " " .. species.name .. " seed is riding the Pollen Parade!", "#ffe070")
	end

	local info = TweenInfo.new(Config.ParadeTravelSeconds, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(crate, info, { CFrame = CFrame.new(finish) })
	TweenService:Create(top, info, { CFrame = CFrame.new(finish) * CFrame.new(0, 2.4, 0) }):Play()
	tween.Completed:Once(function()
		if crate.Parent then
			crate:Destroy()
		end
	end)
	tween:Play()
end

----------------------------------------------------------------------------------------------

function ShopService.init(map: Instance)
	local plaza = map.Plaza
	local shop = plaza:FindFirstChild("Seed Shop")
	for index, species in Species.ShopList do
		local kiosk = shop.Kiosks:FindFirstChild("Kiosk" .. index) :: BasePart
		kiosk:SetAttribute("Species", species.id)
		kiosk.Color = Species.RarityColors[species.rarity]
		local prompt = Prompts.create(kiosk, "Buy " .. Format.number(species.price), species.name .. " seed")
		prompt.MaxActivationDistance = 8
		prompt.Triggered:Connect(function(player)
			buySeed(species, player)
		end)
		-- the label text is filled in per player by the client from the "Stock" attribute
		local gui = Instance.new("BillboardGui")
		gui.Name = "StockLabel"
		gui.Size = UDim2.fromOffset(110, 60)
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
		text.TextColor3 = Species.RarityColors[species.rarity]
		text.Text = species.name .. "\n" .. Format.number(species.price)
		text.Parent = gui
	end

	local sellAnchor = plaza:FindFirstChild("Sell Stand"):FindFirstChild("Anchor")
	local sell = Prompts.create(sellAnchor, "Sell stored Sproutlings", "Sell Stand")
	sell.Triggered:Connect(function(player)
		local session = State.get(player)
		if session then
			PlotService.sellStorage(session)
		end
	end)

	ReplicatedStorage:SetAttribute("NextRestock", ShopService.nextRestockAt())
	task.spawn(function()
		local nextRestock = ShopService.nextRestockAt()
		while true do
			task.wait(1)
			if os.time() >= nextRestock then
				nextRestock = ShopService.nextRestockAt()
				ReplicatedStorage:SetAttribute("NextRestock", nextRestock)
				for _, session in State.sessions do
					ShopService.rollStock(session)
					State.notify(session, "The Seed Shop restocked!", "#a0ffa0")
				end
			end
		end
	end)

	local parade = map.Parade
	task.spawn(function()
		while true do
			spawnParadeCrate(parade)
			task.wait(Config.ParadeSpawnSeconds)
		end
	end)
end

return ShopService
