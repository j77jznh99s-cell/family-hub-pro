-- Quests on the client: the talk window, the quest tracker, the guide beam and the marks over
-- quest givers' heads.
--
-- Talk to someone (their prompt) and the server opens the talk window: quests they offer
-- (Accept), quests in progress (Drop) and quests ready to hand in (Turn in). The tracker in the
-- top-right lists active quests; tap one to follow it, and a beam of light marks where to go.
-- L hides or shows the tracker. Marks over heads: ! has a quest for you, ? is ready to hand in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared:WaitForChild("Quests"))
local Loot = require(Shared:WaitForChild("Loot"))

local QuestLog = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local StateRemote = remotes:WaitForChild("QuestState") :: RemoteEvent
local ActionRemote = remotes:WaitForChild("QuestAction") :: RemoteEvent
local DialogRemote = remotes:WaitForChild("QuestDialog") :: RemoteEvent

local FONT = Enum.Font.FredokaOne
local TITLE = Enum.Font.Fantasy
local PANEL = Color3.fromRGB(40, 32, 28)
local CARD = Color3.fromRGB(66, 54, 46)
local GOLD = Color3.fromRGB(240, 200, 110)
local WHITE = Color3.new(1, 1, 1)

local snapshot: any = { active = {}, done = {} }
local openNpc: string? = nil
local tracked: string? = nil

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

local function label(text: string, size: UDim2, pos: UDim2, color: Color3?, font: Enum.Font?, wrapped: boolean?): TextLabel
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Position = pos,
		Font = font or FONT,
		TextScaled = not wrapped,
		TextWrapped = wrapped == true,
		TextSize = 15,
		TextColor3 = color or WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = if wrapped then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
		TextStrokeTransparency = 0.6,
		Text = text,
	})
end

local function button(text: string, size: UDim2, pos: UDim2, color: Color3, onClick: () -> ()): TextButton
	local b = make("TextButton", {
		Size = size,
		Position = pos,
		BackgroundColor3 = color,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.5,
		Text = text,
		AutoButtonColor = true,
	}, { corner(6) })
	b.Activated:Connect(onClick)
	return b
end

local gui = make("ScreenGui", { Name = "QuestGui", ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })

----------------------------------------------------------------------------------------------
-- helpers

local function canStart(q: Quests.Quest): boolean
	if snapshot.done[q.id] or snapshot.active[q.id] then
		return false
	end
	for _, req in q.requires or {} do
		if not snapshot.done[req] then
			return false
		end
	end
	return true
end

local function rewardText(r: Quests.Reward): string
	local parts = {}
	if r.dew then
		table.insert(parts, r.dew .. " Dew")
	end
	for id, count in r.materials or {} do
		local m = Loot.Materials[id]
		table.insert(parts, count .. " " .. (if m then m.name else id))
	end
	if r.weapon then
		table.insert(parts, Loot.Rarities[r.weapon].name .. "+ weapon")
	end
	if r.potions then
		table.insert(parts, r.potions .. " Healing Draughts")
	end
	if r.unlock == "skyward" then
		table.insert(parts, "the Skyward Charm (ride the wind shrines)")
	end
	if r.crate then
		table.insert(parts, "a " .. r.crate .. " crate")
	end
	return "Reward: " .. table.concat(parts, ", ")
end

local function progressText(q: Quests.Quest, a: any): string
	if a.ready then
		return "Return to " .. Quests.Npcs[q.turnIn or q.giver].name
	end
	if q.objective.kind == "talk" or q.objective.kind == "bring" then
		return q.objective.text
	end
	return string.format("%s %d/%d", q.objective.text, a.n, a.goal)
end

----------------------------------------------------------------------------------------------
-- the talk window

local win = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(560, 440),
	BackgroundColor3 = PANEL,
	Visible = false,
	Parent = gui,
}, { corner(10), make("UIStroke", { Color = GOLD, Thickness = 2 }) })
do
	local scale = make("UIScale", { Parent = win })
	local function fit()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.min(1, (view.X - 20) / 560, (view.Y - 80) / 440)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end
