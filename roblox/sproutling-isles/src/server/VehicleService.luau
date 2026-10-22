-- Owned vehicles (Shared/Vehicles): summon one from the garage (G) and ride it.
--
-- The vehicle model is welded under the player's character, painted in their chosen colours
-- (parts named "Body" take the paint, "Trim" the trim). Land vehicles add MountSpeed like the
-- horse. Water and air vehicles set VehicleClass/VehicleSpeed/VehicleFlight attributes, and the
-- client (client/Vehicles.luau) drives the character's physics: holding to the sea surface, or
-- flying. Boats can only be summoned beside water; nothing can be summoned in the crypt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Vehicles = require(Shared.Vehicles)
local Landscape = require(Shared.Landscape)

local State = require(script.Parent.State)
local BuffService = require(script.Parent.BuffService)

local VehicleService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local VehicleRemote = Instance.new("RemoteEvent")
VehicleRemote.Name = "Vehicle" -- client -> server: ("summon", vehicleId) | ("dismiss")
VehicleRemote.Parent = remotes

type Ride = { model: Model, hip: number, id: string }
local rides: { [Player]: Ride } = {}

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function notify(player: Player, text: string, color: string?)
	local session = State.get(player)
	if session then
		State.notify(session, text, color)
	end
end

----------------------------------------------------------------------------------------------
-- models, built round the rider (origin = HumanoidRootPart, facing -Z)

