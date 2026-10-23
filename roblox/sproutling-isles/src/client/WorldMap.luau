-- The world map (M, the Map button, the Cartographer, the Adventurers' Guild board).
--
-- Drawn on the client from Shared/Landscape the first time it opens: land coloured by height,
-- the sea, the city, and every road. Pins come from the server (MapPOIs): towns and villages,
-- quest givers, shops and halls, wind shrines, sky isles, the arena and the crypt. Tap a pin to
-- see its name and set a waypoint (a blue beam of light in the world). A legend lists every
-- way of getting around.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Landscape = require(Shared:WaitForChild("Landscape"))
local Shops = require(Shared:WaitForChild("Shops"))

local WaystoneClient = require(script.Parent:WaitForChild("Waystones"))

local WorldMap = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local POIRemote = remotes:WaitForChild("MapPOIs") :: RemoteFunction
local OpenShopRemote = remotes:WaitForChild("OpenShop") :: RemoteEvent

local FONT = Enum.Font.FredokaOne
local TITLE = Enum.Font.Fantasy
local PANEL = Color3.fromRGB(40, 32, 28)
local GOLD = Color3.fromRGB(240, 200, 110)
local WHITE = Color3.new(1, 1, 1)

local KINDS = {
	town = { color = Color3.fromRGB(255, 230, 120), label = "Town" },
	village = { color = Color3.fromRGB(255, 190, 120), label = "Village / site" },
	quest = { color = Color3.fromRGB(255, 215, 60), label = "Quest giver" },
	vehicles = { color = Color3.fromRGB(120, 200, 255), label = "Vehicles & horses" },
	custom = { color = Color3.fromRGB(255, 140, 200), label = "Paint shops" },
	crates = { color = Color3.fromRGB(240, 170, 60), label = "Crate vault" },
	hall = { color = Color3.fromRGB(200, 170, 255), label = "Halls & guild" },
	shop = { color = Color3.fromRGB(200, 200, 200), label = "Shops" },
	travel = { color = Color3.fromRGB(120, 255, 220), label = "Airships & boats" },
	shrine = { color = Color3.fromRGB(170, 230, 255), label = "Wind shrine" },
	sky = { color = Color3.fromRGB(230, 240, 255), label = "Sky isle" },
	waystone = { color = Color3.fromRGB(90, 170, 255), label = "Waystone (fast travel)" },
	arena = { color = Color3.fromRGB(255, 90, 80), label = "Arena" },
	dungeon = { color = Color3.fromRGB(150, 110, 200), label = "Crypt" },
}

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

local gui = make("ScreenGui", { Name = "WorldMapGui", ResetOnSpawn = false, DisplayOrder = 8, Parent = player:WaitForChild("PlayerGui") })

local W, H = 860, 600
local win = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = PANEL,
	Visible = false,
	Parent = gui,
}, { corner(10), make("UIStroke", { Color = GOLD, Thickness = 2 }) })
do
	local scale = make("UIScale", { Parent = win })
	local function fit()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.min(1, (view.X - 20) / W, (view.Y - 40) / H)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end
make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(400, 32), Font = TITLE, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD, Text = "Map of the Isles", Parent = win })
local close = make("TextButton", { Position = UDim2.new(1, -38, 0, 8), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(150, 60, 60), Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = "X", Parent = win }, { corner(6) })
close.Activated:Connect(function()
	win.Visible = false
end)

-- the map canvas keeps the land's shape (x across, z down)
local b = Landscape.Bounds
local MAPH = H - 60
local MAPW = math.floor(MAPH * (b.x1 - b.x0) / (b.z1 - b.z0))
local canvas = make("Frame", {
	Position = UDim2.fromOffset(14, 46),
	Size = UDim2.fromOffset(MAPW, MAPH),
	BackgroundColor3 = Color3.fromRGB(40, 120, 190),
	ClipsDescendants = true,
	Parent = win,
}, { corner(6) })
local function toMap(x: number, z: number): (number, number)
	return (x - b.x0) / (b.x1 - b.x0) * MAPW, (z - b.z0) / (b.z1 - b.z0) * MAPH
end

