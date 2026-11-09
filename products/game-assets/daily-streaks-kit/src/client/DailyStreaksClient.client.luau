-- Daily Streaks Kit: client panel. Builds its own UI in code (no assets needed), works with
-- mouse, touch and gamepad. Colours and the shortcut key are in ReplicatedStorage.DailyStreaks.Config.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("DailyStreaks")
local Config = require(Shared:WaitForChild("Config"))
local remote = Shared:WaitForChild("Remote")
local player = Players.LocalPlayer
local C = Config.Colors

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r: number?)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 10) })
end

local function padding(px: number)
	return make("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

local function text(props: { [string]: any })
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextColor3 = props.TextColor3 or C.text
	props.TextSize = props.TextSize or 15
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local gui = make("ScreenGui", {
	Name = "DailyStreaks",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Open button (bottom left, clear of the mobile jump button)
local button = make("TextButton", {
	Name = "Open",
	Visible = Config.ShowButton,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -96),
	Size = UDim2.fromOffset(112, 40),
	BackgroundColor3 = C.panel,
	Font = Enum.Font.GothamBold,
	Text = "Daily",
	TextColor3 = C.accent,
	TextSize = 16,
	AutoButtonColor = true,
	Parent = gui,
}, { corner(12) })

-- Panel
local panel = make("Frame", {
	Name = "Panel",
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.9, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = C.panel,
	Parent = gui,
}, {
	corner(14),
	padding(14),
	make("UISizeConstraint", { MaxSize = Vector2.new(380, math.huge) }),
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local header = make("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = panel })
text({ Text = "Daily Tasks", Font = Enum.Font.GothamBold, TextSize = 20, Size = UDim2.new(1, -36, 1, 0), Parent = header })
local close = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = C.row,
	Font = Enum.Font.GothamBold,
	Text = "X",
	TextColor3 = C.muted,
	TextSize = 14,
	Parent = header,
}, { corner(8) })

local rows = make("Frame", {
	LayoutOrder = 2,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Parent = panel,
}, { make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

local bonusLabel = text({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 18), TextColor3 = C.muted, TextSize = 13, Parent = panel })
local streakLabel = text({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 20), TextColor3 = C.accent, Font = Enum.Font.GothamBold, Parent = panel })
local timerLabel = text({ LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 18), TextColor3 = C.muted, TextSize = 13, Parent = panel })

-- Toasts (top centre)
local toasts = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 60),
	Size = UDim2.new(0.9, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	make("UISizeConstraint", { MaxSize = Vector2.new(420, math.huge) }),
	make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
})

local function showToast(message: string)
	local label = text({
		Text = message,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBold,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.1,
		BackgroundColor3 = C.panel,
		Parent = toasts,
	})
	corner(10).Parent = label
	padding(10).Parent = label
	task.delay(4, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
end

local function addRow(order: number, row)
	local frame = make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = C.row,
		Parent = rows,
	}, { corner(10), padding(8) })
	text({
		Text = row.text,
		TextColor3 = if row.done then C.done else C.text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -64, 0, 20),
		Parent = frame,
	})
	text({
		Text = if row.reward > 0 then "+" .. row.reward else "",
		TextColor3 = C.accent,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 60, 0, 20),
		Parent = frame,
	})
	local back = make("Frame", {
		Position = UDim2.new(0, 0, 1, -12),
		Size = UDim2.new(1, -64, 0, 10),
		BackgroundColor3 = C.barBack,
		Parent = frame,
	}, { corner(5) })
	make("Frame", {
		Size = UDim2.fromScale(math.clamp(row.n / row.target, 0, 1), 1),
		BackgroundColor3 = if row.done then C.done else C.bar,
		Parent = back,
	}, { corner(5) })
	text({
		Text = if row.done then "Done" else string.format("%d/%d", row.n, row.target),
		TextColor3 = C.muted,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0, 60, 0, 16),
		Parent = frame,
	})
end

local deadline = 0
local askedAtZero = false

local function render(view)
	for _, child in rows:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local done = 0
	for i, row in view.tasks do
		addRow(i, row)
		if row.done then
			done += 1
		end
	end
	if #view.tasks == 0 then
		text({ Text = "No tasks today.", TextColor3 = C.muted, Size = UDim2.new(1, 0, 0, 20), Parent = rows })
	end
	button.Text = string.format("Daily %d/%d", done, #view.tasks)
	bonusLabel.Text = if view.full
		then "All done for today. Come back tomorrow!"
		else string.format("Finish all for a bonus of +%d", view.allDoneBonus)
	local days = if view.streak == 1 then "1 day" else view.streak .. " days"
	streakLabel.Text = string.format("Streak: %s  (best %d)", days, view.best)
	deadline = os.clock() + view.secondsLeft
	askedAtZero = false
end

local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		remote:FireServer("refresh")
	end
end

button.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
close.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Config.ToggleKey then
		setOpen(not panel.Visible)
	end
end)

remote.OnClientEvent:Connect(function(kind, payload)
	if kind == "state" then
		render(payload)
	elseif kind == "open" then
		panel.Visible = true
	elseif kind == "toast" then
		showToast(payload)
	end
end)

-- countdown to new tasks
task.spawn(function()
	while true do
		local left = math.max(0, math.floor(deadline - os.clock()))
		timerLabel.Text = string.format("New tasks in %02d:%02d:%02d", left // 3600, left % 3600 // 60, left % 60)
		if left == 0 and deadline > 0 and not askedAtZero then
			askedAtZero = true
			task.delay(3, function()
				remote:FireServer("refresh")
			end)
		end
		task.wait(1)
	end
end)

remote:FireServer("refresh")
