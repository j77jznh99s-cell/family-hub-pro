--!strict
-- Builds the whole Sproutling Isles map out of primitive parts.
--
-- It only creates geometry and named anchor parts; gameplay scripts find the anchors
-- by name and attach prompts/behaviour at runtime. Because it touches no services it can run:
--   * at server start (if Workspace.Map is missing),
--   * from the Studio command bar to bake the map into the place:
--       require(game.ReplicatedStorage.Shared.MapBuilder).Build(workspace)
--   * offline under Lune (see tools/bake-map.luau), which passes its own Roblox API table.
--
-- Layout (studs, +Z = south):
--   Bloom Plaza at origin, Wishing Pond at the north tip (z = -300),
--   8 plots in two columns (x = +-155), Pollen Parade belt south of the plaza (z = 85),
--   Sky Garden floating over the south tip (y = 90, z = 300).

local MapBuilder = {}

-- Roblox API aliases, overridable for Lune.
local Instance = Instance
local Vector3 = Vector3
local CFrame = CFrame
local Color3 = Color3
local Enum = Enum
local UDim2 = UDim2

function MapBuilder.useApi(api: any)
	Instance = api.Instance
	Vector3 = api.Vector3
	CFrame = api.CFrame
	Color3 = api.Color3
	Enum = api.Enum
	UDim2 = api.UDim2
end

MapBuilder.PlotSize = 100
MapBuilder.PlotColors = {
	{ "Red", 235, 80, 80 },
	{ "Orange", 245, 150, 60 },
	{ "Yellow", 240, 210, 70 },
	{ "Green", 90, 200, 100 },
	{ "Teal", 60, 200, 190 },
	{ "Blue", 80, 140, 240 },
	{ "Purple", 160, 100, 230 },
	{ "Pink", 240, 120, 190 },
}

-- Returns plot centre X, centre Z and "inward" direction (+1 = gate faces +X).
function MapBuilder.plotPlacement(index: number): (number, number, number)
	local rows = { -165, -55, 55, 165 }
	if index <= 4 then
		return -155, rows[index], 1
	end
	return 155, rows[index - 4], -1
end

-- Soil tile positions in plot-local (u = towards gate, v = along the avenue).
function MapBuilder.soilLocal(tile: number): (number, number)
	local row = (tile - 1) // 4 -- 0..2
	local col = (tile - 1) % 4 -- 0..3
	return 40 - row * 16, -24 + col * 16
end

-- Pads 1-8 are base, 9-12 unlock with the Big Greenhouse pass.
local padSlots = {
	{ -20, -40 }, { -20, -24 }, { -20, -8 }, { -20, 8 }, { -20, 24 }, { -20, 40 },
	{ -38, -8 }, { -38, 8 },
	{ -38, -40 }, { -38, -24 }, { -38, 24 }, { -38, 40 },
}
function MapBuilder.padLocal(pad: number): (number, number)
	local slot = padSlots[pad]
	return slot[1], slot[2]
end

