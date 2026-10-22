-- The help panel (F1 or the Help button): every control and where to find things.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne
local GOLD = Color3.fromRGB(240, 200, 110)
local WHITE = Color3.new(1, 1, 1)

local LINES = {
	{ "GETTING STARTED", true },
	{ "Talk to Mara the Guide by the bridge south of the plaza for a tour.", false },
	{ "Gold ! over a head = a quest for you. Green ? = hand it in.", false },
	{ "", false },
	{ "CONTROLS", true },
	{ "Click / tap: attack     1 / 2 / 3: sword, bow, staff     Shift: dodge roll", false },
	{ "Q / X / C: Whirlwind, Firebolt, Second Wind     H: healing draught     J: stamina tonic", false },
	{ "E: talk, shop, pick up     B: bag     K: crates     L: quest tracker", false },
	{ "M: world map     G: garage (vehicles)     V: horse     P: companion", false },
	{ "Flying: Space up, Ctrl down. The Ornithopter always flies forward; W for speed.", false },
	{ "", false },
	{ "WHERE TO GO", true },
	{ "Market Square: shops, fountain, level leaderboard.     Arena: wave trials, crates.", false },
	{ "Royal Treasury: crates.     Grand Library: XP tomes.     Cartographer / Guild: map.", false },
	{ "Carriage Works, Boatwright, Aerie Workshop: vehicles (unlock by level).", false },
	{ "Coachpaint Atelier, Sailmaker, Paint Loft: paint your vehicles.", false },
	{ "Skyward Shipyard (airship port) and Shipwright (docks): fast travel.", false },
	{ "Wind shrines: up to the sky isles, once Pell gives you the Skyward Charm.", false },
	{ "Every day you log in: a free crate. Every 7 days in a row: a silver one too.", false },
}

local gui = Instance.new("ScreenGui")
gui.Name = "HelpGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 9
gui.Parent = player:WaitForChild("PlayerGui")

local W, H = 760, 520
local win = Instance.new("Frame")
win.AnchorPoint = Vector2.new(0.5, 0.5)
win.Position = UDim2.fromScale(0.5, 0.5)
win.Size = UDim2.fromOffset(W, H)
win.BackgroundColor3 = Color3.fromRGB(40, 32, 28)
win.Visible = false
win.Parent = gui
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke")
stroke.Color = GOLD
stroke.Thickness = 2
stroke.Parent = win
local scale = Instance.new("UIScale")
scale.Parent = win
local function fit()
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	scale.Scale = math.min(1, (view.X - 20) / W, (view.Y - 40) / H)
end
fit()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end

local list = Instance.new("Frame")
list.BackgroundTransparency = 1
list.Position = UDim2.fromOffset(18, 14)
list.Size = UDim2.new(1, -60, 1, -28)
list.Parent = win
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 3)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list
for i, line in LINES do
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.LayoutOrder = i
	l.Size = UDim2.new(1, 0, 0, if line[1] == "" then 6 elseif line[2] then 26 else 21)
	l.Font = FONT
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = if line[2] then GOLD else WHITE
	l.TextStrokeTransparency = 0.6
	l.Text = line[1]
	l.Parent = list
end

local close = Instance.new("TextButton")
close.Position = UDim2.new(1, -38, 0, 8)
close.Size = UDim2.fromOffset(30, 30)
close.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
close.Font = FONT
close.TextScaled = true
close.TextColor3 = WHITE
close.Text = "X"
close.Parent = win
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
close.Activated:Connect(function()
	win.Visible = false
end)

local button = Instance.new("TextButton")
button.Position = UDim2.new(0, 12, 0, 340)
button.Size = UDim2.fromOffset(110, 34)
button.BackgroundColor3 = Color3.fromRGB(110, 90, 150)
button.Font = FONT
button.TextScaled = true
button.TextColor3 = WHITE
button.Text = "Help (F1)"
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
button.Activated:Connect(function()
	win.Visible = not win.Visible
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.F1 then
		win.Visible = not win.Visible
	end
end)

return {}
