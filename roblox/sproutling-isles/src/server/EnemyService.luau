-- Enemies: builds the monster models, spawns them at the hill camps (and training dummies in
-- the barracks yard), runs their AI, and handles damage, death, rewards and respawns.
--
-- AI per enemy, ticked a few times a second: wander near the camp; chase the nearest living
-- player inside aggro range; when in reach, telegraph (red flash) for `attackWindup` seconds,
-- then hit if the player is still in reach and not mid-dodge; give up and walk home past the
-- leash range. Models are server-owned so players can't push them around by network ownership.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Combat)
local Landscape = require(Shared.Landscape)

local CombatService = require(script.Parent.CombatService)
local LootService = require(script.Parent.LootService)

local EnemyService = {}

type Enemy = {
	kind: Combat.EnemyType,
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	radius: number,
	home: Vector3,
	target: Player?,
	nextAttack: number,
	winding: boolean,
	nextWander: number,
	lastHitBy: Player?,
	dead: boolean,
	leash: number,
	onDeath: ((Enemy) -> ())?,
	respawn: boolean,
	attackIndex: number,
}

export type SpawnOptions = {
	respawn: boolean?, -- default: true when the enemy type has a respawn time
	onDeath: ((any) -> ())?,
	leash: number?,
}

local enemies: { Enemy } = {}
local folder: Folder
local bossAttack: (any, Vector3, Vector3) -> () -- defined below, used by think()

----------------------------------------------------------------------------------------------
-- models

