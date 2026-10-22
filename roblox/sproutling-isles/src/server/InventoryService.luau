-- Inventory and shops.
--
-- Data (saved with the player):
--   data.bag         = { { u = uid, b = base, r = rarity } }   weapons you carry (Shops.BagSize max)
--   data.gear[base]  = { r = rarity, u = uid? }                 equipped weapon per type (r = 1 is
--                                                               the starter weapon, never in the bag)
--   data.armor       = tier (0 = none, see Shops.Armor)
--   data.consumables = { [itemId] = count }
--   data.materials   = { [materialId] = count }
--
-- The client gets a full snapshot through the Inventory remote whenever something changes and
-- asks for changes through InventoryAction. Shops open from a ProximityPrompt on each city
-- ShopAnchor; buying and selling only work while standing near the shop you opened.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loot = require(Shared.Loot)
local Shops = require(Shared.Shops)
local Recipes = require(Shared.Recipes)

local State = require(script.Parent.State)
local Prompts = require(script.Parent.Prompts)
local BuffService = require(script.Parent.BuffService)
local LevelService = require(script.Parent.LevelService)
local Vehicles = require(Shared.Vehicles)

local InventoryService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end
local InventoryRemote = remote("Inventory") -- server -> client: (snapshot)
local ActionRemote = remote("InventoryAction") -- client -> server: (action, arg)
local OpenShopRemote = remote("OpenShop") -- server -> client: (shopKey, displayName, greeting)

local SHOP_RANGE = 22
local openShop: { [Player]: { key: string, pos: Vector3 } } = {}
local staminaHandler: ((Player, number) -> ())? = nil

----------------------------------------------------------------------------------------------
-- data

local function normalise(data)
	data.bag = data.bag or {}
	data.gear = data.gear or {}
	for _, id in Loot.WeaponIds do
		if type(data.gear[id]) ~= "table" then
			data.gear[id] = { r = 1 }
		end
	end
	data.armor = data.armor or 0
	data.consumables = data.consumables or {}
	data.materials = data.materials or {}
	data.unlocks = data.unlocks or {}
	data.vehicles = data.vehicles or {}
	data.crates = data.crates or {}
	return data
end

