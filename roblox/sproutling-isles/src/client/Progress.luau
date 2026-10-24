-- Levels on screen: the level badge and XP bar, the level-up celebration, the arena wave banner
-- and the crate window (K or the Crates button).
--
-- Level-up: the screen dims, rays spin behind a golden LEVEL UP!, the number counts up with a
-- bounce, confetti bursts out, then the new rank, unlocks and crate slide in. Everyone nearby
-- sees a pillar of light rise from the player who levelled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crates = require(Shared:WaitForChild("Crates"))

local Progress = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local LevelUpRemote = remotes:WaitForChild("LevelUp") :: RemoteEvent
local CrateRemote = remotes:WaitForChild("Crate") :: RemoteEvent

local FONT = Enum.Font.FredokaOne
local TITLE = Enum.Font.Fantasy
local GOLD = Color3.fromRGB(255, 205, 90)
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(40, 32, 28)

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

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local playerGui = player:WaitForChild("PlayerGui")
local gui = make("ScreenGui", { Name = "ProgressGui", ResetOnSpawn = false, DisplayOrder = 5, Parent = playerGui })

----------------------------------------------------------------------------------------------
-- level badge and XP bar

local badge = make("Frame", {
	Position = UDim2.new(0, 12, 0, 152),
	Size = UDim2.fromOffset(230, 54),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.2,
	Parent = gui,
}, { corner(10), make("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.3 }) })
local disc = make("Frame", {
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.fromOffset(46, 46),
	BackgroundColor3 = Color3.fromRGB(255, 190, 60),
	Parent = badge,
}, {
	make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 235, 140), Color3.fromRGB(230, 140, 30)), Rotation = 60 }),
	make("UIStroke", { Color = Color3.fromRGB(120, 70, 20), Thickness = 2 }),
})
local levelText = make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.2,
	Text = "1",
	Parent = disc,
}, { make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }) })
local rankText = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(58, 4),
	Size = UDim2.new(1, -64, 0, 22),
	Font = FONT,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = GOLD,
	TextStrokeTransparency = 0.5,
	Text = "Wanderer",
	Parent = badge,
})
local barBack = make("Frame", {
	Position = UDim2.fromOffset(58, 30),
	Size = UDim2.new(1, -66, 0, 16),
	BackgroundColor3 = Color3.fromRGB(25, 20, 18),
	Parent = badge,
}, { corner(8) })
local barFill = make("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(120, 220, 255),
	Parent = barBack,
}, { corner(8), make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(150, 240, 255), Color3.fromRGB(90, 140, 255)) }) })
local xpText = make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.3,
	Text = "",
	Parent = barBack,
})

local function updateBadge()
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("XP") or 0
	local nextXP = player:GetAttribute("XPNext") or 100
	levelText.Text = tostring(level)
	rankText.Text = tostring(player:GetAttribute("Rank") or "Wanderer")
	xpText.Text = string.format("%d / %d XP", xp, nextXP)
	tween(barFill, 0.4, { Size = UDim2.fromScale(math.clamp(xp / math.max(1, nextXP), 0, 1), 1) })
end
for _, attr in { "Level", "XP", "XPNext", "Rank" } do
	player:GetAttributeChangedSignal(attr):Connect(updateBadge)
end
updateBadge()

----------------------------------------------------------------------------------------------
-- the level-up celebration

local celebrating = false

