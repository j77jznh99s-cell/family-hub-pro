-- Combat on the client: input (mouse/keyboard, gamepad, on-screen buttons on phones), the
-- health/stamina/ability HUD, and every combat visual (slashes, projectiles, impacts, damage
-- numbers, enemy telegraphs). The server decides what actually hits; this only asks and shows.
--
-- Controls: click / R2 / Attack button = attack; Shift / B / Dodge button = dodge roll;
-- 1 2 3 = sword, bow, staff; Q X C = Whirlwind, Firebolt, Second Wind.

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Combat"))
local Loot = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Loot"))

local CombatClient = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local AttackRemote = remotes:WaitForChild("Attack") :: RemoteEvent
local DodgeRemote = remotes:WaitForChild("Dodge") :: RemoteEvent
local AbilityRemote = remotes:WaitForChild("Ability") :: RemoteEvent
local EquipRemote = remotes:WaitForChild("Equip") :: RemoteEvent
local FxRemote = remotes:WaitForChild("CombatFx") :: RemoteEvent

local FONT = Enum.Font.FredokaOne
local fxFolder = Workspace:WaitForChild("CombatFx")

----------------------------------------------------------------------------------------------
-- helpers

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Where the player is aiming, as a flat direction from the character.
local function aimDirection(screenPos: Vector2?): Vector3
	local root = rootPart()
	local camera = Workspace.CurrentCamera
	if not root or not camera then
		return Vector3.new(0, 0, -1)
	end
	local target: Vector3
	if screenPos and UserInputService.MouseEnabled then
		local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Instance, fxFolder }
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 600, params)
		target = if hit then hit.Position else ray.Origin + ray.Direction * 200
	else
		target = root.Position + camera.CFrame.LookVector * 50
	end
	local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
end

local function face(dir: Vector3)
	local root = rootPart()
	if root then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	end
end

local function fxPart(size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?, transparency: number?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Transparency = transparency or 0.2
	if shape then
		p.Shape = shape
	end
	p.Parent = fxFolder
	return p
end

local function fadeOut(p: BasePart, time: number, grow: Vector3?)
	local goal: { [string]: any } = { Transparency = 1 }
	if grow then
		goal.Size = grow
	end
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, time + 0.05)
end

local function floatText(pos: Vector3, text: string, color: Color3, size: number?)
	local anchor = fxPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), color, nil, 1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	if size then
		gui.Size = UDim2.fromOffset(120 * size, 40 * size)
	end
	TweenService:Create(anchor, TweenInfo.new(0.9), { CFrame = CFrame.new(pos + Vector3.new(math.random() * 2 - 1, 4, 0)) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1)
end

local function flash(model: Instance, color: Color3, time: number)
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 0.35
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	TweenService:Create(h, TweenInfo.new(time), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	Debris:AddItem(h, time + 0.05)
end

----------------------------------------------------------------------------------------------
-- HUD

local gui = Instance.new("ScreenGui")
gui.Name = "CombatHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local function bar(y: number, color: Color3, label: string): (Frame, TextLabel)
	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, y)
	back.Size = UDim2.fromOffset(300, 16)
	back.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	back.BackgroundTransparency = 0.25
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 6)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = FONT
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Text = label
	text.ZIndex = 2
	text.Parent = back
	return fill, text
end

local healthFill, healthText = bar(-118, Color3.fromRGB(220, 60, 70), "")
local staminaFill, staminaText = bar(-98, Color3.fromRGB(240, 190, 60), "")