local nameLabel = label("", UDim2.new(1, -60, 0, 30), UDim2.fromOffset(14, 8), GOLD, TITLE)
nameLabel.Parent = win
local titleLabel = label("", UDim2.new(1, -60, 0, 18), UDim2.fromOffset(14, 38), Color3.fromRGB(200, 220, 255))
titleLabel.Parent = win
local greetLabel = label("", UDim2.new(1, -28, 0, 40), UDim2.fromOffset(14, 60), Color3.fromRGB(235, 225, 205), FONT, true)
greetLabel.Parent = win
button("X", UDim2.fromOffset(30, 30), UDim2.new(1, -38, 0, 8), Color3.fromRGB(150, 60, 60), function()
	win.Visible = false
	openNpc = nil
end).Parent = win
local list = make("ScrollingFrame", {
	BackgroundColor3 = Color3.fromRGB(30, 24, 22),
	Position = UDim2.fromOffset(14, 106),
	Size = UDim2.new(1, -28, 1, -120),
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = win,
}, {
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10) }),
})

local function card(order: number, q: Quests.Quest, body: string, status: string, statusColor: Color3, buttons: { { any } })
	local c = make("Frame", { BackgroundColor3 = CARD, Size = UDim2.new(1, 0, 0, 132), LayoutOrder = order, Parent = list }, { corner(6) })
	label(q.name, UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 4), GOLD).Parent = c
	label(body, UDim2.new(1, -16, 0, 50), UDim2.fromOffset(8, 28), Color3.fromRGB(225, 215, 195), FONT, true).Parent = c
	label(status, UDim2.new(1, -16, 0, 16), UDim2.fromOffset(8, 80), statusColor).Parent = c
	label(rewardText(q.reward), UDim2.new(0.6, -8, 0, 16), UDim2.fromOffset(8, 104), Color3.fromRGB(170, 255, 200)).Parent = c
	for i, b in buttons do
		button(b[1], UDim2.fromOffset(96, 28), UDim2.new(1, -8 - i * 102, 0, 98), b[2], b[3]).Parent = c
	end
end

local function renderDialog()
	if not openNpc then
		return
	end
	local npc = Quests.Npcs[openNpc]
	for _, c in list:GetChildren() do
		if c:IsA("Frame") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	nameLabel.Text = npc.name
	titleLabel.Text = npc.title
	greetLabel.Text = npc.greeting
	local order = 0
	for _, q in Quests.List do
		local a = snapshot.active[q.id]
		local turnIn = q.turnIn or q.giver
		order += 1
		if a and turnIn == openNpc and a.ready then
			card(order, q, q.finish, "Ready to hand in!", Color3.fromRGB(150, 255, 160), {
				{ "Turn in", Color3.fromRGB(70, 150, 80), function()
					ActionRemote:FireServer("turnin", q.id)
				end },
			})
		elseif a and q.giver == openNpc then
			card(order, q, q.intro, progressText(q, a), Color3.fromRGB(255, 230, 150), {
				{ "Drop", Color3.fromRGB(120, 70, 60), function()
					ActionRemote:FireServer("abandon", q.id)
				end },
				{ "Track", Color3.fromRGB(60, 110, 170), function()
					tracked = q.id
					QuestLog.refresh()
				end },
			})
		elseif q.giver == openNpc and canStart(q) then
			card(order, q, q.intro, "Task: " .. q.objective.text, Color3.fromRGB(255, 230, 150), {
				{ "Accept", Color3.fromRGB(70, 140, 80), function()
					tracked = q.id
					ActionRemote:FireServer("accept", q.id)
				end },
			})
		end
	end
	if order == 0 or #list:GetChildren() <= 2 then
		local waiting = false
		for _, q in Quests.List do
			if q.giver == openNpc and not snapshot.done[q.id] and not snapshot.active[q.id] then
				waiting = true
			end
		end
		local text = if waiting then "\"Come back once you've made a name for yourself out there.\"" else "\"You've done all I could ask. Safe travels, friend.\""
		label(text, UDim2.new(1, 0, 0, 40), UDim2.new(), Color3.fromRGB(220, 210, 190), FONT, true).Parent = list
	end
end

DialogRemote.OnClientEvent:Connect(function(npcId: string)
	if not Quests.Npcs[npcId] then
		return
	end
	openNpc = npcId
	win.Visible = true
	renderDialog()
end)