local function piece(m: Model, root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = root.CFrame * offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.Parent = m
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	return p
end

-- Returns the model, its root and its hit radius. `at` is the ground point to stand on.
local function build(kind: Combat.EnemyType, at: Vector3): (Model, BasePart, number)
	local m = Instance.new("Model")
	m.Name = kind.name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Transparency = 1
	root.CanCollide = true
	m.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayName = kind.name
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.NameDisplayDistance = 70
	humanoid.HealthDisplayDistance = 70
	humanoid.MaxHealth = kind.health
	humanoid.Health = kind.health
	humanoid.WalkSpeed = kind.speed
	local radius = 2.5
	local id = kind.id
	if id == "slime" then
		root.Size = Vector3.new(4, 3, 4)
		root.CFrame = CFrame.new(at + Vector3.new(0, 1.7, 0))
		humanoid.HipHeight = 0.1
		local tint = Color3.fromRGB(110, 200, 90)
		piece(m, root, "Body", Vector3.new(4.6, 4.6, 4.6), CFrame.new(0, 0.2, 0), tint, Enum.Material.Glass, Enum.PartType.Ball).Transparency = 0.15
		piece(m, root, "Core", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 0.3, 0), Color3.fromRGB(60, 140, 50), Enum.Material.Neon, Enum.PartType.Ball)
		for _, s in { -1, 1 } do
			piece(m, root, "Eye", Vector3.new(0.7, 0.9, 0.3), CFrame.new(s * 0.8, 1, -2.1), Color3.fromRGB(20, 20, 20))
		end
		radius = 2.6
	elseif id == "goblin" then
		root.Size = Vector3.new(2.4, 2.4, 1.6)
		root.CFrame = CFrame.new(at + Vector3.new(0, 3.3, 0))
		humanoid.HipHeight = 2.1
		local skin = Color3.fromRGB(110, 160, 70)
		piece(m, root, "Torso", Vector3.new(2.4, 2.4, 1.6), CFrame.new(), Color3.fromRGB(120, 80, 50), Enum.Material.Fabric)
		piece(m, root, "Head", Vector3.new(2, 1.8, 1.8), CFrame.new(0, 2.1, 0), skin)
		for _, s in { -1, 1 } do
			piece(m, root, "Ear", Vector3.new(1.4, 0.4, 0.4), CFrame.new(s * 1.5, 2.4, 0) * CFrame.Angles(0, 0, s * math.rad(-20)), skin)
			piece(m, root, "Eye", Vector3.new(0.4, 0.4, 0.2), CFrame.new(s * 0.45, 2.3, -0.92), Color3.fromRGB(255, 220, 60), Enum.Material.Neon)
			piece(m, root, "Leg", Vector3.new(0.8, 2.2, 0.8), CFrame.new(s * 0.6, -2.3, 0), skin)
			piece(m, root, "Arm", Vector3.new(0.7, 2.2, 0.7), CFrame.new(s * 1.6, -0.2, 0), skin)
		end
		for k = 0, 3 do
			piece(m, root, "Thorn", Vector3.new(0.4, 1, 0.4), CFrame.new(-0.6 + k * 0.4, 1.2, 0.9) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(70, 110, 50))
		end
		piece(m, root, "Club", Vector3.new(0.6, 3, 0.6), CFrame.new(1.8, -0.6, -1) * CFrame.Angles(math.rad(-60), 0, 0), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
		radius = 2
	elseif id == "wolf" then
		root.Size = Vector3.new(2.4, 2.2, 6)
		root.CFrame = CFrame.new(at + Vector3.new(0, 3.2, 0))
		humanoid.HipHeight = 2.1
		local fur = Color3.fromRGB(110, 110, 120)
		piece(m, root, "Body", Vector3.new(2.4, 2.2, 6), CFrame.new(), fur, Enum.Material.Fabric)
		piece(m, root, "Head", Vector3.new(2, 1.8, 2.4), CFrame.new(0, 0.8, -3.6), fur, Enum.Material.Fabric)
		piece(m, root, "Snout", Vector3.new(1.1, 0.9, 1.4), CFrame.new(0, 0.4, -5.2), Color3.fromRGB(80, 80, 88), Enum.Material.Fabric)
		for _, s in { -1, 1 } do
			piece(m, root, "Ear", Vector3.new(0.5, 0.9, 0.4), CFrame.new(s * 0.6, 2, -3.4), fur, Enum.Material.Fabric)
			piece(m, root, "Eye", Vector3.new(0.35, 0.3, 0.2), CFrame.new(s * 0.5, 1.1, -4.85), Color3.fromRGB(255, 120, 60), Enum.Material.Neon)
			piece(m, root, "Leg", Vector3.new(0.7, 2.2, 0.7), CFrame.new(s * 0.8, -2.1, -2), fur, Enum.Material.Fabric)
			piece(m, root, "Leg", Vector3.new(0.7, 2.2, 0.7), CFrame.new(s * 0.8, -2.1, 2), fur, Enum.Material.Fabric)
		end
		piece(m, root, "Tail", Vector3.new(0.6, 0.6, 2.4), CFrame.new(0, 0.6, 3.8) * CFrame.Angles(math.rad(25), 0, 0), fur, Enum.Material.Fabric)
		radius = 3
	elseif id == "warden" then
		-- a towering skeleton in an iron crown with a rusted cleaver
		local s = kind.size or 2
		root.Size = Vector3.new(3.2, 3.2, 2) * s
		root.CFrame = CFrame.new(at + Vector3.new(0, 4.6 * s, 0))
		humanoid.HipHeight = 3 * s
		local bone = Color3.fromRGB(225, 218, 200)
		piece(m, root, "Ribcage", Vector3.new(3.2, 3.2, 2) * s, CFrame.new(), bone)
		piece(m, root, "Spine", Vector3.new(0.8, 2.6, 0.8) * s, CFrame.new(0, -2.6 * s, 0), bone)
		piece(m, root, "Pelvis", Vector3.new(2.6, 0.9, 1.4) * s, CFrame.new(0, -3.8 * s, 0), bone)
		piece(m, root, "Skull", Vector3.new(2.2, 2.2, 2.2) * s, CFrame.new(0, 2.8 * s, 0), bone, nil, Enum.PartType.Ball)
		piece(m, root, "Jaw", Vector3.new(1.6, 0.5, 1.4) * s, CFrame.new(0, 1.7 * s, -0.4 * s), bone)
		for _, side in { -1, 1 } do
			piece(m, root, "Eye", Vector3.new(0.5, 0.4, 0.2) * s, CFrame.new(side * 0.45 * s, 2.9 * s, -1.05 * s), Color3.fromRGB(110, 230, 255), Enum.Material.Neon)
			piece(m, root, "Arm", Vector3.new(0.7, 4.2, 0.7) * s, CFrame.new(side * 2.2 * s, -0.6 * s, 0) * CFrame.Angles(0, 0, side * math.rad(8)), bone)
			piece(m, root, "Leg", Vector3.new(0.8, 3.2, 0.8) * s, CFrame.new(side * 0.9 * s, -5.6 * s, 0), bone)
		end
		for k = 0, 4 do
			piece(m, root, "Crown", Vector3.new(0.35, 1.1, 0.35) * s, CFrame.new((k - 2) * 0.45 * s, 4 * s, 0), Color3.fromRGB(70, 70, 76), Enum.Material.Metal)
		end
		piece(m, root, "Cleaver", Vector3.new(0.3, 5.5, 1.8) * s, CFrame.new(2.6 * s, -2.6 * s, -1.2 * s) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(130, 95, 70), Enum.Material.CorrodedMetal)
		radius = 3.4 * s
	elseif id == "treant" then
		-- an ancient walking tree with amber eyes and a mossy crown
		local s = kind.size or 2.5
		root.Size = Vector3.new(3.4, 4.4, 3.4) * s
		root.CFrame = CFrame.new(at + Vector3.new(0, 5 * s, 0))
		humanoid.HipHeight = 2.8 * s
		local bark = Color3.fromRGB(95, 70, 50)
		piece(m, root, "Trunk", Vector3.new(4.4, 3.4, 3.4) * s, CFrame.new() * CFrame.Angles(0, 0, math.rad(90)), bark, Enum.Material.Wood, Enum.PartType.Cylinder)
		piece(m, root, "Moss", Vector3.new(3.5, 1, 3.5) * s, CFrame.new(0, 0.6 * s, 0), Color3.fromRGB(80, 130, 60), Enum.Material.Grass)
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			piece(m, root, "Canopy", Vector3.new(3.4, 3.4, 3.4) * s, CFrame.new(math.cos(a) * 1.6 * s, 3.6 * s, math.sin(a) * 1.6 * s), Color3.fromRGB(70 + k * 8, 140 + k * 6, 60), Enum.Material.Grass, Enum.PartType.Ball)
		end
		piece(m, root, "Crown", Vector3.new(3.8, 3.8, 3.8) * s, CFrame.new(0, 4.6 * s, 0), Color3.fromRGB(90, 160, 70), Enum.Material.Grass, Enum.PartType.Ball)
		for _, side in { -1, 1 } do
			piece(m, root, "Eye", Vector3.new(0.6, 0.4, 0.2) * s, CFrame.new(side * 0.6 * s, 1.2 * s, -1.75 * s), Color3.fromRGB(255, 190, 60), Enum.Material.Neon)
			piece(m, root, "Arm", Vector3.new(1, 5, 1) * s, CFrame.new(side * 2.6 * s, -0.6 * s, -0.6 * s) * CFrame.Angles(math.rad(-20), 0, side * math.rad(20)), bark, Enum.Material.Wood)
			piece(m, root, "Claw", Vector3.new(1.6, 0.6, 1.6) * s, CFrame.new(side * 3.4 * s, -3 * s, -1.4 * s), bark, Enum.Material.Wood)
			piece(m, root, "Leg", Vector3.new(1.4, 3, 1.4) * s, CFrame.new(side * 1 * s, -3.6 * s, 0), bark, Enum.Material.Wood)
		end
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + 0.4
			piece(m, root, "Root", Vector3.new(0.7, 0.7, 3) * s, CFrame.new(math.cos(a) * 1.8 * s, -4.8 * s, math.sin(a) * 1.8 * s) * CFrame.Angles(math.rad(-30), a, 0), bark, Enum.Material.Wood)
		end
		radius = 4 * s
	else -- training dummy
		root.Size = Vector3.new(2.6, 4, 2.6)
		root.CFrame = CFrame.new(at + Vector3.new(0, 2.4, 0))
		root.Anchored = true
		humanoid.HipHeight = 0
		piece(m, root, "Post", Vector3.new(0.5, 7, 0.5), CFrame.new(0, 1, 0), Color3.fromRGB(110, 75, 50), Enum.Material.Wood)
		piece(m, root, "Sack", Vector3.new(3, 3.4, 3), CFrame.new(0, 0.4, 0), Color3.fromRGB(215, 195, 145), Enum.Material.Fabric, Enum.PartType.Ball)
		piece(m, root, "Head", Vector3.new(2, 2, 2), CFrame.new(0, 3, 0), Color3.fromRGB(215, 195, 145), Enum.Material.Fabric, Enum.PartType.Ball)
		piece(m, root, "Arms", Vector3.new(5, 0.5, 0.5), CFrame.new(0, 1.8, 0), Color3.fromRGB(110, 75, 50), Enum.Material.Wood)
		radius = 2
	end
	root.Parent = m
	humanoid.Parent = m
	return m, root, radius
end

----------------------------------------------------------------------------------------------
-- spawning

local function spawnEnemy(kind: Combat.EnemyType, home: Vector3, opts: SpawnOptions?): Enemy
	local options: SpawnOptions = opts or {}
	local model, root, radius = build(kind, home)
	model:SetAttribute("Enemy", kind.id)
	if kind.boss then
		model:SetAttribute("Boss", true)
	end
	model.Parent = folder
	if not root.Anchored then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local enemy: Enemy = {
		kind = kind,
		model = model,
		root = root,
		humanoid = humanoid,
		radius = radius,
		home = home,
		target = nil,
		nextAttack = 0,
		winding = false,
		nextWander = os.clock() + math.random() * 4,
		lastHitBy = nil,
		dead = false,
		leash = options.leash or Combat.LeashRange,
		onDeath = options.onDeath,
		respawn = if options.respawn == nil then kind.respawn > 0 else options.respawn,
		attackIndex = 0,
	}
	table.insert(enemies, enemy)
	humanoid.Died:Connect(function()
		if enemy.dead then
			return
		end
		enemy.dead = true
		local killer = enemy.lastHitBy
		local deathPos = root.Position
		if killer and killer.Parent then
			CombatService.reward(killer, kind.reward, kind.name)
			LootService.drop(killer, kind.id, deathPos)
		end
		CombatService.fx("defeat", { pos = deathPos, kind = kind.id, boss = kind.boss })
		if enemy.onDeath then
			task.spawn(enemy.onDeath, enemy)
		end
		task.delay(0.6, function()
			model:Destroy()
		end)
		for i, e in enemies do
			if e == enemy then
				table.remove(enemies, i)
				break
			end
		end
		if enemy.respawn then
			task.delay(kind.respawn, function()
				spawnEnemy(kind, home, options)
			end)
		end
	end)
	return enemy
end

-- Spawns an enemy of kind `id` standing at `pos` (the ground point). Used by DungeonService.
function EnemyService.spawn(id: string, pos: Vector3, opts: SpawnOptions?): any
	local kind = Combat.Enemies[id]
	assert(kind, "unknown enemy " .. tostring(id))
	return spawnEnemy(kind, pos, opts)
end

-- Removes an enemy without rewards or loot (dungeon reset).
function EnemyService.despawn(enemy: any)
	if enemy.dead then
		return
	end
	enemy.dead = true
	for i, e in enemies do
		if e == enemy then
			table.remove(enemies, i)
			break
		end
	end
	enemy.model:Destroy()
end

-- Ground height at (x, z): the terrain hills, or the flat city/island (y = 0.4 for flagstones).
local function groundAt(x: number, z: number): number
	if Landscape.inPlayArea(x, z) then
		return 0.4
	end
	return Landscape.height(x, z)
end

local function spawnCamps()
	for ci, camp in Combat.Camps do
		local kind = Combat.Enemies[camp.kind]
		for k = 1, camp.count do
			local a = (k / camp.count) * math.pi * 2 + ci
			local x, z = camp.x + math.cos(a) * 10, camp.z + math.sin(a) * 10
			spawnEnemy(kind, Vector3.new(x, groundAt(x, z), z))
		end
	end
end

----------------------------------------------------------------------------------------------
-- damage (called through CombatService)

function EnemyService.damage(enemy: Enemy, amount: number, by: Player, knockDir: Vector3, knockback: number)
	if enemy.dead or enemy.humanoid.Health <= 0 then
		return
	end
	enemy.lastHitBy = by
	enemy.target = enemy.target or by
	local dealt = math.min(amount, enemy.humanoid.Health)
	enemy.humanoid:TakeDamage(amount)
	if not enemy.root.Anchored then
		enemy.root.AssemblyLinearVelocity = knockDir * knockback + Vector3.new(0, knockback * 0.4, 0)
	end
	CombatService.fx("hit", { model = enemy.model, pos = enemy.root.Position + Vector3.new(0, enemy.radius, 0), amount = math.floor(dealt + 0.5) })
	if enemy.kind.dummy then
		-- training dummies never die: top them back up shortly after
		task.delay(1.5, function()
			if not enemy.dead then
				enemy.humanoid.Health = enemy.humanoid.MaxHealth
			end
		end)
	end
end

-- Living enemies within radius of pos (plus their size).
function EnemyService.near(pos: Vector3, radius: number): { Enemy }
	local out = {}
	for _, e in enemies do
		if not e.dead and e.model.Parent and (e.root.Position - pos).Magnitude <= radius + e.radius then
			table.insert(out, e)
		end
	end
	return out
end

----------------------------------------------------------------------------------------------
-- AI

local function nearestPlayer(pos: Vector3, range: number): (Player?, BasePart?)
	local best: Player?, bestRoot: BasePart?, bestDist = nil, nil, range
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local d = (root.Position - pos).Magnitude
			if d < bestDist then
				best, bestRoot, bestDist = p, root, d
			end
		end
	end
	return best, bestRoot
end

-- Players (alive) inside a boss attack's area.
local function playersIn(center: Vector3, radius: number, dir: Vector3?, arc: number?): { Player }
	local out = {}
	local cosArc = if arc then math.cos(math.rad(arc)) else -2
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local offset = root.Position - center
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude <= radius and math.abs(offset.Y) < 14 then
				if not dir or flat.Magnitude < 0.01 or flat.Unit:Dot(dir) >= cosArc then
					table.insert(out, p)
				end
			end
		end
	end
	return out
end

-- Telegraphs the boss's next attack on the ground, then lands it on everyone still inside.
bossAttack = function(e: Enemy, targetPos: Vector3, facing: Vector3)
	local attacks = e.kind.attacks :: { Combat.BossAttack }
	e.attackIndex = e.attackIndex % #attacks + 1
	local attack = attacks[e.attackIndex]
	local ground = e.root.Position - Vector3.new(0, e.humanoid.HipHeight + e.root.Size.Y / 2, 0)
	local center = if attack.kind == "roots" then Vector3.new(targetPos.X, ground.Y, targetPos.Z) else ground
	CombatService.fx("telegraph", { pos = center, radius = attack.radius, time = attack.windup, shape = attack.kind, dir = facing, arc = attack.arc, model = e.model })
	task.delay(attack.windup, function()
		e.winding = false
		if e.dead then
			return
		end
		local dir = if attack.kind == "swipe" then facing else nil
		for _, p in playersIn(center, attack.radius, dir, attack.arc) do
			CombatService.hurtPlayer(p, attack.damage, if attack.kind == "roots" then center - facing * 3 else e.root.Position)
		end
		CombatService.fx("burst", { pos = center, radius = attack.radius, shape = attack.kind, dir = facing, arc = attack.arc })
	end)
end

local function think(e: Enemy, t: number)
	if e.dead or e.kind.dummy or e.winding then
		return
	end
	local pos = e.root.Position
	local fromHome = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(e.home.X, 0, e.home.Z)).Magnitude
	-- pick or keep a target
	local targetRoot: BasePart? = nil
	if e.target then
		local character = e.target.Character
		targetRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not targetRoot or not humanoid or humanoid.Health <= 0 or fromHome > e.leash or (targetRoot.Position - pos).Magnitude > e.kind.aggroRange * 1.8 then
			e.target, targetRoot = nil, nil
		end
	end
	if not e.target and fromHome <= e.leash then
		e.target, targetRoot = nearestPlayer(pos, e.kind.aggroRange)
	end
	if not e.target or not targetRoot then
		-- wander near home, or walk back to it
		if fromHome > 20 then
			e.humanoid:MoveTo(e.home)
		elseif t >= e.nextWander then
			e.nextWander = t + 3 + math.random() * 4
			local a = math.random() * math.pi * 2
			local x, z = e.home.X + math.cos(a) * 12, e.home.Z + math.sin(a) * 12
			e.humanoid:MoveTo(Vector3.new(x, groundAt(x, z), z))
		end
		return
	end
	local toTarget = targetRoot.Position - pos
	local dist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude
	if dist > e.kind.attackRange + e.radius then
		e.humanoid:MoveTo(targetRoot.Position)
		return
	end
	-- in reach: stop, face the player, telegraph, then strike
	e.humanoid:MoveTo(pos)
	if t < e.nextAttack then
		return
	end
	e.winding = true
	e.nextAttack = t + e.kind.attackCooldown
	local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
	if flat.Magnitude > 0.01 then
		e.root.CFrame = CFrame.lookAt(pos, pos + flat.Unit)
	end
	if e.kind.boss and e.kind.attacks then
		bossAttack(e, targetRoot.Position, if flat.Magnitude > 0.01 then flat.Unit else e.root.CFrame.LookVector)
		return
	end
	CombatService.fx("windup", { model = e.model, time = e.kind.attackWindup })
	local victim = e.target
	task.delay(e.kind.attackWindup, function()
		e.winding = false
		if e.dead or not victim then
			return
		end
		local character = victim.Character
		local vRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if vRoot then
			local gap = vRoot.Position - e.root.Position
			if Vector3.new(gap.X, 0, gap.Z).Magnitude <= e.kind.attackRange + e.radius + 2 then
				CombatService.hurtPlayer(victim, e.kind.damage, e.root.Position)
			end
		end
		CombatService.fx("strike", { pos = e.root.Position + e.root.CFrame.LookVector * (e.radius + 1), kind = e.kind.id })
	end)
end

function EnemyService.init()
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = Workspace
	CombatService.register(EnemyService)

	-- training dummies in the city barracks yard are always available
	for _, d in Combat.Dummies do
		spawnEnemy(Combat.Enemies.dummy, Vector3.new(d.x, groundAt(d.x, d.z), d.z))
	end

	-- hill camps wait for the terrain so monsters don't drop into the sea
	task.spawn(function()
		local waited = 0
		while not Workspace:GetAttribute("TerrainReady") and waited < 90 do
			task.wait(1)
			waited += 1
		end
		spawnCamps()
		-- the field boss in its clearing
		local site = Landscape.Sites[Combat.FieldBoss.site]
		if site then
			spawnEnemy(Combat.Enemies[Combat.FieldBoss.kind], Vector3.new(site.x, site.h, site.z), { leash = site.r + 20 })
		end
	end)

	task.spawn(function()
		while true do
			local t = os.clock()
			for _, e in enemies do
				local ok, err = pcall(think, e, t)
				if not ok then
					warn("[EnemyService] AI error:", err)
				end
			end
			task.wait(0.2)
		end
	end)
end

return EnemyService
