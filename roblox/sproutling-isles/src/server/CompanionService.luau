-- Companions and mounts (bought from the Beast Tamer and the Stables in the city).
--
-- P calls or dismisses your companion: your best Sproutling (highest Dew/s across your pads and
-- storage) floats at your shoulder and zaps the nearest monster every couple of seconds. Its
-- damage grows with how strong that Sproutling is. Kills it makes count as yours (loot and Dew).
-- V mounts or dismounts your horse: a steed welded under you that adds MountSpeed to your
-- walk speed (see BuffService.refreshSpeed). No riding inside the crypt. Both are cleared when
-- your character respawns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SproutModel = require(Shared.SproutModel)

local State = require(script.Parent.State)
local BuffService = require(script.Parent.BuffService)
local EnemyService = require(script.Parent.EnemyService)
local CombatService = require(script.Parent.CombatService)

local CompanionService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local CompanionRemote = Instance.new("RemoteEvent")
CompanionRemote.Name = "Companion" -- client -> server: ("pet" | "horse")
CompanionRemote.Parent = remotes

local MOUNT_SPEED = 14
local MOUNT_HIP = 3.4
local PET_RANGE = 24
local PET_COOLDOWN = 1.8

type Pet = { model: Model, damage: number, nextAttack: number, name: string }
local pets: { [Player]: Pet } = {}
local mounts: { [Player]: { model: Model, hip: number } } = {}

local function notify(player: Player, text: string, color: string?)
	local session = State.get(player)
	if session then
		State.notify(session, text, color)
	end
end

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

----------------------------------------------------------------------------------------------
-- companion

local function bestSprout(session: State.Session): SproutModel.Sprout?
	local best, bestIncome = nil, -1
	local function consider(sprout: SproutModel.Sprout?)
		if sprout and sprout.s then
			local income = SproutModel.income(sprout)
			if income > bestIncome then
				best, bestIncome = sprout, income
			end
		end
	end
	for _, sprout in session.data.pads do
		consider(sprout)
	end
	for _, sprout in session.data.storage do
		consider(sprout)
	end
	return best
end

local function dismissPet(player: Player)
	local pet = pets[player]
	if pet then
		pet.model:Destroy()
		pets[player] = nil
	end
	player:SetAttribute("PetOut", false)
end

local function callPet(player: Player)
	local session = State.get(player)
	local root = rootOf(player)
	if not session or not root then
		return
	end
	local sprout = bestSprout(session)
	if not sprout then
		notify(player, "You have no Sproutlings yet. Hatch one in your garden first!", "#ffb070")
		return
	end
	local model = SproutModel.build(sprout, false)
	model.Name = "Companion"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	model.Parent = player.Character
	SproutModel.weldTo(model, root, CFrame.new(3.2, 2.2, 1.5))
	local income = SproutModel.income(sprout)
	local damage = math.clamp(math.floor(6 + math.log(1 + income, 2) * 2.5), 6, 40)
	local name = SproutModel.displayName(sprout)
	pets[player] = { model = model, damage = damage, nextAttack = 0, name = name }
	player:SetAttribute("PetOut", true)
	notify(player, string.format("%s joins you! (%d damage per zap)", name, damage), "#a0ffa0")
end

local function petTick(t: number)
	for player, pet in pets do
		local root = rootOf(player)
		if not root or not pet.model.Parent then
			dismissPet(player)
		elseif t >= pet.nextAttack then
			local nearest, best = nil, PET_RANGE
			for _, enemy in EnemyService.near(root.Position, PET_RANGE) do
				local d = (enemy.root.Position - root.Position).Magnitude
				if d <= best and not enemy.dead then
					nearest, best = enemy, d
				end
			end
			if nearest then
				pet.nextAttack = t + PET_COOLDOWN
				local from = (pet.model.PrimaryPart :: BasePart).Position
				local to = nearest.root.Position
				local dir = (to - from).Unit
				CombatService.fx("impact", { id = -1, pos = to, kind = "staff", radius = 2 })
				EnemyService.damage(nearest, pet.damage, player, Vector3.new(dir.X, 0, dir.Z), 6)
			end
		end
	end
end

----------------------------------------------------------------------------------------------
-- horse

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = true
	p.Parent = parent
	return p
end