----------------------------------------------------------------------------------------------
-- tracker and guide beam

local tracker = make("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 130),
	Size = UDim2.fromOffset(260, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.25,
	Parent = gui,
}, {
	corner(8),
	make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
})
local trackerVisible = true

local beam: Part? = nil
local function setBeam(pos: Vector3?)
	if not pos then
		if beam then
			beam:Destroy()
			beam = nil
		end
		return
	end
	if not beam then
		local b = Instance.new("Part")
		b.Name = "QuestBeam"
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Material = Enum.Material.Neon
		b.Color = Color3.fromRGB(255, 220, 110)
		b.Transparency = 0.55
		b.Size = Vector3.new(2.5, 260, 2.5)
		b.Parent = workspace
		beam = b
	end
	(beam :: Part).CFrame = CFrame.new(pos + Vector3.new(0, 130, 0))
end

function QuestLog.refresh()
	for _, c in tracker:GetChildren() do
		if c:IsA("TextButton") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local count = 0
	if tracked and not snapshot.active[tracked] then
		tracked = nil
	end
	for _, q in Quests.List do
		local a = snapshot.active[q.id]
		if a then
			count += 1
			tracked = tracked or q.id
			local mine = tracked == q.id
			local line = make("TextButton", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 34),
				LayoutOrder = count,
				Font = FONT,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if a.ready then Color3.fromRGB(150, 255, 160) elseif mine then GOLD else WHITE,
				TextStrokeTransparency = 0.5,
				Text = (if mine then "> " else "") .. q.name .. "\n" .. progressText(q, a),
				Parent = tracker,
			})
			line.Activated:Connect(function()
				tracked = q.id
				QuestLog.refresh()
			end)
		end
	end
	if count == 0 then
		local hint = label("No quests. Look for people with a ! over their heads.", UDim2.new(1, 0, 0, 30), UDim2.new(), Color3.fromRGB(220, 210, 190), FONT, true)
		hint.Parent = tracker
	end
	tracker.Visible = trackerVisible
	local a = tracked and snapshot.active[tracked]
	setBeam(if a and trackerVisible then a.target else nil)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.L then
		trackerVisible = not trackerVisible
		QuestLog.refresh()
	end
end)

----------------------------------------------------------------------------------------------
-- marks over quest givers

local marks: { [string]: TextLabel } = {}

local function updateMarks()
	for npcId, text in marks do
		if not text.Parent then
			marks[npcId] = nil
			continue
		end
		local mark, color = "", WHITE
		for _, q in Quests.List do
			local a = snapshot.active[q.id]
			if a and a.ready and (q.turnIn or q.giver) == npcId then
				mark, color = "?", Color3.fromRGB(120, 255, 140)
				break
			elseif q.giver == npcId and canStart(q) and mark == "" then
				mark, color = "!", Color3.fromRGB(255, 215, 60)
			end
		end
		text.Text = mark
		text.TextColor3 = color
		local gui_ = text.Parent :: BillboardGui
		gui_.Enabled = mark ~= ""
	end
end

local function watchNpc(m: Instance)
	local npcId = m:GetAttribute("QuestNpc")
	if not m:IsA("Model") or typeof(npcId) ~= "string" then
		return
	end
	task.spawn(function()
		local head = m:WaitForChild("Head", 10)
		local mark = head and head:WaitForChild("QuestMark", 10)
		local text = mark and mark:WaitForChild("Text", 10)
		if text then
			marks[npcId] = text :: TextLabel
			updateMarks()
		end
	end)
end

task.spawn(function()
	local map = workspace:WaitForChild("Map", 60)
	if not map then
		return
	end
	local wilds = map:WaitForChild("Wilds", 30)
	if not wilds then
		return
	end
	for _, d in wilds:GetDescendants() do
		watchNpc(d)
	end
	wilds.DescendantAdded:Connect(watchNpc)
end)

StateRemote.OnClientEvent:Connect(function(data)
	snapshot = data
	snapshot.active = snapshot.active or {}
	snapshot.done = snapshot.done or {}
	QuestLog.refresh()
	renderDialog()
	updateMarks()
end)

QuestLog.refresh()

return QuestLog
