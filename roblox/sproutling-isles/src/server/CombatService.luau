-- Player combat: weapons, stamina, dodge, abilities, server-side hit detection and damage.
--
-- The client sends intents (attack with an aim direction, dodge, use ability Q/X/C, switch
-- weapon); the server checks stamina and cooldowns, finds what was hit and applies damage.
-- Visuals go back to everyone through the CombatFx remote. Enemies live in EnemyService;
-- players can't hurt each other yet (the Arena is reserved for that later).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Shared").Combat)

local State = require(script.Parent.State)
local LootService = require(script.Parent.LootService)
local InventoryService = require(script.Parent.InventoryService)

local CombatService = {}

type Fighter = {
	weapon: string,
	stamina: number,
	spentAt: number,
	nextAttack: number,
	nextDodge: number,
	invulnerableUntil: number,
	cooldowns: { [string]: number },
}

type Projectile = {
	id: number,
	owner: Player,
	pos: Vector3,
	dir: Vector3,
	speed: number,
	left: number,
	radius: number,
	damage: number,
	knockback: number,
	splash: number?, -- area damage radius on impact
	kind: string,
}

local fighters: { [Player]: Fighter } = {}
local projectiles: { Projectile } = {}
local nextProjectileId = 0

-- EnemyService registers itself here (avoids a require cycle: it calls hurtPlayer).
local enemies: any = nil

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end
local AttackRemote = remote("Attack") -- client -> server: (aim: Vector3)
local DodgeRemote = remote("Dodge") -- client -> server: ()
local AbilityRemote = remote("Ability") -- client -> server: (abilityId: string, aim: Vector3)
local EquipRemote = remote("Equip") -- client -> server: (weaponId: string)
local FxRemote = remote("CombatFx") -- server -> clients: (kind: string, data: table)

local function now(): number
	return Workspace:GetServerTimeNow()
end

function CombatService.fx(kind: string, data: { [string]: any })
	FxRemote:FireAllClients(kind, data)
end

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end

-- A clean, flat unit aim vector, or the character's facing if the client sent rubbish.
local function aimFrom(root: BasePart, aim: any): Vector3
	if typeof(aim) == "Vector3" and aim.X == aim.X and aim.Z == aim.Z then
		local flat = Vector3.new(aim.X, 0, aim.Z)
		if flat.Magnitude > 0.01 then
			return flat.Unit
		end
	end
	local look = root.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z).Unit
end

local function spend(player: Player, f: Fighter, amount: number): boolean
	if f.stamina < amount then
		return false
	end
	f.stamina -= amount
	f.spentAt = os.clock()
	player:SetAttribute("Stamina", math.floor(f.stamina))
	return true
end

----------------------------------------------------------------------------------------------
-- damage

-- Called by enemies. Respects the dodge's invulnerability window.
function CombatService.hurtPlayer(player: Player, amount: number, from: Vector3)
	local root, humanoid = rootOf(player)
	local f = fighters[player]
	if not root or not humanoid or not f then
		return
	end
	if now() < f.invulnerableUntil then
		CombatService.fx("dodged", { pos = root.Position })
		return
	end
	amount = math.max(1, math.floor(amount * (1 - InventoryService.armorReduction(player)) + 0.5))
	humanoid:TakeDamage(amount)
	local push = root.Position - from
	push = Vector3.new(push.X, 0, push.Z)
	local dir = if push.Magnitude > 0.01 then push.Unit else Vector3.zero
	FxRemote:FireClient(player, "knock", { vector = dir * 35 + Vector3.new(0, 18, 0) })
	CombatService.fx("damage", { pos = root.Position + Vector3.new(0, 3, 0), amount = amount, player = true })
end

local function hitEnemy(player: Player, enemy: any, damage: number, knockDir: Vector3, knockback: number)
	if enemies then
		enemies.damage(enemy, damage, player, knockDir, knockback)
	end
end

local function enemiesNear(pos: Vector3, radius: number): { any }
	return if enemies then enemies.near(pos, radius) else {}