-- A saddled horse built around the origin, facing -Z (the way a character faces).
local function buildHorse(): Model
	local m = Instance.new("Model")
	m.Name = "Steed"
	local coat = Color3.fromRGB(150, 100, 65)
	local dark = Color3.fromRGB(45, 34, 28)
	local body = part(m, "Body", Vector3.new(2.6, 2.6, 6), CFrame.new(0, 0, 0), coat)
	m.PrimaryPart = body
	part(m, "Neck", Vector3.new(1.5, 3.4, 1.7), CFrame.new(0, 1.8, -3) * CFrame.Angles(math.rad(35), 0, 0), coat)
	part(m, "Head", Vector3.new(1.3, 1.4, 2.8), CFrame.new(0, 3.3, -4.3) * CFrame.Angles(math.rad(-25), 0, 0), coat)
	part(m, "Mane", Vector3.new(0.5, 3.4, 1.6), CFrame.new(0, 2.2, -2.5) * CFrame.Angles(math.rad(35), 0, 0), dark, Enum.Material.Fabric)
	part(m, "Tail", Vector3.new(0.6, 2.8, 0.8), CFrame.new(0, -0.2, 3.4) * CFrame.Angles(math.rad(-25), 0, 0), dark, Enum.Material.Fabric)
	for _, l in { { -0.8, -2.2 }, { 0.8, -2.2 }, { -0.8, 2.2 }, { 0.8, 2.2 } } do
		part(m, "Leg", Vector3.new(0.7, 3.2, 0.7), CFrame.new(l[1], -2.9, l[2]), coat)
		part(m, "Hoof", Vector3.new(0.8, 0.5, 0.9), CFrame.new(l[1], -4.6, l[2]), dark)
	end
	part(m, "Saddle", Vector3.new(2.8, 0.5, 2.4), CFrame.new(0, 1.5, 0.2), Color3.fromRGB(120, 40, 35), Enum.Material.Fabric)
	part(m, "Blanket", Vector3.new(2.9, 1.3, 2.8), CFrame.new(0, 1, 0.2), Color3.fromRGB(40, 60, 140), Enum.Material.Fabric)
	part(m, "BlanketTrim", Vector3.new(2.95, 0.25, 2.85), CFrame.new(0, 0.4, 0.2), Color3.fromRGB(230, 190, 90), Enum.Material.Fabric)
	return m
end

local function dismount(player: Player)
	local mount = mounts[player]
	if mount then
		mount.model:Destroy()
		mounts[player] = nil
		local _, humanoid = rootOf(player)
		if humanoid then
			humanoid.HipHeight = mount.hip
		end
	end
	player:SetAttribute("MountSpeed", 0)
	player:SetAttribute("Mounted", false)
	BuffService.refreshSpeed(player)
end

local function mount(player: Player)
	local root, humanoid = rootOf(player)
	if not root or not humanoid then
		return
	end
	if player:GetAttribute("InDungeon") then
		notify(player, "Your horse won't go down into the crypt.", "#ffb070")
		return
	end
	if player:GetAttribute("VehicleId") then
		notify(player, "Leave your vehicle first (G).", "#ffb070")
		return
	end
	local model = buildHorse()
	model.Parent = player.Character
	local hip = humanoid.HipHeight
	humanoid.HipHeight = hip + MOUNT_HIP
	-- the saddle sits just under the rider's hips
	SproutModel.weldTo(model, root, CFrame.new(0, -1.6, 0.3))
	mounts[player] = { model = model, hip = hip }
	player:SetAttribute("MountSpeed", MOUNT_SPEED)
	player:SetAttribute("Mounted", true)
	BuffService.refreshSpeed(player)
end

----------------------------------------------------------------------------------------------

local function unlocked(player: Player, id: string): boolean
	local session = State.get(player)
	return session ~= nil and session.data.unlocks ~= nil and session.data.unlocks[id] == true
end

local cooldown: { [Player]: number } = {}

function CompanionService.init()
	CompanionRemote.OnServerEvent:Connect(function(player, what)
		if os.clock() < (cooldown[player] or 0) then
			return
		end
		cooldown[player] = os.clock() + 0.6
		if what == "pet" then
			if not unlocked(player, "companion") then
				notify(player, "Visit the Beast Tamer in the city to bond with a Sproutling companion.", "#ffb070")
			elseif pets[player] then
				dismissPet(player)
			else
				callPet(player)
			end
		elseif what == "horse" then
			if not unlocked(player, "horse") then
				notify(player, "Buy a horse at the Stables in the city to ride.", "#ffb070")
			elseif mounts[player] then
				dismount(player)
			else
				mount(player)
			end
		end
	end)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			pets[player] = nil
			mounts[player] = nil
			player:SetAttribute("PetOut", false)
			player:SetAttribute("Mounted", false)
			player:SetAttribute("MountSpeed", 0)
		end)
		-- entering the crypt sends the horse home
		player:GetAttributeChangedSignal("InDungeon"):Connect(function()
			if player:GetAttribute("InDungeon") and mounts[player] then
				dismount(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		pets[player] = nil
		mounts[player] = nil
		cooldown[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			petTick(os.clock())
		end
	end)
end

return CompanionService
