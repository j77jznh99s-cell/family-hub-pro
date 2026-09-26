-- Sproutling Isles client: HUD, seed hotbar, notifications, Robux store, per-player prompt
-- visibility, live kiosk stock labels and weather particles. All game rules live on the server.

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Species = require(Shared.Species)
local Weather = require(Shared.Weather)
local Products = require(Shared.Products)
local Format = require(Shared.Format)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)

----------------------------------------------------------------------------------------------
-- tiny UI helpers

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: number): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(thickness: number, color: Color3?): UIStroke
	return make("UIStroke", { Thickness = thickness, Color = color or Color3.fromRGB(30, 40, 30), ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = FONT
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	props.TextColor3 = props.TextColor3 or WHITE
	local label = make("TextLabel", props)
	make("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(20, 30, 20), Parent = label })
	return label
end

local function button(props: { [string]: any }): TextButton
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or WHITE
	props.AutoButtonColor = true
	local b = make("TextButton", props)
	corner(10).Parent = b
	stroke(2).Parent = b
	return b
end

local screen = make("ScreenGui", { Name = "SproutlingHUD", ResetOnSpawn = false, IgnoreGuiInset = false, Parent = playerGui })

----------------------------------------------------------------------------------------------
-- top-left: Dew + income

local dewPanel = make("Frame", {
	Name = "Dew",
	Size = UDim2.new(0, 230, 0, 70),
	Position = UDim2.new(0, 12, 0, 12),
	BackgroundColor3 = Color3.fromRGB(40, 90, 60),
	BackgroundTransparency = 0.1,
	Parent = screen,
}, { corner(14), stroke(3) })
local dewLabel = text({ Size = UDim2.new(1, -16, 0.6, 0), Position = UDim2.new(0, 8, 0, 4), TextXAlignment = Enum.TextXAlignment.Left, Text = "0 Dew", TextColor3 = Color3.fromRGB(170, 235, 255), Parent = dewPanel })
local incomeLabel = text({ Size = UDim2.new(1, -16, 0.35, 0), Position = UDim2.new(0, 8, 0.6, 0), TextXAlignment = Enum.TextXAlignment.Left, Text = "+0/s", Parent = dewPanel })

local function refreshDew()
	dewLabel.Text = Format.number(player:GetAttribute("Dew") or 0) .. " Dew"
	incomeLabel.Text = "+" .. Format.number(player:GetAttribute("Income") or 0) .. " Dew/s"
end
player:GetAttributeChangedSignal("Dew"):Connect(refreshDew)
player:GetAttributeChangedSignal("Income"):Connect(refreshDew)
refreshDew()

-- status line under the Dew panel: shield, luck, carrying, storage
local statusLabel = text({ Size = UDim2.new(0, 330, 0, 24), Position = UDim2.new(0, 12, 0, 88), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = screen })

----------------------------------------------------------------------------------------------
-- Hollow Harvest: Moonberries + next Spooky Fog countdown (mirrors the Dew panel / Stock-label
-- pattern above -- read a server-set player Attribute, format it, show it; nothing more)

local eventPanel = make("Frame", {
	Name = "Event",
	Size = UDim2.new(0, 330, 0, 28),
	Position = UDim2.new(0, 12, 0, 116),
	BackgroundColor3 = Color3.fromRGB(70, 40, 100),
	BackgroundTransparency = 0.1,
	Visible = false,
	Parent = screen,
}, { corner(10), stroke(2) })
local eventLabel = text({ Size = UDim2.new(1, -12, 1, -6), Position = UDim2.new(0, 6, 0, 3), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = Color3.fromRGB(230, 190, 255), Parent = eventPanel })

local function refreshEvent()
	local active = ReplicatedStorage:GetAttribute("EventActive") == true
	eventPanel.Visible = active
	if not active then
		return
	end
	local berries = player:GetAttribute("Moonberries") or 0
	local nextFogAt = ReplicatedStorage:GetAttribute("NextFogAt") or 0
	local remaining = nextFogAt - workspace:GetServerTimeNow()
	local fogText = if remaining > 0 then ("Next Fog in " .. Format.time(remaining)) else "Fog is here!"
	eventLabel.Text = "🎃 Moonberries: " .. Format.number(berries) .. " · " .. fogText
end
player:GetAttributeChangedSignal("Moonberries"):Connect(refreshEvent)
ReplicatedStorage:GetAttributeChangedSignal("EventActive"):Connect(refreshEvent)
refreshEvent()

----------------------------------------------------------------------------------------------
-- top-centre: weather banner

local weatherBanner = make("Frame", {
	Size = UDim2.new(0, 360, 0, 44),
	Position = UDim2.new(0.5, -180, 0, 12),
	BackgroundColor3 = Color3.fromRGB(60, 60, 110),
	BackgroundTransparency = 0.15,
	Visible = false,
	Parent = screen,
}, { corner(12), stroke(2) })
local weatherLabel = text({ Size = UDim2.new(1, -12, 1, -8), Position = UDim2.new(0, 6, 0, 4), Text = "", Parent = weatherBanner })

----------------------------------------------------------------------------------------------
-- notifications (bottom-right toasts) + big centre popup

local toasts = make("Frame", {
	Size = UDim2.new(0, 380, 0, 300),
	Position = UDim2.new(1, -392, 1, -420),
	BackgroundTransparency = 1,
	Parent = screen,
}, { make("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

local toastCount = 0
local function toast(message: string, colorHex: string?)
	toastCount += 1
	local color = if colorHex then Color3.fromHex(colorHex) else WHITE
	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.fromRGB(25, 35, 30),
		BackgroundTransparency = 0.2,
		LayoutOrder = toastCount,
		Parent = toasts,
	}, { corner(10) })
	text({ Size = UDim2.new(1, -16, 1, -8), Position = UDim2.new(0, 8, 0, 4), Text = message, TextColor3 = color, TextWrapped = true, Parent = frame })
	local children = toasts:GetChildren()
	if #children > 7 then
		for _, child in children do
			if child:IsA("Frame") then
				child:Destroy()
				break
			end
		end
	end
	task.delay(6, function()
		if frame.Parent then
			TweenService:Create(frame, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			task.wait(0.4)
			frame:Destroy()
		end
	end)
end
Remotes:WaitForChild("Notify").OnClientEvent:Connect(toast)

local popup = text({
	Size = UDim2.new(0, 600, 0, 80),
	Position = UDim2.new(0.5, -300, 0.3, 0),
	Text = "",
	Visible = false,
	Parent = screen,
})
local popupToken = 0
local function showPopup(message: string, color: Color3)
	popupToken += 1
	local token = popupToken
	popup.Text = message
	popup.TextColor3 = color
	popup.Visible = true
	popup.Size = UDim2.new(0, 300, 0, 40)
	popup.Position = UDim2.new(0.5, -150, 0.3, 20)
	TweenService:Create(popup, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.new(0, 600, 0, 80), Position = UDim2.new(0.5, -300, 0.3, 0) }):Play()
	task.delay(2.5, function()
		if token == popupToken then
			popup.Visible = false
		end
	end)
end

Remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind: string, data)
	if kind == "Hatch" then
		showPopup("Hatched " .. data.name .. "!", Species.RarityColors[data.rarity] or WHITE)
	elseif kind == "Stolen" then
		showPopup(data.thief .. " is stealing from you!", Color3.fromRGB(255, 90, 90))
	elseif kind == "SnatchSuccess" then
		showPopup("Snatched " .. data.name .. "!", Color3.fromRGB(255, 170, 80))
	elseif kind == "Rebirth" then
		showPopup("REBIRTH " .. data.rebirths .. "!", Color3.fromRGB(210, 160, 255))
	elseif kind == "LanternGone" then
		-- Hollow Harvest: hides this one Wisp Lantern for just this client (everyone else can still
		-- take it -- lanterns are collectible once per player, not once total). Purely a local
		-- rendering change: it never replicates back to the server or to other players.
		if typeof(data) == "Instance" and data:IsA("BasePart") then
			data.Transparency = 1
			data.CanCollide = false
			local light = data:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = false
			end
			local gui = data:FindFirstChild("Label")
			if gui and gui:IsA("BillboardGui") then
				gui.Enabled = false
			end
			local prompt = data:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = false
			end
		end
	end
end)

----------------------------------------------------------------------------------------------
-- bottom: seed hotbar

local hotbar = make("ScrollingFrame", {
	Name = "Seeds",
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.new(0.94, 0, 0, 92),
	Position = UDim2.new(0.5, 0, 1, -12),
	BackgroundColor3 = Color3.fromRGB(40, 70, 45),
	BackgroundTransparency = 0.25,
	ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.X,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	Parent = screen,
}, {
	corner(14),
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
	make("UISizeConstraint", { MaxSize = Vector2.new(620, 92) }),
})
local emptyHint = text({ Size = UDim2.new(1, -12, 0, 40), Text = "No seeds - visit the Seed Shop, Pollen Parade or Wishing Pond!", Parent = hotbar })

local seedsFolder = player:WaitForChild("Seeds")
local selectSeed = Remotes:WaitForChild("SelectSeed")

local function rebuildHotbar()
	for _, child in hotbar:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local selected = player:GetAttribute("SelectedSeed")
	local any = false
	for order, species in Species.List do
		local value = seedsFolder:FindFirstChild(species.id) :: IntValue?
		if value and value.Value > 0 then
			any = true
			local isSelected = selected == species.id
			local b = button({
				Name = species.id,
				Size = UDim2.new(0, 96, 0, 76),
				LayoutOrder = order,
				BackgroundColor3 = if isSelected then Color3.fromRGB(255, 225, 120) else Species.RarityColors[species.rarity]:Lerp(Color3.new(0, 0, 0), 0.35),
				Text = "",
				Parent = hotbar,
			})
			text({ Size = UDim2.new(1, -8, 0.55, 0), Position = UDim2.new(0, 4, 0, 4), Text = species.name, TextColor3 = if isSelected then Color3.fromRGB(40, 40, 40) else WHITE, Parent = b })
			text({ Size = UDim2.new(1, -8, 0.35, 0), Position = UDim2.new(0, 4, 0.6, 0), Text = "x" .. value.Value, TextColor3 = if isSelected then Color3.fromRGB(40, 40, 40) else WHITE, Parent = b })
			b.Activated:Connect(function()
				selectSeed:FireServer(species.id)
			end)
		end
	end
	emptyHint.Visible = not any
end

local function watchSeed(value: Instance)
	if value:IsA("IntValue") then
		value.Changed:Connect(rebuildHotbar)
	end
	rebuildHotbar()
end
seedsFolder.ChildAdded:Connect(watchSeed)
seedsFolder.ChildRemoved:Connect(rebuildHotbar)
for _, value in seedsFolder:GetChildren() do
	watchSeed(value)
end
player:GetAttributeChangedSignal("SelectedSeed"):Connect(rebuildHotbar)
rebuildHotbar()

----------------------------------------------------------------------------------------------
-- Robux store

local storeFrame = make("Frame", {
	Name = "Store",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.new(0.94, 0, 0.8, 0),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	BackgroundColor3 = Color3.fromRGB(35, 55, 80),
	Visible = false,
	Parent = screen,
}, { corner(18), stroke(3), make("UISizeConstraint", { MaxSize = Vector2.new(520, 440) }) })
text({ Size = UDim2.new(1, -80, 0, 44), Position = UDim2.new(0, 16, 0, 8), Text = "Sprout Supply", TextXAlignment = Enum.TextXAlignment.Left, Parent = storeFrame })
local closeButton = button({ Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(1, -56, 0, 8), Text = "X", BackgroundColor3 = Color3.fromRGB(200, 70, 70), Parent = storeFrame })
local storeList = make("ScrollingFrame", {
	Size = UDim2.new(1, -24, 1, -70),
	Position = UDim2.new(0, 12, 0, 60),
	BackgroundTransparency = 1,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	Parent = storeFrame,
}, { make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function storeRow(order: number, name: string, description: string, price: number, owned: boolean, onBuy: (() -> ())?)
	local row = make("Frame", { Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = Color3.fromRGB(50, 75, 105), LayoutOrder = order, Parent = storeList }, { corner(10) })
	text({ Size = UDim2.new(0.68, 0, 0.5, 0), Position = UDim2.new(0, 10, 0, 4), Text = name, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	text({ Size = UDim2.new(0.68, 0, 0.38, 0), Position = UDim2.new(0, 10, 0.55, 0), Text = description, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 220, 240), Parent = row })
	local b = button({
		Size = UDim2.new(0.28, 0, 0, 44),
		Position = UDim2.new(0.7, 0, 0, 10),
		Text = if owned then "Owned" elseif onBuy then ("R$ " .. price) else "Set ID",
		BackgroundColor3 = if owned then Color3.fromRGB(90, 90, 90) else Color3.fromRGB(60, 190, 90),
		Parent = row,
	})
	if onBuy and not owned then
		b.Activated:Connect(onBuy)
	end
end

local function openStore()
	for _, child in storeList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local order = 0
	for _, product in Products.DevProducts do
		if not (product.key == "StarterPack" and player:GetAttribute("StarterBought")) then
			order += 1
			storeRow(order, product.name, product.description, product.price, false, if product.id ~= 0 then function()
				MarketplaceService:PromptProductPurchase(player, product.id)
			end else nil)
		end
	end
	for _, pass in Products.Passes do
		order += 1
		storeRow(order, pass.name .. " (pass)", pass.description, pass.price, player:GetAttribute("Pass_" .. pass.key) == true, if pass.id ~= 0 then function()
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end else nil)
	end
	storeFrame.Visible = true
end
closeButton.Activated:Connect(function()
	storeFrame.Visible = false
end)

local storeButton = button({ Size = UDim2.new(0, 120, 0, 50), Position = UDim2.new(1, -132, 0, 12), Text = "Store", BackgroundColor3 = Color3.fromRGB(70, 150, 255), Parent = screen })
storeButton.Activated:Connect(function()
	if storeFrame.Visible then
		storeFrame.Visible = false
	else
		openStore()
	end
end)

local homeButton = button({ Size = UDim2.new(0, 120, 0, 50), Position = UDim2.new(1, -132, 0, 70), Text = "Home", BackgroundColor3 = Color3.fromRGB(90, 190, 110), Parent = screen })

----------------------------------------------------------------------------------------------
-- per-player prompt visibility (see server Prompts module)

local function refreshPrompt(prompt: ProximityPrompt)
	local active = prompt:GetAttribute("Active") ~= false
	local only = prompt:GetAttribute("OnlyUser")
	local except = prompt:GetAttribute("ExceptUser")
	local visible = active
	if only ~= nil and only ~= player.UserId then
		visible = false
	end
	if except ~= nil and except == player.UserId then
		visible = false
	end
	prompt.Enabled = visible
end

local function trackPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.AttributeChanged:Connect(function()
		refreshPrompt(prompt)
	end)
	refreshPrompt(prompt)
end
CollectionService:GetInstanceAddedSignal("SIPrompt"):Connect(trackPrompt)
for _, prompt in CollectionService:GetTagged("SIPrompt") do
	trackPrompt(prompt)
end

----------------------------------------------------------------------------------------------
-- world labels: kiosk stock, restock timer, rebirth cost; Sprout Supply opens the store

local map = workspace:WaitForChild("Map")
local plaza = map:WaitForChild("Plaza")
local shop = plaza:WaitForChild("Seed Shop")

local function refreshStock()
	local ok, stock = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Stock") or "{}")
	if not ok then
		return
	end
	for _, kiosk in shop:WaitForChild("Kiosks"):GetChildren() do
		local id = kiosk:GetAttribute("Species")
		local species = id and Species.get(id)
		local label = kiosk:FindFirstChild("StockLabel")
		local textLabel = label and label:FindFirstChild("Text") :: TextLabel?
		if species and textLabel then
			local left = stock[id] or 0
			textLabel.Text = species.name .. "\n" .. Format.number(species.price) .. (if left > 0 then ("  x" .. left) else "  SOLD OUT")
		end
	end
end
player:GetAttributeChangedSignal("Stock"):Connect(refreshStock)
task.defer(refreshStock)

local restockLabel = (shop:WaitForChild("RestockBoard"):WaitForChild("Label"):WaitForChild("Text")) :: TextLabel
local shrineLabel = plaza:WaitForChild("Rebirth Shrine"):WaitForChild("Anchor"):WaitForChild("Label"):WaitForChild("Text") :: TextLabel

-- Sprout Supply is purely a UI shortcut, so its prompt is created locally
do
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open store"
	prompt.ObjectText = "Sprout Supply"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(openStore)
	prompt.Parent = plaza:WaitForChild("Sprout Supply"):WaitForChild("Anchor")
end

homeButton.Activated:Connect(function()
	local color = player:GetAttribute("PlotColor")
	toast("Head to your " .. tostring(color) .. " plot!", "#a0ffa0")
	-- show a beam from the player to their plot for a few seconds
	local plotsFolder = map:FindFirstChild("Plots")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not plotsFolder or not root then
		return
	end
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			local target = plot:FindFirstChild("SpawnPoint")
			if target then
				local a0 = Instance.new("Attachment")
				a0.Parent = root
				local a1 = Instance.new("Attachment")
				a1.Parent = target
				local beam = make("Beam", { Attachment0 = a0, Attachment1 = a1, Width0 = 1.5, Width1 = 1.5, FaceCamera = true, Color = ColorSequence.new(Color3.fromRGB(120, 255, 150)), LightEmission = 1, Parent = root })
				task.delay(8, function()
					beam:Destroy()
					a0:Destroy()
					a1:Destroy()
				end)
			end
		end
	end
end)

----------------------------------------------------------------------------------------------
-- weather particles that follow the camera

local weatherPart = make("Part", { Name = "WeatherFX", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(80, 1, 80), Parent = workspace })
local emitter = make("ParticleEmitter", { Enabled = false, Rate = 0, Lifetime = NumberRange.new(1.5, 2), Speed = NumberRange.new(40, 50), EmissionDirection = Enum.NormalId.Bottom, Parent = weatherPart })

local function applyWeatherFX(id: string)
	if id == "drizzle" or id == "thunder" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(170, 200, 255))
		emitter.Size = NumberSequence.new(0.15)
		emitter.Speed = NumberRange.new(60, 70)
		emitter.Rate = if id == "thunder" then 400 else 250
		emitter.LightEmission = 0.2
	elseif id == "starfall" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(220, 200, 255))
		emitter.Size = NumberSequence.new(0.5)
		emitter.Speed = NumberRange.new(20, 30)
		emitter.Rate = 60
		emitter.LightEmission = 1
	elseif id == "aurora" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(120, 255, 200), Color3.fromRGB(255, 120, 230))
		emitter.Size = NumberSequence.new(0.6)
		emitter.Speed = NumberRange.new(8, 14)
		emitter.Rate = 80
		emitter.LightEmission = 1
	end
	emitter.Enabled = id ~= ""
end

local function refreshWeather()
	local id = ReplicatedStorage:GetAttribute("Weather") or ""
	local w = Weather.Types[id]
	weatherBanner.Visible = w ~= nil
	applyWeatherFX(if w then id else "")
end
ReplicatedStorage:GetAttributeChangedSignal("Weather"):Connect(refreshWeather)
refreshWeather()

----------------------------------------------------------------------------------------------
-- 5 Hz UI refresh: timers and status

local lastUpdate = 0
RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if camera then
		weatherPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 40, 0))
	end
	local now = os.clock()
	if now - lastUpdate < 0.2 then
		return
	end
	lastUpdate = now
	local t = os.time()

	local w = Weather.Types[ReplicatedStorage:GetAttribute("Weather") or ""]
	if w then
		local mutation = w.mutation and Weather.Mutations[w.mutation]
		weatherLabel.Text = w.name .. (if mutation then (" - " .. mutation.name .. " x" .. mutation.multiplier) else "") .. (if w.growthSpeed > 1 then (" - grow x" .. w.growthSpeed) else "")
	end

	local nextRestock = ReplicatedStorage:GetAttribute("NextRestock")
	if nextRestock then
		restockLabel.Text = "Restock in " .. Format.time(math.max(0, nextRestock - t))
	end
	shrineLabel.Text = "Rebirth: " .. Format.number(player:GetAttribute("RebirthCost") or 0) .. " Dew"

	local parts = {}
	local carrying = player:GetAttribute("Carrying")
	if carrying then
		local ends = player:GetAttribute("CarryEndsAt") or 0
		table.insert(parts, "Carrying " .. carrying .. " - " .. Format.time(ends - workspace:GetServerTimeNow()) .. " to get home!")
	end
	local shield = player:GetAttribute("ShieldUntil") or 0
	if shield > t then
		table.insert(parts, "Shield " .. Format.time(shield - t))
	end
	local luck = player:GetAttribute("LuckUntil") or 0
	if luck > t then
		table.insert(parts, "Luck x2 " .. Format.time(luck - t))
	end
	local stored = player:GetAttribute("Stored") or 0
	if stored > 0 then
		table.insert(parts, stored .. " in storage")
	end
	statusLabel.Text = table.concat(parts, "  |  ")

	refreshEvent()
end)
