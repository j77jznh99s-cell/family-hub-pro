-- Inventory and shop screens.
--
-- B (or the Bag button) opens the inventory: equipped gear, the weapon bag (equip / salvage),
-- potions and meals (use), and materials. Shops open when you use a shop's prompt in the city:
-- buy items and sell all your materials. H drinks a Healing Draught, J a Stamina Tonic.
-- The airship and boat docks list fast-travel destinations. P calls your companion, V rides.
-- The server sends a fresh snapshot after every change, so these screens only display it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loot = require(Shared:WaitForChild("Loot"))
local Shops = require(Shared:WaitForChild("Shops"))
local Recipes = require(Shared:WaitForChild("Recipes"))
local Travel = require(Shared:WaitForChild("Travel"))

local Inventory = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local InventoryRemote = remotes:WaitForChild("Inventory") :: RemoteEvent
local ActionRemote = remotes:WaitForChild("InventoryAction") :: RemoteEvent
local OpenShopRemote = remotes:WaitForChild("OpenShop") :: RemoteEvent
local TravelRemote = remotes:WaitForChild("Travel") :: RemoteEvent
local CompanionRemote = remotes:WaitForChild("Companion") :: RemoteEvent

local FONT = Enum.Font.FredokaOne
local TITLE = Enum.Font.Fantasy
local PANEL = Color3.fromRGB(40, 32, 28)
local CARD = Color3.fromRGB(66, 54, 46)
local GOLD = Color3.fromRGB(240, 200, 110)
local WHITE = Color3.new(1, 1, 1)

local snapshot: any = nil
local currentShop: string? = nil

----------------------------------------------------------------------------------------------
-- ui helpers

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	return inst
end

local function corner(r: number): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function label(text: string, size: UDim2, pos: UDim2, color: Color3?, font: Enum.Font?, align: Enum.TextXAlignment?): TextLabel
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Position = pos,
		Font = font or FONT,
		TextScaled = true,
		TextColor3 = color or WHITE,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.6,
		Text = text,
	})
end

local function button(text: string, size: UDim2, pos: UDim2, color: Color3, onClick: () -> ()): TextButton
	local b = make("TextButton", {
		Size = size,
		Position = pos,
		BackgroundColor3 = color,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.5,
		Text = text,
		AutoButtonColor = true,
	}, { corner(6) })
	b.Activated:Connect(onClick)
	return b
end

local function clear(container: Instance)
	for _, c in container:GetChildren() do
		if not c:IsA("UIGridLayout") and not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

local gui = make("ScreenGui", { Name = "InventoryGui", ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })

local function window(title: string, w: number, h: number): (Frame, TextLabel)
	local frame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = PANEL,
		Visible = false,
		Parent = gui,
	}, { corner(10), make("UIStroke", { Color = GOLD, Thickness = 2 }) })
	-- shrink to fit small (phone) screens
	local scale = make("UIScale", { Parent = frame })
	local function fit()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.min(1, (view.X - 20) / w, (view.Y - 80) / h)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	local heading = label(title, UDim2.new(1, -60, 0, 32), UDim2.fromOffset(14, 8), GOLD, TITLE)
	heading.Parent = frame
	button("X", UDim2.fromOffset(30, 30), UDim2.new(1, -38, 0, 8), Color3.fromRGB(150, 60, 60), function()
		frame.Visible = false
	end).Parent = frame
	return frame, heading
end

----------------------------------------------------------------------------------------------
-- inventory window

local inv = window("Inventory", 640, 430)
local gearList = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 48), Size = UDim2.new(0, 230, 1, -60), Parent = inv }, {
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local bagGrid = make("ScrollingFrame", {
	BackgroundColor3 = Color3.fromRGB(30, 24, 22),
	Position = UDim2.fromOffset(256, 48),
	Size = UDim2.new(1, -270, 1, -60),
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = inv,
}, {
	corner(6),
	make("UIGridLayout", { CellSize = UDim2.fromOffset(170, 74), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6) }),
})

local function row(parent: Instance, order: number, h: number): Frame
	return make("Frame", { BackgroundColor3 = CARD, Size = UDim2.new(1, 0, 0, h), LayoutOrder = order, Parent = parent }, { corner(6) })
end