local function celebrate(level: number, rank: string, unlocks: { string }, crate: string)
	if celebrating then
		task.wait(4.5)
	end
	celebrating = true
	local overlay = make("ScreenGui", { Name = "LevelUp", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50, Parent = playerGui })
	local dim = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = overlay })
	tween(dim, 0.4, { BackgroundTransparency = 0.45 })
	local centre = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = overlay })
	-- spinning rays
	local rays = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(900, 900), BackgroundTransparency = 1, Parent = centre })
	for k = 0, 15 do
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(34, 900),
			Rotation = k * 22.5,
			BackgroundColor3 = if k % 2 == 0 then Color3.fromRGB(255, 220, 110) else Color3.fromRGB(255, 255, 220),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = rays,
		}, { make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }) })
	end
	for _, ray in rays:GetChildren() do
		tween(ray, 0.6, { BackgroundTransparency = 0.55 })
	end
	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 25
	end)
	-- expanding ring
	local ring = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Parent = centre }, {
		make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		make("UIStroke", { Color = GOLD, Thickness = 10 }),
	})
	tween(ring, 0.9, { Size = UDim2.fromOffset(820, 820) }, Enum.EasingStyle.Quart)
	tween(ring:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.9, { Transparency = 1 })
	-- LEVEL UP! and the number
	local title = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -95),
		Size = UDim2.fromOffset(620, 90),
		BackgroundTransparency = 1,
		Font = TITLE,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "LEVEL UP!",
		Parent = centre,
	}, {
		make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 200)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 190, 50)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 250, 200)) }), Rotation = 90 }),
		make("UIStroke", { Color = Color3.fromRGB(110, 55, 10), Thickness = 4 }),
	})
	local titleScale = make("UIScale", { Scale = 0, Parent = title })
	tween(titleScale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
	local number = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 30),
		Size = UDim2.fromOffset(320, 170),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = tostring(level - 1),
		Parent = centre,
	}, {
		make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 200, 80)), Rotation = 90 }),
		make("UIStroke", { Color = Color3.fromRGB(90, 45, 10), Thickness = 6 }),
	})
	local numberScale = make("UIScale", { Scale = 0.2, Parent = number })
	tween(numberScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.45, function()
		number.Text = tostring(level)
		numberScale.Scale = 1.5
		tween(numberScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Elastic)
	end)
	-- confetti
	local colors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 210, 70), Color3.fromRGB(110, 220, 120), Color3.fromRGB(110, 180, 255), Color3.fromRGB(220, 130, 255), WHITE }
	for k = 1, 60 do
		local bit = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(8 + math.random(0, 8), 5 + math.random(0, 6)),
			Rotation = math.random(0, 360),
			BackgroundColor3 = colors[k % #colors + 1],
			BorderSizePixel = 0,
			Parent = centre,
		})
		local a = math.random() * math.pi * 2
		local d = 180 + math.random() * 320
		tween(bit, 1.6 + math.random() * 0.6, {
			Position = UDim2.new(0.5, math.cos(a) * d, 0.5, math.sin(a) * d + 160),
			Rotation = bit.Rotation + math.random(-540, 540),
			BackgroundTransparency = 1,
		}, Enum.EasingStyle.Quad)
	end
	-- rank, unlocks and crate
	local lines = { "Rank: " .. rank }
	for _, u in unlocks do
		table.insert(lines, "Unlocked: " .. u)
	end
	table.insert(lines, "Reward: " .. Crates.Tiers[crate].name)
	for i, line in lines do
		local l = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.5, 120 + i * 34),
			Size = UDim2.fromOffset(640, 30),
			BackgroundTransparency = 1,
			Font = FONT,
			TextScaled = true,
			TextColor3 = if i == 1 then GOLD elseif line:sub(1, 6) == "Reward" then rgb(Crates.Tiers[crate].color) else Color3.fromRGB(170, 255, 200),
			TextStrokeTransparency = 0.2,
			TextTransparency = 1,
			Text = line,
			Parent = centre,
		})
		task.delay(0.6 + i * 0.25, function()
			l.Position = UDim2.new(0.5, 60, 0.5, 120 + i * 34)
			tween(l, 0.35, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 120 + i * 34) }, Enum.EasingStyle.Back)
		end)
	end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = 0.8
	sound.Parent = overlay
	sound:Play()
	-- close on tap, or after a few seconds
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		for _, d in overlay:GetDescendants() do
			if d:IsA("TextLabel") then
				tween(d, 0.4, { TextTransparency = 1 })
			elseif d:IsA("Frame") then
				tween(d, 0.4, { BackgroundTransparency = 1 })
			elseif d:IsA("UIStroke") then
				tween(d, 0.4, { Transparency = 1 })
			end
		end
		task.delay(0.45, function()
			spin:Disconnect()
			overlay:Destroy()
			celebrating = false
		end)
	end
	local tap = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = overlay })
	tap.Activated:Connect(close)
	task.delay(4.2, close)
end