-- boss health bar across the top while a boss is close
local bossFrame = Instance.new("Frame")
bossFrame.AnchorPoint = Vector2.new(0.5, 0)
bossFrame.Position = UDim2.new(0.5, 0, 0, 56)
bossFrame.Size = UDim2.fromOffset(460, 22)
bossFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 25)
bossFrame.BackgroundTransparency = 0.2
bossFrame.Visible = false
bossFrame.Parent = gui
Instance.new("UICorner", bossFrame).CornerRadius = UDim.new(0, 6)
local bossFill = Instance.new("Frame")
bossFill.Size = UDim2.fromScale(1, 1)
bossFill.BackgroundColor3 = Color3.fromRGB(190, 40, 60)
bossFill.Parent = bossFrame
Instance.new("UICorner", bossFill).CornerRadius = UDim.new(0, 6)
local bossName = Instance.new("TextLabel")
bossName.BackgroundTransparency = 1
bossName.AnchorPoint = Vector2.new(0.5, 1)
bossName.Position = UDim2.new(0.5, 0, 0, -2)
bossName.Size = UDim2.new(1, 0, 0, 24)
bossName.Font = Enum.Font.Fantasy
bossName.TextScaled = true
bossName.TextColor3 = Color3.fromRGB(255, 225, 170)
bossName.TextStrokeTransparency = 0.3
bossName.Parent = bossFrame

local slots: { [string]: { frame: Frame, shade: Frame, label: TextLabel } } = {}
local function slot(index: number, key: string, name: string, color: Color3): { frame: Frame, shade: Frame, label: TextLabel }
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, (index - 3.5) * 52, 1, -136)
	frame.Size = UDim2.fromOffset(46, 46)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0.15
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(255, 230, 150)
	stroke.Thickness = 0
	stroke.Name = "Selected"
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -4, 0.62, 0)
	label.Position = UDim2.fromOffset(2, 2)
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = name
	label.Parent = frame
	local keyLabel = Instance.new("TextLabel")
	keyLabel.BackgroundTransparency = 1
	keyLabel.AnchorPoint = Vector2.new(0, 1)
	keyLabel.Position = UDim2.new(0, 3, 1, -1)
	keyLabel.Size = UDim2.new(1, -6, 0.34, 0)
	keyLabel.Font = FONT
	keyLabel.TextScaled = true
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel.TextColor3 = Color3.fromRGB(255, 230, 150)
	keyLabel.Text = key
	keyLabel.Parent = frame
	local shade = Instance.new("Frame")
	shade.AnchorPoint = Vector2.new(0, 1)
	shade.Position = UDim2.fromScale(0, 1)
	shade.Size = UDim2.fromScale(1, 0)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.4
	shade.ZIndex = 3
	shade.Parent = frame
	Instance.new("UICorner", shade).CornerRadius = UDim.new(0, 8)
	return { frame = frame, shade = shade, label = label }
end

local weaponColors = { sword = Color3.fromRGB(120, 130, 150), bow = Color3.fromRGB(120, 90, 60), staff = Color3.fromRGB(110, 80, 170) }
local weaponShort = { sword = "Sword", bow = "Bow", staff = "Staff" }
for i, id in Combat.WeaponOrder do
	slots[id] = slot(i, tostring(i), weaponShort[id], weaponColors[id])
end
local abilityColors = { whirlwind = Color3.fromRGB(70, 130, 200), firebolt = Color3.fromRGB(220, 100, 40), secondwind = Color3.fromRGB(60, 170, 110) }
local abilityShort = { whirlwind = "Whirl", firebolt = "Fire", secondwind = "Heal" }
for i, a in Combat.Abilities do
	slots[a.id] = slot(i + 3, a.key, abilityShort[a.id], abilityColors[a.id])
end