local function renderInventory()
	if not snapshot then
		return
	end
	clear(gearList)
	local order = 0
	local function heading(text: string)
		order += 1
		label(text, UDim2.new(1, 0, 0, 20), UDim2.new(), GOLD, TITLE).Parent = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order, Parent = gearList })
	end
	heading("Equipped")
	for _, id in Loot.WeaponIds do
		order += 1
		local g = snapshot.gear[id] or { r = 1 }
		local rarity = Loot.Rarities[g.r] or Loot.Rarities[1]
		local r = row(gearList, order, 26)
		label(Loot.weaponName(id, g.r), UDim2.new(0.72, -6, 1, -4), UDim2.fromOffset(6, 2), rarity.color).Parent = r
		label(string.format("x%.2f", rarity.power), UDim2.new(0.28, -6, 1, -4), UDim2.new(0.72, 0, 0, 2), WHITE, FONT, Enum.TextXAlignment.Right).Parent = r
	end
	order += 1
	local armor = Shops.Armor[snapshot.armor or 0]
	local ar = row(gearList, order, 26)
	label(if armor then string.format("%s (-%d%% damage)", armor.name, math.floor((armor.reduce or 0) * 100)) else "No armour", UDim2.new(1, -12, 1, -4), UDim2.fromOffset(6, 2), Color3.fromRGB(190, 210, 255)).Parent = ar

	heading("Potions & meals")
	local any = false
	for id, count in snapshot.consumables do
		local item: any = Shops.Consumables[id] or Recipes.get(id)
		if item and count > 0 then
			any = true
			order += 1
			local r = row(gearList, order, 28)
			label(string.format("%s x%d", item.name, count), UDim2.new(0.66, -6, 1, -4), UDim2.fromOffset(6, 2), Color3.fromRGB(170, 255, 200)).Parent = r
			button("Use", UDim2.new(0.3, 0, 1, -6), UDim2.new(0.68, 0, 0, 3), Color3.fromRGB(60, 140, 90), function()
				ActionRemote:FireServer("use", id)
			end).Parent = r
		end
	end
	if not any then
		order += 1
		label("None. The Alchemist sells potions.", UDim2.new(1, 0, 0, 18), UDim2.new(), Color3.fromRGB(180, 170, 160)).Parent = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = order, Parent = gearList })
	end

	heading("Materials")
	any = false
	for id, count in snapshot.materials do
		local m = Loot.Materials[id]
		if m and count > 0 then
			any = true
			order += 1
			local r = row(gearList, order, 22)
			label(string.format("%s x%d", m.name, count), UDim2.new(1, -12, 1, -4), UDim2.fromOffset(6, 2), m.color).Parent = r
		end
	end
	if not any then
		order += 1
		label("None yet. Monsters drop them.", UDim2.new(1, 0, 0, 18), UDim2.new(), Color3.fromRGB(180, 170, 160)).Parent = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = order, Parent = gearList })
	end

	-- the bag, best first
	clear(bagGrid)
	local items = table.clone(snapshot.bag)
	table.sort(items, function(a, b)
		return if a.r ~= b.r then a.r > b.r else a.b < b.b
	end)
	for i, item in items do
		local rarity = Loot.Rarities[item.r] or Loot.Rarities[1]
		local equipped = snapshot.gear[item.b] and snapshot.gear[item.b].u == item.u
		local card = make("Frame", { BackgroundColor3 = CARD, LayoutOrder = i, Parent = bagGrid }, {
			corner(6),
			make("UIStroke", { Color = rarity.color, Thickness = if equipped then 3 else 1 }),
		})
		label(Loot.weaponName(item.b, item.r), UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 3), rarity.color).Parent = card
		label(string.format("%s  x%.2f", rarity.name, rarity.power), UDim2.new(1, -10, 0, 16), UDim2.fromOffset(5, 26), WHITE).Parent = card
		if equipped then
			label("Equipped", UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 48), GOLD, FONT, Enum.TextXAlignment.Center).Parent = card
		else
			button("Equip", UDim2.new(0.48, -4, 0, 22), UDim2.new(0, 4, 0, 47), Color3.fromRGB(70, 110, 170), function()
				ActionRemote:FireServer("equip", item.u)
			end).Parent = card
			button(string.format("Salvage %d", rarity.salvage), UDim2.new(0.52, -6, 0, 22), UDim2.new(0.48, 2, 0, 47), Color3.fromRGB(120, 80, 50), function()
				ActionRemote:FireServer("salvage", item.u)
			end).Parent = card
		end
	end
	if #items == 0 then
		label("Your bag is empty. Defeat monsters or visit the Blacksmith.", UDim2.new(1, -12, 0, 22), UDim2.fromOffset(6, 6), Color3.fromRGB(180, 170, 160)).Parent = bagGrid
	end
end

----------------------------------------------------------------------------------------------
-- shop window