end

----------------------------------------------------------------------------------------------
-- attacks

local function meleeAttack(player: Player, root: BasePart, weapon: Combat.Weapon, aim: Vector3, damage: number)
	local origin = root.Position
	local arc = math.cos(math.rad(weapon.arc or 60))
	for _, enemy in enemiesNear(origin, weapon.range + 4) do
		local offset = enemy.root.Position - origin
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local dist = flat.Magnitude
		local facing = if dist > 0.01 then flat.Unit:Dot(aim) else 1
		if dist <= weapon.range + enemy.radius and facing >= arc then
			hitEnemy(player, enemy, damage, if dist > 0.01 then flat.Unit else aim, weapon.knockback)
		end
	end
	CombatService.fx("slash", { pos = origin + aim * 3, dir = aim, range = weapon.range, player = player })
end

local function launch(player: Player, root: BasePart, aim: Vector3, kind: string, speed: number, range: number, radius: number, damage: number, knockback: number, splash: number?)
	nextProjectileId += 1
	local start = root.Position + aim * 2.5 + Vector3.new(0, 1, 0)
	table.insert(projectiles, {
		id = nextProjectileId,
		owner = player,
		pos = start,
		dir = aim,
		speed = speed,
		left = range,
		radius = radius,
		damage = damage,
		knockback = knockback,
		splash = splash,
		kind = kind,
	})
	CombatService.fx("projectile", { id = nextProjectileId, from = start, dir = aim, speed = speed, range = range, kind = kind })
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function stepProjectiles(dt: number)
	if #projectiles == 0 then
		return
	end
	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local enemyFolder = Workspace:FindFirstChild("Enemies")
	if enemyFolder then
		table.insert(ignore, enemyFolder)
	end
	local fxFolder = Workspace:FindFirstChild("CombatFx")
	if fxFolder then
		table.insert(ignore, fxFolder)
	end
	rayParams.FilterDescendantsInstances = ignore
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		local step = math.min(p.speed * dt, p.left)
		local nextPos = p.pos + p.dir * step
		local done = false
		local impact = nextPos
		-- enemies along the way
		for _, enemy in enemiesNear(nextPos, p.radius + 6) do
			local d = (enemy.root.Position - nextPos).Magnitude
			if d <= p.radius + enemy.radius then
				if not p.splash then
					hitEnemy(p.owner, enemy, p.damage, p.dir, p.knockback)
				end
				done = true
				break
			end
		end
		-- walls, terrain, the ground
		if not done then
			local hit = Workspace:Raycast(p.pos, nextPos - p.pos, rayParams)
			if hit and hit.Instance and (hit.Instance:IsA("Terrain") or (hit.Instance :: BasePart).CanCollide) then
				impact = hit.Position
				done = true
			end
		end
		p.pos = nextPos
		p.left -= step
		if done or p.left <= 0 then
			if p.splash then
				for _, enemy in enemiesNear(impact, p.splash + 4) do
					local offset = enemy.root.Position - impact
					if offset.Magnitude <= p.splash + enemy.radius then
						hitEnemy(p.owner, enemy, p.damage, if offset.Magnitude > 0.01 then Vector3.new(offset.X, 0, offset.Z).Unit else p.dir, p.knockback)
					end
				end
			end
			CombatService.fx("impact", { id = p.id, pos = impact, kind = p.kind, radius = p.splash or 2 })
			table.remove(projectiles, i)
		end
	end
end

local function onAttack(player: Player, aim: any)
	local f = fighters[player]
	local root = rootOf(player)
	if not f or not root then
		return
	end
	local weapon = Combat.Weapons[f.weapon]
	local t = os.clock()
	if t < f.nextAttack or not spend(player, f, weapon.stamina) then
		return
	end
	f.nextAttack = t + weapon.cooldown
	local dir = aimFrom(root, aim)
	local damage = weapon.damage * LootService.power(player, weapon.id)
	if weapon.kind == "melee" then
		meleeAttack(player, root, weapon, dir, damage)
	else
		launch(player, root, dir, weapon.id, weapon.speed or 100, weapon.range, weapon.radius or 2, damage, weapon.knockback)
	end