RunService.RenderStepped:Connect(function()
	local humanoid = humanoidOf()
	if humanoid then
		local h = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		healthFill.Size = UDim2.fromScale(h, 1)
		healthText.Text = string.format("%d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth)
	end
	local stamina = player:GetAttribute("Stamina") or 0
	local maxStamina = player:GetAttribute("MaxStamina") or Combat.Player.maxStamina
	staminaFill.Size = UDim2.fromScale(math.clamp(stamina / maxStamina, 0, 1), 1)
	staminaText.Text = "Stamina " .. tostring(stamina)
	local weapon = player:GetAttribute("Weapon") or "sword"
	for _, id in Combat.WeaponOrder do
		local stroke = slots[id].frame:FindFirstChild("Selected") :: UIStroke
		local rarity = Loot.Rarities[player:GetAttribute("Gear_" .. id) or 1] or Loot.Rarities[1]
		stroke.Color = rarity.color
		stroke.Thickness = if id == weapon then 4 elseif (player:GetAttribute("Gear_" .. id) or 1) > 1 then 2 else 0
	end
	-- nearest boss within 140 studs
	local root = rootPart()
	local bossHumanoid: Humanoid? = nil
	local enemiesFolder = Workspace:FindFirstChild("Enemies")
	if root and enemiesFolder then
		local best = 140
		for _, m in enemiesFolder:GetChildren() do
			if m:GetAttribute("Boss") and m:IsA("Model") and m.PrimaryPart then
				local d = (m.PrimaryPart.Position - root.Position).Magnitude
				local h = m:FindFirstChildOfClass("Humanoid")
				if d < best and h and h.Health > 0 then
					best, bossHumanoid = d, h
				end
			end
		end
	end
	bossFrame.Visible = bossHumanoid ~= nil
	if bossHumanoid then
		bossFill.Size = UDim2.fromScale(math.clamp(bossHumanoid.Health / bossHumanoid.MaxHealth, 0, 1), 1)
		bossName.Text = bossHumanoid.DisplayName
	end
	local t = Workspace:GetServerTimeNow()
	for _, a in Combat.Abilities do
		local ready = player:GetAttribute("CD_" .. a.id) or 0
		local left = math.max(0, ready - t)
		slots[a.id].shade.Size = UDim2.fromScale(1, math.clamp(left / a.cooldown, 0, 1))
	end
end)

----------------------------------------------------------------------------------------------
-- actions

local lastDodge = 0

local function attack(screenPos: Vector2?)
	local dir = aimDirection(screenPos)
	face(dir)
	AttackRemote:FireServer(dir)
end

local function dodge()
	local root = rootPart()
	local humanoid = humanoidOf()
	local t = os.clock()
	if not root or not humanoid or t - lastDodge < Combat.Player.dodgeCooldown then
		return
	end
	if (player:GetAttribute("Stamina") or 0) < Combat.Player.dodgeCost then
		return
	end
	lastDodge = t
	local move = humanoid.MoveDirection
	local dir = if move.Magnitude > 0.1 then Vector3.new(move.X, 0, move.Z).Unit else -Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	root.AssemblyLinearVelocity = dir * Combat.Player.dodgeSpeed + Vector3.new(0, 8, 0)
	DodgeRemote:FireServer()
	local trail = fxPart(Vector3.new(2.5, 4, 2.5), root.CFrame, Color3.fromRGB(200, 230, 255), Enum.PartType.Ball, 0.5)
	fadeOut(trail, 0.3)
end

local function ability(id: string, screenPos: Vector2?)
	local dir = aimDirection(screenPos)
	face(dir)
	AbilityRemote:FireServer(id, dir)
end

local function equip(id: string)
	EquipRemote:FireServer(id)
end

-- keyboard and mouse
local keyToAbility: { [Enum.KeyCode]: string } = {}
for _, a in Combat.Abilities do
	keyToAbility[(Enum.KeyCode :: any)[a.key]] = a.id
end
local keyToWeapon = { [Enum.KeyCode.One] = "sword", [Enum.KeyCode.Two] = "bow", [Enum.KeyCode.Three] = "staff" }

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		attack(UserInputService:GetMouseLocation())
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonB then
		dodge()
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		attack(nil)
	elseif keyToAbility[input.KeyCode] then
		ability(keyToAbility[input.KeyCode], UserInputService:GetMouseLocation())
	elseif keyToWeapon[input.KeyCode] then
		equip(keyToWeapon[input.KeyCode])
	end
end)