local shopWin, shopTitle = window("Shop", 520, 420)
local greeting = label("", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 40), Color3.fromRGB(220, 210, 190))
greeting.Parent = shopWin
local dewLabel = label("", UDim2.new(0.5, -14, 0, 22), UDim2.new(0.5, 0, 1, -34), GOLD, FONT, Enum.TextXAlignment.Right)
dewLabel.Parent = shopWin
local shopList = make("ScrollingFrame", {
	BackgroundColor3 = Color3.fromRGB(30, 24, 22),
	Position = UDim2.fromOffset(14, 66),
	Size = UDim2.new(1, -28, 1, -112),
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = shopWin,
}, {
	corner(6),
	make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
	make("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }),
})
local sellButton = button("Sell all materials", UDim2.new(0.46, 0, 0, 30), UDim2.new(0, 14, 1, -38), Color3.fromRGB(150, 110, 50), function()
	ActionRemote:FireServer("sellMaterials")
end)
sellButton.Parent = shopWin

local function describe(item: Shops.Item): (string, Color3)
	if item.kind == "weapon" then
		local r = Loot.Rarities[item.rarity or 1]
		return string.format("%s weapon, x%.2f damage", r.name, r.power), r.color
	elseif item.kind == "armor" then
		return string.format("Armour, blocks %d%% of damage", math.floor((item.reduce or 0) * 100)), Color3.fromRGB(190, 210, 255)
	elseif item.kind == "unlock" then
		return if item.unlock == "horse" then "Ride with V: much faster travel" else "Call with P: your best Sproutling fights beside you", Color3.fromRGB(255, 210, 140)
	end
	local parts = {}
	if item.heal then
		table.insert(parts, "+" .. item.heal .. " health")
	end
	if item.stamina then
		table.insert(parts, "+" .. item.stamina .. " stamina")
	end
	return table.concat(parts, ", "), Color3.fromRGB(170, 255, 200)
end

local function renderShop()
	if not currentShop or not snapshot then
		return
	end
	local shop = Shops.Catalog[currentShop]
	if not shop then
		return
	end
	dewLabel.Text = string.format("Your Dew: %d", snapshot.dew or 0)
	local value = 0
	for id, count in snapshot.materials do
		local m = Loot.Materials[id]
		if m then
			value += m.value * count
		end
	end
	sellButton.Text = string.format("Sell all materials (+%d Dew)", value)
	clear(shopList)
	local nextOrder = #shop.items
	if shop.travel then
		local price = Travel.Prices[shop.travel] or 0
		local j = 0
		for _, dest in Travel.Destinations do
			if dest.modes[shop.travel] then
				j += 1
				local r = make("Frame", { BackgroundColor3 = Color3.fromRGB(46, 58, 78), Size = UDim2.new(1, 0, 0, 44), LayoutOrder = nextOrder + j, Parent = shopList }, { corner(6) })
				label(dest.name, UDim2.new(0.62, -8, 0, 24), UDim2.fromOffset(8, 10), Color3.fromRGB(190, 225, 255)).Parent = r
				button(string.format("Go %d", price), UDim2.new(0.34, 0, 0, 32), UDim2.new(0.64, 0, 0, 6), Color3.fromRGB(60, 110, 170), function()
					TravelRemote:FireServer(dest.id)
					shopWin.Visible = false
				end).Parent = r
			end
		end
		nextOrder += j
	end
	if shop.cooking then
		for j, recipe in Recipes.List do
			local have = true
			local parts = {}
			for id, count in recipe.needs do
				local m = Loot.Materials[id]
				local owned = snapshot.materials[id] or 0
				if owned < count then
					have = false
				end
				table.insert(parts, string.format("%s %d/%d", if m then m.name else id, owned, count))
			end
			local r = make("Frame", { BackgroundColor3 = Color3.fromRGB(58, 48, 70), Size = UDim2.new(1, 0, 0, 70), LayoutOrder = nextOrder + j, Parent = shopList }, { corner(6) })
			label(recipe.name, UDim2.new(0.62, -8, 0, 22), UDim2.fromOffset(8, 3), Color3.fromRGB(255, 210, 140)).Parent = r
			label(recipe.blurb, UDim2.new(0.62, -8, 0, 18), UDim2.fromOffset(8, 26), Color3.fromRGB(210, 200, 185)).Parent = r
			label(table.concat(parts, "  "), UDim2.new(0.62, -8, 0, 16), UDim2.fromOffset(8, 47), if have then Color3.fromRGB(150, 240, 160) else Color3.fromRGB(240, 150, 150)).Parent = r
			button(if have then "Cook" else "Missing", UDim2.new(0.34, 0, 0, 34), UDim2.new(0.64, 0, 0, 18), if have then Color3.fromRGB(170, 100, 50) else Color3.fromRGB(80, 80, 80), function()
				if have then
					ActionRemote:FireServer("cook", recipe.id)
				end
			end).Parent = r
		end
	end
	for i, item in shop.items do
		local text, color = describe(item)
		local r = make("Frame", { BackgroundColor3 = CARD, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = i, Parent = shopList }, { corner(6) })
		label(item.name, UDim2.new(0.62, -8, 0, 24), UDim2.fromOffset(8, 3), color).Parent = r
		label(text, UDim2.new(0.62, -8, 0, 18), UDim2.fromOffset(8, 28), Color3.fromRGB(210, 200, 185)).Parent = r
		local owned = (item.kind == "armor" and (item.tier or 0) <= (snapshot.armor or 0))
			or (item.kind == "unlock" and player:GetAttribute("Unlock_" .. (item.unlock or "")) == true)
		local b = button(if owned then "Owned" else string.format("Buy %d", item.price), UDim2.new(0.34, 0, 0, 34), UDim2.new(0.64, 0, 0, 9), if owned then Color3.fromRGB(80, 80, 80) else Color3.fromRGB(70, 140, 80), function()
			if not owned then
				ActionRemote:FireServer("buy", item.id)
			end
		end)
		b.Parent = r
	end
end

----------------------------------------------------------------------------------------------
-- the Bag button and keys

local bagButton = button("Bag (B)", UDim2.fromOffset(78, 46), UDim2.new(0.5, 158, 1, -182), Color3.fromRGB(110, 80, 50), function()
	inv.Visible = not inv.Visible
	if inv.Visible then
		ActionRemote:FireServer("refresh")
	end
end)
bagButton.AnchorPoint = Vector2.new(0, 0)
bagButton.Parent = gui
local potionLabel = label("", UDim2.fromOffset(78, 16), UDim2.new(0.5, 158, 1, -134), Color3.fromRGB(170, 255, 200), FONT, Enum.TextXAlignment.Center)
potionLabel.Parent = gui

local function updatePotionLabel()
	local n = player:GetAttribute("Potions") or 0
	potionLabel.Text = if n > 0 then string.format("H: %d potions", n) else ""
end
player:GetAttributeChangedSignal("Potions"):Connect(updatePotionLabel)
updatePotionLabel()

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		inv.Visible = not inv.Visible
		if inv.Visible then
			ActionRemote:FireServer("refresh")
		end
	elseif input.KeyCode == Enum.KeyCode.H then
		ActionRemote:FireServer("use", "potion_health")
	elseif input.KeyCode == Enum.KeyCode.J then
		ActionRemote:FireServer("use", "potion_stamina")
	elseif input.KeyCode == Enum.KeyCode.P then
		CompanionRemote:FireServer("pet")
	elseif input.KeyCode == Enum.KeyCode.V then
		CompanionRemote:FireServer("horse")
	end
end)