-- a pillar of light and a ring at the player who levelled (everyone sees it)
local function pillar(who: Player)
	local character = who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local base = root.Position - Vector3.new(0, 3, 0)
	local column = Instance.new("Part")
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.Material = Enum.Material.Neon
	column.Color = Color3.fromRGB(255, 215, 100)
	column.Shape = Enum.PartType.Cylinder
	column.Size = Vector3.new(2, 7, 7)
	column.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	column.Transparency = 0.2
	column.Parent = workspace
	tween(column, 1.4, { Size = Vector3.new(80, 3, 3), CFrame = CFrame.new(base + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 1 })
	local ring = column:Clone()
	ring.Size = Vector3.new(0.5, 4, 4)
	ring.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	tween(ring, 1, { Size = Vector3.new(0.5, 40, 40), Transparency = 1 })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 215, 100)
	light.Range = 30
	light.Brightness = 3
	light.Parent = column
	task.delay(1.5, function()
		column:Destroy()
		ring:Destroy()
	end)
end

LevelUpRemote.OnClientEvent:Connect(function(who: Player, level: number, rank: string, unlocks: { string }, crate: string)
	pillar(who)
	if who == player then
		task.spawn(celebrate, level, rank, unlocks or {}, crate)
	end
end)

----------------------------------------------------------------------------------------------
-- arena banner

local arenaBanner = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 66),
	Size = UDim2.fromOffset(380, 40),
	BackgroundColor3 = Color3.fromRGB(110, 25, 25),
	BackgroundTransparency = 0.15,
	Font = TITLE,
	TextScaled = true,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.3,
	Visible = false,
	Parent = gui,
}, { corner(8), make("UIStroke", { Color = GOLD, Thickness = 2 }) })
local function updateArena()
	local wave = player:GetAttribute("ArenaWave")
	if typeof(wave) == "number" and wave > 0 then
		arenaBanner.Visible = true
		arenaBanner.Text = string.format("ARENA  -  Wave %d  -  %d foes left", wave, player:GetAttribute("ArenaLeft") or 0)
	else
		arenaBanner.Visible = false
	end
end
player:GetAttributeChangedSignal("ArenaWave"):Connect(updateArena)

-- burning warning
local burnLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -186),
	Size = UDim2.fromOffset(240, 30),
	BackgroundColor3 = Color3.fromRGB(150, 50, 10),
	BackgroundTransparency = 0.2,
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(255, 220, 120),
	TextStrokeTransparency = 0.3,
	Text = "BURNING!",
	Visible = false,
	Parent = gui,
}, { corner(8) })
task.spawn(function()
	while true do
		task.wait(0.2)
		local ends = player:GetAttribute("Burning")
		local left = if typeof(ends) == "number" then ends - workspace:GetServerTimeNow() else 0
		burnLabel.Visible = left > 0
		if left > 0 then
			burnLabel.Text = string.format("BURNING! %.1fs", left)
			burnLabel.BackgroundTransparency = 0.15 + 0.15 * math.sin(os.clock() * 10)
		end
	end
end)
player:GetAttributeChangedSignal("ArenaLeft"):Connect(updateArena)

----------------------------------------------------------------------------------------------
-- crates

local crateWin = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(560, 380),
	BackgroundColor3 = PANEL,
	Visible = false,
	Parent = gui,
}, { corner(10), make("UIStroke", { Color = GOLD, Thickness = 2 }) })
do
	local scale = make("UIScale", { Parent = crateWin })
	local function fit()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.min(1, (view.X - 20) / 560, (view.Y - 80) / 380)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end
make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -60, 0, 32), Font = TITLE, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD, Text = "Reward Crates", Parent = crateWin })
local closeCrates = make("TextButton", { Position = UDim2.new(1, -38, 0, 8), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(150, 60, 60), Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "X", Parent = crateWin }, { corner(6) })
closeCrates.Activated:Connect(function()
	crateWin.Visible = false
end)
make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 18), Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(220, 210, 190), Text = "Earned by levelling up, arena waves and quests. Buy more at the Royal Treasury.", Parent = crateWin })

local reel = make("Frame", {
	Position = UDim2.fromOffset(14, 230),
	Size = UDim2.new(1, -28, 0, 96),
	BackgroundColor3 = Color3.fromRGB(25, 20, 18),
	ClipsDescendants = true,
	Parent = crateWin,
}, { corner(8) })
make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = GOLD, ZIndex = 5, Parent = reel })
local resultText = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 334), Size = UDim2.new(1, -28, 0, 30), Font = FONT, TextScaled = true, TextColor3 = GOLD, Text = "", Parent = crateWin })

