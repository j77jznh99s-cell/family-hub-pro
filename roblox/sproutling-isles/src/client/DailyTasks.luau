-- The Daily Tasks window (Y, the Tasks button, or a Task Board): today's three tasks with
-- progress bars and rewards, the all-done crate, the streak, and when new tasks arrive.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyTasks = require(Shared:WaitForChild("DailyTasks"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local DailyRemote = remotes:WaitForChild("DailyTasks") :: RemoteEvent

local FONT = Enum.Font.FredokaOne
local TITLE = Enum.Font.Fantasy
local PANEL = Color3.fromRGB(34, 44, 36)
local CARD = Color3.fromRGB(52, 68, 54)
local LEAF = Color3.fromRGB(170, 230, 150)
local WHITE = Color3.new(1, 1, 1)

local state: any = nil
local nextAt = 0 -- os.clock() when new tasks arrive

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

local gui = make("ScreenGui", { Name = "DailyTasksGui", ResetOnSpawn = false, DisplayOrder = 9, Parent = player:WaitForChild("PlayerGui") })
local W, H = 480, 330
local win = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = PANEL,
	Visible = false,
	Parent = gui,
}, { corner(10), make("UIStroke", { Color = LEAF, Thickness = 2 }) })
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
make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -60, 0, 32), Font = TITLE, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = LEAF, Text = "Daily Tasks", Parent = win })
local subtitle = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 18), Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(215, 235, 205), Text = "", Parent = win })
local close = make("TextButton", { Position = UDim2.new(1, -38, 0, 8), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(150, 60, 60), Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "X", Parent = win }, { corner(6) })
close.Activated:Connect(function()
	win.Visible = false
end)
local rows = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 66), Size = UDim2.new(1, -28, 0, 200), Parent = win }, {
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local footer = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 14, 1, -54), Size = UDim2.new(1, -28, 0, 40), Font = FONT, TextScaled = true, TextWrapped = true, TextColor3 = Color3.fromRGB(255, 220, 140), Text = "", Parent = win })

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
end

local function render()
	for _, c in rows:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	if not state then
		subtitle.Text = "Loading..."
		return
	end
	local done = 0
	for i, entry in state.tasks do
		local t = DailyTasks.ById[entry.id]
		if t then
			if entry.done then
				done += 1
			end
			local row = make("Frame", { BackgroundColor3 = CARD, Size = UDim2.new(1, 0, 0, 58), LayoutOrder = i, Parent = rows }, { corner(8) })
			make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.74, -10, 0, 24), Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if entry.done then Color3.fromRGB(150, 230, 150) else WHITE, Text = (if entry.done then "Done: " else "") .. string.format(t.text, t.target), Parent = row })
			make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0.75, 0, 0, 4), Size = UDim2.new(0.24, 0, 0, 24), Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(255, 225, 130), Text = "+" .. t.dew .. " Dew", Parent = row })
			local bar = make("Frame", { Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -20, 0, 16), BackgroundColor3 = Color3.fromRGB(30, 38, 32), Parent = row }, { corner(8) })
			local fill = math.clamp(entry.n / t.target, 0, 1)
			make("Frame", { Size = UDim2.fromScale(fill, 1), BackgroundColor3 = if entry.done then Color3.fromRGB(240, 200, 90) else Color3.fromRGB(110, 200, 110), Parent = bar }, { corner(8) })
			make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = FONT, TextScaled = true, TextColor3 = WHITE, TextStrokeTransparency = 0.4, Text = string.format("%d / %d", entry.n, t.target), Parent = bar })
		end
	end
	subtitle.Text = string.format("%d of %d done. New tasks in %s.", done, #state.tasks, clock(nextAt - os.clock()))
	local streak = state.streak or 0
	footer.Text = if state.full
		then string.format("All done today! Streak: %d day%s. Come back tomorrow.", streak, if streak == 1 then "" else "s")
		else string.format("Finish all three for a crate (every %dth day in a row: a golden one). Streak: %d.", DailyTasks.StreakEvery, streak)
end

DailyRemote.OnClientEvent:Connect(function(kind: string, a: any, b: any)
	if kind == "state" then
		state = a
		nextAt = os.clock() + (tonumber(b) or 0)
		if win.Visible then
			render()
		end
	elseif kind == "open" then
		win.Visible = true
		render()
	end
end)

local function toggle()
	win.Visible = not win.Visible
	if win.Visible then
		render()
	end
end

local button = make("TextButton", {
	Position = UDim2.new(0, 12, 0, 466),
	Size = UDim2.fromOffset(110, 34),
	BackgroundColor3 = Color3.fromRGB(70, 140, 80),
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "Tasks (Y)",
	Parent = gui,
}, { corner(8) })
button.Activated:Connect(toggle)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Y then
		toggle()
	end
end)

-- keep the countdown ticking while open
task.spawn(function()
	while true do
		task.wait(20)
		if win.Visible then
			render()
		end
	end
end)

return {}