-- Pet / Ride buttons (for phones), shown once bought
local petButton = button("Pet (P)", UDim2.fromOffset(78, 40), UDim2.new(0.5, 242, 1, -182), Color3.fromRGB(70, 130, 80), function()
	CompanionRemote:FireServer("pet")
end)
petButton.Parent = gui
local rideButton = button("Ride (V)", UDim2.fromOffset(78, 40), UDim2.new(0.5, 242, 1, -136), Color3.fromRGB(130, 90, 50), function()
	CompanionRemote:FireServer("horse")
end)
rideButton.Parent = gui
local function updateUnlockButtons()
	petButton.Visible = player:GetAttribute("Unlock_companion") == true
	rideButton.Visible = player:GetAttribute("Unlock_horse") == true
	petButton.Text = if player:GetAttribute("PetOut") then "Dismiss (P)" else "Pet (P)"
	rideButton.Text = if player:GetAttribute("Mounted") then "Dismount" else "Ride (V)"
end
for _, attr in { "Unlock_companion", "Unlock_horse", "PetOut", "Mounted" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		updateUnlockButtons()
		renderShop()
	end)
end
updateUnlockButtons()

-- active meal buffs, listed above the health bar
local buffLabel = label("", UDim2.fromOffset(300, 18), UDim2.new(0.5, -150, 1, -158), Color3.fromRGB(255, 220, 150), FONT, Enum.TextXAlignment.Center)
buffLabel.Parent = gui
task.spawn(function()
	while true do
		local now = workspace:GetServerTimeNow()
		local seen = {}
		local parts = {}
		for _, kind in { "damage", "defense", "speed", "stamina", "regen" } do
			local ends = player:GetAttribute("Buff_" .. kind)
			local name = player:GetAttribute("BuffName_" .. kind)
			if typeof(ends) == "number" and ends > now and typeof(name) == "string" and not seen[name] then
				seen[name] = true
				local left = math.floor(ends - now)
				table.insert(parts, string.format("%s %d:%02d", name, left // 60, left % 60))
			end
		end
		buffLabel.Text = table.concat(parts, "   ")
		task.wait(0.5)
	end
end)

InventoryRemote.OnClientEvent:Connect(function(data)
	snapshot = data
	renderInventory()
	renderShop()
end)

OpenShopRemote.OnClientEvent:Connect(function(key: string, name: string, text: string)
	currentShop = key
	shopTitle.Text = name
	greeting.Text = text
	shopWin.Visible = true
	inv.Visible = false
	renderShop()
end)

return Inventory