end

local function onDodge(player: Player)
	local f = fighters[player]
	local root = rootOf(player)
	if not f or not root then
		return
	end
	local t = os.clock()
	if t < f.nextDodge or not spend(player, f, Combat.Player.dodgeCost) then
		return
	end
	f.nextDodge = t + Combat.Player.dodgeCooldown
	f.invulnerableUntil = now() + Combat.Player.dodgeTime
end

local abilityById: { [string]: Combat.Ability } = {}
for _, a in Combat.Abilities do
	abilityById[a.id] = a
end

local function onAbility(player: Player, id: any, aim: any)
	local f = fighters[player]
	local root, humanoid = rootOf(player)
	local ability = if typeof(id) == "string" then abilityById[id] else nil
	if not f or not root or not humanoid or not ability then
		return
	end
	local ready = f.cooldowns[ability.id] or 0
	if now() < ready or not spend(player, f, ability.stamina) then
		return
	end
	f.cooldowns[ability.id] = now() + ability.cooldown
	player:SetAttribute("CD_" .. ability.id, f.cooldowns[ability.id])
	local dir = aimFrom(root, aim)
	if ability.id == "whirlwind" then
		local radius = ability.radius or 10
		for _, enemy in enemiesNear(root.Position, radius + 4) do
			local offset = enemy.root.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude <= radius + enemy.radius then
				hitEnemy(player, enemy, (ability.damage or 20) * LootService.power(player, "sword"), if flat.Magnitude > 0.01 then flat.Unit else dir, 40)
			end
		end
		CombatService.fx("whirl", { pos = root.Position, radius = radius })
	elseif ability.id == "firebolt" then
		launch(player, root, dir, "firebolt", ability.speed or 100, ability.range or 120, 2.5, (ability.damage or 30) * LootService.power(player, "staff"), 30, ability.radius)
	elseif ability.id == "secondwind" then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (ability.heal or 30))
		f.stamina = Combat.Player.maxStamina
		player:SetAttribute("Stamina", f.stamina)
		CombatService.fx("heal", { pos = root.Position })
	end
end

----------------------------------------------------------------------------------------------
-- weapon models (welded to the right hand so everyone sees them)

local function weaponModel(id: string): Model
	local m = Instance.new("Model")
	m.Name = "Weapon"
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = offset
		p.Color = color
		p.Material = material
		if shape then
			p.Shape = shape
		end
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Parent = m
		return p
	end
	-- built around a Handle at the origin; the weapon extends along +Y
	local handle = piece("Handle", Vector3.new(0.4, 1.2, 0.4), CFrame.new(), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
	m.PrimaryPart = handle
	if id == "sword" then
		piece("Guard", Vector3.new(1.6, 0.25, 0.4), CFrame.new(0, 0.7, 0), Color3.fromRGB(220, 180, 70), Enum.Material.Metal)
		piece("Blade", Vector3.new(0.5, 4, 0.15), CFrame.new(0, 2.8, 0), Color3.fromRGB(215, 220, 230), Enum.Material.Metal)
		piece("Pommel", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, -0.7, 0), Color3.fromRGB(220, 180, 70), Enum.Material.Metal, Enum.PartType.Ball)
	elseif id == "bow" then
		for i = -2, 2 do
			local a = math.rad(i * 18)
			piece("Limb", Vector3.new(0.3, 1.3, 0.3), CFrame.new(0, i * 1.2, -math.cos(a) * 0.8 + 0.8) * CFrame.Angles(a, 0, 0), Color3.fromRGB(120, 80, 45), Enum.Material.Wood)
		end
		piece("String", Vector3.new(0.08, 5.6, 0.08), CFrame.new(0, 0, 0.9), Color3.fromRGB(240, 235, 220), Enum.Material.Fabric)
	elseif id == "staff" then
		piece("Pole", Vector3.new(0.35, 6, 0.35), CFrame.new(0, 2, 0), Color3.fromRGB(110, 75, 50), Enum.Material.Wood)
		piece("Orb", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 5.4, 0), Color3.fromRGB(170, 120, 255), Enum.Material.Neon, Enum.PartType.Ball)
	end
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = p
			weld.Parent = p
		end
	end
	return m