----------------------------------------------------------------------------------------------
-- helpers

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: any?, props: { [string]: any }?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- Vertical cylinder (Roblox cylinders run along X, so roll 90 degrees).
local function cylinder(parent: Instance, name: string, height: number, diameter: number, x: number, y: number, z: number, color: Color3, material: any?): BasePart
	local p = part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent: Instance, name: string, diameter: number, x: number, y: number, z: number, color: Color3, material: any?): BasePart
	local p = part(parent, name, Vector3.new(diameter, diameter, diameter), at(x, y, z), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function label(adornee: BasePart, text: string, offsetY: number, size: UDim2?, color: Color3?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = size or UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Parent = adornee
	local text_ = Instance.new("TextLabel")
	text_.Name = "Text"
	text_.BackgroundTransparency = 1
	text_.Size = UDim2.fromScale(1, 1)
	text_.Font = Enum.Font.FredokaOne
	text_.TextScaled = true
	text_.Text = text
	text_.TextColor3 = color or rgb(255, 255, 255)
	text_.TextStrokeTransparency = 0.2
	text_.Parent = gui
	return text_
end

-- Cheap deterministic noise so the map is identical every build.
local function hash(n: number): number
	local s = math.sin(n * 12.9898) * 43758.5453
	return s - math.floor(s)
end

local function tree(parent: Instance, x: number, z: number, scale: number, seed: number)
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = parent
	local h = 10 * scale
	cylinder(model, "Trunk", h, 2.2 * scale, x, h / 2, z, rgb(110, 80, 55), Enum.Material.Wood)
	local leafColor = rgb(70 + math.floor(hash(seed) * 40), 150 + math.floor(hash(seed + 1) * 50), 70)
	ball(model, "Canopy", 9 * scale, x, h + 2 * scale, z, leafColor, Enum.Material.Grass)
	ball(model, "Canopy2", 6 * scale, x + 2.5 * scale, h + 4.5 * scale, z - 1.5 * scale, leafColor, Enum.Material.Grass)
end

local function lamp(parent: Instance, x: number, z: number)
	local model = Instance.new("Model")
	model.Name = "Lamp"
	model.Parent = parent
	cylinder(model, "Post", 12, 0.8, x, 6, z, rgb(60, 60, 70), Enum.Material.Metal)
	local bulb = ball(model, "Bulb", 2.2, x, 12.5, z, rgb(255, 235, 170), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 20
	light.Brightness = 1.2
	light.Color = rgb(255, 225, 160)
	light.Parent = bulb
end

local function flowerBed(parent: Instance, x: number, z: number, w: number, d: number, seed: number)
	part(parent, "FlowerBed", Vector3.new(w, 1.2, d), at(x, 0.6, z), rgb(100, 70, 50), Enum.Material.Ground)
	local colors = { rgb(255, 120, 150), rgb(255, 220, 90), rgb(160, 120, 255), rgb(255, 255, 255), rgb(255, 140, 70) }
	local count = math.floor(w * d / 10)
	for i = 1, count do
		local fx = x + (hash(seed * 31 + i) - 0.5) * (w - 1.5)
		local fz = z + (hash(seed * 17 + i * 3) - 0.5) * (d - 1.5)
		local color = colors[(i + seed) % #colors + 1]
		cylinder(parent, "Stem", 1.6, 0.25, fx, 2, fz, rgb(60, 140, 60))
		ball(parent, "Bloom", 1.1, fx, 2.9, fz, color, Enum.Material.SmoothPlastic)
	end
end

local function stall(parent: Instance, name: string, x: number, z: number, facing: Vector3, width: number, awning: Color3): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local base = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + facing)
	local function rel(u: number, y: number, v: number): CFrame
		-- u = right, v = forward (towards customers)
		return base * CFrame.new(u, y, -v)
	end
	part(model, "Counter", Vector3.new(width, 3.5, 3), rel(0, 1.75, 0), rgb(170, 120, 80), Enum.Material.WoodPlanks)
	part(model, "Back", Vector3.new(width, 12, 1), rel(0, 6, -6), rgb(240, 230, 210), Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		part(model, "Post", Vector3.new(0.8, 12, 0.8), rel(side * (width / 2 - 0.4), 6, 1.2), rgb(150, 100, 70), Enum.Material.Wood)
	end
	local stripes = math.max(2, math.floor(width / 4))
	for i = 1, stripes do
		local u = -width / 2 + (i - 0.5) * (width / stripes)
		local color = if i % 2 == 0 then rgb(255, 255, 255) else awning
		part(model, "Awning", Vector3.new(width / stripes, 0.6, 9), rel(u, 12.5, -2) * CFrame.Angles(math.rad(-12), 0, 0), color, Enum.Material.Fabric)
	end
	local sign = part(model, "Sign", Vector3.new(width * 0.6, 3, 0.6), rel(0, 15.5, -2), awning, Enum.Material.SmoothPlastic)
	label(sign, name, 0, UDim2.fromOffset(300, 60))
	return model
end

----------------------------------------------------------------------------------------------
-- areas

local function buildIsland(map: Instance)
	local island = Instance.new("Folder")
	island.Name = "Island"
	island.Parent = map

	part(island, "Sea", Vector3.new(1400, 2, 1600), at(0, -3, -30), rgb(60, 150, 210), Enum.Material.Glass, { Transparency = 0.25, CanCollide = false })
	part(island, "Seabed", Vector3.new(1400, 2, 1600), at(0, -10, -30), rgb(200, 185, 140), Enum.Material.Sand)
	part(island, "Sand", Vector3.new(520, 2, 760), at(0, -1.4, -30), rgb(235, 215, 160), Enum.Material.Sand)
	part(island, "Grass", Vector3.new(490, 2, 730), at(0, -1, -30), rgb(110, 180, 90), Enum.Material.Grass)
	-- the avenue: a stone path running the full length of the island
	part(island, "Avenue", Vector3.new(44, 0.2, 700), at(0, 0.1, -30), rgb(215, 200, 170), Enum.Material.Cobblestone)

	for i, z in { -250, -200, -130, -90, -20, 120, 160, 200 } do
		lamp(island, -24, z)
		lamp(island, 24, z + 20)
		flowerBed(island, -38, z, 8, 16, i)
		flowerBed(island, 38, z + 20, 8, 16, i + 20)
	end

	-- trees around the shore, skipping the pond and parade areas
	local n = 0
	for i = 0, 71 do
		local angle = (i / 72) * math.pi * 2
		local rx, rz = 225 + hash(i) * 10, 355 + hash(i + 5) * 10
		local x, z = math.cos(angle) * rx, math.sin(angle) * rz - 30
		local inPlotBand = math.abs(x) > 90 and math.abs(x) < 222 and z > -230 and z < 230
		if (math.abs(x) > 60 or (z > -250 and z < 200)) and not inPlotBand then
			n += 1
			tree(island, x, z, 0.9 + hash(i + 9) * 0.6, i)
		end
	end
	return n
end

local function buildPlaza(map: Instance)
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = map

	local floor = cylinder(plaza, "Floor", 0.6, 130, 0, 0.3, 0, rgb(225, 215, 195), Enum.Material.Slate)
	floor.Name = "Floor"
	cylinder(plaza, "Ring", 0.7, 126, 0, 0.35, 0, rgb(200, 185, 160), Enum.Material.Slate)
	cylinder(plaza, "Inner", 0.8, 60, 0, 0.4, 0, rgb(235, 225, 205), Enum.Material.Slate)

	-- Dewdrop Fountain
	cylinder(plaza, "FountainBase", 3, 30, 0, 1.5, 0, rgb(190, 190, 200), Enum.Material.Marble)
	cylinder(plaza, "FountainWater", 0.6, 26, 0, 3.1, 0, rgb(90, 180, 240), Enum.Material.Glass).Transparency = 0.3
	cylinder(plaza, "FountainPillar", 12, 4, 0, 7, 0, rgb(200, 200, 210), Enum.Material.Marble)
	local drop = ball(plaza, "Dewdrop", 6, 0, 16, 0, rgb(120, 220, 255), Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Range = 30
	glow.Color = rgb(120, 220, 255)
	glow.Parent = drop

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = at(0, 0.9, 24)
	spawn.Color = rgb(235, 225, 205)
	spawn.Material = Enum.Material.Slate
	spawn.Duration = 0
	spawn.Parent = plaza
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- Seed Shop: long market stall on the north edge with one kiosk per shop species
	local shop = stall(plaza, "Seed Shop", 0, -52, Vector3.new(0, 0, 1), 84, rgb(90, 190, 110))
	local kiosks = Instance.new("Folder")
	kiosks.Name = "Kiosks"
	kiosks.Parent = shop
	for i = 1, 11 do
		local x = -40 + (i - 0.5) * (80 / 11)
		local k = part(kiosks, "Kiosk" .. i, Vector3.new(5, 1, 2.4), at(x, 4, -51), rgb(255, 250, 235), Enum.Material.SmoothPlastic)
		k:SetAttribute("Slot", i)
	end
	local timer = part(shop, "RestockBoard", Vector3.new(16, 4, 0.5), at(0, 19.5, -54), rgb(40, 60, 45), Enum.Material.SmoothPlastic)
	label(timer, "Restock in 5m 00s", 0, UDim2.fromOffset(260, 40), rgb(200, 255, 200))

	local sell = stall(plaza, "Sell Stand", 52, 0, Vector3.new(-1, 0, 0), 18, rgb(240, 180, 60))
	part(sell, "Anchor", Vector3.new(4, 1, 4), at(49, 4, 0), rgb(255, 220, 120), Enum.Material.Neon)

	local rebirth = Instance.new("Model")
	rebirth.Name = "Rebirth Shrine"
	rebirth.Parent = plaza
	cylinder(rebirth, "Step", 1, 20, -50, 0.5, 0, rgb(210, 200, 230), Enum.Material.Marble)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		cylinder(rebirth, "Pillar", 12, 1.5, -50 + math.cos(a) * 8, 6.5, math.sin(a) * 8, rgb(230, 225, 245), Enum.Material.Marble)
	end
	local orb = ball(rebirth, "Anchor", 5, -50, 6, 0, rgb(200, 150, 255), Enum.Material.Neon)
	label(orb, "Rebirth Shrine", 6)

	local daily = stall(plaza, "Daily Gift", -32, 44, Vector3.new(0.6, 0, -0.8).Unit, 14, rgb(240, 110, 150))
	part(daily, "Anchor", Vector3.new(3, 3, 3), at(-31, 5, 42.5), rgb(255, 120, 170), Enum.Material.Neon)

	local supply = stall(plaza, "Sprout Supply", 32, 44, Vector3.new(-0.6, 0, -0.8).Unit, 14, rgb(90, 160, 255))
	part(supply, "Anchor", Vector3.new(3, 3, 3), at(31, 5, 42.5), rgb(120, 190, 255), Enum.Material.Neon)

	for i = 0, 7 do
		local a = (i + 0.5) / 8 * math.pi * 2
		lamp(plaza, math.cos(a) * 60, math.sin(a) * 60)
	end
end

local function buildPlot(plots: Instance, index: number)
	local cx, cz, d = MapBuilder.plotPlacement(index)
	local colorInfo = MapBuilder.PlotColors[index]
	local color = rgb(colorInfo[2], colorInfo[3], colorInfo[4])
	local half = MapBuilder.PlotSize / 2

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("Index", index)
	plot:SetAttribute("ColorName", colorInfo[1])
	plot:SetAttribute("Inward", d)
	plot.Parent = plots

	local function w(u: number, y: number, v: number): Vector3
		return Vector3.new(cx + d * u, y, cz + v)
	end
	local facing = Vector3.new(d, 0, 0)

	local floor = part(plot, "Floor", Vector3.new(MapBuilder.PlotSize, 1, MapBuilder.PlotSize), at(cx, 0.5, cz), rgb(125, 190, 100), Enum.Material.Grass)
	plot.PrimaryPart = floor
	-- coloured border so plots are recognisable from afar
	for _, e in { { 0, -half }, { 0, half } } do
		part(plot, "Border", Vector3.new(MapBuilder.PlotSize, 1.2, 2), CFrame.new(w(e[1], 0.6, e[2])), color, Enum.Material.SmoothPlastic)
	end
	part(plot, "Border", Vector3.new(2, 1.2, MapBuilder.PlotSize), CFrame.new(w(-half, 0.6, 0)), color, Enum.Material.SmoothPlastic)

	-- hedges on the three non-gate sides
	part(plot, "Hedge", Vector3.new(MapBuilder.PlotSize, 8, 3), CFrame.new(w(0, 4, -half - 1.5)), rgb(70, 140, 60), Enum.Material.Grass)
	part(plot, "Hedge", Vector3.new(MapBuilder.PlotSize, 8, 3), CFrame.new(w(0, 4, half + 1.5)), rgb(70, 140, 60), Enum.Material.Grass)
	part(plot, "Hedge", Vector3.new(3, 8, MapBuilder.PlotSize + 6), CFrame.new(w(-half - 1.5, 4, 0)), rgb(70, 140, 60), Enum.Material.Grass)

	-- soil tiles
	local soil = Instance.new("Folder")
	soil.Name = "Soil"
	soil.Parent = plot
	for tile = 1, 12 do
		local u, v = MapBuilder.soilLocal(tile)
		local s = part(soil, "Soil" .. tile, Vector3.new(12, 1.2, 12), CFrame.new(w(u, 1.1, v)), rgb(110, 75, 50), Enum.Material.Ground)
		s:SetAttribute("Tile", tile)
	end

	-- greenhouse over the pad area
	local gh = Instance.new("Model")
	gh.Name = "Greenhouse"
	gh.Parent = plot
	part(gh, "GreenhouseFloor", Vector3.new(34, 0.4, 98), CFrame.new(w(-30, 1.2, 0)), rgb(235, 230, 220), Enum.Material.Marble)
	for _, v in { -48, -16, 16, 48 } do
		for _, u in { -47, -13 } do
			part(gh, "Frame", Vector3.new(1, 16, 1), CFrame.new(w(u, 9, v)), rgb(245, 245, 245), Enum.Material.Metal)
		end
	end
	part(gh, "Roof", Vector3.new(36, 0.6, 100), CFrame.new(w(-30, 17.3, 0)), rgb(200, 240, 255), Enum.Material.Glass, { Transparency = 0.6 })
	part(gh, "RoofTrim", Vector3.new(36, 1, 2), CFrame.new(w(-30, 17.8, 0)), color, Enum.Material.SmoothPlastic)

	local pads = Instance.new("Folder")
	pads.Name = "Pads"
	pads.Parent = plot
	for pad = 1, 12 do
		local u, v = MapBuilder.padLocal(pad)
		local p = cylinder(pads, "Pad" .. pad, 1, 9, 0, 0, 0, rgb(250, 250, 250), Enum.Material.Marble)
		p.CFrame = CFrame.new(w(u, 1.9, v)) * CFrame.Angles(0, 0, math.rad(90))
		p.Name = "Pad" .. pad
		p:SetAttribute("Pad", pad)
		p:SetAttribute("Bonus", pad > 8)
		if pad > 8 then
			p.Transparency = 0.7
		end
		local rim = cylinder(pads, "Rim" .. pad, 0.4, 9.6, 0, 0, 0, color, Enum.Material.Neon)
		rim.CFrame = CFrame.new(w(u, 1.5, v)) * CFrame.Angles(0, 0, math.rad(90))
	end

	-- gate: two pillars, a laser curtain (visible when locked) and the lock button
	local gate = Instance.new("Model")
	gate.Name = "Gate"
	gate.Parent = plot
	for _, v in { -half - 1.5, half + 1.5 } do
		part(gate, "Pillar", Vector3.new(4, 14, 4), CFrame.new(w(half, 7, v)), color, Enum.Material.SmoothPlastic)
		ball(gate, "PillarCap", 4.5, w(half, 14.5, v).X, 14.5, v + cz, color, Enum.Material.Neon)
	end
	part(gate, "Laser", Vector3.new(0.6, 10, MapBuilder.PlotSize), CFrame.new(w(half, 5, 0)), rgb(255, 60, 60), Enum.Material.ForceField, { Transparency = 1, CanCollide = false, CanQuery = false })
	local button = part(gate, "LockButton", Vector3.new(3, 3, 3), CFrame.lookAt(w(half - 5, 2.5, -half + 6), w(half - 5, 2.5, -half + 6) + facing), rgb(255, 80, 80), Enum.Material.Neon)
	part(gate, "LockPost", Vector3.new(2, 1, 2), CFrame.new(w(half - 5, 0.9, -half + 6)), rgb(80, 80, 90), Enum.Material.Metal)
	label(button, "LOCK", 3, UDim2.fromOffset(160, 40))

	-- owner sign over the gate
	local sign = part(plot, "Sign", Vector3.new(1, 5, 30), CFrame.new(w(half + 2, 16, 0)), rgb(250, 245, 230), Enum.Material.WoodPlanks)
	label(sign, colorInfo[1] .. " plot - unclaimed", 4, UDim2.fromOffset(360, 70), color)

	local spawnPoint = part(plot, "SpawnPoint", Vector3.new(4, 1, 4), CFrame.lookAt(w(-4, 3.5, 0), w(-4, 3.5, 0) + facing), color, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	spawnPoint:SetAttribute("Spawn", true)
end

local function buildParade(map: Instance)
	local parade = Instance.new("Model")
	parade.Name = "Parade"
	parade.Parent = map
	-- low belt with walk-through rails so the avenue stays passable
	part(parade, "Belt", Vector3.new(150, 0.8, 10), at(0, 0.5, 85), rgb(60, 60, 70), Enum.Material.DiamondPlate)
	part(parade, "RailNorth", Vector3.new(150, 0.8, 1), at(0, 1.2, 79.5), rgb(255, 210, 90), Enum.Material.SmoothPlastic, { CanCollide = false })
	part(parade, "RailSouth", Vector3.new(150, 0.8, 1), at(0, 1.2, 90.5), rgb(255, 210, 90), Enum.Material.SmoothPlastic, { CanCollide = false })
	part(parade, "Start", Vector3.new(2, 2, 2), at(-72, 2.7, 85), rgb(255, 255, 255), nil, { Transparency = 1, CanCollide = false })
	part(parade, "Finish", Vector3.new(2, 2, 2), at(72, 2.7, 85), rgb(255, 255, 255), nil, { Transparency = 1, CanCollide = false })
	for _, x in { -78, 78 } do
		local arch = part(parade, "Arch", Vector3.new(4, 14, 16), at(x, 7, 85), rgb(250, 170, 60), Enum.Material.SmoothPlastic)
		if x < 0 then
			label(arch, "Pollen Parade", 9, UDim2.fromOffset(300, 70), rgb(255, 240, 150))
		end
	end
	part(parade, "Items", Vector3.new(1, 1, 1), at(0, -20, 85), rgb(0, 0, 0), nil, { Transparency = 1, CanCollide = false }).Name = "ItemsAnchor"
	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = parade
end

local function buildPond(map: Instance)
	local pond = Instance.new("Model")
	pond.Name = "Pond"
	pond.Parent = map
	cylinder(pond, "Rim", 1.2, 98, 0, 0.2, -300, rgb(170, 160, 150), Enum.Material.Slate)
	local water = cylinder(pond, "Water", 1.4, 90, 0, 0.35, -300, rgb(70, 170, 200), Enum.Material.Glass)
	water.Transparency = 0.2
	water.CanCollide = false
	cylinder(pond, "PondBed", 1, 90, 0, -2, -300, rgb(60, 110, 110), Enum.Material.Mud)
	part(pond, "Dock", Vector3.new(12, 1, 44), at(0, 1.4, -262), rgb(160, 115, 75), Enum.Material.WoodPlanks)
	part(pond, "DockEnd", Vector3.new(34, 1, 10), at(0, 1.4, -286), rgb(160, 115, 75), Enum.Material.WoodPlanks)
	for i, x in { -14, -5, 5, 14 } do
		local spot = part(pond, "CastSpot" .. i, Vector3.new(3, 0.3, 3), at(x, 2, -289), rgb(120, 220, 255), Enum.Material.Neon)
		spot:SetAttribute("CastSpot", i)
	end
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2
		local r = 22 + hash(i) * 16
		local lily = cylinder(pond, "LilyPad", 0.3, 4 + hash(i + 3) * 3, math.cos(a) * r, 1.2, -300 + math.sin(a) * r, rgb(90, 170, 80), Enum.Material.Grass)
		lily.CanCollide = false
	end
	for _, x in { -18, 18 } do
		lamp(pond, x, -280)
	end
	local sign = part(pond, "Sign", Vector3.new(10, 4, 1), at(0, 4, -238), rgb(160, 115, 75), Enum.Material.WoodPlanks)
	label(sign, "Wishing Pond", 3, UDim2.fromOffset(260, 60), rgb(160, 230, 255))
end

local function buildSkyGarden(map: Instance)
	local sky = Instance.new("Model")
	sky.Name = "SkyGarden"
	sky.Parent = map
	local pad = cylinder(sky, "LaunchPad", 1, 14, 0, 0.6, 240, rgb(170, 120, 255), Enum.Material.Neon)
	label(pad, "Sky Garden (Rebirth 1+)", 5, UDim2.fromOffset(300, 60), rgb(220, 200, 255))
	cylinder(sky, "Island", 8, 80, 0, 88, 300, rgb(110, 180, 90), Enum.Material.Grass)
	cylinder(sky, "Underside", 10, 60, 0, 80, 300, rgb(130, 110, 90), Enum.Material.Rock)
	part(sky, "Landing", Vector3.new(8, 1, 8), at(0, 92.5, 275), rgb(220, 200, 255), Enum.Material.Neon, { Transparency = 0.5 })
	local well = cylinder(sky, "WellBase", 4, 12, 0, 94, 305, rgb(200, 200, 215), Enum.Material.Marble)
	well.Name = "WellBase"
	local wellWater = cylinder(sky, "SkyWell", 0.5, 10, 0, 96.1, 305, rgb(180, 140, 255), Enum.Material.Neon)
	label(wellWater, "Sky Well", 5)
	part(sky, "ReturnPad", Vector3.new(8, 1, 8), at(0, 92.5, 330), rgb(255, 255, 255), Enum.Material.Neon, { Transparency = 0.3 })
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		tree(sky, math.cos(a) * 30, 300 + math.sin(a) * 30, 0.8, 100 + i)
	end
end

----------------------------------------------------------------------------------------------

function MapBuilder.Build(parent: Instance): Instance
	local existing = parent:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"

	buildIsland(map)
	buildPlaza(map)
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = map
	for index = 1, 8 do
		buildPlot(plots, index)
	end
	buildParade(map)
	buildPond(map)
	buildSkyGarden(map)

	map.Parent = parent
	return map
end

return MapBuilder