local info = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(MAPW + 28, 46), Size = UDim2.new(1, -MAPW - 42, 0, 44), Font = FONT, TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = WHITE, Text = "Tap a pin to set a waypoint.", Parent = win })

-- legend and ways to travel
local side = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(MAPW + 28, 96), Size = UDim2.new(1, -MAPW - 42, 1, -110), Parent = win }, {
	make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local order = 0
local function sideLine(text: string, color: Color3, height: number?)
	order += 1
	make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height or 16), LayoutOrder = order, Font = FONT, TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color, Text = text, Parent = side })
end
for _, k in { "town", "village", "waystone", "quest", "vehicles", "custom", "crates", "hall", "travel", "shrine", "sky", "arena", "dungeon" } do
	sideLine("\226\151\143 " .. KINDS[k].label, KINDS[k].color)
end
sideLine("", WHITE, 6)
sideLine("GETTING AROUND", GOLD, 20)
sideLine("Waystones: touch to attune, then travel (T)", Color3.fromRGB(120, 190, 255), 30)
sideLine("Walk or run the roads", WHITE)
sideLine("Horse (V) - Stables", Color3.fromRGB(210, 200, 185))
sideLine("Horse & wagon, carriage, coach - Carriage Works", Color3.fromRGB(210, 200, 185), 30)
sideLine("Rowboat, sloop, swan barge - Boatwright", Color3.fromRGB(210, 200, 185), 30)
sideLine("Ornithopter (plane), Aerial Screw (helicopter), skyship, griffin - Aerie Workshop", Color3.fromRGB(210, 200, 185), 44)
sideLine("Airships and boats to far places - ports", Color3.fromRGB(210, 200, 185), 30)
sideLine("Wind shrines to the sky isles - Skyward Charm", Color3.fromRGB(210, 200, 185), 30)
sideLine("Your vehicles: Garage (G)", Color3.fromRGB(120, 200, 255))

local you = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.fromRGB(255, 60, 60), ZIndex = 10, Parent = canvas }, {
	make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	make("UIStroke", { Color = WHITE, Thickness = 2 }),
})
local youTag = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(40, 14), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = WHITE, TextStrokeTransparency = 0, Text = "You", ZIndex = 10, Parent = canvas })

----------------------------------------------------------------------------------------------
-- waypoint

local waypoint: Part? = nil
local function setWaypoint(x: number, z: number)
	local y = if Landscape.inPlayArea(x, z) then 0 else math.max(Landscape.height(x, z), Landscape.WaterLevel)
	if not waypoint then
		local p = Instance.new("Part")
		p.Name = "MapWaypoint"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(110, 210, 255)
		p.Transparency = 0.5
		p.Size = Vector3.new(3, 300, 3)
		p.Parent = workspace
		waypoint = p
	end
	(waypoint :: Part).CFrame = CFrame.new(x, y + 150, z)
end

----------------------------------------------------------------------------------------------
-- drawing

local built = false
local filter: string? = nil
local pins: { { frame: Frame, kind: string } } = {}

local function landColor(x: number, z: number): Color3?
	if Landscape.inPlayArea(x, z) then
		return Color3.fromRGB(120, 195, 95)
	end
	local h = Landscape.height(x, z)
	if h < Landscape.WaterLevel then
		return nil
	elseif h < 1.5 then
		return Color3.fromRGB(230, 210, 150)
	elseif Landscape.cityWeight(x, z) > 0.7 then
		return Color3.fromRGB(200, 185, 160)
	elseif h > 160 then
		return Color3.fromRGB(235, 235, 240)
	elseif h > 110 then
		return Color3.fromRGB(150, 140, 130)
	end
	local g = math.clamp(1 - h / 140, 0, 1)
	return Color3.fromRGB(math.floor(70 + 50 * g), math.floor(120 + 70 * g), math.floor(55 + 30 * g))
end

