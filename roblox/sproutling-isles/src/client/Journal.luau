-- The Monster Journal window (N or the Journal button): every monster by region, with how many
-- you've defeated, whether you've mastered it, and each region's completion reward.
-- Undiscovered monsters show as "???" until you defeat one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Journal = require(Shared:WaitForChild("Journal"))
local Combat = require(Shared:WaitForChild("Combat"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local JournalRemote = remotes:WaitForChild("Journal") :: RemoteEvent

local FONT = Enum.Font.FredokaOne
local TITLE = Enum.Font.Fantasy
local PANEL = Color3.fromRGB(44, 36, 30)
local CARD = Color3.fromRGB(70, 58, 48)
local PAPER = Color3.fromRGB(240, 220, 170)
local WHITE = Color3.new(1, 1, 1)
local GREY = Color3.fromRGB(150, 140, 130)

local book: any = { kills = {}, regions = {} }

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

local gui = make("ScreenGui", { Name = "JournalGui", ResetOnSpawn = false, DisplayOrder = 9, Parent = player:WaitForChild("PlayerGui") })

local W, H = 620, 520
local win = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = PANEL,
	Visible = false,
	Parent = gui,
}, { corner(10), make("UIStroke", { Color = PAPER, Thickness = 2 }) })
do
	local scale = make("UIScale", { Parent = win })
	local function fit()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.min(1, (view.X - 20) / W, (view.Y - 60) / H)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end
make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -60, 0, 32), Font = TITLE, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = PAPER, Text = "Monster Journal", Parent = win })
local subtitle = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 18), Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(225, 210, 180), Text = "", Parent = win })
local close = make("TextButton", { Position = UDim2.new(1, -38, 0, 8), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(150, 60, 60), Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "X", Parent = win }, { corner(6) })
close.Activated:Connect(function()
	win.Visible = false
end)
local list = make("ScrollingFrame", {
	BackgroundColor3 = Color3.fromRGB(30, 25, 22),
	Position = UDim2.fromOffset(14, 66),
	Size = UDim2.new(1, -28, 1, -80),
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = win,
}, {
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10) }),
})

local ELEMENT_TEXT = {
	fire = { "Fire", Color3.fromRGB(255, 140, 60) },
	water = { "Water", Color3.fromRGB(110, 190, 255) },
	earth = { "Earth", Color3.fromRGB(210, 170, 110) },
	shadow = { "Shadow", Color3.fromRGB(190, 140, 255) },
}

local function render()
	for _, c in list:GetChildren() do
		if c:IsA("Frame") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local found, total = 0, 0
	local order = 0
	for _, region in Journal.Regions do
		local regionFound = 0
		for _, k in region.kinds do
			total += 1
			if (book.kills[k] or 0) > 0 then
				found += 1
				regionFound += 1
			end
		end
		order += 1
		local done = book.regions[region.id] == true
		local header = make("Frame", { BackgroundColor3 = Color3.fromRGB(90, 70, 50), Size = UDim2.new(1, 0, 0, 44), LayoutOrder = order, Parent = list }, { corner(6) })
		make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 2), Size = UDim2.new(0.62, 0, 0, 24), Font = TITLE, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = PAPER, Text = string.format("%s  (%d/%d)", region.name, regionFound, #region.kinds), Parent = header })
		make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 25), Size = UDim2.new(0.62, 0, 0, 16), Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(220, 200, 170), Text = region.blurb, Parent = header })
		make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0.64, 0, 0, 6), Size = UDim2.new(0.34, 0, 0, 32), Font = FONT, TextScaled = true, TextColor3 = if done then Color3.fromRGB(140, 230, 140) else Color3.fromRGB(255, 220, 140), Text = if done then "Complete! Reward claimed" else string.format("Reward: %d Dew + %s crate", region.reward.dew, region.reward.crate), Parent = header })
		for _, k in region.kinds do
			order += 1
			local kind = Combat.Enemies[k]
			local kills = book.kills[k] or 0
			local known = kills > 0
			local need = Journal.masterAt(kind and kind.boss)
			local row = make("Frame", { BackgroundColor3 = CARD, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order, Parent = list }, { corner(6) })
			local nameText = if known and kind then kind.name else "???"
			make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 5), Size = UDim2.new(0.44, -10, 0, 24), Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if known then WHITE else GREY, Text = nameText .. (if kind and kind.boss then "  (boss)" else ""), Parent = row })
			local el = kind and kind.element and ELEMENT_TEXT[kind.element]
			if el and known then
				make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0.45, 0, 0, 7), Size = UDim2.new(0.14, 0, 0, 20), Font = FONT, TextScaled = true, TextColor3 = el[2], Text = el[1], Parent = row })
			end
			-- mastery bar
			local bar = make("Frame", { Position = UDim2.new(0.6, 0, 0, 11), Size = UDim2.new(0.38, 0, 0, 12), BackgroundColor3 = Color3.fromRGB(40, 34, 30), Parent = row }, { corner(6) })
			local fill = math.clamp(kills / need, 0, 1)
			make("Frame", { Size = UDim2.fromScale(fill, 1), BackgroundColor3 = if fill >= 1 then Color3.fromRGB(240, 200, 90) else Color3.fromRGB(120, 200, 120), Parent = bar }, { corner(6) })
			make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = FONT, TextScaled = true, TextColor3 = WHITE, TextStrokeTransparency = 0.4, Text = if fill >= 1 then string.format("Mastered (%d)", kills) else string.format("%d / %d", kills, need), Parent = bar })
		end
	end
	subtitle.Text = string.format("Discovered %d of %d monsters. Defeat one to discover it; defeat enough to master it.", found, total)
end

JournalRemote.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == "state" then
		book = data or { kills = {}, regions = {} }
		book.kills = book.kills or {}
		book.regions = book.regions or {}
		if win.Visible then
			render()
		end
	end
end)

local function toggle()
	win.Visible = not win.Visible
	if win.Visible then
		render()
	end
end

local button = make("TextButton", {
	Position = UDim2.new(0, 12, 0, 424),
	Size = UDim2.fromOffset(110, 34),
	BackgroundColor3 = Color3.fromRGB(150, 110, 60),
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "Journal (N)",
	Parent = gui,
}, { corner(8) })
button.Activated:Connect(toggle)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.N then
		toggle()
	end
end)

return {}