-- on-screen buttons for touch devices
if UserInputService.TouchEnabled then
	local function touchAction(name: string, title: string, position: UDim2, fn: () -> ())
		ContextActionService:BindAction(name, function(_, state)
			if state == Enum.UserInputState.Begin then
				fn()
			end
			return Enum.ContextActionResult.Sink
		end, true)
		ContextActionService:SetTitle(name, title)
		ContextActionService:SetPosition(name, position)
	end
	touchAction("CombatAttack", "Hit", UDim2.new(1, -150, 1, -150), function()
		attack(nil)
	end)
	touchAction("CombatDodge", "Roll", UDim2.new(1, -210, 1, -100), dodge)
	for i, a in Combat.Abilities do
		touchAction("CombatAbility" .. i, abilityShort[a.id], UDim2.new(1, -230 + (i - 1) * 60, 1, -220), function()
			ability(a.id, nil)
		end)
	end
	touchAction("CombatSwap", "Swap", UDim2.new(1, -90, 1, -220), function()
		local current = player:GetAttribute("Weapon") or "sword"
		local index = table.find(Combat.WeaponOrder, current) or 1
		equip(Combat.WeaponOrder[index % #Combat.WeaponOrder + 1])
	end)
end

----------------------------------------------------------------------------------------------
-- effects from the server

local liveProjectiles: { [number]: { part: BasePart, dir: Vector3, speed: number, left: number } } = {}
-- each element's look: warning colour, inner fill, burst ring, damage number (Shared/Combat.Elements)
local ELEMENT_FX: { [string]: { warn: Color3, inner: Color3, burst: Color3, text: Color3 } } = {
	fire = { warn = Color3.fromRGB(255, 110, 20), inner = Color3.fromRGB(255, 200, 60), burst = Color3.fromRGB(255, 110, 30), text = Color3.fromRGB(255, 150, 40) },
	water = { warn = Color3.fromRGB(40, 140, 255), inner = Color3.fromRGB(160, 230, 255), burst = Color3.fromRGB(70, 180, 255), text = Color3.fromRGB(110, 200, 255) },
	earth = { warn = Color3.fromRGB(200, 140, 60), inner = Color3.fromRGB(240, 200, 120), burst = Color3.fromRGB(190, 150, 90), text = Color3.fromRGB(230, 190, 120) },
	shadow = { warn = Color3.fromRGB(150, 60, 230), inner = Color3.fromRGB(210, 150, 255), burst = Color3.fromRGB(160, 80, 240), text = Color3.fromRGB(200, 140, 255) },
}

local projectileColors = { bow = Color3.fromRGB(240, 230, 200), staff = Color3.fromRGB(170, 120, 255), firebolt = Color3.fromRGB(255, 120, 40) }

RunService.Heartbeat:Connect(function(dt)
	for id, p in liveProjectiles do
		local step = math.min(p.speed * dt, p.left)
		p.left -= step
		p.part.CFrame = p.part.CFrame + p.dir * step
		if p.left <= 0 then
			p.part:Destroy()
			liveProjectiles[id] = nil
		end
	end
end)

FxRemote.OnClientEvent:Connect(function(kind: string, data: { [string]: any })
	if kind == "slash" then
		local dir = data.dir :: Vector3
		local base = CFrame.lookAt(data.pos, data.pos + dir)
		for k = -2, 2 do
			local arc = fxPart(Vector3.new(0.4, 0.4, data.range * 0.6), base * CFrame.Angles(0, math.rad(k * 18), 0) * CFrame.new(0, 0.5, -data.range * 0.3), Color3.fromRGB(230, 240, 255), nil, 0.25)
			fadeOut(arc, 0.18)
		end
	elseif kind == "projectile" then
		local color = projectileColors[data.kind] or Color3.new(1, 1, 1)
		local size = if data.kind == "bow" then Vector3.new(0.3, 0.3, 3) else Vector3.new(1.6, 1.6, 1.6)
		local part = fxPart(size, CFrame.lookAt(data.from, data.from + data.dir), color, if data.kind == "bow" then nil else Enum.PartType.Ball, 0)
		if data.kind ~= "bow" then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 10
			light.Parent = part
		end
		liveProjectiles[data.id] = { part = part, dir = data.dir, speed = data.speed, left = data.range }
	elseif kind == "impact" then
		local live = liveProjectiles[data.id]
		if live then
			live.part:Destroy()
			liveProjectiles[data.id] = nil
		end
		local radius = data.radius or 2
		local color = projectileColors[data.kind] or Color3.new(1, 1, 1)
		local burst = fxPart(Vector3.new(1, 1, 1), CFrame.new(data.pos), color, Enum.PartType.Ball, 0.2)
		fadeOut(burst, 0.35, Vector3.new(radius * 2, radius * 2, radius * 2))
	elseif kind == "hit" then
		if data.model then
			flash(data.model, Color3.new(1, 1, 1), 0.15)
		end
		floatText(data.pos, tostring(data.amount), Color3.fromRGB(255, 240, 120))
	elseif kind == "damage" then
		if data.player then
			local look = data.element and ELEMENT_FX[data.element]
			floatText(data.pos, "-" .. tostring(data.amount), if look then look.text else Color3.fromRGB(255, 90, 90))
		end
	elseif kind == "windup" then
		if data.model then
			flash(data.model, Color3.fromRGB(255, 60, 60), data.time or 0.5)
		end
	elseif kind == "strike" then
		local ring = fxPart(Vector3.new(0.4, 3, 3), CFrame.new(data.pos) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 120, 90), Enum.PartType.Cylinder, 0.3)
		fadeOut(ring, 0.2, Vector3.new(0.4, 7, 7))
	elseif kind == "whirl" then
		local ring = fxPart(Vector3.new(1, 2, 2), CFrame.new(data.pos) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(160, 210, 255), Enum.PartType.Cylinder, 0.3)
		fadeOut(ring, 0.35, Vector3.new(1, data.radius * 2, data.radius * 2))
	elseif kind == "heal" then
		local glow = fxPart(Vector3.new(4, 4, 4), CFrame.new(data.pos), Color3.fromRGB(120, 255, 170), Enum.PartType.Ball, 0.4)
		fadeOut(glow, 0.6, Vector3.new(9, 9, 9))
		floatText(data.pos + Vector3.new(0, 3, 0), "+Heal", Color3.fromRGB(120, 255, 170))
	elseif kind == "telegraph" then
		-- a red warning on the ground that fills up until the attack lands
		local radius = data.radius or 10
		local pos = data.pos + Vector3.new(0, 0.3, 0)
		local parts: { BasePart } = {}
		local look = data.element and ELEMENT_FX[data.element]
		local warn = if look then look.warn else Color3.fromRGB(255, 60, 60)
		if data.shape == "swipe" and data.dir then
			local arc = math.rad(data.arc or 60)
			local base = CFrame.lookAt(pos, pos + data.dir)
			for k = -3, 3 do
				local wedgeLine = fxPart(Vector3.new(radius * 0.32, 0.2, radius), base * CFrame.Angles(0, k / 3 * arc, 0) * CFrame.new(0, 0, -radius / 2), warn, nil, 0.65)
				table.insert(parts, wedgeLine)
			end
		else
			local disc = fxPart(Vector3.new(0.2, radius * 2, radius * 2), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), warn, Enum.PartType.Cylinder, 0.7)
			table.insert(parts, disc)
			local inner = fxPart(Vector3.new(0.25, 0.5, 0.5), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), if look then look.inner else Color3.fromRGB(255, 120, 80), Enum.PartType.Cylinder, 0.4)
			TweenService:Create(inner, TweenInfo.new(data.time or 1, Enum.EasingStyle.Linear), { Size = Vector3.new(0.25, radius * 2, radius * 2) }):Play()
			table.insert(parts, inner)
		end
		for _, p in parts do
			Debris:AddItem(p, (data.time or 1) + 0.05)
		end
		if data.model then
			flash(data.model, Color3.fromRGB(255, 60, 60), data.time or 1)
		end
	elseif kind == "burst" then
		local radius = data.radius or 10
		local fire = data.element == "fire"
		local look = data.element and ELEMENT_FX[data.element]
		local color = if look then look.burst elseif data.shape == "roots" then Color3.fromRGB(120, 200, 80) else Color3.fromRGB(255, 170, 90)
		local ring = fxPart(Vector3.new(1, 2, 2), CFrame.new(data.pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder, 0.2)
		fadeOut(ring, 0.4, Vector3.new(1, radius * 2, radius * 2))
		if fire then
			-- pillars of flame burst up through the blast
			for k = 0, 7 do
				local a = k / 8 * math.pi * 2
				local r = radius * (0.3 + (k % 2) * 0.4)
				local flame = fxPart(Vector3.new(2, 7, 2), CFrame.new(data.pos + Vector3.new(math.cos(a) * r, 3.5, math.sin(a) * r)), Color3.fromRGB(255, 140 + (k % 3) * 30, 40), Enum.PartType.Ball, 0.1)
				fadeOut(flame, 0.7, Vector3.new(0.5, 14, 0.5))
			end
		elseif data.element == "water" then
			-- geysers of spray
			for k = 0, 7 do
				local a = k / 8 * math.pi * 2
				local r = radius * (0.3 + (k % 2) * 0.4)
				local spout = fxPart(Vector3.new(2, 6, 2), CFrame.new(data.pos + Vector3.new(math.cos(a) * r, 3, math.sin(a) * r)), Color3.fromRGB(150, 220, 255), Enum.PartType.Ball, 0.25)
				fadeOut(spout, 0.7, Vector3.new(0.6, 15, 0.6))
			end
		elseif data.element == "earth" then
			-- rock shards jut up through the floor
			for k = 0, 6 do
				local a = k / 7 * math.pi * 2
				local spike = fxPart(Vector3.new(1.6, 5, 1.6), CFrame.new(data.pos + Vector3.new(math.cos(a) * radius * 0.55, 2.5, math.sin(a) * radius * 0.55)) * CFrame.Angles(math.cos(a) * 0.3, 0, math.sin(a) * 0.3), Color3.fromRGB(140, 120, 100), nil, 0)
				spike.Material = Enum.Material.Slate
				fadeOut(spike, 0.7)
			end
		elseif data.element == "shadow" then
			local gloom = fxPart(Vector3.new(radius * 1.6, 3, radius * 1.6), CFrame.new(data.pos + Vector3.new(0, 1.5, 0)), Color3.fromRGB(90, 30, 140), Enum.PartType.Ball, 0.4)
			fadeOut(gloom, 0.8, Vector3.new(radius * 2.2, 8, radius * 2.2))
		elseif data.shape == "roots" then
			for k = 0, 5 do
				local a = k / 6 * math.pi * 2
				local spike = fxPart(Vector3.new(1, 6, 1), CFrame.new(data.pos + Vector3.new(math.cos(a) * radius * 0.5, 3, math.sin(a) * radius * 0.5)), Color3.fromRGB(110, 80, 50), nil, 0)
				spike.Material = Enum.Material.Wood
				fadeOut(spike, 0.6)
			end
		end
		local camera = Workspace.CurrentCamera
		local root = rootPart()
		if camera and root and (root.Position - data.pos).Magnitude < radius + 30 then
			task.spawn(function()
				for _ = 1, 6 do
					camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * 0.8, (math.random() - 0.5) * 0.8, 0)
					task.wait()
				end
			end)
		end
	elseif kind == "dodged" then
		floatText(data.pos + Vector3.new(0, 3, 0), "Dodged!", Color3.fromRGB(180, 220, 255))
	elseif kind == "defeat" then
		local size = if data.boss then 40 else 10
		local puff = fxPart(Vector3.new(2, 2, 2), CFrame.new(data.pos), if data.boss then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(255, 255, 255), Enum.PartType.Ball, 0.3)
		fadeOut(puff, if data.boss then 1.2 else 0.5, Vector3.new(size, size, size))
	elseif kind == "knock" then
		local root = rootPart()
		if root and data.vector then
			root.AssemblyLinearVelocity = data.vector
		end
		local camera = Workspace.CurrentCamera
		if camera then
			-- a tiny camera shake
			task.spawn(function()
				for _ = 1, 4 do
					camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * 0.4, (math.random() - 0.5) * 0.4, 0)
					task.wait()
				end
			end)
		end
	end
end)

return CombatClient
