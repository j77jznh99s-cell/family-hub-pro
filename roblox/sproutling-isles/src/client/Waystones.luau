-- Waystones on the client: the travel window, the arrival flash, and lighting up the runes of
-- waystones you've attuned.
--
-- The window opens at a waystone (travel anywhere you've attuned, free) or with T / the
-- Travel button / a waystone pin on the world map (works anywhere, once a minute).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Waystones = require(Shared:WaitForChild("Waystones"))

local WaystoneClient = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local WaystoneRemote = remotes:WaitForChild("Waystone") :: RemoteEvent

local FONT = Enum.Font.FredokaOne
local TITLE = Enum.Font.Fantasy
local PANEL = Color3.fromRGB(32, 36, 48)
local CARD = Color3.fromRGB(50, 56, 74)
local ICE = Color3.fromRGB(150, 210, 255)
local WHITE = Color3.new(1, 1, 1)
local LIT = Color3.fromRGB(120, 210, 255)
local DIM = Color3.fromRGB(110, 110, 120)

local attuned: { [string]: boolean } = {}
local mapReadyAt = 0 -- os.clock() on this client when map travel is ready
local atStone: string? = nil

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

local gui = make("ScreenGui", { Name = "WaystoneGui", ResetOnSpawn = false, DisplayOrder = 9, Parent = player:WaitForChild("PlayerGui") })

local W, H = 600, 500
local win = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = PANEL,
	Visible = false,
	Parent = gui,
}, { corner(10), make("UIStroke", { Color = ICE, Thickness = 2 }) })
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
local title = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -60, 0, 32), Font = TITLE, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = ICE, Text = "Waystones", Parent = win })
local subtitle = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 18), Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(210, 220, 240), Text = "", Parent = win })
local close = make("TextButton", { Position = UDim2.new(1, -38, 0, 8), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(150, 60, 60), Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "X", Parent = win }, { corner(6) })
close.Activated:Connect(function()
	win.Visible = false
end)
local list = make("ScrollingFrame", {
	BackgroundColor3 = Color3.fromRGB(22, 25, 34),
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

local function render()
	for _, c in list:GetChildren() do
		if c:IsA("Frame") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local count = 0
	for _ in attuned do
		count += 1
	end
	local wait = math.max(0, math.ceil(mapReadyAt - os.clock()))
	if atStone then
		title.Text = "Waystone: " .. (Waystones.ById[atStone] and Waystones.ById[atStone].name or "")
		subtitle.Text = string.format("Travel free to any attuned waystone. Attuned: %d of %d.", count, #Waystones.List)
	else
		title.Text = "Fast Travel"
		subtitle.Text = if wait > 0 then string.format("Recharging: %ds (no wait when you stand at a waystone).", wait) else string.format("Travel from anywhere once a minute. Attuned: %d of %d.", count, #Waystones.List)
	end
	local order = 0
	for _, region in Waystones.Regions do
		order += 1
		make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = order, Font = TITLE, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = ICE, Text = region, Parent = list })
		for _, w in Waystones.List do
			if w.region == region then
				order += 1
				local known = attuned[w.id] == true
				local row = make("Frame", { BackgroundColor3 = CARD, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order, Parent = list }, { corner(6) })
				make("Frame", { Position = UDim2.fromOffset(8, 12), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = if known then LIT else DIM, Parent = row }, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
				make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 6), Size = UDim2.new(0.62, -32, 0, 28), Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if known then WHITE else Color3.fromRGB(150, 150, 160), Text = if known then w.name else w.name .. " (not attuned)", Parent = row })
				if known and w.id ~= atStone then
					local can = atStone ~= nil or wait == 0
					local b = make("TextButton", { Position = UDim2.new(0.66, 0, 0, 5), Size = UDim2.new(0.32, 0, 0, 30), BackgroundColor3 = if can then Color3.fromRGB(60, 120, 190) else Color3.fromRGB(70, 70, 80), Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = if can then "Travel" else "Recharging", Parent = row }, { corner(6) })
					b.Activated:Connect(function()
						if can then
							WaystoneRemote:FireServer("travel", w.id, atStone == nil)
							win.Visible = false
						end
					end)
				elseif w.id == atStone then
					make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0.66, 0, 0, 5), Size = UDim2.new(0.32, 0, 0, 30), Font = FONT, TextScaled = true, TextColor3 = ICE, Text = "You are here", Parent = row })
				end
			end
		end
	end
end

function WaystoneClient.open(at: string?)
	atStone = at
	win.Visible = true
	render()
end

function WaystoneClient.isAttuned(id: string): boolean
	return attuned[id] == true
end

-- light up the runes of attuned waystones
local function paint(model: Instance)
	local id = model:GetAttribute("Waystone")
	if typeof(id) ~= "string" or not model:IsA("Model") then
		return
	end
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Rune" then
			p.Color = if attuned[id] then LIT else DIM
		end
	end
end
local stonesFolder: Instance? = nil
local function paintAll()
	if stonesFolder then
		for _, m in stonesFolder:GetChildren() do
			paint(m)
		end
	end
end
task.spawn(function()
	local map = workspace:WaitForChild("Map", 60)
	local wilds = map and map:WaitForChild("Wilds", 30)
	local folder = wilds and wilds:WaitForChild("Waystones", 30)
	if folder then
		stonesFolder = folder
		folder.ChildAdded:Connect(function(m)
			task.defer(paint, m)
		end)
		paintAll()
	end
end)

-- arrival: a soft blue flash
local function flash(name: string)
	local f = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 235, 255), BackgroundTransparency = 0, ZIndex = 20, Parent = gui })
	local t = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(600, 60), BackgroundTransparency = 1, Font = TITLE, TextScaled = true, TextColor3 = Color3.fromRGB(40, 70, 110), Text = name, ZIndex = 21, Parent = gui })
	gui.IgnoreGuiInset = true
	TweenService:Create(f, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(t, TweenInfo.new(1.8, Enum.EasingStyle.Quad), { TextTransparency = 1 }):Play()
	task.delay(2, function()
		f:Destroy()
		t:Destroy()
		gui.IgnoreGuiInset = false
	end)
end

WaystoneRemote.OnClientEvent:Connect(function(kind: string, a: any, b: any)
	if kind == "state" then
		attuned = a or {}
		mapReadyAt = os.clock() + (tonumber(b) or 0)
		paintAll()
		if win.Visible then
			render()
		end
	elseif kind == "open" then
		WaystoneClient.open(a)
	elseif kind == "arrive" then
		flash(tostring(a))
	end
end)

local button = make("TextButton", {
	Position = UDim2.new(0, 12, 0, 382),
	Size = UDim2.fromOffset(110, 34),
	BackgroundColor3 = Color3.fromRGB(60, 110, 170),
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "Travel (T)",
	Parent = gui,
}, { corner(8) })
button.Activated:Connect(function()
	if win.Visible then
		win.Visible = false
	else
		WaystoneClient.open(nil)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.T then
		if win.Visible then
			win.Visible = false
		else
			WaystoneClient.open(nil)
		end
	end
end)

-- keep the recharge countdown ticking while the window is open
task.spawn(function()
	while true do
		task.wait(1)
		if win.Visible and not atStone then
			render()
		end
	end
end)

return WaystoneClient