local function build()
	built = true
	local cols, rows = 60, 74
	local cw, ch = MAPW / cols, MAPH / rows
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			local x = b.x0 + (c + 0.5) / cols * (b.x1 - b.x0)
			local z = b.z0 + (r + 0.5) / rows * (b.z1 - b.z0)
			local color = landColor(x, z)
			if color then
				make("Frame", { Position = UDim2.fromOffset(c * cw, r * ch), Size = UDim2.fromOffset(cw + 1, ch + 1), BackgroundColor3 = color, BorderSizePixel = 0, Parent = canvas })
			end
		end
		if r % 10 == 0 then
			task.wait()
		end
	end
	-- roads
	for i, samples in Landscape.RoadSamples do
		local color = if Landscape.RoadMaterial[i] == "Ground" then Color3.fromRGB(150, 110, 75) else Color3.fromRGB(120, 115, 110)
		for k = 1, #samples, 6 do
			local s = samples[k]
			local px, pz = toMap(s.x, s.z)
			local size = math.max(2, s.hw / 6)
			make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(px, pz), Size = UDim2.fromOffset(size, size), BackgroundColor3 = color, BorderSizePixel = 0, Parent = canvas })
		end
	end
	-- pins
	local ok, list = pcall(function()
		return POIRemote:InvokeServer()
	end)
	if not ok or typeof(list) ~= "table" then
		return
	end
	for _, poi in list do
		local kind = KINDS[poi.kind] or KINDS.shop
		local px, pz = toMap(poi.x, poi.z)
		local major = poi.kind == "town" or poi.kind == "village"
		local size = if major then 12 else 9
		local pin = make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(px, pz),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = kind.color,
			Text = "",
			ZIndex = if major then 4 else 5,
			Parent = canvas,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), make("UIStroke", { Color = Color3.fromRGB(30, 25, 20), Thickness = 1.5 }) })
		if major then
			make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 1), Size = UDim2.fromOffset(110, 13), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = WHITE, TextStrokeTransparency = 0.2, Text = poi.name, ZIndex = 4, Parent = pin })
		end
		pin.Activated:Connect(function()
			if poi.kind == "waystone" and poi.id and WaystoneClient.isAttuned(poi.id) then
				win.Visible = false
				WaystoneClient.open(nil)
				return
			end
			info.Text = poi.name .. (if poi.kind == "waystone" then " - not attuned yet. Waypoint set." else " - waypoint set (blue beam).")
			setWaypoint(poi.x, poi.z)
		end)
		pin.MouseEnter:Connect(function()
			info.Text = poi.name
		end)
		table.insert(pins, { frame = pin, kind = poi.kind })
	end
end

local function applyFilter()
	for _, p in pins do
		local show = filter == nil or p.kind == filter or p.kind == "town" or p.kind == "village"
		p.frame.Visible = show
	end
end

function WorldMap.open(only: string?)
	filter = only
	win.Visible = true
	if not built then
		info.Text = "Drawing the map..."
		task.spawn(function()
			build()
			applyFilter()
			info.Text = if filter == "quest" then "Gold pins are people who need help. Tap one for a waypoint." else "Tap a pin to set a waypoint."
		end)
	else
		applyFilter()
	end
end

function WorldMap.toggle()
	if win.Visible then
		win.Visible = false
	else
		WorldMap.open(nil)
	end
end

-- keep the "you" marker moving while the map is open
task.spawn(function()
	while true do
		task.wait(0.25)
		if win.Visible then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local px, pz = toMap(root.Position.X, root.Position.Z)
				you.Position = UDim2.fromOffset(px, pz)
				youTag.Position = UDim2.fromOffset(px, pz - 8)
			end
		end
	end
end)

local mapButton = make("TextButton", {
	Position = UDim2.new(0, 12, 0, 298),
	Size = UDim2.fromOffset(110, 34),
	BackgroundColor3 = Color3.fromRGB(60, 130, 120),
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "Map (M)",
	Parent = gui,
}, { corner(8) })
mapButton.Activated:Connect(WorldMap.toggle)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.M then
		WorldMap.toggle()
	end
end)

-- the Cartographer and the Adventurers' Guild open the map
OpenShopRemote.OnClientEvent:Connect(function(key: string)
	local shop = Shops.Catalog[key]
	if shop and shop.map then
		WorldMap.open(if shop.map == "quests" then "quest" else nil)
	end
end)

return WorldMap