end

local function equipModel(player: Player, id: string)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("Weapon")
	if old then
		old:Destroy()
	end
	local hand = (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	if not hand then
		return
	end
	local m = weaponModel(id)
	local grip = if hand.Name == "RightHand" then CFrame.new(0, -0.3, 0) else CFrame.new(0, -1, 0)
	m:PivotTo(hand.CFrame * grip * CFrame.Angles(math.rad(-90), 0, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = m.PrimaryPart :: BasePart
	weld.Parent = m.PrimaryPart
	m.Parent = character
end

local function onEquip(player: Player, id: any)
	local f = fighters[player]
	if not f or typeof(id) ~= "string" or not Combat.Weapons[id] or f.weapon == id then
		return
	end
	f.weapon = id
	player:SetAttribute("Weapon", id)
	equipModel(player, id)
end

----------------------------------------------------------------------------------------------

function CombatService.register(enemyService: any)
	enemies = enemyService
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local f = fighters[player]
	if not humanoid or not f then
		return
	end
	humanoid.MaxHealth = Combat.Player.maxHealth
	humanoid.Health = Combat.Player.maxHealth
	f.stamina = Combat.Player.maxStamina
	player:SetAttribute("Stamina", f.stamina)
	character:WaitForChild("RightHand", 5)
	equipModel(player, f.weapon)
end

local function onPlayerAdded(player: Player)
	fighters[player] = {
		weapon = "sword",
		stamina = Combat.Player.maxStamina,
		spentAt = 0,
		nextAttack = 0,
		nextDodge = 0,
		invulnerableUntil = 0,
		cooldowns = {},
	}
	player:SetAttribute("Weapon", "sword")
	player:SetAttribute("Stamina", Combat.Player.maxStamina)
	player:SetAttribute("MaxStamina", Combat.Player.maxStamina)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

-- Dew reward for a kill (called by EnemyService).
function CombatService.reward(player: Player, amount: number, enemyName: string)
	local session = State.get(player)
	if session and amount > 0 then
		State.addDew(session, amount, "Kill:" .. enemyName)
		State.notify(session, string.format("Defeated %s! +%d Dew", enemyName, amount), "#ffd27a")
	end
end

function CombatService.init()
	-- potions and meals refill stamina through here
	InventoryService.setStaminaHandler(function(player, amount)
		local f = fighters[player]
		if f then
			f.stamina = math.min(Combat.Player.maxStamina, f.stamina + amount)
			player:SetAttribute("Stamina", math.floor(f.stamina))
		end
	end)
	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "CombatFx"
	fxFolder.Parent = Workspace
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		fighters[p] = nil
	end)
	AttackRemote.OnServerEvent:Connect(onAttack)
	DodgeRemote.OnServerEvent:Connect(onDodge)
	AbilityRemote.OnServerEvent:Connect(onAbility)
	EquipRemote.OnServerEvent:Connect(onEquip)
	RunService.Heartbeat:Connect(function(dt)
		stepProjectiles(dt)
		-- stamina regen
		local t = os.clock()
		for player, f in fighters do
			if f.stamina < Combat.Player.maxStamina and t - f.spentAt > Combat.Player.staminaRegenDelay then
				local before = math.floor(f.stamina)
				f.stamina = math.min(Combat.Player.maxStamina, f.stamina + Combat.Player.staminaRegen * dt)
				if math.floor(f.stamina) ~= before then
					player:SetAttribute("Stamina", math.floor(f.stamina))
				end
			end
		end
	end)
end

return CombatService