local function hex(c: Color3): string
	return string.format("#%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

function InventoryService.push(player: Player)
	local session = State.get(player)
	if not session then
		return
	end
	local data = normalise(session.data)
	for _, id in Loot.WeaponIds do
		player:SetAttribute("Gear_" .. id, data.gear[id].r)
	end
	player:SetAttribute("Armor", data.armor)
	player:SetAttribute("Potions", data.consumables.potion_health or 0)
	for id, on in data.unlocks do
		player:SetAttribute("Unlock_" .. id, on == true)
	end
	-- owned vehicles and their colours, and unopened crates (garage, paint shops, crate window)
	for id, v in data.vehicles do
		player:SetAttribute("Vehicle_" .. id, true)
		player:SetAttribute("VPaint_" .. id, v.paint or 1)
		player:SetAttribute("VTrim_" .. id, v.trim or 1)
	end
	for _, tier in { "wood", "silver", "gold" } do
		player:SetAttribute("Crates_" .. tier, data.crates[tier] or 0)
	end
	InventoryRemote:FireClient(player, {
		bag = data.bag,
		gear = data.gear,
		armor = data.armor,
		consumables = data.consumables,
		materials = data.materials,
		dew = data.dew,
	})
end

-- Fraction of incoming damage blocked by worn armour plus meal buffs (0..0.75).
function InventoryService.armorReduction(player: Player): number
	local session = State.get(player)
	local tier = session and session.data.armor or 0
	local armor = Shops.Armor[tier]
	return math.min(0.75, (armor and armor.reduce or 0) + BuffService.get(player, "defense"))
end

-- Adds a material (herbs, monster parts) and tells the player.
function InventoryService.addMaterial(player: Player, id: string, count: number)
	local session = State.get(player)
	local m = Loot.Materials[id]
	if not session or not m then
		return
	end
	local data = normalise(session.data)
	data.materials[id] = (data.materials[id] or 0) + count
	player:SetAttribute("Mat_" .. id, data.materials[id])
	State.notify(session, string.format("+%d %s", count, m.name), hex(m.color))
	InventoryService.push(player)
end

-- Garden bonus: every hatch on your plot also yields a herb for cooking.
function InventoryService.gardenHarvest(player: Player)
	local roll = math.random()
	for _, h in Recipes.GardenHerbs do
		if roll < h.chance then
			InventoryService.addMaterial(player, h.id, 1)
			return
		end
	end
end

function InventoryService.setStaminaHandler(fn: (Player, number) -> ())
	staminaHandler = fn
end

----------------------------------------------------------------------------------------------
-- weapons

local function equip(player: Player, data, item)
	data.gear[item.b] = { r = item.r, u = item.u }
	player:SetAttribute("Gear_" .. item.b, item.r)
end

-- Adds a weapon (from a drop, chest or shop). Auto-equips it if it beats what you're using.
function InventoryService.addWeapon(player: Player, base: string, rarity: number, quiet: boolean?)
	local session = State.get(player)
	if not session then
		return
	end
	local data = normalise(session.data)
	local r = Loot.Rarities[rarity]
	local name = Loot.weaponName(base, rarity)
	if #data.bag >= Shops.BagSize then
		-- full bag: salvage the incoming item instead of losing something you chose to keep
		State.addDew(session, r.salvage, "Salvage:" .. base)
		State.notify(session, string.format("Bag full! Salvaged %s for %d Dew", name, r.salvage), "#d8d8d8")
		InventoryService.push(player)
		return
	end
	local item = { u = State.newUid(), b = base, r = rarity }
	table.insert(data.bag, item)
	if rarity > data.gear[base].r then
		equip(player, data, item)
		State.notify(session, string.format("Equipped %s (%s, x%.2f damage)", name, r.name, r.power), hex(r.color))
	elseif not quiet then
		State.notify(session, string.format("%s added to your bag", name), hex(r.color))
	end
	InventoryService.push(player)
end

local function findItem(data, uid: any): (any, number?)
	for i, item in data.bag do
		if item.u == uid then
			return item, i
		end
	end
	return nil, nil
end

local function isEquipped(data, item): boolean
	return data.gear[item.b] and data.gear[item.b].u == item.u
end

----------------------------------------------------------------------------------------------
-- actions

-- The shop key the player opened and is still standing near, or nil.
function InventoryService.nearShop(player: Player): string?
	local shop = openShop[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if shop and root and (root.Position - shop.pos).Magnitude <= SHOP_RANGE then
		return shop.key
	end
	return nil
end

local function onAction(player: Player, action: any, arg: any)
	local session = State.get(player)
	if not session or typeof(action) ~= "string" then
		return
	end
	local data = normalise(session.data)
	if action == "equip" then
		local item = findItem(data, arg)
		if item then
			equip(player, data, item)
			State.notify(session, "Equipped " .. Loot.weaponName(item.b, item.r), hex(Loot.Rarities[item.r].color))
		end
	elseif action == "unequip" then
		-- back to the starter weapon of that type
		if typeof(arg) == "string" and data.gear[arg] then
			data.gear[arg] = { r = 1 }
			player:SetAttribute("Gear_" .. arg, 1)
		end
	elseif action == "salvage" then
		local item, index = findItem(data, arg)
		if item and index then
			if isEquipped(data, item) then
				State.notify(session, "Unequip it first.", "#ff9a9a")
			else
				table.remove(data.bag, index)
				local r = Loot.Rarities[item.r]
				State.addDew(session, r.salvage, "Salvage:" .. item.b)
				State.notify(session, string.format("Salvaged for %d Dew", r.salvage), "#d8d8d8")
			end
		end
	elseif action == "use" then
		-- shop consumables and cooked meals share the consumables counter
		local item: any = if typeof(arg) == "string" then (Shops.Consumables[arg] or Recipes.get(arg)) else nil
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if item and humanoid and humanoid.Health > 0 and (data.consumables[arg] or 0) > 0 then
			data.consumables[arg] -= 1
			if item.heal then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + item.heal)
			end
			if item.stamina and staminaHandler then
				staminaHandler(player, item.stamina)
			end
			if item.buff then
				BuffService.apply(player, item.buff, item.duration or 60, item.name)
			end
			if item.xp then
				LevelService.addXP(player, item.xp, "Read")
				State.notify(session, "You read the " .. item.name .. ". +" .. item.xp .. " XP", "#c8b4ff")
			else
				State.notify(session, "Used " .. item.name .. (if item.blurb then " - " .. item.blurb else ""), "#9affc4")
			end
		end
	elseif action == "cook" then
		local key = InventoryService.nearShop(player)
		local shop = key and Shops.Catalog[key]
		local recipe = if typeof(arg) == "string" then Recipes.get(arg) else nil
		if not shop or not shop.cooking then
			State.notify(session, "You need a kitchen to cook.", "#ff9a9a")
		elseif recipe then
			local missing = false
			for id, count in recipe.needs do
				if (data.materials[id] or 0) < count then
					missing = true
				end
			end
			if missing then
				State.notify(session, "You don't have the ingredients for that.", "#ff9a9a")
			else
				for id, count in recipe.needs do
					data.materials[id] -= count
					player:SetAttribute("Mat_" .. id, data.materials[id])
				end
				data.consumables[recipe.id] = (data.consumables[recipe.id] or 0) + 1
				State.notify(session, "You cooked " .. recipe.name .. "! Eat it from your bag (B).", "#ffd27a")
			end
		end
	elseif action == "buy" then
		local key = InventoryService.nearShop(player)
		local shop = key and Shops.Catalog[key]
		local item = if typeof(arg) == "string" then Shops.item(arg) else nil
		if not shop or not item or not table.find(shop.items, item) then
			State.notify(session, "Walk back to the shop to buy that.", "#ff9a9a")
		elseif item.kind == "armor" and (item.tier or 0) <= data.armor then
			State.notify(session, "You already wear armour that good.", "#d8d8d8")
		elseif item.kind == "unlock" and data.unlocks[item.unlock or ""] then
			State.notify(session, "You already have that.", "#d8d8d8")
		elseif item.kind == "vehicle" and data.vehicles[item.vehicle or ""] then
			State.notify(session, "That's already in your garage (G).", "#d8d8d8")
		elseif item.level and (data.level or 1) < item.level then
			State.notify(session, string.format("You need to be level %d for that.", item.level), "#ff9a9a")
		elseif item.kind == "weapon" and #data.bag >= Shops.BagSize then
			State.notify(session, "Your bag is full.", "#ff9a9a")
		elseif not State.spendDew(session, item.price, "Shop:" .. item.id) then
			State.notify(session, string.format("You need %d Dew for that.", item.price), "#ff9a9a")
		else
			if item.kind == "weapon" then
				InventoryService.addWeapon(player, item.base :: string, item.rarity :: number)
			elseif item.kind == "armor" then
				data.armor = item.tier :: number
				State.notify(session, "You put on the " .. item.name .. ".", "#c8d8ff")
			elseif item.kind == "consumable" then
				data.consumables[item.id] = (data.consumables[item.id] or 0) + 1
				State.notify(session, "Bought " .. item.name, "#9affc4")
			elseif item.kind == "vehicle" then
				data.vehicles[item.vehicle :: string] = { paint = 1, trim = 1 }
				State.notify(session, "The " .. item.name .. " is yours! Press G to open your garage and ride it.", "#ffd27a")
			elseif item.kind == "crate" then
				data.crates[item.crate :: string] = (data.crates[item.crate :: string] or 0) + 1
				State.notify(session, "Bought a " .. item.name .. ". Open it from the Crates button.", "#ffd27a")
			elseif item.kind == "unlock" then
				data.unlocks[item.unlock :: string] = true
				player:SetAttribute("Unlock_" .. (item.unlock :: string), true)
				State.notify(session, if item.unlock == "horse" then "Your horse is ready! Press V to ride." else "Your best Sproutling will fight beside you! Press P to call it.", "#ffd27a")
			end
		end
	elseif action == "paint" then
		-- arg = { vehicle = id, slot = "paint" | "trim", index = n }, at a paint shop for that class
		local key = InventoryService.nearShop(player)
		local shop = key and Shops.Catalog[key]
		local vehicle = typeof(arg) == "table" and typeof(arg.vehicle) == "string" and Vehicles.get(arg.vehicle)
		local owned = vehicle and data.vehicles[vehicle.id]
		local index = typeof(arg) == "table" and tonumber(arg.index)
		local slot = typeof(arg) == "table" and arg.slot
		if not shop or not shop.customize or not vehicle or vehicle.class ~= shop.customize then
			State.notify(session, "Bring it to the right paint shop.", "#ff9a9a")
		elseif not owned or not index or not Vehicles.Paints[index] or (slot ~= "paint" and slot ~= "trim") then
			return
		elseif not State.spendDew(session, Vehicles.PaintPrice, "Paint") then
			State.notify(session, string.format("A new coat costs %d Dew.", Vehicles.PaintPrice), "#ff9a9a")
		else
			owned[slot] = index
			State.notify(session, string.format("%s %s: %s", vehicle.name, slot, Vehicles.Paints[index].name), "#ffd27a")
		end
	elseif action == "sellMaterials" then
		if not InventoryService.nearShop(player) then
			State.notify(session, "Walk back to the shop to sell.", "#ff9a9a")
		else
			local total = 0
			for id, count in data.materials do
				local m = Loot.Materials[id]
				if m and count > 0 then
					total += m.value * count
					data.materials[id] = 0
					player:SetAttribute("Mat_" .. id, 0)
				end
			end
			if total > 0 then
				State.addDew(session, total, "SellMaterials")
				State.notify(session, string.format("Sold your materials for %d Dew", total), "#ffd27a")
			else
				State.notify(session, "You have no materials to sell.", "#d8d8d8")
			end
		end
	end
	-- every action (including "refresh") ends with a fresh snapshot
	InventoryService.push(player)
end

----------------------------------------------------------------------------------------------

function InventoryService.init(map: Instance)
	ActionRemote.OnServerEvent:Connect(onAction)
	Players.PlayerAdded:Connect(function(player)
		for _ = 1, 40 do
			if State.get(player) then
				break
			end
			task.wait(0.25)
		end
		InventoryService.push(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		openShop[player] = nil
	end)

	-- a prompt at every shop counter (city, airship port inn, hamlet cooking pots)
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "ShopAnchor" then
			local id = d:GetAttribute("Shop")
			if typeof(id) == "string" then
				local shop, key = Shops.get(id)
				local action = if not shop then "Closed" elseif key == "kitchen" then "Cook" elseif shop.customize then "Customize" elseif shop.map then "Look" else "Browse"
				local prompt = Prompts.create(d, action, if shop then shop.name else "Shop", 0)
				prompt.MaxActivationDistance = 12
				prompt.Triggered:Connect(function(player)
					local session = State.get(player)
					if not session then
						return
					end
					if not shop then
						State.notify(session, "This trade opens in a later update.", "#d8d8d8")
						return
					end
					openShop[player] = { key = key, pos = d.CFrame.Position }
					InventoryService.push(player)
					OpenShopRemote:FireClient(player, key, shop.name, shop.greeting)
				end)
			end
		end
	end
end

return InventoryService