local countLabels: { [string]: TextLabel } = {}
local opening = false
for i, tier in Crates.Order do
	local c = Crates.Tiers[tier]
	local cardFrame = make("Frame", {
		Position = UDim2.new((i - 1) / 3, 14 - (i - 1) * 4, 0, 66),
		Size = UDim2.new(1 / 3, -14, 0, 150),
		BackgroundColor3 = Color3.fromRGB(66, 54, 46),
		Parent = crateWin,
	}, { corner(8) })
	make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(54, 44), BackgroundColor3 = rgb(c.color), Parent = cardFrame }, {
		corner(6),
		make("UIStroke", { Color = Color3.fromRGB(60, 40, 20), Thickness = 2 }),
		make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(1, 4, 0, 5), BackgroundColor3 = Color3.fromRGB(90, 60, 30) }),
	})
	make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 60), Size = UDim2.new(1, -12, 0, 22), Font = FONT, TextScaled = true, TextColor3 = rgb(c.color), Text = c.name, Parent = cardFrame })
	countLabels[tier] = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 84), Size = UDim2.new(1, -12, 0, 18), Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "x0", Parent = cardFrame })
	local open = make("TextButton", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.new(1, -24, 0, 32), BackgroundColor3 = Color3.fromRGB(70, 140, 80), Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "Open", Parent = cardFrame }, { corner(6) })
	open.Activated:Connect(function()
		if not opening and (player:GetAttribute("Crates_" .. tier) or 0) > 0 then
			opening = true
			resultText.Text = "Opening..."
			CrateRemote:FireServer("open", tier)
			task.delay(4, function()
				opening = false
			end)
		end
	end)
end
local function updateCounts()
	for tier, label in countLabels do
		label.Text = "x" .. tostring(player:GetAttribute("Crates_" .. tier) or 0)
	end
end
for _, tier in Crates.Order do
	player:GetAttributeChangedSignal("Crates_" .. tier):Connect(updateCounts)
end
updateCounts()

-- the opening reel: a strip of rewards that spins and settles on the server's roll
CrateRemote.OnClientEvent:Connect(function(kind: string, tier: string, index: number)
	if kind ~= "result" then
		return
	end
	crateWin.Visible = true
	for _, c in reel:GetChildren() do
		if c.Name == "Strip" then
			c:Destroy()
		end
	end
	local rewards = Crates.Tiers[tier].rewards
	local CARD, TARGET, COUNT = 120, 26, 30
	local strip = make("Frame", { Name = "Strip", BackgroundTransparency = 1, Size = UDim2.new(0, CARD * COUNT, 1, 0), Position = UDim2.new(0.5, -CARD / 2, 0, 0), Parent = reel })
	for k = 1, COUNT do
		local r = if k == TARGET then rewards[index] else rewards[math.random(1, #rewards)]
		local color = if r.kind == "weapon" then Color3.fromRGB(190, 110, 255) elseif r.kind == "dew" then Color3.fromRGB(120, 210, 255) elseif r.kind == "xp" then Color3.fromRGB(255, 210, 90) else Color3.fromRGB(140, 230, 160)
		make("TextLabel", {
			Position = UDim2.new(0, (k - 1) * CARD + 4, 0, 8),
			Size = UDim2.new(0, CARD - 8, 1, -16),
			BackgroundColor3 = Color3.fromRGB(55, 45, 40),
			Font = FONT,
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = color,
			Text = r.label,
			Parent = strip,
		}, { corner(6), make("UIStroke", { Color = color, Thickness = 1.5 }) })
	end
	local finalX = -((TARGET - 1) * CARD) - CARD / 2
	tween(strip, 2.2, { Position = UDim2.new(0.5, finalX, 0, 0) }, Enum.EasingStyle.Quint)
	task.delay(2.3, function()
		resultText.Text = "You got: " .. rewards[index].label .. "!"
		local pop = make("UIScale", { Scale = 1.4, Parent = resultText })
		tween(pop, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		opening = false
	end)
end)

function Progress.openCrates()
	crateWin.Visible = not crateWin.Visible
	updateCounts()
	resultText.Text = ""
end

local crateButton = make("TextButton", {
	Position = UDim2.new(0, 12, 0, 214),
	Size = UDim2.fromOffset(110, 34),
	BackgroundColor3 = Color3.fromRGB(150, 110, 50),
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "Crates (K)",
	Parent = gui,
}, { corner(8) })
crateButton.Activated:Connect(Progress.openCrates)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.K then
		Progress.openCrates()
	end
end)

return Progress
