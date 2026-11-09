-- Loot drops and gear.
--
-- When an enemy dies, LootService.drop() rolls its table (Shared.Loot) and leaves glowing
-- pickups that only the player who earned them can collect, by walking close. A weapon better
-- than the one you have upgrades it (damage x rarity power); a worse one is salvaged for Dew.
-- Materials are counted for cooking later. Gear and materials save with the player's data.
--
-- Data: data.gear = { [weaponId] = { r = rarityIndex } }, data.materials = { [id] = count }.
-- Player attributes for the HUD: Gear_<weaponId> = rarity index.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Loot = require(ReplicatedStorage:WaitForChild("Shared").Loot)

local State = require(script.Parent.State)
local InventoryService = require(script.Parent.InventoryService)

local LootService = {}

local rng = Random.new()
local PICKUP_RANGE = 7
local PICKUP_LIFETIME = 90

type Pickup = { part: BasePart, owner: number, expires: number, weapon: Loot.WeaponDrop?, material: string? }
local pickups: { Pickup } = {}
local folder: Folder

local function gearOf(session): { [string]: { r: number } }
	local data = session.data
	data.gear = data.gear or {}
	for _, id in Loot.WeaponIds do
		if type(data.gear[id]) ~= "table" then
			data.gear[id] = { r = 1 }
		end
	end
	return data.gear
end

local function sync(player: Player)
	local session = State.get(player)
	if not session then
		return
	end
	for id, g in gearOf(session) do
		player:SetAttribute("Gear_" .. id, g.r)
	end
end

-- Damage multiplier for a player's weapon (1 if unknown).
function LootService.power(player: Player, weaponId: string): number
	local session = State.get(player)
	if not session then
		return 1
	end
	local g = gearOf(session)[weaponId]
	local rarity = Loot.Rarities[g and g.r or 1]
	return rarity and rarity.power or 1
end

----------------------------------------------------------------------------------------------
-- giving loot

-- Weapons go into the bag (InventoryService), auto-equipping if better.
function LootService.giveWeapon(player: Player, drop: Loot.WeaponDrop)
	InventoryService.addWeapon(player, drop.base, drop.rarity)
end

function LootService.giveMaterial(player: Player, id: string, count: number)
	InventoryService.addMaterial(player, id, count)
end

----------------------------------------------------------------------------------------------
-- pickups in the world

local function spawnPickup(owner: Player, pos: Vector3, color: Color3, label: string, weapon: Loot.WeaponDrop?, material: string?)
	local p: BasePart = Instance.new("Part")
	p.Name = "Loot"
	(p :: Part).Shape = Enum.PartType.Ball
	p.Size = if weapon then Vector3.new(1.8, 1.8, 1.8) else Vector3.new(1.2, 1.2, 1.2)
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-2, 2), 2, rng:NextNumber(-2, 2)))
	p:SetAttribute("Owner", owner.UserId)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = if weapon then 14 else 8
	light.Brightness = 1.5
	light.Parent = p
	if weapon then
		-- a pillar of light so rare drops are easy to spot
		local beam = Instance.new("Part")
		beam.Name = "LootBeam"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Material = Enum.Material.Neon
		beam.Color = color
		beam.Transparency = 0.6
		beam.Size = Vector3.new(0.6, 18, 0.6)
		beam.CFrame = p.CFrame + Vector3.new(0, 9, 0)
		beam.Parent = p
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 30)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Parent = p
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = color
	text.TextStrokeTransparency = 0.3
	text.Text = label
	text.Parent = gui
	p.Parent = folder
	table.insert(pickups, { part = p, owner = owner.UserId, expires = os.clock() + PICKUP_LIFETIME, weapon = weapon, material = material })
end

-- Rolls an enemy's drop table and leaves pickups for `killer` at pos.
function LootService.drop(killer: Player?, enemyId: string, pos: Vector3)
	local table_ = Loot.Drops[enemyId]
	if not table_ or not killer or not killer.Parent then
		return
	end
	if table_.material and rng:NextNumber() < table_.materialChance then
		local m = Loot.Materials[table_.material]
		spawnPickup(killer, pos, m.color, m.name, nil, m.id)
	end
	if rng:NextNumber() < table_.weaponChance then
		local w = Loot.rollWeapon(rng, table_.minRarity)
		local rarity = Loot.Rarities[w.rarity]
		spawnPickup(killer, pos, rarity.color, Loot.weaponName(w.base, w.rarity), w, nil)
	end
end

-- Opens a crypt chest for one player: weapons straight into their gear, plus Dew.
function LootService.openChest(player: Player, kind: string)
	local chest = Loot.Chests[kind]
	local session = State.get(player)
	if not chest or not session then
		return
	end
	for _ = 1, chest.weapons do
		LootService.giveWeapon(player, Loot.rollWeapon(rng, chest.minRarity))
	end
	State.addDew(session, chest.dew, "Chest:" .. kind)
	State.notify(session, string.format("The chest held %d Dew!", chest.dew), "#ffd27a")
	InventoryService.push(player)
end

----------------------------------------------------------------------------------------------

function LootService.init()
	folder = Instance.new("Folder")
	folder.Name = "Loot"
	folder.Parent = Workspace
	Players.PlayerAdded:Connect(function(player)
		-- the session is created by the bootstrap; wait for it, then publish gear
		for _ = 1, 40 do
			if State.get(player) then
				break
			end
			task.wait(0.25)
		end
		sync(player)
	end)
	task.spawn(function()
		while true do
			local t = os.clock()
			for i = #pickups, 1, -1 do
				local p = pickups[i]
				local done = t > p.expires or not p.part.Parent
				if not done then
					local owner = Players:GetPlayerByUserId(p.owner)
					local character = owner and owner.Character
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if not owner then
						done = true
					elseif root and (root.Position - p.part.Position).Magnitude <= PICKUP_RANGE then
						if p.weapon then
							LootService.giveWeapon(owner, p.weapon)
						elseif p.material then
							LootService.giveMaterial(owner, p.material, 1)
						end
						done = true
					else
						-- gentle bob
						p.part.CFrame = p.part.CFrame * CFrame.Angles(0, 0.2, 0)
					end
				end
				if done then
					p.part:Destroy()
					table.remove(pickups, i)
				end
			end
			task.wait(0.15)
		end
	end)
end

return LootService