local function piece(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = m
	return p
end

local WOOD = Color3.fromRGB(120, 85, 55)
local DARK = Color3.fromRGB(45, 38, 32)
local COAT = Color3.fromRGB(150, 100, 65)

local function horse(m: Model, x: number, y: number, z: number, coat: Color3)
	piece(m, "HorseBody", Vector3.new(2.6, 2.6, 6), CFrame.new(x, y, z), coat)
	piece(m, "HorseNeck", Vector3.new(1.5, 3.4, 1.7), CFrame.new(x, y + 1.8, z - 3) * CFrame.Angles(math.rad(35), 0, 0), coat)
	piece(m, "HorseHead", Vector3.new(1.3, 1.4, 2.8), CFrame.new(x, y + 3.3, z - 4.3) * CFrame.Angles(math.rad(-25), 0, 0), coat)
	piece(m, "Mane", Vector3.new(0.5, 3.4, 1.6), CFrame.new(x, y + 2.2, z - 2.5) * CFrame.Angles(math.rad(35), 0, 0), DARK, Enum.Material.Fabric)
	for _, l in { { -0.8, -2.2 }, { 0.8, -2.2 }, { -0.8, 2.2 }, { 0.8, 2.2 } } do
		piece(m, "Leg", Vector3.new(0.7, 3.2, 0.7), CFrame.new(x + l[1], y - 2.9, z + l[2]), coat)
	end
end

local function wheel(m: Model, x: number, y: number, z: number, d: number, color: Color3)
	piece(m, "Wheel", Vector3.new(0.5, d, d), CFrame.new(x, y, z), color, Enum.Material.Wood, Enum.PartType.Cylinder)
end

local BUILD: { [string]: (Model) -> number } = {} -- returns the hip height to add

BUILD.wagon = function(m)
	horse(m, 0, -1.6, 0.3, COAT)
	piece(m, "Saddle", Vector3.new(2.8, 0.5, 2.4), CFrame.new(0, 0, 0.5), Color3.fromRGB(120, 40, 35), Enum.Material.Fabric)
	piece(m, "Body", Vector3.new(4.6, 2, 6), CFrame.new(0, -2.4, 8.5), COAT, Enum.Material.WoodPlanks)
	piece(m, "Trim", Vector3.new(4.8, 0.4, 6.2), CFrame.new(0, -1.3, 8.5), COAT, Enum.Material.Wood)
	for _, s in { -1, 1 } do
		wheel(m, s * 2.6, -3.6, 8.5, 3.4, WOOD)
		piece(m, "Shaft", Vector3.new(0.3, 0.3, 5), CFrame.new(s * 1.6, -2.4, 4.4), WOOD, Enum.Material.Wood)
	end
	piece(m, "Hay", Vector3.new(3.8, 1.2, 5), CFrame.new(0, -0.8, 8.5), Color3.fromRGB(235, 205, 110), Enum.Material.Fabric)
	return 3.4
end

BUILD.carriage = function(m)
	piece(m, "Bench", Vector3.new(4, 0.6, 2), CFrame.new(0, -3.1, 0.4), WOOD, Enum.Material.WoodPlanks)
	piece(m, "Body", Vector3.new(5, 5, 7), CFrame.new(0, -1.6, 5.5), COAT, Enum.Material.WoodPlanks)
	piece(m, "Trim", Vector3.new(5.4, 0.6, 7.4), CFrame.new(0, 1.2, 5.5), COAT, Enum.Material.SmoothPlastic)
	piece(m, "Roof", Vector3.new(5.6, 0.5, 7.6), CFrame.new(0, 1.6, 5.5), DARK, Enum.Material.Wood)
	for _, s in { -1, 1 } do
		piece(m, "Window", Vector3.new(0.1, 2, 2.6), CFrame.new(s * 2.55, -0.6, 5.5), Color3.fromRGB(255, 220, 150), Enum.Material.Glass)
		wheel(m, s * 2.8, -4.6, 3.2, 3, WOOD)
		wheel(m, s * 2.8, -4.2, 8, 3.8, WOOD)
		horse(m, s * 1.6, -3.4, -6, if s < 0 then COAT else Color3.fromRGB(70, 55, 45))
	end
	return 3.6
end

BUILD.coach = function(m)
	local gold = Color3.fromRGB(225, 185, 70)
	piece(m, "Bench", Vector3.new(4.4, 0.6, 2), CFrame.new(0, -3.1, 0.4), gold, Enum.Material.Metal)
	piece(m, "Body", Vector3.new(6, 6, 9), CFrame.new(0, -1.2, 6.5), COAT, Enum.Material.SmoothPlastic)
	piece(m, "Trim", Vector3.new(6.4, 0.7, 9.4), CFrame.new(0, 2, 6.5), gold, Enum.Material.Metal)
	piece(m, "Crown", Vector3.new(2, 1.4, 2), CFrame.new(0, 3, 6.5), gold, Enum.Material.Metal)
	for _, s in { -1, 1 } do
		piece(m, "Window", Vector3.new(0.1, 2.4, 3.4), CFrame.new(s * 3.05, -0.4, 6.5), Color3.fromRGB(255, 220, 150), Enum.Material.Glass)
		wheel(m, s * 3.3, -4.4, 3.6, 3.6, gold)
		wheel(m, s * 3.3, -4, 9.6, 4.4, gold)
		horse(m, s * 1.6, -3.4, -6, Color3.fromRGB(240, 238, 230))
		horse(m, s * 1.6, -3.4, -13, Color3.fromRGB(240, 238, 230))
	end
	return 3.6
end

BUILD.rowboat = function(m)
	piece(m, "Body", Vector3.new(4.6, 1.6, 10), CFrame.new(0, -3.6, 0), COAT, Enum.Material.WoodPlanks)
	piece(m, "Trim", Vector3.new(4.9, 0.4, 10.3), CFrame.new(0, -2.7, 0), COAT, Enum.Material.Wood)
	piece(m, "Bow", Vector3.new(3, 1.4, 2.4), CFrame.new(0, -3.4, -5.6), COAT, Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		piece(m, "Oar", Vector3.new(0.3, 0.3, 7), CFrame.new(s * 3.6, -3, 1) * CFrame.Angles(0, s * math.rad(60), math.rad(-12)), WOOD, Enum.Material.Wood)
	end
	return 0
end

BUILD.sloop = function(m)
	piece(m, "Body", Vector3.new(6, 2.4, 16), CFrame.new(0, -3.8, 1), COAT, Enum.Material.WoodPlanks)
	piece(m, "Trim", Vector3.new(6.3, 0.5, 16.3), CFrame.new(0, -2.5, 1), COAT, Enum.Material.Wood)
	piece(m, "Bow", Vector3.new(4, 2, 3), CFrame.new(0, -3.6, -8.2), COAT, Enum.Material.WoodPlanks)
	piece(m, "Mast", Vector3.new(0.6, 18, 0.6), CFrame.new(0, 6, 2), WOOD, Enum.Material.Wood)
	piece(m, "Sail", Vector3.new(0.3, 12, 8), CFrame.new(0.4, 7, 4.5), Color3.fromRGB(245, 240, 225), Enum.Material.Fabric)
	return 0
end

BUILD.barge = function(m)
	piece(m, "Body", Vector3.new(6.4, 2.4, 14), CFrame.new(0, -3.8, 1.5), COAT, Enum.Material.SmoothPlastic)
	piece(m, "Trim", Vector3.new(6.8, 0.5, 14.4), CFrame.new(0, -2.5, 1.5), COAT, Enum.Material.Metal)
	piece(m, "SwanNeck", Vector3.new(1.4, 7, 1.4), CFrame.new(0, -0.6, -6.4) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(250, 250, 250))
	piece(m, "SwanHead", Vector3.new(1.6, 1.6, 2.6), CFrame.new(0, 3, -7.6), Color3.fromRGB(250, 250, 250))
	piece(m, "Beak", Vector3.new(0.6, 0.6, 1.4), CFrame.new(0, 2.8, -9.2), Color3.fromRGB(240, 140, 40))
	for _, s in { -1, 1 } do
		piece(m, "Wing", Vector3.new(0.4, 3, 9), CFrame.new(s * 3.4, -1.6, 2) * CFrame.Angles(0, 0, s * math.rad(-20)), Color3.fromRGB(250, 250, 250))
	end
	return 0
end

BUILD.ornithopter = function(m)
	piece(m, "Frame", Vector3.new(1.2, 0.6, 10), CFrame.new(0, -3, 1), WOOD, Enum.Material.Wood)
	piece(m, "Seat", Vector3.new(2.4, 0.6, 2.4), CFrame.new(0, -3.1, 0), WOOD, Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		piece(m, "Body", Vector3.new(11, 0.3, 5), CFrame.new(s * 6.4, -0.4, 0.5) * CFrame.Angles(0, 0, s * math.rad(-10)), COAT, Enum.Material.Fabric)
		piece(m, "Trim", Vector3.new(11, 0.5, 0.5), CFrame.new(s * 6.4, -0.1, -2), COAT, Enum.Material.Wood)
		piece(m, "Rib", Vector3.new(10, 0.3, 0.3), CFrame.new(s * 6.4, -0.3, 2.4), WOOD, Enum.Material.Wood)
	end
	piece(m, "Tail", Vector3.new(5, 0.3, 3.5), CFrame.new(0, -2.4, 6.6), COAT, Enum.Material.Fabric)
	return 0
end

BUILD.aerialscrew = function(m)
	piece(m, "Platform", Vector3.new(6, 0.8, 6), CFrame.new(0, -3.2, 0), WOOD, Enum.Material.WoodPlanks)
	piece(m, "Mast", Vector3.new(0.6, 9, 0.6), CFrame.new(0, 1.5, 1.5), WOOD, Enum.Material.Wood)
	local screw = piece(m, "Body", Vector3.new(0.6, 16, 16), CFrame.new(0, 6.5, 1.5) * CFrame.Angles(0, 0, math.rad(90)), COAT, Enum.Material.Fabric, Enum.PartType.Cylinder)
	screw:SetAttribute("Spin", 2)
	piece(m, "Trim", Vector3.new(0.4, 16.6, 16.6), CFrame.new(0, 6.1, 1.5) * CFrame.Angles(0, 0, math.rad(90)), COAT, Enum.Material.Metal, Enum.PartType.Cylinder)
	for _, s in { -1, 1 } do
		piece(m, "Rail", Vector3.new(0.3, 1.6, 6), CFrame.new(s * 3, -2, 0), WOOD, Enum.Material.Wood)
	end
	return 0
end

BUILD.skyship = function(m)
	piece(m, "Gondola", Vector3.new(6, 2, 10), CFrame.new(0, -3.6, 1), WOOD, Enum.Material.WoodPlanks)
	piece(m, "Trim", Vector3.new(6.3, 0.4, 10.3), CFrame.new(0, -2.5, 1), COAT, Enum.Material.Metal)
	piece(m, "Body", Vector3.new(9, 9, 22), CFrame.new(0, 9, 1), COAT, Enum.Material.Fabric, Enum.PartType.Ball)
	for _, s in { -1, 1 } do
		piece(m, "Rope", Vector3.new(0.2, 8, 0.2), CFrame.new(s * 2.6, 2, -3), DARK, Enum.Material.Fabric)
		piece(m, "Rope", Vector3.new(0.2, 8, 0.2), CFrame.new(s * 2.6, 2, 5), DARK, Enum.Material.Fabric)
		piece(m, "Fin", Vector3.new(0.3, 3, 4), CFrame.new(s * 2, 10, 11.5), COAT, Enum.Material.Fabric)
	end
	local prop = piece(m, "Propeller", Vector3.new(0.3, 4, 0.6), CFrame.new(0, -3, 6.4), DARK, Enum.Material.Metal)
	prop:SetAttribute("Spin", 8)
	return 0
end

BUILD.griffin = function(m)
	piece(m, "Body", Vector3.new(3.6, 3.4, 8), CFrame.new(0, -3.6, 0.6), COAT, Enum.Material.Fabric)
	piece(m, "Head", Vector3.new(2.4, 2.4, 2.6), CFrame.new(0, -1.4, -4.4), Color3.fromRGB(245, 245, 240), Enum.Material.Fabric)
	piece(m, "Beak", Vector3.new(0.8, 0.8, 1.6), CFrame.new(0, -1.6, -6.2), Color3.fromRGB(240, 190, 60))
	for _, s in { -1, 1 } do
		piece(m, "Trim", Vector3.new(12, 0.4, 4.6), CFrame.new(s * 7.4, -1.8, 0) * CFrame.Angles(0, 0, s * math.rad(-15)), COAT, Enum.Material.Fabric)
		piece(m, "Eye", Vector3.new(0.3, 0.4, 0.2), CFrame.new(s * 0.7, -1.1, -5.65), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
		piece(m, "Leg", Vector3.new(0.8, 2.4, 0.8), CFrame.new(s * 1.2, -6.2, -1.6), Color3.fromRGB(240, 190, 60))
	end
	piece(m, "Tail", Vector3.new(0.8, 0.8, 5), CFrame.new(0, -3.4, 6.8) * CFrame.Angles(math.rad(-20), 0, 0), COAT, Enum.Material.Fabric)
	return 0
end

----------------------------------------------------------------------------------------------

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

local function clearAttributes(player: Player)
	player:SetAttribute("VehicleId", nil)
	player:SetAttribute("VehicleClass", nil)
	player:SetAttribute("VehicleSpeed", nil)
	player:SetAttribute("VehicleFlight", nil)
	player:SetAttribute("MountSpeed", 0)
end

function VehicleService.dismiss(player: Player)
	local ride = rides[player]
	if ride then
		ride.model:Destroy()
		rides[player] = nil
		local _, humanoid = rootOf(player)
		if humanoid then
			humanoid.HipHeight = ride.hip
		end
	end
	clearAttributes(player)
	BuffService.refreshSpeed(player)
end

-- The nearest open water within reach of (x, z), if any.
local function waterNear(pos: Vector3): Vector3?
	local best, bestD = nil, math.huge
	for r = 0, 40, 8 do
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			local x, z = pos.X + math.cos(a) * r, pos.Z + math.sin(a) * r
			if not Landscape.inPlayArea(x, z) and Landscape.height(x, z) < Landscape.WaterLevel - 1 and r < bestD then
				best, bestD = Vector3.new(x, Landscape.WaterLevel, z), r
			end
		end
		if best then
			return best
		end
	end
	return nil
end

local function summon(player: Player, id: any)
	local session = State.get(player)
	local vehicle = typeof(id) == "string" and Vehicles.get(id)
	local root, humanoid = rootOf(player)
	if not session or not vehicle or not root or not humanoid then
		return
	end
	local owned = session.data.vehicles and session.data.vehicles[vehicle.id]
	if not owned then
		notify(player, "You don't own that yet. Visit the " .. vehicle.shopName .. ".", "#ffb070")
		return
	end
	if player:GetAttribute("InDungeon") then
		notify(player, "There's no room for that down here.", "#ffb070")
		return
	end
	if player:GetAttribute("Mounted") then
		notify(player, "Get off your horse first (V).", "#ffb070")
		return
	end
	if vehicle.class == "water" then
		local spot = waterNear(root.Position)
		if not spot then
			notify(player, "Boats need water. Walk to the shore and try again.", "#ffb070")
			return
		end
		VehicleService.dismiss(player)
		;(player.Character :: Model):PivotTo(CFrame.new(spot + Vector3.new(0, 4, 0)))
	else
		VehicleService.dismiss(player)
	end
	-- build round the rider, paint it, weld it on
	local m = Instance.new("Model")
	m.Name = "Vehicle"
	local hipAdd = BUILD[vehicle.id](m)
	local paint = rgb((Vehicles.Paints[owned.paint or 1] or Vehicles.Paints[1]).rgb)
	local trim = rgb((Vehicles.Paints[owned.trim or 1] or Vehicles.Paints[1]).rgb)
	local frame = root.CFrame
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			if p.Name == "Body" then
				p.Color = paint
			elseif p.Name == "Trim" then
				p.Color = trim
			end
			p.CFrame = frame * p.CFrame
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		end
	end
	m.Parent = player.Character
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			p.Anchored = false
		end
	end
	local hip = humanoid.HipHeight
	humanoid.HipHeight = hip + hipAdd
	rides[player] = { model = m, hip = hip, id = vehicle.id }
	player:SetAttribute("VehicleId", vehicle.id)
	player:SetAttribute("VehicleClass", vehicle.class)
	player:SetAttribute("VehicleSpeed", vehicle.speed)
	player:SetAttribute("VehicleFlight", vehicle.flight)
	player:SetAttribute("MountSpeed", if vehicle.class == "land" then vehicle.speed else 0)
	BuffService.refreshSpeed(player)
	notify(player, "You ride the " .. vehicle.name .. "!" .. (if vehicle.class == "air" then " Space to climb, Shift to dive." else ""), "#bfe3ff")
end

function VehicleService.init()
	VehicleRemote.OnServerEvent:Connect(function(player, action, id)
		if action == "summon" then
			summon(player, id)
		elseif action == "dismiss" then
			VehicleService.dismiss(player)
		end
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			rides[player] = nil
			clearAttributes(player)
		end)
		player:GetAttributeChangedSignal("InDungeon"):Connect(function()
			if player:GetAttribute("InDungeon") and rides[player] then
				VehicleService.dismiss(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		rides[player] = nil
	end)
end

return VehicleService
