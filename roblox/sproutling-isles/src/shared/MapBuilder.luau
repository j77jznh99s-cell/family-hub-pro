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
--   Bloom Plaza at origin on the garden island (280 wide), Wishing Pond at the north tip (z = -300),
--   the 8 garden houses in Greenhollow Gardens, a farm village off the city's Grand Way
--   (MapBuilder.Garden, Landscape site "greenhollow"),
--   Pollen Parade belt south of the plaza (z = 85),
--   Sky Garden floating over the south tip (y = 90, z = 300).
--   Scenery (cottages, towers, windmill, festoon lights) sits in the strips between the avenue
--   and the plots (|x| 60-100) and at the island's north/south ends; floating islets, clouds and
--   waterfalls are out over the sea. None of it is gameplay: it lives in Map.Scenery.

local MapBuilder = {}

-- Roblox API aliases, overridable for Lune.
local Instance = Instance
local Vector3 = Vector3
local CFrame = CFrame
local Color3 = Color3
local Enum = Enum
local UDim2 = UDim2
local NumberRange = NumberRange
local NumberSequence = NumberSequence
local NumberSequenceKeypoint = NumberSequenceKeypoint
local ColorSequence = ColorSequence
local Vector2 = Vector2

function MapBuilder.useApi(api: any)
	Instance = api.Instance
	Vector3 = api.Vector3
	CFrame = api.CFrame
	Color3 = api.Color3
	Enum = api.Enum
	UDim2 = api.UDim2
	NumberRange = api.NumberRange
	NumberSequence = api.NumberSequence
	NumberSequenceKeypoint = api.NumberSequenceKeypoint
	ColorSequence = api.ColorSequence
	Vector2 = api.Vector2
end

-- Shared.Landscape (the terrain hills). Required lazily in Roblox; Lune passes it in.
local Landscape: any = nil
function MapBuilder.useLandscape(module: any)
	Landscape = module
end

-- Shared.CityBuilder (Sproutling City and the airport), same arrangement.
local City: any = nil
function MapBuilder.useCity(module: any)
	City = module
end

-- Shared.WildsBuilder and Shared.Quests (quest camps, homesteads, sky isle content), same arrangement.
local Wilds: any = nil
local QuestData: any = nil
local WaystoneData: any = nil
function MapBuilder.useWilds(module: any, quests: any, waystones: any?)
	Wilds = module
	QuestData = quests
	WaystoneData = waystones
end

-- Shared.DungeonBuilder (The Hollow Crypt), same arrangement.
local Dungeon: any = nil
function MapBuilder.useDungeon(module: any)
	Dungeon = module
end

MapBuilder.PlotSize = 54 -- inside of a garden house (walls stand just outside this square)
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
-- Greenhollow Gardens: the village green at the top of the lane, and the eight garden houses spread
-- round the lane (x = Garden.laneX), each on its own levelled pad with its doors facing the branch
-- path that meets the lane at jz. Same numbers as Shared/Landscape.GardenPlots (checked at bake).
MapBuilder.Garden = { x = -170, z = 1253, laneX = -170 }
MapBuilder.GardenPlots = {
	{ x = -365, z = 1330, jz = 1305 },
	{ x = -410, z = 1460, jz = 1440 },
	{ x = -320, z = 1565, jz = 1585 },
	{ x = -262, z = 1712, jz = 1690 },
	{ x = -82, z = 1338, jz = 1320 },
	{ x = -40, z = 1440, jz = 1455 },
	{ x = -110, z = 1525, jz = 1530 },
	{ x = -50, z = 1700, jz = 1680 },
}

-- Returns plot centre X, centre Z and "inward" direction (+1: the house is west of the lane and
-- its doors face roughly +X; -1: east of the lane, doors face roughly -X).
function MapBuilder.plotPlacement(index: number): (number, number, number)
	local g = MapBuilder.GardenPlots[index]
	return g.x, g.z, if g.x < MapBuilder.Garden.laneX then 1 else -1
end

-- The house's own axes: `facing` points out of its doors towards where its branch path meets the
-- lane, `along` runs across the doorway. Plot-local (u, v) = cx, cz + facing * u + along * v
-- (houses east of the lane are mirror images, as the old plot columns were).
function MapBuilder.plotAxes(index: number): (Vector3, Vector3)
	local g = MapBuilder.GardenPlots[index]
	local _, _, d = MapBuilder.plotPlacement(index)
	local f = Vector3.new(MapBuilder.Garden.laneX - g.x, 0, g.jz - g.z).Unit
	local along = if d > 0 then Vector3.new(-f.Z, 0, f.X) else Vector3.new(f.Z, 0, -f.X)
	return f, along
end

-- The house's rotation: its X axis along the u line (out of the doors for d = 1), Z along v.
function MapBuilder.plotRot(index: number): CFrame
	local facing, along = MapBuilder.plotAxes(index)
	local _, _, d = MapBuilder.plotPlacement(index)
	return CFrame.fromMatrix(Vector3.zero, facing * d, Vector3.new(0, 1, 0), along)
end

-- Soil tile positions in plot-local (u = towards gate, v = along the avenue).
function MapBuilder.soilLocal(tile: number): (number, number)
	local row = (tile - 1) // 4 -- 0..2
	local col = (tile - 1) % 4 -- 0..3
	return 19 - row * 8.5, -14.4 + col * 9.6
end

-- Pads 1-8 are base, 9-12 unlock with the Big Greenhouse pass.
local padSlots = {
	{ -10.5, -20.5 }, { -10.5, -12.3 }, { -10.5, -4.1 }, { -10.5, 4.1 }, { -10.5, 12.3 }, { -10.5, 20.5 },
	{ -20, -4.1 }, { -20, 4.1 },
	{ -20, -20.5 }, { -20, -12.3 }, { -20, 12.3 }, { -20, 20.5 },
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

-- Purely visual part: no collisions, raycasts, touches or shadows.
local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- NumberSequence that goes from a to b over a particle's life.
local function fade(a: number, b: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

-- Particles use Roblox's built-in default texture, so no uploaded assets are needed.
local function emitter(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function glowLight(parent: Instance, range: number, brightness: number, color: Color3)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = color
	light.Parent = parent
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

local function tree(parent: Instance, x: number, z: number, scale: number, seed: number, y0: number?)
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = parent
	local base = y0 or 0
	local h = 10 * scale
	cylinder(model, "Trunk", h, 2.2 * scale, x, base + h / 2, z, rgb(110, 80, 55), Enum.Material.Wood)
	-- Mostly bright greens, with blossom, autumn and lilac trees mixed in for colour.
	local pick = hash(seed + 0.37)
	local leafColor = if pick < 0.16
		then rgb(255, 165 + math.floor(hash(seed + 2) * 30), 200)
		elseif pick < 0.27 then rgb(245, 145 + math.floor(hash(seed + 2) * 50), 60)
		elseif pick < 0.34 then rgb(185, 150, 245)
		else rgb(60 + math.floor(hash(seed) * 40), 165 + math.floor(hash(seed + 1) * 50), 70)
	ball(model, "Canopy", 9 * scale, x, base + h + 2 * scale, z, leafColor, Enum.Material.Grass)
	ball(model, "Canopy2", 6 * scale, x + 2.5 * scale, base + h + 4.5 * scale, z - 1.5 * scale, leafColor, Enum.Material.Grass)
	-- two more puffs so the crown reads round and fluffy instead of a single ball
	ball(model, "Canopy3", 5.6 * scale, x - 3 * scale, base + h + 3.2 * scale, z + 1.4 * scale, leafColor, Enum.Material.Grass)
	ball(model, "Canopy3", 4.6 * scale, x + 0.6 * scale, base + h + 1 * scale, z + 3.2 * scale, leafColor, Enum.Material.Grass)
end

-- WedgePart: tall edge at the back (+Z), slope facing the front (-Z, the LookVector).
local function wedge(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: any?): BasePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.CFrame = cframe
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

-- Low-poly cone (pine tiers, tower roofs): wedge slices around a centre, apex at y + height.
local function cone(parent: Instance, name: string, x: number, y: number, z: number, radius: number, height: number, color: Color3, material: any?, sides: number?)
	local n = sides or 6
	local width = 2 * radius * math.tan(math.pi / n) * 1.06
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = Vector3.new(x, y + height / 2, z) + dir * (radius / 2)
		wedge(parent, name, Vector3.new(width, height, radius), CFrame.lookAt(pos, pos + dir), color, material)
	end
end

-- Low-poly pine: a short trunk and three stacked cones.
local function pine(parent: Instance, x: number, z: number, scale: number, seed: number, y0: number?)
	local model = Instance.new("Model")
	model.Name = "Pine"
	model.Parent = parent
	local base = y0 or 0
	cylinder(model, "Trunk", 5 * scale, 1.6 * scale, x, base + 2.5 * scale, z, rgb(105, 75, 55), Enum.Material.Wood)
	local g = math.floor(hash(seed + 0.3) * 30)
	local color = rgb(45 + g, 135 + g, 75 + math.floor(g / 2))
	for i = 1, 3 do
		local r = (6 - i * 1.5) * scale
		cone(model, "Needles", x, base + (2.6 + (i - 1) * 4) * scale, z, r, 7 * scale, color, Enum.Material.Grass, 5)
	end
end

-- A lighter pine for the far forests: a trunk and two four-sided tiers.
local function lightPine(parent: Instance, x: number, z: number, scale: number, seed: number, y0: number?)
	local model = Instance.new("Model")
	model.Name = "Pine"
	model.Parent = parent
	local base = y0 or 0
	cylinder(model, "Trunk", 5 * scale, 1.6 * scale, x, base + 2.5 * scale, z, rgb(105, 75, 55), Enum.Material.Wood)
	local g = math.floor(hash(seed + 0.3) * 30)
	local color = rgb(40 + g, 120 + g, 70 + math.floor(g / 2))
	cone(model, "Needles", x, base + 2.6 * scale, z, 5 * scale, 9 * scale, color, Enum.Material.Grass, 4)
	cone(model, "Needles", x, base + 8 * scale, z, 3.4 * scale, 7 * scale, color, Enum.Material.Grass, 4)
end

-- Moves every part under container up by dy (for groups built at y = 0 and placed on a hill).
local function lift(container: Instance, dy: number)
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame + Vector3.new(0, dy, 0)
		end
	end
end

local function lamp(parent: Instance, x: number, z: number)
	local model = Instance.new("Model")
	model.Name = "Lamp"
	model.Parent = parent
	cylinder(model, "LampBase", 1.2, 1.8, x, 0.6, z, rgb(60, 60, 70), Enum.Material.Metal)
	cylinder(model, "Post", 12, 0.8, x, 6, z, rgb(60, 60, 70), Enum.Material.Metal)
	cylinder(model, "LampCollar", 0.5, 1.6, x, 11.4, z, rgb(60, 60, 70), Enum.Material.Metal)
	local bulb = ball(model, "Bulb", 2.2, x, 12.5, z, rgb(255, 235, 170), Enum.Material.Neon)
	cone(model, "LampCap", x, 13.4, z, 1.5, 1.6, rgb(60, 60, 70), Enum.Material.Metal, 6)
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
		local post = part(model, "Post", Vector3.new(12, 1, 1), rel(side * (width / 2 - 0.4), 6, 1.2) * CFrame.Angles(0, 0, math.rad(90)), rgb(150, 100, 70), Enum.Material.Wood)
		post.Shape = Enum.PartType.Cylinder
		ball(model, "PostCap", 1.4, 0, 0, 0, rgb(150, 100, 70), Enum.Material.Wood).CFrame = rel(side * (width / 2 - 0.4), 12.2, 1.2)
	end
	-- a striped awning with a scalloped front edge
	local stripes = math.max(2, math.floor(width / 4))
	for i = 1, stripes do
		local u = -width / 2 + (i - 0.5) * (width / stripes)
		local color = if i % 2 == 0 then rgb(255, 255, 255) else awning
		part(model, "Awning", Vector3.new(width / stripes, 0.6, 9), rel(u, 12.5, -2) * CFrame.Angles(math.rad(-12), 0, 0), color, Enum.Material.Fabric)
		local sw = width / stripes / 2
		for _, k in { -1, 1 } do
			local scallop = part(model, "Scallop", Vector3.new(0.3, sw, sw), rel(u + k * sw / 2, 11.3, 2.45) * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Fabric)
			scallop.Shape = Enum.PartType.Cylinder
			scallop.CanCollide = false
		end
	end
	local sign = part(model, "Sign", Vector3.new(width * 0.6, 3, 0.6), rel(0, 15.5, -2), awning, Enum.Material.SmoothPlastic)
	label(sign, name, 0, UDim2.fromOffset(300, 60))
	return model
end

----------------------------------------------------------------------------------------------
-- areas

-- Hollow Harvest: 14 marker points for Wisp Lanterns to spawn at (EventService picks 10 of them
-- at random each Fog). Placed along the avenue north of the Plaza (towards the Pond) and south of
-- the Parade (towards the Sky Garden's ground footprint), well clear of the Plaza's ~65-stud
-- radius, the Pond (centred z = -300), the Parade belt (z 79.5-90.5) and the village row
-- (the island's village row sits at |x| = 60-100; these markers stay within |x| <= 12
-- regardless of z). Doubles as a squashed-pumpkin decoration so the avenue looks intentional even
-- outside Fog.
local LANTERN_SPAWN_POINTS = {
	{ -12, -90 }, { 12, -110 }, { -12, -130 }, { 12, -150 }, { -12, -170 }, { 12, -190 }, { -12, -210 },
	{ 12, 100 }, { -12, 130 }, { 12, 160 }, { -12, 190 }, { 12, 220 }, { -12, 250 }, { 12, 280 },
}

local function buildLanternSpawns(island: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "LanternSpawns"
	folder.Parent = island
	for i, xz in LANTERN_SPAWN_POINTS do
		local pumpkin = part(folder, "LanternSpawn" .. i, Vector3.new(2.6, 2, 2.6), at(xz[1], 1.5, xz[2]), rgb(230, 130, 40), Enum.Material.Neon, { Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false })
		pumpkin:SetAttribute("Spot", i)
	end
end

local function buildIsland(map: Instance)
	local island = Instance.new("Folder")
	island.Name = "Island"
	island.Parent = map

	part(island, "Sea", Vector3.new(1400, 2, 1600), at(0, -3, -30), rgb(60, 150, 210), Enum.Material.Glass, { Transparency = 0.25, CanCollide = false })
	part(island, "Seabed", Vector3.new(1400, 2, 1600), at(0, -10, -30), rgb(200, 185, 140), Enum.Material.Sand)
	part(island, "Sand", Vector3.new(276, 2, 760), at(0, -1.4, -30), rgb(235, 215, 160), Enum.Material.Sand)
	part(island, "Grass", Vector3.new(250, 2, 730), at(0, -1, -30), rgb(110, 180, 90), Enum.Material.Grass)
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
		local rx, rz = 112 + hash(i) * 6, 355 + hash(i + 5) * 10
		local x, z = math.cos(angle) * rx, math.sin(angle) * rz - 30
		-- skip the avenue ends, and the village row and shops along the sides
		local nearHouses = math.abs(x) > 60 and ((z > -320 and z < -130) or (z > -110 and z < -80) or (z > 100 and z < 210))
		if (math.abs(x) > 60 or (z > -250 and z < 200)) and not nearHouses then
			n += 1
			if hash(i + 0.71) < 0.3 then
				pine(island, x, z, 0.9 + hash(i + 9) * 0.5, i)
			else
				tree(island, x, z, 0.9 + hash(i + 9) * 0.6, i)
			end
		end
	end

	buildLanternSpawns(island)
	return n
end

-- Two physical boards (Top Income, Rarest Hatch) just north-west of the Rebirth Shrine, in the
-- gap between it and the Seed Shop. LeaderboardService.luau fills in the BillboardGui text and
-- refreshes it periodically; this function only builds the geometry (no Roblox services, so Lune
-- can still bake it offline).
local function buildLeaderboards(plaza: Instance)
	local model = Instance.new("Model")
	model.Name = "Leaderboards"
	model.Parent = plaza

	local x, z = -48, -33
	local facing = Vector3.new(0, 0, 1) -- faces south, back towards the Rebirth Shrine / spawn
	local base = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + facing)
	local function rel(u: number, y: number, v: number): CFrame
		return base * CFrame.new(u, y, -v)
	end

	for _, side in { -1, 1 } do
		part(model, "Post", Vector3.new(0.8, 16, 0.8), rel(side * 13, 8, 0), rgb(90, 75, 60), Enum.Material.Wood)
	end
	local header = part(model, "Header", Vector3.new(26, 3, 0.6), rel(0, 16.5, 0), rgb(90, 190, 110), Enum.Material.SmoothPlastic)
	label(header, "Leaderboards", 0, UDim2.fromOffset(320, 60), rgb(255, 250, 220))

	local function board(name: string, u: number)
		local backing = part(model, name, Vector3.new(11, 13, 0.6), rel(u, 8.5, 0), rgb(60, 50, 45), Enum.Material.WoodPlanks)
		local gui = Instance.new("BillboardGui")
		gui.Name = "Label" -- matches the MapBuilder convention: BillboardGui "Label" > TextLabel "Text"
		gui.Size = UDim2.fromOffset(260, 300)
		gui.StudsOffset = Vector3.new(0, 0, 0.4)
		gui.LightInfluence = 0
		gui.MaxDistance = 100
		gui.Parent = backing
		-- TextLabel is a direct child of the BillboardGui ("Label" > "Text"), matching the
		-- MapBuilder convention the `label()` helper above uses. LeaderboardService.init looks
		-- it up with a non-recursive FindFirstChild, which an earlier version of this code broke
		-- by nesting Text inside an extra Background Frame — background color/transparency live
		-- directly on the TextLabel instead (TextLabel supports both, same as Frame).
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Size = UDim2.fromScale(0.94, 0.94)
		text.Position = UDim2.fromScale(0.03, 0.03)
		text.BackgroundColor3 = rgb(20, 30, 25)
		text.BackgroundTransparency = 0.1
		text.BorderSizePixel = 0
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextYAlignment = Enum.TextYAlignment.Top
		text.TextColor3 = rgb(255, 255, 255)
		text.TextStrokeTransparency = 0.4
		text.TextWrapped = true
		text.Text = "Loading..."
		text.Parent = gui
	end

	board("IncomeBoard", -6)
	board("RarityBoard", 6)
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
	emitter(drop, "Spray", {
		Color = ColorSequence.new(rgb(200, 240, 255)),
		Size = fade(0.6, 0.1),
		Rate = 40,
		Lifetime = NumberRange.new(1.2, 1.8),
		Speed = NumberRange.new(14, 18),
		SpreadAngle = Vector2.new(18, 18),
		Acceleration = Vector3.new(0, -24, 0),
		LightEmission = 0.6,
		Transparency = NumberSequence.new(0.25),
	})

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
	-- the client reads labels in these from anywhere on the map, so they never stream out
	for _, m in { shop, rebirth, supply } do
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
	part(supply, "Anchor", Vector3.new(3, 3, 3), at(31, 5, 42.5), rgb(120, 190, 255), Enum.Material.Neon)

	-- Hollow Harvest Lantern Stall: reuses the Seed Shop kiosk pattern (see EventService.luau, which
	-- adds the ProximityPrompts and BillboardGui price labels at runtime, same as ShopService does
	-- for the Seed Shop kiosks below).
	local lanternStall = stall(plaza, "Lantern Stall", 0, 58, Vector3.new(0, 0, -1), 20, rgb(255, 140, 40))
	local eventKiosks = Instance.new("Folder")
	eventKiosks.Name = "Kiosks"
	eventKiosks.Parent = lanternStall
	for i, slot in { "pumpkit", "gourdgeist", "skin" } do
		local x = -7 + (i - 1) * 7
		local k = part(eventKiosks, "Kiosk" .. i, Vector3.new(5, 1, 2.4), at(x, 4, 57), rgb(255, 250, 235), Enum.Material.SmoothPlastic)
		k:SetAttribute("Slot", slot)
	end

	buildLeaderboards(plaza)

	for i = 0, 7 do
		local a = (i + 0.5) / 8 * math.pi * 2
		lamp(plaza, math.cos(a) * 60, math.sin(a) * 60)
	end
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
	local rim = cylinder(pond, "Rim", 1.2, 98, 0, 0.2, -300, rgb(170, 160, 150), Enum.Material.Slate)
	-- QA m11: Rim is a full disc reaching under the whole pond, not just its edge, and its top
	-- (y 0.8) sits just under the water surface (y 1.05) -- with default CanCollide=true, players
	-- could walk across the entire pond as if it were solid ground barely covered by water.
	-- Fix (game-designer decision, 2026-09-26): CanCollide=false, same as Water below. Anyone who
	-- goes in now sinks to PondBed (top y -1.5, about 2.5 studs under the surface) instead -- a
	-- shallow wade, which fits a fishing pond you're meant to cast into from the Dock, not a floor
	-- you walk across. Not a ring/annulus (the QA note's other option): that needs a part shape
	-- this codebase's helpers don't build, for a purely cosmetic fix.
	rim.CanCollide = false
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
		if i % 2 == 1 then
			local blossom = ball(pond, "LilyBlossom", 1.4, math.cos(a) * r + 0.6, 1.8, -300 + math.sin(a) * r, if i % 4 == 1 then rgb(255, 150, 200) else rgb(255, 245, 250), Enum.Material.Neon)
			blossom.CanCollide = false
		end
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
-- scenery: atmosphere pieces with no gameplay role (all under Map.Scenery)

-- A storybook cottage: plaster walls with a timber frame and round corner posts, a steep
-- bell-cast roof (flared eaves, tile courses, round ridge with finials, a dormer), a round
-- chimney pot, arched door under a little hood, arched shuttered windows on every side.
local function cottage(parent: Instance, x: number, z: number, facing: Vector3, seed: number, storeys: number?, awning: Color3?)
	local model = Instance.new("Model")
	model.Name = "Cottage"
	model.Parent = parent
	local base = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + facing)
	local function rel(u: number, y: number, v: number): CFrame
		return base * CFrame.new(u, y, -v) -- u = right, v = forward (towards the avenue)
	end
	local walls = { rgb(250, 238, 215), rgb(255, 214, 200), rgb(220, 240, 220), rgb(255, 230, 170), rgb(215, 225, 250) }
	local roofs = { rgb(205, 85, 70), rgb(70, 110, 180), rgb(60, 160, 150), rgb(225, 160, 60), rgb(150, 90, 170) }
	local wall = walls[seed % #walls + 1]
	local roof = roofs[(seed * 3) % #roofs + 1]
	local dark = Color3.new(roof.R * 0.72, roof.G * 0.72, roof.B * 0.72)
	local beam = rgb(110, 75, 50)
	local glass = rgb(255, 210, 130)
	local floors = storeys or 1
	local W, D, H, rise = 16, 12, 10 * floors, 6
	local top = H + 1 -- top of the walls

	-- a disc facing along the cframe's X axis (round windows, arch tops)
	local function disc(name: string, d: number, cf: CFrame, color: Color3, material: any?): BasePart
		local p = part(model, name, Vector3.new(0.3, d, d), cf, color, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local FRONT = CFrame.Angles(0, math.rad(90), 0) -- turns a disc to face out of the front/back walls
	-- an arched window on the front (side = 1) or back (side = -1) wall
	local function window(u: number, y: number, side: number, shutters: boolean)
		local v = side * (D / 2 + 0.15)
		part(model, "WindowFrame", Vector3.new(3.2, 2.8, 0.3), rel(u, y, v), beam, Enum.Material.Wood)
		part(model, "Window", Vector3.new(2.4, 2.2, 0.3), rel(u, y, v + side * 0.1), glass, Enum.Material.Neon)
		disc("WindowArch", 3.2, rel(u, y + 1.3, v) * FRONT, beam, Enum.Material.Wood)
		disc("WindowArch", 2.4, rel(u, y + 1.1, v + side * 0.1) * FRONT, glass, Enum.Material.Neon)
		if shutters then
			for _, k in { -1, 1 } do
				part(model, "Shutter", Vector3.new(1.1, 3.2, 0.25), rel(u + k * 2.25, y + 0.3, v + side * 0.05), roof, Enum.Material.WoodPlanks)
			end
		end
	end

	-- walls, footing and timber frame
	part(model, "Footing", Vector3.new(W + 1, 1.4, D + 1), rel(0, 0.7, 0), rgb(150, 145, 140), Enum.Material.Cobblestone)
	part(model, "Walls", Vector3.new(W, H, D), rel(0, H / 2 + 1, 0), wall, Enum.Material.Plaster)
	local attic = math.sqrt(2) * rise
	part(model, "Attic", Vector3.new(W - 0.2, attic, attic), rel(0, top, 0) * CFrame.Angles(math.rad(45), 0, 0), wall, Enum.Material.Plaster)
	for _, u in { -W / 2, W / 2 } do
		for _, v in { -D / 2, D / 2 } do
			local post = part(model, "Timber", Vector3.new(H + 0.4, 1.1, 1.1), rel(u, H / 2 + 1, v) * CFrame.Angles(0, 0, math.rad(90)), beam, Enum.Material.Wood)
			post.Shape = Enum.PartType.Cylinder
		end
	end
	for _, u in { -2.6, 2.6 } do
		part(model, "Timber", Vector3.new(0.8, H, 0.5), rel(u, H / 2 + 1, D / 2 + 0.1), beam, Enum.Material.Wood)
	end
	part(model, "Timber", Vector3.new(W, 0.8, 0.5), rel(0, H + 0.8, D / 2 + 0.1), beam, Enum.Material.Wood)
	part(model, "Timber", Vector3.new(W, 0.8, 0.5), rel(0, H + 0.8, -D / 2 - 0.1), beam, Enum.Material.Wood)
	for floor = 2, floors do
		local y0 = (floor - 1) * 10
		part(model, "Timber", Vector3.new(W + 0.4, 0.8, D + 0.4), rel(0, y0 + 1, 0), beam, Enum.Material.Wood)
		for _, u in { -4.5, 4.5 } do
			window(u, y0 + 5.8, 1, true)
		end
		window(0, y0 + 5.8, -1, false)
	end

	-- door with a round arch, a brass knob, a little hood on brackets and a lantern
	part(model, "Door", Vector3.new(3.4, 5.6, 0.4), rel(0, 3.8, D / 2 + 0.2), rgb(120, 80, 55), Enum.Material.WoodPlanks)
	disc("DoorArch", 3.4, rel(0, 6.6, D / 2 + 0.2) * FRONT, rgb(120, 80, 55), Enum.Material.WoodPlanks)
	disc("DoorStone", 4.4, rel(0, 6.6, D / 2 + 0.05) * FRONT, rgb(170, 160, 150), Enum.Material.Cobblestone)
	local knob = ball(model, "Knob", 0.45, 0, 0, 0, rgb(240, 200, 90), Enum.Material.Metal)
	knob.CFrame = rel(1.1, 4, D / 2 + 0.45)
	part(model, "Step", Vector3.new(5, 0.6, 1.6), rel(0, 1.1, D / 2 + 1.2), rgb(165, 160, 150), Enum.Material.Slate)
	if not awning then
		part(model, "Hood", Vector3.new(5.4, 0.4, 2.6), rel(0, 9.2, D / 2 + 1.1) * CFrame.Angles(math.rad(-25), 0, 0), roof, Enum.Material.Slate)
		for _, k in { -1, 1 } do
			part(model, "HoodBracket", Vector3.new(0.4, 1.4, 1.2), rel(k * 2.3, 8.4, D / 2 + 0.6), beam, Enum.Material.Wood)
		end
	end
	local lantern = ball(model, "DoorLantern", 0.9, 0, 0, 0, rgb(255, 215, 140), Enum.Material.Neon)
	lantern.CFrame = rel(-2.9, 8, D / 2 + 0.8)

	-- arched, shuttered windows with flower boxes at the front; plain ones round the back and sides
	local flowerColors = { rgb(255, 110, 150), rgb(255, 225, 90), rgb(170, 130, 255), rgb(255, 255, 255) }
	for _, u in { -5.3, 5.3 } do
		window(u, 6.4, 1, true)
		part(model, "WindowBox", Vector3.new(3.6, 0.9, 1), rel(u, 4.6, D / 2 + 0.6), rgb(150, 100, 70), Enum.Material.Wood)
		for i = 1, 3 do
			local bloom = ball(model, "WindowBloom", 1.1, 0, 0, 0, flowerColors[(i + seed) % 4 + 1])
			bloom.CFrame = rel(u - 2 + i, 5.4, D / 2 + 0.7)
		end
		window(u, 6.4, -1, false)
	end
	for _, side in { -1, 1 } do
		local u = side * (W / 2 + 0.15)
		part(model, "Window", Vector3.new(0.3, 2.2, 2.4), rel(u, 6.4, 0), glass, Enum.Material.Neon)
		disc("WindowArch", 2.4, rel(u, 7.5, 0), glass, Enum.Material.Neon)
		-- a round window high in each gable
		disc("GableWindow", 2.4, rel(side * (W / 2 + 0.05), top + rise * 0.4, 0), glass, Enum.Material.Neon)
	end
	if awning then
		-- a striped awning with a scalloped edge
		for i = 1, 4 do
			local u = -W / 2 + (i - 0.5) * (W / 4)
			local color = if i % 2 == 0 then rgb(255, 255, 255) else awning
			part(model, "Awning", Vector3.new(W / 4, 0.5, 4), rel(u, 9.4, D / 2 + 2) * CFrame.Angles(math.rad(-18), 0, 0), color, Enum.Material.Fabric)
			for _, k in { -1, 1 } do
				disc("Scallop", W / 8, rel(u + k * W / 16, 8.6, D / 2 + 3.9) * FRONT, color, Enum.Material.Fabric).CanCollide = false
			end
		end
	end

	-- roof: steep slabs flaring out into shallow eaves (a bell-cast curve), darker tile courses,
	-- a round ridge with ball finials
	local slope = math.atan(rise / (D / 2))
	local length = math.sqrt(rise * rise + (D / 2) ^ 2) + 0.6
	local flare = math.rad(22)
	for _, side in { 1, -1 } do
		local tilt = CFrame.Angles(-side * slope, 0, 0)
		part(model, "Roof", Vector3.new(W + 2, 0.9, length), rel(0, top + rise / 2 + 0.4, side * D / 4) * tilt, roof, Enum.Material.Slate)
		for _, f in { 0.3, 0.62 } do
			-- a course of tiles: a thin darker band standing proud of the slab
			local v = side * D / 2 * f
			part(model, "RoofTiles", Vector3.new(W + 2.1, 0.35, 0.7), rel(0, top + rise * (1 - f) + 0.4 + 0.42, v + side * 0.3) * tilt, dark, Enum.Material.Slate)
		end
		local ev = side * (D / 2 + 0.2)
		part(model, "Eave", Vector3.new(W + 2.6, 0.7, 3.4), rel(0, top + 0.2 - math.sin(flare) * 1.5, ev + side * math.cos(flare) * 1.5) * CFrame.Angles(-side * flare, 0, 0), roof, Enum.Material.Slate)
		-- bargeboards: dark trim down the gable edges
		for _, e in { -1, 1 } do
			part(model, "Barge", Vector3.new(0.5, 0.9, length), rel(e * (W / 2 + 1.05), top + rise / 2 + 0.55, side * D / 4) * tilt, dark, Enum.Material.Wood)
		end
	end
	local ridge = part(model, "Ridge", Vector3.new(W + 2.4, 1.3, 1.3), rel(0, top + rise + 0.5, 0), dark, Enum.Material.Wood)
	ridge.Shape = Enum.PartType.Cylinder
	for _, u in { -(W / 2 + 1.4), W / 2 + 1.4 } do
		ball(model, "Finial", 1.6, 0, 0, 0, dark, Enum.Material.Wood).CFrame = rel(u, top + rise + 0.7, 0)
	end
	-- a dormer window on the front slope
	do
		local du = -W / 4
		part(model, "Dormer", Vector3.new(3.6, 3.2, 3.4), rel(du, top + 2.6, 3.2), wall, Enum.Material.Plaster)
		for _, k in { -1, 1 } do
			part(model, "DormerRoof", Vector3.new(2.9, 0.4, 4.2), rel(du + k * 0.95, top + 5.35, 3.1) * CFrame.Angles(0, 0, -k * math.rad(45)), roof, Enum.Material.Slate)
		end
		part(model, "Window", Vector3.new(1.6, 1.2, 0.3), rel(du, top + 2.7, 4.95), glass, Enum.Material.Neon)
		disc("WindowArch", 1.6, rel(du, top + 3.3, 4.95) * FRONT, glass, Enum.Material.Neon)
	end
	-- a round chimney pot with a wider cap (and a weathervane on some roofs)
	local cp = rel(W / 2 - 3.5, H + rise, -D / 4).Position
	cylinder(model, "Chimney", 7, 2.4, cp.X, cp.Y, cp.Z, rgb(170, 110, 90), Enum.Material.Brick)
	cylinder(model, "ChimneyCap", 0.8, 3.2, cp.X, cp.Y + 3.7, cp.Z, rgb(120, 85, 70), Enum.Material.Brick)
	if seed % 3 == 0 then
		local vp = rel(-W / 2 + 2, top + rise + 2.6, 0).Position
		cylinder(model, "VanePole", 3.4, 0.25, vp.X, vp.Y, vp.Z, rgb(60, 60, 65), Enum.Material.Metal)
		part(model, "VaneArrow", Vector3.new(2.6, 0.5, 0.15), rel(-W / 2 + 2, top + rise + 3.8, 0), rgb(230, 190, 70), Enum.Material.Metal)
	end
	return model
end

local function lanternTower(parent: Instance, x: number, z: number, accent: Color3)
	local model = Instance.new("Model")
	model.Name = "LanternTower"
	model.Parent = parent
	cylinder(model, "Base", 4, 9, x, 2, z, rgb(165, 160, 150), Enum.Material.Cobblestone)
	cylinder(model, "Shaft", 22, 6.5, x, 15, z, rgb(200, 195, 185), Enum.Material.Brick)
	cylinder(model, "Balcony", 1, 10, x, 26.5, z, rgb(120, 85, 60), Enum.Material.WoodPlanks)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		cylinder(model, "Post", 6, 0.6, x + math.cos(a) * 3.6, 30, z + math.sin(a) * 3.6, rgb(110, 75, 50), Enum.Material.Wood)
	end
	local flame = ball(model, "Flame", 4, x, 30, z, rgb(255, 190, 90), Enum.Material.Neon)
	glowLight(flame, 45, 1.6, rgb(255, 200, 120))
	emitter(flame, "Embers", {
		Color = ColorSequence.new(rgb(255, 220, 120), rgb(255, 120, 40)),
		Size = fade(0.5, 0),
		Rate = 10,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(25, 25),
		LightEmission = 1,
	})
	-- tiered roof
	for i, d in { 10, 7.5, 5, 2.5 } do
		cylinder(model, "Roof", 1.4, d, x, 33 + i * 1.3, z, accent, Enum.Material.Slate)
	end
	ball(model, "Finial", 1.4, x, 39.5, z, rgb(255, 225, 120), Enum.Material.Neon)
end

-- Windmill whose sail assembly the client spins (attribute SpinSpeed, degrees per second).
local function windmill(parent: Instance, x: number, z: number, facing: Vector3)
	local model = Instance.new("Model")
	model.Name = "Windmill"
	model.Parent = parent
	for i, d in { 16, 14.5, 13, 11.5, 10 } do
		cylinder(model, "Tower", 6, d, x, (i - 0.5) * 6, z, if i % 2 == 0 then rgb(240, 235, 225) else rgb(225, 218, 205), Enum.Material.Plaster)
	end
	for i, d in { 12, 9, 6, 3 } do
		cylinder(model, "Cap", 2, d, x, 30 + i * 2, z, rgb(200, 80, 70), Enum.Material.Slate)
	end
	part(model, "Door", Vector3.new(4, 7, 1), CFrame.lookAt(Vector3.new(x, 3.5, z) + facing * 7.8, Vector3.new(x, 3.5, z) + facing * 9), rgb(120, 80, 55), Enum.Material.WoodPlanks)

	local sails = Instance.new("Model")
	sails.Name = "Sails"
	sails.Parent = model
	local hubPos = Vector3.new(x, 28, z) + facing * 7
	local hubCf = CFrame.lookAt(hubPos, hubPos + facing)
	local hub = part(sails, "Hub", Vector3.new(2.6, 2.6, 2.6), hubCf, rgb(110, 75, 50), Enum.Material.Wood)
	sails.PrimaryPart = hub
	for i = 0, 3 do
		local spoke = hubCf * CFrame.Angles(0, 0, i * math.pi / 2)
		part(sails, "Arm", Vector3.new(0.8, 22, 0.8), spoke * CFrame.new(0, 11, 0), rgb(110, 75, 50), Enum.Material.Wood)
		part(sails, "Sail", Vector3.new(5, 16, 0.3), spoke * CFrame.new(3, 13, 0.3), rgb(250, 248, 240), Enum.Material.Fabric)
		part(sails, "SailTip", Vector3.new(5, 3, 0.35), spoke * CFrame.new(3, 22.5, 0.3), rgb(220, 70, 70), Enum.Material.Fabric)
	end
	for _, p in sails:GetChildren() do
		if p:IsA("BasePart") then
			p.CanCollide = false
		end
	end
	sails:SetAttribute("SpinSpeed", 25)
	sails.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- animated whole on the client
end

-- A string of coloured festoon bulbs between two points.
local function festoon(parent: Instance, a: Vector3, b: Vector3, seed: number)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	deco(part(parent, "FestoonWire", Vector3.new(0.15, 0.15, length), CFrame.lookAt(mid, b), rgb(50, 45, 40)))
	local colors = { rgb(255, 90, 120), rgb(255, 210, 70), rgb(90, 220, 255), rgb(150, 255, 120), rgb(200, 130, 255), rgb(255, 150, 60) }
	local count = math.floor(length / 5)
	for i = 1, count do
		local f = i / (count + 1)
		local sag = math.sin(f * math.pi) * 1.6
		local pos = a + (b - a) * f - Vector3.new(0, sag + 0.5, 0)
		deco(ball(parent, "FestoonBulb", 0.9, pos.X, pos.Y, pos.Z, colors[(i + seed) % #colors + 1], Enum.Material.Neon))
	end
end

-- Tall translucent light column (two nested cylinders) rising from (x, y0, z).
local function lightBeam(parent: Instance, name: string, x: number, y0: number, z: number, height: number, width: number, color: Color3)
	local core = deco(cylinder(parent, name, height, width, x, y0 + height / 2, z, color, Enum.Material.Neon))
	core.Transparency = 0.45
	local halo = deco(cylinder(parent, name .. "Halo", height, width * 2.6, x, y0 + height / 2, z, color, Enum.Material.Neon))
	halo.Transparency = 0.86
	emitter(core, "Motes", {
		Color = ColorSequence.new(rgb(255, 255, 255), color),
		Size = fade(0.7, 0),
		Rate = 6,
		Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(4, 8),
		EmissionDirection = Enum.NormalId.Top,
		LightEmission = 1,
		Transparency = fade(0.1, 1),
	})
	return core
end

-- Glowing crystal cluster; the client bobs and turns the ones tagged with Bob.
local function crystal(parent: Instance, x: number, y: number, z: number, scale: number, color: Color3, seed: number, bob: boolean)
	local model = Instance.new("Model")
	model.Name = "Crystal"
	model.Parent = parent
	local main = part(model, "Shard", Vector3.new(2.4, 7, 2.4) * scale, CFrame.new(x, y + 3.5 * scale, z) * CFrame.Angles(0, math.rad(seed * 37), math.rad(8)), color, Enum.Material.Neon)
	model.PrimaryPart = main
	for i = 1, 3 do
		local a = (i / 3 + hash(seed + i) * 0.2) * math.pi * 2
		part(model, "Shard", Vector3.new(1.4, 4, 1.4) * scale, CFrame.new(x + math.cos(a) * 1.8 * scale, y + 2 * scale, z + math.sin(a) * 1.8 * scale) * CFrame.Angles(math.cos(a) * 0.5, a, math.sin(a) * 0.5), color, Enum.Material.Neon)
	end
	for _, p in model:GetChildren() do
		deco(p :: BasePart)
	end
	glowLight(main, 18 * scale, 1.2, color)
	emitter(main, "Glint", {
		Color = ColorSequence.new(rgb(255, 255, 255), color),
		Size = fade(0.4, 0),
		Rate = 3,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
	})
	if bob then
		model:SetAttribute("Bob", true)
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- animated whole on the client
	end
end

-- A falling ribbon of water from (x, top, z) down to the sea, with spray at the bottom.
local function waterfall(parent: Instance, x: number, top: number, z: number, width: number, facing: Vector3, bottom: number?)
	local floor = bottom or -2
	local height = top - floor
	local cf = CFrame.lookAt(Vector3.new(x, top - height / 2, z), Vector3.new(x, top - height / 2, z) + facing)
	local sheet = deco(part(parent, "Waterfall", Vector3.new(width, height, 1.2), cf, rgb(95, 185, 240), Enum.Material.Glass))
	sheet.Transparency = 0.2
	-- brighter white-water streak down the middle
	local foam = deco(part(parent, "WaterfallFoam", Vector3.new(width * 0.35, height, 0.4), cf * CFrame.new(0, 0, -0.7), rgb(225, 245, 255), Enum.Material.SmoothPlastic))
	foam.Transparency = 0.35
	local back = deco(part(parent, "WaterfallBack", Vector3.new(width + 2, height, 0.6), cf * CFrame.new(0, 0, 1), rgb(50, 130, 200), Enum.Material.Glass))
	back.Transparency = 0.35
	emitter(sheet, "Streaks", {
		Color = ColorSequence.new(rgb(235, 250, 255)),
		Size = fade(0.8, 0.3),
		Rate = 25,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(30, 40),
		EmissionDirection = Enum.NormalId.Bottom,
		LightEmission = 0.5,
		Transparency = fade(0.3, 0.9),
	})
	local splash = deco(part(parent, "Splash", Vector3.new(width + 6, 1, 8), CFrame.new(x, floor + 1, z), rgb(255, 255, 255), nil, { Transparency = 1 }))
	emitter(splash, "Mist", {
		Color = ColorSequence.new(rgb(255, 255, 255)),
		Size = fade(4, 9),
		Rate = 12,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Top,
		Transparency = fade(0.5, 1),
		RotSpeed = NumberRange.new(-20, 20),
	})
end

local function floatingIslet(parent: Instance, x: number, y: number, z: number, r: number, seed: number, falls: boolean)
	local model = Instance.new("Model")
	model.Name = "Islet"
	model.Parent = parent
	cylinder(model, "Top", 3, r * 2, x, y, z, rgb(105, 190, 85), Enum.Material.Grass)
	cylinder(model, "Soil", 4, r * 2 - 1, x, y - 3.4, z, rgb(130, 95, 65), Enum.Material.Ground)
	cylinder(model, "Rock", r * 0.5, r * 1.5, x, y - 5.4 - r * 0.25, z, rgb(140, 125, 115), Enum.Material.Rock)
	cylinder(model, "Rock", r * 0.5, r * 0.9, x + r * 0.08, y - 5.4 - r * 0.7, z - r * 0.05, rgb(125, 110, 100), Enum.Material.Rock)
	ball(model, "RockTip", r * 0.55, x - r * 0.05, y - 5.4 - r * 1.05, z + r * 0.05, rgb(115, 100, 95), Enum.Material.Rock)
	-- hanging roots
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + hash(seed + i)
		local len = 6 + hash(seed * 3 + i) * 10
		cylinder(model, "Root", len, 0.5, x + math.cos(a) * r * 0.7, y - 5 - len / 2, z + math.sin(a) * r * 0.7, rgb(95, 120, 60), Enum.Material.Grass)
	end
	for i = 1, math.max(1, math.floor(r / 12)) do
		local a = hash(seed + i * 7) * math.pi * 2
		local d = hash(seed + i * 11) * r * 0.55
		tree(model, x + math.cos(a) * d, z + math.sin(a) * d, 0.8 + hash(seed + i) * 0.5, seed * 10 + i, y + 1.5)
	end
	local crystalColors = { rgb(120, 230, 255), rgb(255, 130, 200), rgb(190, 140, 255), rgb(140, 255, 170) }
	local ca = hash(seed + 5) * math.pi * 2
	crystal(model, x + math.cos(ca) * r * 0.6, y + 1.5, z + math.sin(ca) * r * 0.6, 0.9, crystalColors[seed % 4 + 1], seed, false)
	if falls then
		-- pour off the edge facing the main island
		local toward = Vector3.new(-x, 0, -z).Unit
		local edge = Vector3.new(x, 0, z) + toward * (r - 0.5)
		local floor = if Landscape and not Landscape.inPlayArea(edge.X, edge.Z) then math.max(Landscape.height(edge.X, edge.Z), -2) else -2
		waterfall(model, edge.X, y + 1, edge.Z, math.max(5, r * 0.2), toward, floor)
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
		end
	end
end

local function cloud(parent: Instance, x: number, y: number, z: number, scale: number, seed: number)
	local model = Instance.new("Model")
	model.Name = "Cloud"
	model.Parent = parent
	for i = 1, 6 do
		local ox = (i - 3.5) * 9 * scale
		local d = (14 + hash(seed + i) * 12) * scale
		local p = deco(ball(model, "Puff", d, x + ox, y + hash(seed * 2 + i) * 5 * scale, z + (hash(seed * 3 + i) - 0.5) * 12 * scale, rgb(255, 255, 255)))
		p.Transparency = 0.12
	end
end

-- Drifting glowing motes in a box-shaped volume.
local function motes(parent: Instance, name: string, cf: CFrame, size: Vector3, color: Color3, rate: number)
	local volume = deco(part(parent, name, size, cf, color, nil, { Transparency = 1 }))
	emitter(volume, "Motes", {
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Color = ColorSequence.new(color),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 0.35),
			NumberSequenceKeypoint.new(0.8, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Rate = rate,
		Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Drag = 0.5,
	})
end

-- A cylinder running from point a to point b (for trunks, branches and posts at an angle).
local function segment(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, material: any?): BasePart
	local length = (b - a).Magnitude
	local p = part(parent, name, Vector3.new(length, diameter, diameter), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Flat stone path between two ground points.
local function path(parent: Instance, a: Vector3, b: Vector3, width: number)
	local mid = (a + b) / 2
	part(parent, "Path", Vector3.new(width, 0.25, (b - a).Magnitude), CFrame.lookAt(Vector3.new(mid.X, 0.12, mid.Z), Vector3.new(b.X, 0.12, b.Z)), rgb(200, 190, 170), Enum.Material.Cobblestone, { CanCollide = false })
end

local function barrel(parent: Instance, x: number, z: number)
	cylinder(parent, "Barrel", 3.6, 3, x, 1.8, z, rgb(150, 100, 60), Enum.Material.WoodPlanks)
	cylinder(parent, "Hoop", 0.4, 3.15, x, 2.8, z, rgb(80, 80, 85), Enum.Material.Metal)
	cylinder(parent, "Hoop", 0.4, 3.15, x, 0.8, z, rgb(80, 80, 85), Enum.Material.Metal)
end

local function crate(parent: Instance, x: number, y: number, z: number, size: number, turn: number)
	part(parent, "Crate", Vector3.new(size, size, size), CFrame.new(x, y + size / 2, z) * CFrame.Angles(0, turn, 0), rgb(190, 145, 90), Enum.Material.WoodPlanks)
end

local function bench(parent: Instance, x: number, z: number, facing: Vector3)
	local base = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + facing)
	part(parent, "BenchSeat", Vector3.new(6, 0.5, 2), base * CFrame.new(0, 1.8, 0), rgb(170, 120, 75), Enum.Material.WoodPlanks)
	part(parent, "BenchBack", Vector3.new(6, 2, 0.4), base * CFrame.new(0, 3, 0.9), rgb(170, 120, 75), Enum.Material.WoodPlanks)
	for _, u in { -2.5, 2.5 } do
		part(parent, "BenchLeg", Vector3.new(0.5, 1.8, 2), base * CFrame.new(u, 0.9, 0), rgb(70, 70, 75), Enum.Material.Metal)
	end
end

local function cart(parent: Instance, x: number, z: number, turn: number, produce: Color3)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, turn, 0)
	part(parent, "CartBed", Vector3.new(5, 1, 8), base * CFrame.new(0, 2.6, 0), rgb(160, 110, 70), Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		part(parent, "CartSide", Vector3.new(0.4, 1.6, 8), base * CFrame.new(s * 2.5, 3.6, 0), rgb(140, 95, 60), Enum.Material.WoodPlanks)
		local wheel = part(parent, "Wheel", Vector3.new(0.6, 4, 4), base * CFrame.new(s * 2.9, 2, 1), rgb(110, 75, 50), Enum.Material.Wood)
		wheel.Shape = Enum.PartType.Cylinder
	end
	for i = 1, 6 do
		local fruit = part(parent, "Produce", Vector3.new(1.6, 1.6, 1.6), base * CFrame.new(((i - 1) % 2 - 0.5) * 2, 3.8, (i - 3.5) * 1.1), produce, Enum.Material.SmoothPlastic)
		fruit.Shape = Enum.PartType.Ball
	end
end

local function haystack(parent: Instance, x: number, z: number, d: number)
	cylinder(parent, "Hay", d * 0.6, d, x, d * 0.3, z, rgb(235, 200, 100), Enum.Material.Fabric)
	ball(parent, "HayTop", d * 0.9, x, d * 0.6, z, rgb(240, 210, 110), Enum.Material.Fabric)
end

local function well(parent: Instance, x: number, z: number)
	cylinder(parent, "WellWall", 3, 7, x, 1.5, z, rgb(170, 165, 160), Enum.Material.Cobblestone)
	cylinder(parent, "WellWater", 0.4, 5.6, x, 2.8, z, rgb(80, 170, 220), Enum.Material.Glass)
	for _, s in { -1, 1 } do
		part(parent, "WellPost", Vector3.new(0.6, 7, 0.6), at(x + s * 3, 5, z), rgb(110, 75, 50), Enum.Material.Wood)
	end
	for _, s in { -1, 1 } do
		part(parent, "WellRoof", Vector3.new(8, 0.5, 4.4), at(x, 9.3, z + s * 1.6) * CFrame.Angles(s * math.rad(35), 0, 0), rgb(205, 85, 70), Enum.Material.Slate)
	end
	cylinder(parent, "Bucket", 1.4, 1.4, x, 4.2, z, rgb(150, 100, 60), Enum.Material.WoodPlanks)
end

local function signpost(parent: Instance, x: number, z: number, text: string, color: Color3)
	cylinder(parent, "SignPole", 9, 0.6, x, 4.5, z, rgb(110, 75, 50), Enum.Material.Wood)
	local board = part(parent, "SignBoard", Vector3.new(6, 1.6, 0.4), at(x, 8, z), rgb(200, 160, 110), Enum.Material.WoodPlanks)
	label(board, text, 1.6, UDim2.fromOffset(220, 50), color)
end

-- Front-yard picket fence with a gate gap and two vegetable patches.
local function yard(parent: Instance, x: number, z: number, facing: Vector3, seed: number)
	local base = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + facing)
	local function rel(u: number, y: number, v: number): CFrame
		return base * CFrame.new(u, y, -v)
	end
	local white = rgb(250, 248, 240)
	local front, half = 13, 10
	for _, s in { -1, 1 } do
		-- front rail either side of the gate, and the side rails
		part(parent, "FenceRail", Vector3.new(8, 0.4, 0.3), rel(s * 6, 2, front), white, Enum.Material.WoodPlanks)
		part(parent, "FenceRail", Vector3.new(0.3, 0.4, 7), rel(s * half, 2, front - 3.5), white, Enum.Material.WoodPlanks)
		for i = 0, 3 do
			part(parent, "Picket", Vector3.new(0.5, 3, 0.4), rel(s * (2.5 + i * 2.5), 1.5, front), white, Enum.Material.WoodPlanks)
		end
		part(parent, "Picket", Vector3.new(0.5, 3, 0.4), rel(s * half, 1.5, front - 3.5), white, Enum.Material.WoodPlanks)
		-- vegetable patch
		part(parent, "VegBed", Vector3.new(4, 0.5, 5), rel(s * 6, 0.25, front - 4), rgb(110, 75, 50), Enum.Material.Ground)
		local crop = if (seed + s) % 3 == 0 then rgb(245, 140, 40) elseif (seed + s) % 3 == 1 then rgb(90, 180, 70) else rgb(220, 60, 70)
		for k = 0, 2 do
			local veg = part(parent, "Veg", Vector3.new(1.4, 1.4, 1.4), rel(s * 6, 1, front - 5.5 + k * 1.5), crop, Enum.Material.SmoothPlastic)
			veg.Shape = Enum.PartType.Ball
		end
	end
	-- stepping stones from the door to the gate
	for i = 1, 3 do
		cylinder(parent, "Stone", 0.25, 2.2, 0, 0, 0, rgb(185, 180, 170), Enum.Material.Slate).CFrame = rel((i % 2 - 0.5) * 0.6, 0.15, 6.5 + i * 2) * CFrame.Angles(0, 0, math.rad(90))
	end
end

local function palm(parent: Instance, x: number, z: number, lean: Vector3, seed: number)
	local model = Instance.new("Model")
	model.Name = "Palm"
	model.Parent = parent
	local prev = Vector3.new(x, 0, z)
	for i = 1, 6 do
		local nxt = Vector3.new(x, 0, z) + lean * (0.35 * i * i) + Vector3.new(0, i * 3.6, 0)
		segment(model, "Trunk", prev, nxt, 1.9 - i * 0.12, if i % 2 == 0 then rgb(150, 115, 80) else rgb(165, 128, 90), Enum.Material.Wood)
		prev = nxt
	end
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + hash(seed + i)
		local dir = Vector3.new(math.cos(a), -0.35, math.sin(a)).Unit
		part(model, "Frond", Vector3.new(2, 0.3, 9), CFrame.lookAt(prev + dir * 4.2, prev + dir * 9), rgb(60, 165 + math.floor(hash(seed + i * 2) * 40), 70), Enum.Material.Grass, { CanCollide = false })
	end
	for i = 1, 3 do
		ball(model, "Coconut", 1.2, prev.X + (i - 2) * 0.9, prev.Y - 0.9, prev.Z + ((i % 2) - 0.5) * 0.8, rgb(110, 80, 50), Enum.Material.Wood)
	end
end

local function seaArch(parent: Instance, x: number, z: number, turn: number)
	local model = Instance.new("Model")
	model.Name = "SeaArch"
	model.Parent = parent
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, turn, 0)
	local rock = rgb(160, 145, 130)
	for _, s in { -1, 1 } do
		local leg = part(model, "ArchLeg", Vector3.new(44, 14, 14), base * CFrame.new(s * 20, 12, 0) * CFrame.Angles(0, 0, math.rad(90)), rock, Enum.Material.Rock)
		leg.Shape = Enum.PartType.Cylinder
		ball(model, "ArchRock", 16, (base * CFrame.new(s * 22, 0, 2)).Position.X, -2, (base * CFrame.new(s * 22, 0, 2)).Position.Z, rock, Enum.Material.Rock)
	end
	part(model, "ArchTop", Vector3.new(58, 10, 15), base * CFrame.new(0, 37, 0), rock, Enum.Material.Rock)
	part(model, "ArchGrass", Vector3.new(54, 1.5, 13), base * CFrame.new(0, 42.6, 0), rgb(110, 185, 85), Enum.Material.Grass)
	tree(model, (base * CFrame.new(-12, 0, 0)).Position.X, (base * CFrame.new(-12, 0, 0)).Position.Z, 0.7, 501, 43)
	tree(model, (base * CFrame.new(14, 0, 2)).Position.X, (base * CFrame.new(14, 0, 2)).Position.Z, 0.6, 502, 43)
end

local function seaStack(parent: Instance, x: number, z: number, h: number, seed: number)
	cylinder(parent, "SeaStack", h + 10, 12 + hash(seed) * 6, x, h / 2 - 5, z, rgb(150, 138, 125), Enum.Material.Rock)
	cylinder(parent, "SeaStackTop", 1.5, 11 + hash(seed) * 6, x, h + 0.5, z, rgb(110, 185, 85), Enum.Material.Grass)
	ball(parent, "SeaStackRock", 9, x + 6, -1, z - 4, rgb(140, 128, 118), Enum.Material.Rock)
end

local function ruins(parent: Instance, x: number, y: number, z: number)
	local marble = rgb(235, 230, 220)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local h = 4 + hash(i + 40) * 9
		cylinder(parent, "Column", h, 1.8, x + math.cos(a) * 7, y + h / 2, z + math.sin(a) * 7, marble, Enum.Material.Marble)
	end
	part(parent, "Lintel", Vector3.new(10, 1.2, 2.2), at(x + 3.5, y + 13.6, z + 6.1) * CFrame.Angles(0, math.rad(-30), math.rad(4)), marble, Enum.Material.Marble)
	segment(parent, "FallenColumn", Vector3.new(x - 6, y + 1, z - 4), Vector3.new(x + 2, y + 1, z - 8), 1.8, marble, Enum.Material.Marble)
	local orb = ball(parent, "RuinOrb", 2.4, x, y + 3, z, rgb(140, 255, 210), Enum.Material.Neon)
	glowLight(orb, 22, 1.2, rgb(140, 255, 210))
end

-- Landmark: an enormous blossom tree with hanging lanterns and drifting petals.
local function elderTree(parent: Instance, x: number, y: number, z: number)
	local model = Instance.new("Model")
	model.Name = "ElderTree"
	model.Parent = parent
	local bark = rgb(120, 85, 65)
	ball(model, "RootFlare", 16, x, y + 1, z, bark, Enum.Material.Wood)
	local top = Vector3.new(x + 2, y + 34, z - 1)
	segment(model, "Trunk", Vector3.new(x, y, z), top, 9, bark, Enum.Material.Wood)
	local canopyColors = { rgb(255, 170, 205), rgb(255, 195, 220), rgb(250, 150, 195) }
	ball(model, "Crown", 30, top.X, top.Y + 8, top.Z, canopyColors[1], Enum.Material.Grass)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		local tip = top + Vector3.new(math.cos(a) * 18, 2 + hash(i + 60) * 8, math.sin(a) * 18)
		segment(model, "Branch", top - Vector3.new(0, 6, 0), tip, 3.2, bark, Enum.Material.Wood)
		ball(model, "Canopy", 18 + hash(i + 70) * 6, tip.X, tip.Y + 3, tip.Z, canopyColors[i % 3 + 1], Enum.Material.Grass)
		-- hanging lantern under each canopy
		local lx, lz = tip.X * 0.8 + top.X * 0.2, tip.Z * 0.8 + top.Z * 0.2
		deco(part(model, "LanternCord", Vector3.new(0.15, 6, 0.15), at(lx, tip.Y - 6, lz), rgb(60, 50, 40)))
		local lantern = deco(ball(model, "Lantern", 1.8, lx, tip.Y - 9.5, lz, if i % 2 == 0 then rgb(255, 210, 120) else rgb(255, 150, 200), Enum.Material.Neon))
		glowLight(lantern, 16, 1, rgb(255, 200, 170))
	end
	local crown = model:FindFirstChild("Crown") :: BasePart
	glowLight(crown, 40, 0.8, rgb(255, 170, 210))
	emitter(crown, "Petals", {
		Shape = Enum.ParticleEmitterShape.Sphere,
		Color = ColorSequence.new(rgb(255, 190, 215), rgb(255, 150, 195)),
		Size = NumberSequence.new(0.5),
		Rate = 14,
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(1, 3),
		Acceleration = Vector3.new(0.6, -1.4, 0.3),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.2,
	})
end

local function balloon(parent: Instance, x: number, y: number, z: number, a: Color3, b: Color3)
	local model = Instance.new("Model")
	model.Name = "Balloon"
	model.Parent = parent
	local envelope = deco(ball(model, "Envelope", 20, x, y, z, a, Enum.Material.Fabric))
	model.PrimaryPart = envelope
	deco(cylinder(model, "Band", 4, 20.4, x, y, z, b, Enum.Material.Fabric))
	deco(cylinder(model, "Band", 2, 17.4, x, y + 6, z, b, Enum.Material.Fabric))
	deco(cylinder(model, "Skirt", 4, 7, x, y - 10.5, z, b, Enum.Material.Fabric))
	deco(part(model, "Basket", Vector3.new(5, 3.5, 5), at(x, y - 19, z), rgb(170, 120, 70), Enum.Material.WoodPlanks))
	for _, c in { { -2.2, -2.2 }, { 2.2, -2.2 }, { -2.2, 2.2 }, { 2.2, 2.2 } } do
		deco(segment(model, "Rope", Vector3.new(x + c[1], y - 17.2, z + c[2]), Vector3.new(x + c[1] * 1.2, y - 12.4, z + c[2] * 1.2), 0.2, rgb(90, 75, 60)))
	end
	local flame = deco(ball(model, "Burner", 1.6, x, y - 14.5, z, rgb(255, 170, 60), Enum.Material.Neon))
	glowLight(flame, 14, 1, rgb(255, 180, 90))
	model:SetAttribute("Bob", "float")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- animated whole on the client
end

local function buildDetails(scenery: Instance)
	local details = Instance.new("Folder")
	details.Name = "Details"
	details.Parent = scenery

	-- yards and paths for the village row (cottages at x = +-75 facing the avenue)
	local seed = 0
	for _, z in { -195, -145, 145, 195 } do
		for _, side in { -1, 1 } do
			seed += 1
			yard(details, side * 75, z, Vector3.new(-side, 0, 0), seed)
			path(details, Vector3.new(side * 62, 0, z), Vector3.new(side * 22, 0, z), 3.5)
		end
	end
	yard(details, -100, -252, Vector3.new(0, 0, 1), 25)
	yard(details, 100, -252, Vector3.new(0, 0, 1), 26)
	-- shop fronts: path, barrels, crates and a bench
	for _, s in { { -80, -95, 1 }, { 80, -95, -1 }, { -80, 120, 1 }, { 80, 120, -1 } } do
		local x, z, d = s[1], s[2], s[3]
		path(details, Vector3.new(x + d * 6, 0, z), Vector3.new(if x < 0 then -22 else 22, 0, z), 4)
		barrel(details, x + d * 9, z - 9)
		barrel(details, x + d * 9.5, z - 5.8)
		crate(details, x + d * 9, 0, z + 8, 2.6, 0.3)
		crate(details, x + d * 9.2, 2.6, z + 8.2, 2, 0.8)
		bench(details, x + d * 15, z + 12, Vector3.new(d, 0, 0))
	end
	cart(details, -66, -118, math.rad(20), rgb(230, 60, 60))
	cart(details, 66, 98, math.rad(-15), rgb(245, 150, 40))
	-- north village square
	well(details, -58, -275)
	cart(details, 58, -278, math.rad(70), rgb(120, 200, 80))
	bench(details, -50, -262, Vector3.new(0, 0, -1))
	-- farm by the windmill
	haystack(details, 90, 272, 6)
	haystack(details, 96, 282, 4.5)
	haystack(details, 112, 238, 5)
	-- signposts
	signpost(details, -30, -232, "Wishing Pond", rgb(160, 230, 255))
	signpost(details, 30, 104, "Sky Garden", rgb(220, 200, 255))
	signpost(details, -30, -78, "Seed Shop", rgb(200, 255, 200))

	-- beach palms leaning out to sea
	local palms = { { -132, -350, -1 }, { -134, -60, -1 }, { -132, 40, -1 }, { 132, -360, 1 }, { 134, -50, 1 }, { 132, 60, 1 }, { 133, 250, 1 } }
	for i, pt in palms do
		palm(details, pt[1], pt[2], Vector3.new(pt[3], 0, (hash(i) - 0.5) * 0.6).Unit, i)
	end
	for i, x in { -110, -40, 40, 110 } do
		palm(details, x, -404, Vector3.new((hash(i + 9) - 0.5) * 0.6, 0, -1).Unit, i + 10)
	end

	-- sea features
	local sea = Instance.new("Folder")
	sea.Name = "SeaFeatures"
	sea.Parent = scenery
	-- in the bays where the sea comes through the hill ring
	seaArch(sea, -330, -565, math.rad(35))
	seaStack(sea, 430, 50, 22, 1)
	seaStack(sea, 445, -20, 14, 2)
	seaStack(sea, 120, 490, 24, 3)
	seaStack(sea, 92, 462, 12, 4)

	-- hot-air balloons drifting over the island (the client bobs them)
	local balloons = Instance.new("Folder")
	balloons.Name = "Balloons"
	balloons.Parent = scenery
	balloon(balloons, -150, 150, -120, rgb(255, 90, 110), rgb(255, 220, 80))
	balloon(balloons, 190, 175, -40, rgb(80, 170, 255), rgb(255, 255, 255))
	balloon(balloons, -80, 140, 170, rgb(150, 110, 240), rgb(130, 230, 200))
	balloon(balloons, 110, 160, -260, rgb(255, 160, 60), rgb(255, 90, 110))
	balloon(balloons, 260, 190, 260, rgb(110, 210, 110), rgb(255, 230, 120))
end

-- Terraced grassy hill: stacked, shrinking discs with a rocky skirt and a few trees on top.
local function hill(parent: Instance, x: number, z: number, r: number, tiers: number, seed: number, trees: boolean?): number
	local model = Instance.new("Model")
	model.Name = "Hill"
	model.Parent = parent
	local y = 0
	local radius = r
	for i = 1, tiers do
		local h = 5 + hash(seed + i) * 3
		local green = rgb(95 + i * 8, 175 + i * 6, 80)
		cylinder(model, "Terrace", h, radius * 2, x + (hash(seed * 2 + i) - 0.5) * 4, y + h / 2 - 0.5, z + (hash(seed * 3 + i) - 0.5) * 4, green, Enum.Material.Grass)
		-- rocks poking out of each terrace edge
		for k = 1, 3 do
			local a = hash(seed * 5 + i * 3 + k) * math.pi * 2
			ball(model, "Rock", 3 + hash(seed + k + i) * 3, x + math.cos(a) * radius * 0.95, y + 1.5, z + math.sin(a) * radius * 0.95, rgb(150, 140, 130), Enum.Material.Rock)
		end
		y += h - 0.5
		radius *= 0.72
	end
	for i = 1, if trees == false then 0 else 2 do
		local a = hash(seed + i * 13) * math.pi * 2
		tree(model, x + math.cos(a) * radius * 0.5, z + math.sin(a) * radius * 0.5, 0.9 + hash(seed + i) * 0.4, seed * 7 + i, y)
	end
	return y
end

-- Striped lighthouse whose beam the client sweeps round (SpinSpeed on the Beam model).
local function lighthouse(parent: Instance, x: number, y: number, z: number)
	local model = Instance.new("Model")
	model.Name = "Lighthouse"
	model.Parent = parent
	for i = 1, 6 do
		cylinder(model, "Tower", 7, 11 - i * 0.8, x, y + (i - 0.5) * 7, z, if i % 2 == 1 then rgb(245, 245, 245) else rgb(215, 65, 60), Enum.Material.SmoothPlastic)
	end
	local top = y + 42
	cylinder(model, "Gallery", 1, 11, x, top + 0.5, z, rgb(60, 60, 70), Enum.Material.Metal)
	local lamp = cylinder(model, "LampRoom", 6, 6, x, top + 4, z, rgb(255, 235, 160), Enum.Material.Neon)
	glowLight(lamp, 60, 2, rgb(255, 230, 160))
	for i, d in { 7.5, 5, 2.5 } do
		cylinder(model, "Roof", 1.4, d, x, top + 7 + i * 1.3, z, rgb(215, 65, 60), Enum.Material.Slate)
	end
	local beam = Instance.new("Model")
	beam.Name = "Beam"
	beam.Parent = model
	local hubCf = CFrame.new(x, top + 4, z) * CFrame.Angles(-math.pi / 2, 0, 0) -- local Z points up
	local hub = deco(part(beam, "Hub", Vector3.new(1, 1, 1), hubCf, rgb(255, 240, 180), Enum.Material.Neon, { Transparency = 1 }))
	beam.PrimaryPart = hub
	for _, side in { 1, -1 } do
		local ray = deco(part(beam, "Ray", Vector3.new(120, 4, 4), hubCf * CFrame.new(side * 62, 0, 0), rgb(255, 240, 180), Enum.Material.Neon))
		ray.Transparency = 0.75
	end
	beam:SetAttribute("SpinSpeed", 40)
	beam.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- animated whole on the client
end

-- Small stone keep with corner towers, battlements and banners.
local function keep(parent: Instance, x: number, y: number, z: number, banner: Color3)
	local model = Instance.new("Model")
	model.Name = "Keep"
	model.Parent = parent
	local stone, dark = rgb(200, 195, 185), rgb(165, 158, 150)
	part(model, "Hall", Vector3.new(30, 22, 30), at(x, y + 11, z), stone, Enum.Material.Cobblestone)
	-- battlements
	for i = 0, 6 do
		local o = -13.5 + i * 4.5
		for _, e in { { o, -14.5 }, { o, 14.5 }, { -14.5, o }, { 14.5, o } } do
			part(model, "Merlon", Vector3.new(2.2, 3, 2.2), at(x + e[1], y + 23.5, z + e[2]), dark, Enum.Material.Cobblestone)
		end
	end
	for _, c in { { -15, -15 }, { 15, -15 }, { -15, 15 }, { 15, 15 } } do
		local tx, tz = x + c[1], z + c[2]
		cylinder(model, "Tower", 32, 10, tx, y + 16, tz, stone, Enum.Material.Cobblestone)
		for i, d in { 12, 9, 6, 3 } do
			cylinder(model, "Spire", 3, d, tx, y + 32 + i * 3 - 1.5, tz, rgb(70, 95, 170), Enum.Material.Slate)
		end
		cylinder(model, "Pole", 6, 0.4, tx, y + 47, tz, rgb(90, 80, 70), Enum.Material.Wood)
		part(model, "Banner", Vector3.new(0.2, 3, 5), at(tx, y + 48.5, tz + 2.7), banner, Enum.Material.Fabric)
	end
	-- gate and lit windows facing the main island (east, +X)
	part(model, "Gate", Vector3.new(1, 10, 8), at(x + 15.2, y + 5, z), rgb(110, 75, 50), Enum.Material.WoodPlanks)
	for _, oz in { -8, 8 } do
		part(model, "Window", Vector3.new(0.5, 4, 2.4), at(x + 15.2, y + 15, z + oz), rgb(255, 210, 130), Enum.Material.Neon)
	end
	local brazier = ball(model, "Brazier", 3, x + 18, y + 25, z, rgb(255, 170, 70), Enum.Material.Neon)
	glowLight(brazier, 40, 1.4, rgb(255, 180, 90))
	emitter(brazier, "Embers", {
		Color = ColorSequence.new(rgb(255, 220, 120), rgb(255, 110, 40)),
		Size = fade(0.6, 0),
		Rate = 12,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(4, 7),
		SpreadAngle = Vector2.new(20, 20),
		LightEmission = 1,
	})
end

local function boat(parent: Instance, x: number, z: number, heading: number, sail: Color3)
	local model = Instance.new("Model")
	model.Name = "Boat"
	model.Parent = parent
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, heading, 0)
	part(model, "Hull", Vector3.new(7, 3, 18), base * CFrame.new(0, 0.5, 0), rgb(140, 95, 60), Enum.Material.WoodPlanks)
	part(model, "Bow", Vector3.new(4.9, 3, 4.9), base * CFrame.new(0, 0.5, -9) * CFrame.Angles(0, math.rad(45), 0), rgb(140, 95, 60), Enum.Material.WoodPlanks)
	part(model, "Deck", Vector3.new(6, 0.4, 16), base * CFrame.new(0, 2.1, 0), rgb(190, 150, 100), Enum.Material.WoodPlanks)
	part(model, "Mast", Vector3.new(0.7, 16, 0.7), base * CFrame.new(0, 10, -1), rgb(110, 75, 50), Enum.Material.Wood)
	part(model, "Sail", Vector3.new(0.3, 11, 8), base * CFrame.new(0.4, 11, 3) * CFrame.Angles(0, math.rad(90), 0), sail, Enum.Material.Fabric)
	part(model, "Stripe", Vector3.new(0.35, 2, 8), base * CFrame.new(0.45, 11, 3) * CFrame.Angles(0, math.rad(90), 0), rgb(255, 255, 255), Enum.Material.Fabric)
end

local function bush(parent: Instance, x: number, z: number, seed: number)
	local green = rgb(70 + math.floor(hash(seed) * 30), 150 + math.floor(hash(seed + 1) * 40), 70)
	ball(parent, "Bush", 4.5, x, 1.6, z, green, Enum.Material.Grass)
	ball(parent, "Bush", 3.4, x + 2.2, 1.3, z + 1, green, Enum.Material.Grass)
	local flowers = { rgb(255, 120, 160), rgb(255, 230, 100), rgb(255, 255, 255), rgb(180, 140, 255) }
	for i = 1, 3 do
		local a = hash(seed * 3 + i) * math.pi * 2
		ball(parent, "BushFlower", 0.8, x + math.cos(a) * 2, 3.2, z + math.sin(a) * 2, flowers[(seed + i) % 4 + 1])
	end
end

local function buildLandscape(scenery: Instance)
	local land = Instance.new("Folder")
	land.Name = "Landscape"
	land.Parent = scenery

	-- terraced hills in the island's four empty corners (outside the shoreline tree ring)
	hill(land, -95, -378, 22, 3, 1)
	hill(land, 95, -378, 20, 3, 2)
	local elderBase = hill(land, -100, 305, 22, 3, 3, false)
	elderTree(land, -100, elderBase, 305)
	hill(land, 108, 318, 16, 2, 4)

	-- town: two-storey shop houses beside the Plaza, more cottages at the north corners
	local town = scenery:FindFirstChild("Village") or land
	cottage(town, -80, -95, Vector3.new(1, 0, 0), 21, 2, rgb(90, 190, 110))
	cottage(town, 80, -95, Vector3.new(-1, 0, 0), 22, 2, rgb(240, 120, 150))
	cottage(town, -80, 120, Vector3.new(1, 0, 0), 23, 2, rgb(90, 160, 255))
	cottage(town, 80, 120, Vector3.new(-1, 0, 0), 24, 2, rgb(255, 180, 60))
	cottage(town, -100, -252, Vector3.new(0, 0, 1), 25)
	cottage(town, 100, -252, Vector3.new(0, 0, 1), 26)
	cottage(town, -100, -310, Vector3.new(0.6, 0, 0.8).Unit, 27, 2)
	cottage(town, 100, -310, Vector3.new(-0.6, 0, 0.8).Unit, 28, 2)

	-- bushes lining the avenue (clear of the Plaza and the Parade)
	local n = 0
	for z = -240, 240, 30 do
		if math.abs(z) > 75 and not (z > 60 and z < 100) then
			for _, side in { -1, 1 } do
				n += 1
				bush(land, side * 50, z + side * 7, n)
			end
		end
	end

	-- boulders along the beach
	for i = 1, 28 do
		local f = i / 28
		local x, z
		if i % 2 == 0 then
			x, z = (f * 2 - 1) * 128, if i % 4 == 0 then -402 else 342
		else
			x, z = if i % 4 == 1 then -133 else 133, -400 + f * 740
		end
		ball(land, "Boulder", 4 + hash(i) * 6, x + (hash(i + 2) - 0.5) * 6, -0.5, z, rgb(160, 150, 140), Enum.Material.Rock)
	end

	-- the harbour pier and boats in the east bay
	local coast = Instance.new("Folder")
	coast.Name = "Coast"
	coast.Parent = scenery
	-- (the castle, lighthouse and ruins now stand on the terrain hills, see buildHills)

	part(coast, "Pier", Vector3.new(80, 1, 10), at(170, 1.5, 20), rgb(160, 115, 75), Enum.Material.WoodPlanks)
	for i = 0, 7 do
		for _, side in { -1, 1 } do
			cylinder(coast, "Piling", 8, 1.2, 134 + i * 10, -2.5, 20 + side * 5.2, rgb(110, 80, 55), Enum.Material.Wood)
		end
	end
	lamp(coast, 208, 26)
	boat(coast, 180, 38, math.rad(80), rgb(240, 90, 90))
	boat(coast, 198, 2, math.rad(100), rgb(90, 150, 240))
	boat(coast, 260, 70, math.rad(30), rgb(255, 210, 80))

	-- (the old distant prop mountains are gone: real terrain mountains ring the land now)
end

----------------------------------------------------------------------------------------------
-- the hills around the lagoon (Roblox Terrain, see Shared.Landscape and server/TerrainBuilder)

local function cascade(parent: Instance, top: Vector3, bottom: Vector3, width: number)
	local mid = (top + bottom) / 2
	local length = (top - bottom).Magnitude
	local cf = CFrame.lookAt(mid, bottom)
	local sheet = deco(part(parent, "Cascade", Vector3.new(width, 1.2, length), cf, rgb(95, 185, 240), Enum.Material.Glass))
	sheet.Transparency = 0.15
	local foam = deco(part(parent, "CascadeFoam", Vector3.new(width * 0.4, 0.5, length), cf * CFrame.new(0, 0.8, 0), rgb(230, 248, 255), Enum.Material.SmoothPlastic))
	foam.Transparency = 0.3
	emitter(sheet, "Spray", {
		Color = ColorSequence.new(rgb(240, 252, 255)),
		Size = fade(1, 0.4),
		Rate = 40,
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(4, 8),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -20, 0),
		LightEmission = 0.4,
		Transparency = fade(0.3, 1),
	})
	local splash = deco(part(parent, "Splash", Vector3.new(width + 8, 1, 10), CFrame.new(bottom.X, bottom.Y + 1, bottom.Z), rgb(255, 255, 255), nil, { Transparency = 1 }))
	emitter(splash, "Mist", {
		Color = ColorSequence.new(rgb(255, 255, 255)),
		Size = fade(5, 12),
		Rate = 16,
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top,
		Transparency = fade(0.45, 1),
		RotSpeed = NumberRange.new(-20, 20),
	})
end

-- Seven translucent bands arcing in a vertical plane that faces +Z (towards the island).
local function rainbow(parent: Instance, cx: number, cy: number, cz: number, inner: number)
	local colors = {
		rgb(255, 70, 70), rgb(255, 150, 50), rgb(255, 230, 70), rgb(90, 220, 90),
		rgb(70, 170, 255), rgb(100, 90, 230), rgb(180, 100, 230),
	}
	local segments = 16
	local normal = Vector3.new(0, 0, 1)
	for band, color in colors do
		local r = inner + (#colors - band) * 2
		for i = 0, segments - 1 do
			local t0, t1 = i / segments * math.pi, (i + 1) / segments * math.pi
			local p0 = Vector3.new(cx + math.cos(t0) * r, cy + math.sin(t0) * r, cz)
			local p1 = Vector3.new(cx + math.cos(t1) * r, cy + math.sin(t1) * r, cz)
			local mid = (p0 + p1) / 2
			local seg = deco(part(parent, "Rainbow", Vector3.new(2.1, 0.3, (p1 - p0).Magnitude + 0.4), CFrame.lookAt(mid, p1, normal), color, Enum.Material.Neon))
			seg.Transparency = 0.6
		end
	end
end

local function gazebo(parent: Instance, x: number, y: number, z: number, roof: Color3)
	cylinder(parent, "GazeboFloor", 1, 16, x, y + 0.5, z, rgb(225, 220, 210), Enum.Material.Marble)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		cylinder(parent, "GazeboPillar", 10, 1, x + math.cos(a) * 6.8, y + 6, z + math.sin(a) * 6.8, rgb(250, 248, 240), Enum.Material.Marble)
	end
	cone(parent, "GazeboRoof", x, y + 11, z, 9.5, 6, roof, Enum.Material.Slate, 6)
	ball(parent, "GazeboFinial", 1.2, x, y + 17.4, z, rgb(255, 220, 110), Enum.Material.Neon)
end

-- A tower with a cone roof and a banner (castle walls, watchtower).
local function coneTower(parent: Instance, x: number, y: number, z: number, d: number, h: number, roof: Color3, banner: Color3)
	cylinder(parent, "Tower", h, d, x, y + h / 2, z, rgb(205, 200, 190), Enum.Material.Cobblestone)
	cylinder(parent, "TowerRim", 1.4, d + 1.2, x, y + h + 0.2, z, rgb(170, 165, 158), Enum.Material.Cobblestone)
	cone(parent, "TowerRoof", x, y + h + 0.9, z, d * 0.68, d * 1.05, roof, Enum.Material.Slate, 6)
	cylinder(parent, "FlagPole", 5, 0.3, x, y + h + d * 1.05 + 3, z, rgb(90, 80, 70), Enum.Material.Wood)
	part(parent, "Flag", Vector3.new(0.15, 2.2, 3.6), at(x, y + h + d * 1.05 + 4.4, z + 1.9), banner, Enum.Material.Fabric)
end

local function castle(parent: Instance, s: any)
	local model = Instance.new("Model")
	model.Name = "Castle"
	model.Parent = parent
	local x, y, z = s.x, s.h, s.z
	keep(model, x, y, z, rgb(220, 70, 90))
	local R, sides = 40, 8
	local apothem = R * math.cos(math.pi / sides)
	local length = 2 * R * math.sin(math.pi / sides)
	local stone = rgb(200, 195, 185)
	for k = 0, sides - 1 do
		local f = k / sides * math.pi * 2 -- face 0 points east (+X), towards the island
		local dir = Vector3.new(math.cos(f), 0, math.sin(f))
		local centre = Vector3.new(x, y + 7, z) + dir * apothem
		local frame = CFrame.lookAt(centre, centre + dir) -- X runs along the wall
		local pieces = if k == 0 then { { -(length + 10) / 4, (length - 10) / 2 }, { (length + 10) / 4, (length - 10) / 2 } } else { { 0, length + 1 } }
		for _, piece in pieces do
			part(model, "Wall", Vector3.new(piece[2], 14, 4), frame * CFrame.new(piece[1], 0, 0), stone, Enum.Material.Cobblestone)
			local merlons = math.floor(piece[2] / 4)
			for m = 0, merlons - 1 do
				local u = piece[1] - piece[2] / 2 + (m + 0.5) * (piece[2] / merlons)
				part(model, "Merlon", Vector3.new(1.8, 2.4, 4.4), frame * CFrame.new(u, 8.2, 0), rgb(175, 170, 162), Enum.Material.Cobblestone)
			end
		end
		local v = f + math.pi / sides
		coneTower(model, x + math.cos(v) * R, y, z + math.sin(v) * R, 9, 22, rgb(70, 95, 170), if k % 2 == 0 then rgb(220, 70, 90) else rgb(255, 210, 80))
	end
	-- gatehouse on the east face
	local gx = x + apothem
	for _, side in { -1, 1 } do
		part(model, "GateTower", Vector3.new(7, 20, 7), at(gx, y + 10, z + side * 8), stone, Enum.Material.Cobblestone)
		cone(model, "GateRoof", gx, y + 20, z + side * 8, 5.2, 7, rgb(205, 85, 70), Enum.Material.Slate, 4)
		local torch = ball(model, "GateTorch", 1.4, gx + 4, y + 9, z + side * 5.5, rgb(255, 180, 80), Enum.Material.Neon)
		glowLight(torch, 18, 1.2, rgb(255, 190, 110))
	end
	part(model, "GateArch", Vector3.new(6, 4, 10), at(gx, y + 12, z), stone, Enum.Material.Cobblestone)
	for i = -2, 2 do
		part(model, "Portcullis", Vector3.new(0.4, 9, 0.4), at(gx + 2.5, y + 5.5, z + i * 2), rgb(70, 70, 75), Enum.Material.Metal)
	end
	part(model, "PortcullisBar", Vector3.new(0.4, 0.4, 9), at(gx + 2.5, y + 7, z), rgb(70, 70, 75), Enum.Material.Metal)
	-- banners hanging on the keep
	for _, side in { -1, 1 } do
		part(model, "Banner", Vector3.new(0.3, 9, 4), at(x + 15.4, y + 15, z + side * 7), rgb(220, 70, 90), Enum.Material.Fabric)
	end
	local yard = Instance.new("Folder")
	yard.Name = "Courtyard"
	yard.Parent = model
	well(yard, x + 26, z - 12)
	barrel(yard, x + 24, z + 18)
	barrel(yard, x + 27, z + 20)
	crate(yard, x - 24, 0, z + 22, 3, 0.4)
	cart(yard, x - 26, z - 20, math.rad(30), rgb(250, 200, 60))
	lift(yard, y)
end

local function hamlet(parent: Instance, s: any, seed: number, stallName: string, stallColor: Color3)
	local model = Instance.new("Model")
	model.Name = "Hamlet"
	model.Parent = parent
	local x, z = s.x, s.z
	well(model, x, z)
	for i = 0, 4 do
		local a = i / 6 * math.pi * 2 + seed
		local px, pz = x + math.cos(a) * 27, z + math.sin(a) * 27
		local facing = Vector3.new(x - px, 0, z - pz).Unit
		cottage(model, px, pz, facing, seed * 10 + i, if i % 2 == 0 then 1 else 2)
	end
	local a = 5 / 6 * math.pi * 2 + seed
	local sx, sz = x + math.cos(a) * 24, z + math.sin(a) * 24
	stall(model, stallName, sx, sz, Vector3.new(x - sx, 0, z - sz).Unit, 14, stallColor)
	for i = 0, 3 do
		local la = (i + 0.5) / 4 * math.pi * 2 + seed
		lamp(model, x + math.cos(la) * 13, z + math.sin(la) * 13)
	end
	bench(model, x + 7, z + 7, Vector3.new(-1, 0, -1).Unit)
	bench(model, x - 7, z - 7, Vector3.new(1, 0, 1).Unit)
	barrel(model, sx + 6, sz + 2)
	barrel(model, sx + 6.5, sz - 1.5)
	crate(model, sx - 6, 0, sz, 2.6, 0.5)
	flowerBed(model, x + 10, z - 10, 6, 6, seed * 3)
	flowerBed(model, x - 10, z + 10, 6, 6, seed * 3 + 1)
	-- a cooking pot over a fire: a kitchen for Shared/Recipes (InventoryService finds ShopAnchor)
	local px, pz = x - 9, z - 9
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		ball(model, "FireStone", 1.4, px + math.cos(a) * 2.6, 0.6, pz + math.sin(a) * 2.6, rgb(120, 115, 110), Enum.Material.Rock)
	end
	local embers = ball(model, "Embers", 2, px, 0.6, pz, rgb(255, 120, 40), Enum.Material.Neon)
	glowLight(embers, 18, 1.4, rgb(255, 150, 70))
	cylinder(model, "Pot", 2.6, 3.4, px, 2.6, pz, rgb(50, 48, 52), Enum.Material.Metal)
	cylinder(model, "Stew", 0.3, 3, px, 3.9, pz, rgb(170, 110, 60), Enum.Material.SmoothPlastic)
	for _, s2 in { -1, 1 } do
		part(model, "PotPost", Vector3.new(0.4, 5, 0.4), at(px + s2 * 2.6, 2.5, pz), rgb(90, 65, 45), Enum.Material.Wood)
	end
	part(model, "PotBar", Vector3.new(5.6, 0.4, 0.4), at(px, 5, pz), rgb(90, 65, 45), Enum.Material.Wood)
	local anchor = part(model, "ShopAnchor", Vector3.new(3, 3, 3), at(px, 2, pz + 3), rgb(255, 255, 255), nil, { Transparency = 1, CanCollide = false })
	anchor:SetAttribute("Shop", "kitchen")
	lift(model, s.h)
end

local function scarecrow(parent: Instance, x: number, z: number)
	part(parent, "ScarecrowPost", Vector3.new(0.5, 7, 0.5), at(x, 3.5, z), rgb(110, 75, 50), Enum.Material.Wood)
	part(parent, "ScarecrowArms", Vector3.new(6, 0.5, 0.5), at(x, 5.2, z), rgb(110, 75, 50), Enum.Material.Wood)
	part(parent, "ScarecrowShirt", Vector3.new(2.6, 2.6, 1.2), at(x, 5, z), rgb(70, 120, 200), Enum.Material.Fabric)
	ball(parent, "ScarecrowHead", 1.8, x, 7.3, z, rgb(240, 220, 160), Enum.Material.Fabric)
	cylinder(parent, "ScarecrowHat", 1.2, 2.2, x, 8.4, z, rgb(170, 120, 60), Enum.Material.Fabric)
	cylinder(parent, "ScarecrowBrim", 0.2, 3.6, x, 7.9, z, rgb(170, 120, 60), Enum.Material.Fabric)
end

local function barn(parent: Instance, x: number, z: number, facing: Vector3)
	local base = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + facing)
	local function rel(u: number, y: number, v: number): CFrame
		return base * CFrame.new(u, y, -v)
	end
	local red, white = rgb(200, 60, 55), rgb(250, 248, 240)
	part(parent, "BarnWalls", Vector3.new(22, 14, 18), rel(0, 7, 0), red, Enum.Material.WoodPlanks)
	local attic = math.sqrt(2) * 8
	part(parent, "BarnAttic", Vector3.new(21.8, attic, attic), rel(0, 14, 0) * CFrame.Angles(math.rad(45), 0, 0), red, Enum.Material.WoodPlanks)
	for _, side in { 1, -1 } do
		part(parent, "BarnRoof", Vector3.new(24, 1, 13.5), rel(0, 18.2, side * 4.6) * CFrame.Angles(-side * math.rad(45), 0, 0), rgb(90, 85, 90), Enum.Material.Slate)
	end
	part(parent, "BarnDoor", Vector3.new(9, 10, 0.4), rel(0, 5, 9.1), rgb(160, 50, 45), Enum.Material.WoodPlanks)
	for _, sgn in { 1, -1 } do
		part(parent, "BarnBrace", Vector3.new(0.6, 12.5, 0.3), rel(0, 5, 9.4) * CFrame.Angles(0, 0, sgn * math.rad(42)), white, Enum.Material.WoodPlanks)
	end
	part(parent, "BarnTrim", Vector3.new(9.6, 0.6, 0.35), rel(0, 10.2, 9.4), white, Enum.Material.WoodPlanks)
	part(parent, "HayLoft", Vector3.new(4, 4, 0.4), rel(0, 15, 9.1), rgb(60, 40, 30), Enum.Material.WoodPlanks)
end

local function silo(parent: Instance, x: number, z: number)
	cylinder(parent, "Silo", 22, 9, x, 11, z, rgb(215, 215, 220), Enum.Material.Metal)
	ball(parent, "SiloDome", 9, x, 22, z, rgb(110, 150, 200), Enum.Material.Metal)
	for i = 1, 4 do
		cylinder(parent, "SiloBand", 0.5, 9.3, x, i * 4.5, z, rgb(170, 170, 175), Enum.Material.Metal)
	end
end

local function farm(parent: Instance, s: any)
	local model = Instance.new("Model")
	model.Name = "Farm"
	model.Parent = parent
	local crops = { rgb(240, 200, 70), rgb(80, 170, 70), rgb(140, 200, 80), rgb(245, 140, 40) }
	for i, f in Landscape.Fields do
		local x0, z0 = f.x - f.w / 2, f.z - f.d / 2
		local rows = 5
		for r = 1, rows do
			local rz = z0 + r * f.d / (rows + 1)
			part(model, "CropRow", Vector3.new(f.w - 5, 1.6, 2.2), at(f.x, 0.6, rz), crops[i], Enum.Material.Grass)
			if i == 4 then
				for k = 0, 4 do
					ball(model, "Pumpkin", 1.8, x0 + 5 + k * (f.w - 10) / 4, 1.6, rz, rgb(245, 130, 30), Enum.Material.SmoothPlastic)
				end
			end
		end
		-- split-rail fence round the field
		local fenceColor = rgb(150, 105, 70)
		for _, e in { { f.x, z0, f.w, true }, { f.x, z0 + f.d, f.w, true }, { x0, f.z, f.d, false }, { x0 + f.w, f.z, f.d, false } } do
			local size = if e[4] then Vector3.new(e[3], 0.4, 0.4) else Vector3.new(0.4, 0.4, e[3])
			part(model, "Rail", size, at(e[1], 1.4, e[2]), fenceColor, Enum.Material.Wood)
			part(model, "Rail", size, at(e[1], 2.6, e[2]), fenceColor, Enum.Material.Wood)
			local posts = math.floor(e[3] / 6.5)
			for k = 0, posts do
				local t = -e[3] / 2 + k * e[3] / posts
				local px, pz = if e[4] then e[1] + t else e[1], if e[4] then e[2] else e[2] + t
				part(model, "FencePost", Vector3.new(0.6, 3.4, 0.6), at(px, 1.7, pz), rgb(120, 85, 55), Enum.Material.Wood)
			end
		end
	end
	scarecrow(model, 372, 240)
	scarecrow(model, 414, 300)
	barn(model, s.x + 58, s.z - 6, Vector3.new(-1, 0, 0))
	silo(model, s.x + 60, s.z + 22)
	windmill(model, s.x - 2, s.z - 60, Vector3.new(-0.6, 0, -0.8).Unit)
	haystack(model, s.x + 40, s.z - 34, 5)
	haystack(model, s.x + 46, s.z - 26, 4)
	haystack(model, s.x + 36, s.z + 40, 5.5)
	cart(model, s.x + 30, s.z + 50, math.rad(-30), rgb(240, 200, 70))
	barrel(model, s.x + 44, s.z + 8)
	crate(model, s.x + 44, 0, s.z + 13, 2.8, 0.3)
	lift(model, s.h)
end

local function watchtower(parent: Instance, s: any)
	local model = Instance.new("Model")
	model.Name = "Watchtower"
	model.Parent = parent
	cylinder(model, "Base", 4, 16, 0, 2, 0, rgb(170, 165, 158), Enum.Material.Cobblestone)
	coneTower(model, 0, 0, 0, 11, 36, rgb(60, 160, 150), rgb(255, 210, 80))
	for i = 1, 3 do
		cylinder(model, "Band", 1, 11.8, 0, i * 9, 0, rgb(170, 165, 158), Enum.Material.Cobblestone)
		part(model, "Slit", Vector3.new(0.4, 3, 1), at(5.6, i * 9 + 4, 0), rgb(255, 210, 130), Enum.Material.Neon)
	end
	local fire = ball(model, "Beacon", 2.6, 0, 38.5, 0, rgb(255, 170, 70), Enum.Material.Neon)
	glowLight(fire, 50, 1.6, rgb(255, 190, 110))
	part(model, "Door", Vector3.new(0.6, 6, 3.5), at(5.6, 3, 0), rgb(110, 75, 50), Enum.Material.WoodPlanks)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = p.CFrame + Vector3.new(s.x, s.h, s.z)
		end
	end
end

-- Arched timber bridge across the lagoon on stone piers, with rails and lamps.
local function bridge(parent: Instance, x0: number, z0: number, x1: number, z1: number)
	local model = Instance.new("Model")
	model.Name = "Bridge"
	model.Parent = parent
	local y0 = 0.6
	local y1 = math.max(Landscape.height(x1, z1), 0) + 0.6
	local a, b = Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z1)
	local length = (b - a).Magnitude
	local dir = (b - a).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local function point(f: number): Vector3
		local p = a + (b - a) * f
		return Vector3.new(p.X, y0 + (y1 - y0) * f + math.sin(f * math.pi) * 5, p.Z)
	end
	local n = math.floor(length / 6)
	for i = 0, n - 1 do
		local p0, p1 = point(i / n), point((i + 1) / n)
		local mid = (p0 + p1) / 2
		part(model, "Deck", Vector3.new(9, 0.8, (p1 - p0).Magnitude + 0.3), CFrame.lookAt(mid, p1), rgb(165, 120, 80), Enum.Material.WoodPlanks)
		for _, sgn in { -1, 1 } do
			local q0, q1 = p0 + side * sgn * 4.3 + Vector3.new(0, 2.6, 0), p1 + side * sgn * 4.3 + Vector3.new(0, 2.6, 0)
			part(model, "Rail", Vector3.new(0.4, 0.4, (q1 - q0).Magnitude), CFrame.lookAt((q0 + q1) / 2, q1), rgb(130, 90, 60), Enum.Material.Wood)
			local post = p0 + side * sgn * 4.3 + Vector3.new(0, 1.3, 0)
			part(model, "RailPost", Vector3.new(0.6, 2.8, 0.6), CFrame.new(post), rgb(120, 85, 55), Enum.Material.Wood)
		end
		if i % 3 == 1 then
			part(model, "Pier", Vector3.new(7, mid.Y + 9, 4), CFrame.lookAt(Vector3.new(mid.X, (mid.Y - 9.4) / 2, mid.Z), Vector3.new(mid.X, (mid.Y - 9.4) / 2, mid.Z) + dir), rgb(175, 170, 160), Enum.Material.Cobblestone)
		end
	end
	for _, f in { 0, 1 } do
		local p = point(f)
		for _, sgn in { -1, 1 } do
			local post = p + side * sgn * 5.2
			cylinder(model, "LampPost", 9, 0.6, post.X, p.Y + 4.5, post.Z, rgb(60, 60, 70), Enum.Material.Metal)
			local bulb = ball(model, "LampBulb", 1.6, post.X, p.Y + 9.4, post.Z, rgb(255, 230, 160), Enum.Material.Neon)
			glowLight(bulb, 16, 1, rgb(255, 225, 160))
		end
	end
end

-- A list of round footprints already used in a village, so nothing lands on top of anything.
local function footprints()
	local used: { { number } } = {}
	local function free(x: number, z: number, r: number, roadMargin: number?): boolean
		if Landscape.onRoad(x, z, roadMargin or r) then
			return false
		end
		for _, u in used do
			if (x - u[1]) ^ 2 + (z - u[2]) ^ 2 < (r + u[3]) ^ 2 then
				return false
			end
		end
		return true
	end
	local function take(x: number, z: number, r: number)
		table.insert(used, { x, z, r })
	end
	return free, take
end

-- Highcrag: a mountain village of tall timber houses on a terrace below Ember Peak, with a
-- beacon plaza, prayer flags, a bell tower, an outfitter and a climbers' lodge. Quest givers
-- (Shared/Quests) stand round the plaza; WildsBuilder places them.
local function mountainVillage(parent: Instance, s: any)
	local model = Instance.new("Model")
	model.Name = "Highcrag"
	model.Parent = parent
	local x, z = s.x, s.z
	local free, take = footprints()
	-- the people round the plaza (Quests: hesk, yara, tobbin) and the plaza itself
	take(x, z, 10)
	for _, o in { { 16, 0 }, { 5.5, 15 }, { 10.3, -12.3 } } do
		take(x + o[1], z + o[2], 4)
	end
	cylinder(model, "Plaza", 0.4, 24, x, 0.2, z, rgb(150, 145, 140), Enum.Material.Slate)
	cylinder(model, "BeaconBase", 3, 6, x, 1.5, z, rgb(120, 115, 110), Enum.Material.Cobblestone)
	cylinder(model, "BeaconPillar", 8, 2.6, x, 7, z, rgb(135, 128, 120), Enum.Material.Cobblestone)
	cylinder(model, "BeaconBowl", 1.4, 5, x, 11.6, z, rgb(60, 55, 55), Enum.Material.Metal)
	local flame = ball(model, "BeaconFlame", 3, x, 13, z, rgb(255, 160, 60), Enum.Material.Neon)
	glowLight(flame, 40, 1.6, rgb(255, 180, 100))
	-- shops: the Highcrag Outfitter and the Climbers' Lodge (cooking)
	local shops = { { "Highcrag Outfitter", 200, "outfitter", rgb(80, 130, 90) }, { "Climbers' Lodge", 35, "lodge", rgb(170, 70, 50) } }
	for _, sh in shops do
		local a = math.rad(sh[2])
		local sx, sz = x + math.cos(a) * 26, z + math.sin(a) * 26
		take(sx, sz, 9)
		local face = Vector3.new(x - sx, 0, z - sz).Unit
		local st = stall(model, sh[1], sx, sz, face, 12, sh[4])
		local anchor = part(st, "ShopAnchor", Vector3.new(3, 3, 3), CFrame.new(sx + face.X * 3, 2, sz + face.Z * 3), rgb(255, 255, 255), nil, { Transparency = 1, CanCollide = false })
		anchor:SetAttribute("Shop", sh[3])
	end
	-- the bell tower
	local ta = math.rad(115)
	local tx, tz = x + math.cos(ta) * 38, z + math.sin(ta) * 38
	if free(tx, tz, 7) then
		take(tx, tz, 7)
		coneTower(model, tx, 0, tz, 9, 26, rgb(70, 80, 95), rgb(230, 120, 60))
		ball(model, "Bell", 3, tx, 22, tz, rgb(220, 180, 70), Enum.Material.Metal)
	end
	-- tall houses round the terrace, facing the plaza
	local n = 0
	for k = 0, 119 do -- walk round the ring, building wherever a house fits
		local a = k / 120 * math.pi * 2 + 0.2
		for _, r in { 39, 33 } do
			local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
			if free(px, pz, 7.5, 6) then
				take(px, pz, 8)
				n += 1
				cottage(model, px, pz, Vector3.new(x - px, 0, z - pz).Unit, 40 + n, if n % 3 == 0 then 1 else 2)
				break
			end
		end
	end
	-- lamps with prayer flags strung between them
	local lamps = {}
	for k = 0, 9 do
		local a = (k + 0.5) / 10 * math.pi * 2
		local lx, lz = x + math.cos(a) * 12, z + math.sin(a) * 12
		if free(lx, lz, 1, 2) then
			take(lx, lz, 3)
			lamp(model, lx, lz)
			table.insert(lamps, Vector3.new(lx, 11.4, lz))
		end
	end
	for k = 1, #lamps - 1 do
		festoon(model, lamps[k], lamps[k + 1], k)
	end
	for _, b in { { 9, -6 }, { -8, 8 } } do
		if free(x + b[1], z + b[2], 2, 3) then
			barrel(model, x + b[1], z + b[2])
		end
	end
	lift(model, s.h)
	-- pines on the slopes round the terrace (on the real ground, not lifted)
	local trees = Instance.new("Model")
	trees.Name = "HighcragPines"
	trees.Parent = parent
	for k = 0, 17 do
		local a = k / 18 * math.pi * 2 + hash(k + 70) * 0.3
		local r = 56 + hash(k + 90) * 22
		local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
		if not Landscape.onRoad(px, pz, 6) and not Landscape.onSite(px, pz, 4) then
			pine(trees, px, pz, 1 + hash(k + 11) * 0.5, 300 + k, Landscape.height(px, pz) - 0.5)
		end
	end
end

-- Saltmere: a fishing village on the beach over Saltwind Pass, with a long pier and lighthouse,
-- moored boats, palms, parasols, a tide market and an inn. The Tidewrack Grotto opens at the
-- water's edge (DungeonBuilder); quest givers stand round the boardwalk square (WildsBuilder).
local function beachVillage(parent: Instance, s: any)
	local model = Instance.new("Model")
	model.Name = "Saltmere"
	model.Parent = parent
	local x, z = s.x, s.z
	local free, take = footprints()
	take(x, z, 12)
	for _, o in { { 0, 16 }, { 15, 5.5 }, { -15, 5.5 } } do
		take(x + o[1], z + o[2], 4)
	end
	take(x - 30, z + 28, 14) -- the grotto's sea-cave entrance
	-- boardwalk square with a fish-drying rack and a fountain of shells
	part(model, "Boardwalk", Vector3.new(24, 0.6, 24), at(x, 0.3, z), rgb(190, 150, 105), Enum.Material.WoodPlanks)
	cylinder(model, "ShellFountain", 1.6, 8, x, 1.4, z, rgb(235, 225, 210), Enum.Material.Marble)
	ball(model, "Pearl", 2.6, x, 3.6, z, rgb(240, 245, 255), Enum.Material.Glass)
	-- the pier south into the sea, with a lighthouse on its end and boats alongside
	local pier = Instance.new("Model")
	pier.Name = "Pier"
	pier.Parent = parent
	local p0, p1 = z + 40, z + 125
	take(x, z + 44, 6)
	part(pier, "PierDeck", Vector3.new(8, 0.8, p1 - p0), at(x, s.h + 1.4, (p0 + p1) / 2), rgb(165, 120, 80), Enum.Material.WoodPlanks)
	for pz = p0 + 4, p1 - 2, 10 do
		for _, sg in { -1, 1 } do
			part(pier, "PierPost", Vector3.new(1, 18, 1), at(x + sg * 3.6, s.h - 7.4, pz), rgb(110, 80, 55), Enum.Material.Wood)
			part(pier, "PierRail", Vector3.new(0.4, 0.4, 10), at(x + sg * 3.8, s.h + 3.6, pz + 5), rgb(130, 95, 60), Enum.Material.Wood)
		end
	end
	part(pier, "PierEnd", Vector3.new(18, 0.8, 18), at(x, s.h + 1.4, p1 + 8), rgb(165, 120, 80), Enum.Material.WoodPlanks)
	lighthouse(pier, x, s.h + 1.8, p1 + 8)
	boat(pier, x - 11, z + 75, math.rad(5), rgb(80, 160, 230))
	boat(pier, x + 11, z + 100, math.rad(-8), rgb(240, 200, 70))
	boat(pier, x - 12, z + 108, math.rad(12), rgb(230, 100, 90))
	for _, b in pier:GetChildren() do
		if b.Name == "Boat" then
			lift(b, -1.5)
		end
	end
	-- shops: the Tide Market and the Salty Gull inn (cooking)
	local shops = { { "Tide Market", -40, "tidemarket", rgb(60, 150, 210) }, { "The Salty Gull", -100, "gull", rgb(240, 170, 60) } }
	for _, sh in shops do
		local a = math.rad(sh[2])
		local sx, sz = x + math.cos(a) * 26, z + math.sin(a) * 26
		take(sx, sz, 9)
		local face = Vector3.new(x - sx, 0, z - sz).Unit
		local st = stall(model, sh[1], sx, sz, face, 12, sh[4])
		local anchor = part(st, "ShopAnchor", Vector3.new(3, 3, 3), CFrame.new(sx + face.X * 3, 2, sz + face.Z * 3), rgb(255, 255, 255), nil, { Transparency = 1, CanCollide = false })
		anchor:SetAttribute("Shop", sh[3])
	end
	-- fishers' cottages round the square
	local n = 0
	for k = 0, 119 do -- walk round the ring, building wherever a house fits
		local a = k / 120 * math.pi * 2 + 0.1
		for _, r in { 40, 34 } do
			local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
			if free(px, pz, 7.5, 6) then
				take(px, pz, 8)
				n += 1
				cottage(model, px, pz, Vector3.new(x - px, 0, z - pz).Unit, 60 + n, 1, if n % 2 == 0 then rgb(80, 170, 220) else rgb(250, 250, 245))
				break
			end
		end
	end
	-- parasols, nets and lamps on the sand
	local colors = { rgb(240, 80, 90), rgb(255, 210, 70), rgb(80, 180, 240), rgb(120, 220, 140) }
	for k = 0, 13 do
		local a = k / 14 * math.pi * 2 + 0.5
		local px, pz = x + math.cos(a) * 21, z + math.sin(a) * 21
		if free(px, pz, 2.5, 2) then
			take(px, pz, 3)
			cylinder(model, "ParasolPole", 7, 0.4, px, 3.5, pz, rgb(240, 240, 240))
			cone(model, "Parasol", px, 6.6, pz, 4.5, 2, colors[k % #colors + 1], Enum.Material.Fabric, 8)
		end
	end
	for k = 0, 7 do
		local a = (k + 0.5) / 8 * math.pi * 2
		local lx, lz = x + math.cos(a) * 13.5, z + math.sin(a) * 13.5
		if free(lx, lz, 1, 2) then
			take(lx, lz, 4)
			lamp(model, lx, lz)
		end
	end
	for _, c in { { 30, 8 }, { -8, -30 }, { 28, -24 } } do
		if free(x + c[1], z + c[2], 3.5, 2) then
			take(x + c[1], z + c[2], 3.5)
			part(model, "NetRack", Vector3.new(6, 0.4, 0.4), at(x + c[1], 4, z + c[2]), rgb(110, 80, 55), Enum.Material.Wood)
			part(model, "Net", Vector3.new(5.6, 3.4, 0.1), at(x + c[1], 2.2, z + c[2]), rgb(200, 190, 160), Enum.Material.Fabric).Transparency = 0.4
			for _, sg in { -1, 1 } do
				part(model, "NetPost", Vector3.new(0.4, 4, 0.4), at(x + c[1] + sg * 3, 2, z + c[2]), rgb(110, 80, 55), Enum.Material.Wood)
			end
		end
	end
	-- palms along the beach
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2 + hash(k + 40) * 0.3
		local r = 43 + hash(k + 50) * 6
		local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
		if free(px, pz, 3, 5) then
			take(px, pz, 3)
			palm(model, px, pz, Vector3.new(math.cos(a), 0, math.sin(a)) * 0.6, 80 + k)
		end
	end
	-- rocks round the grotto mouth
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		ball(model, "CaveRock", 6 + hash(k + 3) * 5, x - 30 + math.cos(a) * 11, 1, z + 28 + math.sin(a) * 11, rgb(120, 125, 130), Enum.Material.Rock)
	end
	lift(model, s.h)
	-- palms along the open beaches either side (Landscape sites "strand" and "cove")
	local beachPalms = Instance.new("Model")
	beachPalms.Name = "BeachPalms"
	beachPalms.Parent = parent
	for i, name in { "strand", "cove" } do
		local b = Landscape.Sites[name]
		if b then
			for k = 0, 7 do
				local a = k / 8 * math.pi * 2 + i
				local r = b.r * (0.65 + hash(k * 7 + i) * 0.3)
				local px, pz = b.x + math.cos(a) * r, b.z + math.sin(a) * r
				if Landscape.height(px, pz) > 0.5 and not Landscape.onRoad(px, pz, 4) then
					palm(beachPalms, px, pz, Vector3.new(math.cos(a), 0, math.sin(a)) * 0.6, 120 + k + i * 10)
				end
			end
		end
	end
	lift(beachPalms, 1.2)
	-- sea stacks offshore
	seaStack(parent, x - 150, z + 40, 34, 61)
	seaStack(parent, x - 120, z + 130, 26, 62)
	seaStack(parent, x + 90, z + 150, 30, 63)
end

-- The cairn and prayer flags on the Saltwind Pass summit, beside the trail (Lookout = "pass" is
-- Yara's quest spot).
local function passSummit(parent: Instance, s: any)
	local model = Instance.new("Model")
	model.Name = "SaltwindSummit"
	model.Parent = parent
	local d, sample = Landscape.nearestRoad(s.x, s.z)
	local x, z = s.x, s.z
	if sample and d < 30 then
		local nx, nz = -sample.tz, sample.tx
		x, z = sample.x + nx * (sample.hw + 7), sample.z + nz * (sample.hw + 7)
	end
	local y = Landscape.height(x, z)
	for k = 0, 4 do
		local dd = 3.6 - k * 0.6
		ball(model, "CairnStone", dd, x, y + 0.4 + k * 1.9, z, rgb(150 - k * 6, 145 - k * 6, 135 - k * 6), Enum.Material.Slate)
	end
	cylinder(model, "FlagPole", 12, 0.4, x, y + 6, z, rgb(110, 80, 50), Enum.Material.Wood)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		festoon(model, Vector3.new(x, y + 11.6, z), Vector3.new(x + math.cos(a) * 12, y + 3, z + math.sin(a) * 12), k)
	end
	signpost(model, x + 4, z + 4, "Saltwind Pass", rgb(190, 230, 255))
	for _, p in model:GetChildren() do
		if p.Name == "SignPole" or p.Name == "SignBoard" then
			p.CFrame = p.CFrame + Vector3.new(0, y, 0)
		end
	end
	local spot = part(model, "LookoutSpot", Vector3.new(4, 1, 4), CFrame.new(x, y + 1.5, z), rgb(255, 255, 255), nil, { Transparency = 1, CanCollide = false })
	spot:SetAttribute("Lookout", "pass")
end

-- Guideposts along the journey from the city to the far coast, beside the road near (x, z).
local GUIDEPOSTS = {
	{ -480, 985, "Ember Trail: Highcrag, Ember Peak, Saltmere" },
	{ -826, 1505, "Highcrag village / Emberdeep Caldera" },
	{ -790, 1622, "Saltwind Pass: over the mountain to Saltmere" },
	{ -948, 1766, "Saltmere beach / Tidewrack Grotto" },
	{ -462, -412, "Miners' Track: Deepdelve Mines" },
	{ 362, -246, "Observatory Trail / Hermit's Climb" },
	{ -560, 905, "Watch Road: Pinecrest and the west" },
	{ 95, 1630, "Old Fort Track / Southvale" },
}

local function guideposts(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Guideposts"
	folder.Parent = parent
	for k, g in GUIDEPOSTS do
		local x, z = g[1], g[2]
		local d, sample = Landscape.nearestRoad(x, z)
		if sample and d < 40 then
			local nx, nz = -sample.tz, sample.tx
			x, z = sample.x + nx * (sample.hw + 4), sample.z + nz * (sample.hw + 4)
		end
		local m = Instance.new("Model")
		m.Name = "Guidepost" .. k
		m.Parent = folder
		signpost(m, x, z, g[3], rgb(255, 235, 170))
		lift(m, Landscape.height(x, z) - 0.3)
	end
end

local function nearPath(x: number, z: number, margin: number): boolean
	if Landscape.onRoad(x, z, margin) then
		return true
	end
	for _, br in Landscape.Bridges do
		local dx, dz = x - br[3], z - br[4]
		if dx * dx + dz * dz < (margin * 2) ^ 2 then
			return true
		end
	end
	return false
end

local function buildHills(scenery: Instance)
	if not Landscape then
		return
	end
	local hills = Instance.new("Folder")
	hills.Name = "Hills"
	hills.Parent = scenery
	local sites = Landscape.Sites

	castle(hills, sites.castle)
	hamlet(hills, sites.hamletWest, 1, "Bakery", rgb(240, 170, 80))
	hamlet(hills, sites.hamletEast, 2, "Florist", rgb(240, 120, 170))
	farm(hills, sites.farm)
	watchtower(hills, sites.watch)
	lighthouse(hills, sites.cape.x, sites.cape.h, sites.cape.z)
	local ruinsFolder = Instance.new("Folder")
	ruinsFolder.Name = "Ruins"
	ruinsFolder.Parent = hills
	ruins(ruinsFolder, sites.ruins.x, sites.ruins.h, sites.ruins.z)
	ruins(ruinsFolder, sites.oldfort.x, sites.oldfort.h, sites.oldfort.z)
	-- villages out in the wider land
	hamlet(hills, sites.southvale, 3, "Cheesemonger", rgb(250, 210, 90))
	hamlet(hills, sites.eastmere, 4, "Weaver", rgb(120, 170, 240))
	hamlet(hills, sites.pinecrest, 5, "Woodcutter", rgb(150, 110, 70))
	if sites.highcrag then
		mountainVillage(hills, sites.highcrag)
	end
	if sites.saltmere then
		beachVillage(hills, sites.saltmere)
	end
	if sites.windpass then
		passSummit(hills, sites.windpass)
	end
	guideposts(hills)
	for _, br in Landscape.Bridges do
		bridge(hills, br[1], br[2], br[3], br[4])
	end

	-- waterfall cliff: a stream across the plateau, the cascade, a lookout and a rainbow
	local falls = sites.falls
	local fallsModel = Instance.new("Model")
	fallsModel.Name = "Falls"
	fallsModel.Parent = hills
	deco(part(fallsModel, "Stream", Vector3.new(10, 0.6, 60), at(0, falls.h + 0.15, falls.z - 2), rgb(80, 175, 230), Enum.Material.Glass)).Transparency = 0.15
	for _, sgn in { -1, 1 } do
		for k = 0, 4 do
			ball(fallsModel, "StreamRock", 2.5 + hash(k + sgn) * 2, sgn * 6.5, falls.h, falls.z - 28 + k * 12, rgb(150, 140, 130), Enum.Material.Rock)
		end
	end
	cascade(fallsModel, Vector3.new(0, falls.h + 0.5, -556), Vector3.new(0, Landscape.WaterLevel, -534), 12)
	for i = 0, 9 do
		local a = i / 10 * math.pi + math.pi
		local rx, rz = math.cos(a) * 26, -515 - math.sin(a) * 24
		ball(fallsModel, "PoolRock", 4 + hash(i + 80) * 5, rx, math.max(Landscape.height(rx, rz), Landscape.WaterLevel) - 0.5, rz, rgb(150, 140, 130), Enum.Material.Rock)
	end
	gazebo(fallsModel, 28, falls.h, -590, rgb(205, 85, 70))
	rainbow(fallsModel, 0, Landscape.WaterLevel, -508, 34)

	-- trees, rocks and wildflowers over the hills
	local wild = Instance.new("Folder")
	wild.Name = "Wilds"
	wild.Parent = hills
	local bounds = Landscape.Bounds
	local step = 21
	local pines, broadleaf, rocks = 0, 0, 0
	local i = 0
	for gz = bounds.z0, bounds.z1, step do
		for gx = bounds.x0, bounds.x1, step do
			i += 1
			local x = gx + (hash(i * 1.3) - 0.5) * step * 0.8
			local z = gz + (hash(i * 2.7) - 0.5) * step * 0.8
			-- the city plants its own trees; the far land gets lighter trees and fewer flowers
			local far = math.sqrt(x * x + (z - 300) ^ 2) > 800
			if not Landscape.inPlayArea(x, z) and Landscape.cityWeight(x, z) < 0.15 then
				local h = Landscape.height(x, z)
				local slope = Landscape.slope(x, z)
				local dense = Landscape.fbm(x / 90 + 11, z / 90 - 4)
				if h > 3 and slope < 0.75 and not Landscape.onSite(x, z, 10) and not nearPath(x, z, 8) then
					if dense > 0.55 and hash(i + 0.5) < 0.45 then
						if hash(i + 0.9) < (if h > 28 then 0.6 else 0.3) then
							pines += 1
							if far then
								lightPine(wild, x, z, 1 + hash(i) * 0.8, i, h - 0.6)
							else
								pine(wild, x, z, 0.9 + hash(i) * 0.7, i, h - 0.6)
							end
						else
							broadleaf += 1
							tree(wild, x, z, 0.9 + hash(i) * (if far then 0.9 else 0.6), i, h - 0.6)
						end
					elseif far and dense > 0.45 and hash(i + 0.6) < 0.25 then
						-- scattered trees between the far forests
						broadleaf += 1
						tree(wild, x, z, 0.8 + hash(i) * 0.7, i, h - 0.6)
					elseif hash(i + 0.2) < (if far then 0.03 else 0.12) then
						local flowers = { rgb(255, 120, 160), rgb(255, 230, 100), rgb(255, 255, 255), rgb(180, 140, 255) }
						for k = 1, 4 do
							ball(wild, "Wildflower", 1, x + (hash(i + k) - 0.5) * 4, h + 0.35, z + (hash(i + k * 3) - 0.5) * 4, flowers[(i + k) % 4 + 1])
						end
					end
				elseif h > 2 and slope >= 0.75 and hash(i + 0.4) < 0.3 then
					rocks += 1
					ball(wild, "Boulder", 5 + hash(i) * 7, x, h, z, rgb(150, 140, 130), Enum.Material.Rock)
				end
			end
		end
	end
	hills:SetAttribute("Pines", pines)
	hills:SetAttribute("Broadleaf", broadleaf)
	hills:SetAttribute("Rocks", rocks)
end

local function buildScenery(map: Instance)
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = map

	-- Village: cottages in the strips between the avenue and the plots, facing the avenue.
	local village = Instance.new("Folder")
	village.Name = "Village"
	village.Parent = scenery
	local seed = 0
	for _, z in { -195, -145, 145, 195 } do
		for _, side in { -1, 1 } do
			seed += 1
			cottage(village, side * 75, z, Vector3.new(-side, 0, 0), seed)
		end
	end
	-- north end, either side of the pond, and the south-west corner
	cottage(village, -110, -275, Vector3.new(1, 0, 0), 11)
	cottage(village, 110, -275, Vector3.new(-1, 0, 0), 12)
	cottage(village, -95, 262, Vector3.new(1, 0, -0.4).Unit, 13)
	windmill(village, 112, 255, Vector3.new(-1, 0, -0.3).Unit)
	lanternTower(village, -62, -245, rgb(70, 110, 180))
	lanternTower(village, 62, -245, rgb(205, 85, 70))
	lanternTower(village, -60, 232, rgb(60, 160, 150))
	lanternTower(village, 60, 225, rgb(150, 90, 170))

	-- Festoon lights strung across the avenue between the lamp pairs (skipping the Plaza).
	local lights = Instance.new("Folder")
	lights.Name = "Festoons"
	lights.Parent = scenery
	for i, z in { -250, -200, -130, -90, 120, 160, 200 } do
		festoon(lights, Vector3.new(-24, 13.2, z), Vector3.new(24, 13.2, z + 20), i)
	end

	-- Light beams: the Dewdrop fountain, the Rebirth Shrine and the Sky Garden lift.
	local beams = Instance.new("Folder")
	beams.Name = "Beams"
	beams.Parent = scenery
	lightBeam(beams, "DewdropBeam", 0, 19, 0, 420, 4, rgb(120, 225, 255))
	lightBeam(beams, "ShrineBeam", -50, 9, 0, 320, 2.4, rgb(200, 150, 255))
	lightBeam(beams, "SkyLiftBeam", 0, 1, 240, 92, 5, rgb(190, 140, 255))
	lightBeam(beams, "SkyWellBeam", 0, 97, 305, 260, 3, rgb(220, 180, 255))

	-- Glowing crystals around the Wishing Pond and on the Sky Garden.
	local crystals = Instance.new("Folder")
	crystals.Name = "Crystals"
	crystals.Parent = scenery
	crystal(crystals, -58, 0, -305, 1.1, rgb(120, 230, 255), 1, false)
	crystal(crystals, 58, 0, -310, 1, rgb(255, 130, 200), 2, false)
	crystal(crystals, -30, 0, -352, 0.9, rgb(190, 140, 255), 3, false)
	crystal(crystals, 32, 0, -350, 1.2, rgb(140, 255, 170), 4, false)
	crystal(crystals, -18, 92, 300, 0.8, rgb(220, 170, 255), 5, false)
	crystal(crystals, 18, 92, 300, 0.8, rgb(120, 230, 255), 6, false)
	-- small floating ones that bob over the pond and plaza edges
	crystal(crystals, -36, 14, -318, 0.5, rgb(255, 190, 110), 7, true)
	crystal(crystals, 38, 16, -290, 0.5, rgb(120, 230, 255), 8, true)
	crystal(crystals, -75, 18, -60, 0.5, rgb(255, 130, 200), 9, true)
	crystal(crystals, 75, 18, -60, 0.5, rgb(190, 140, 255), 10, true)

	-- Drifting motes: gold over the Plaza, blue over the pond, violet on the Sky Garden.
	local fx = Instance.new("Folder")
	fx.Name = "Ambient"
	fx.Parent = scenery
	motes(fx, "PlazaMotes", CFrame.new(0, 9, 0), Vector3.new(120, 12, 120), rgb(255, 225, 130), 14)
	motes(fx, "AvenueMotesNorth", CFrame.new(0, 7, -170), Vector3.new(60, 10, 160), rgb(255, 240, 170), 6)
	motes(fx, "AvenueMotesSouth", CFrame.new(0, 7, 180), Vector3.new(60, 10, 160), rgb(255, 240, 170), 6)
	motes(fx, "PondMotes", CFrame.new(0, 5, -300), Vector3.new(90, 8, 90), rgb(140, 220, 255), 10)
	motes(fx, "SkyGardenMotes", CFrame.new(0, 100, 300), Vector3.new(70, 14, 70), rgb(220, 180, 255), 10)
	local mist = deco(part(fx, "PondMist", Vector3.new(80, 1, 80), CFrame.new(0, 1.6, -300), rgb(255, 255, 255), nil, { Transparency = 1 }))
	emitter(mist, "Mist", {
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Color = ColorSequence.new(rgb(225, 245, 255)),
		Size = fade(6, 12),
		Rate = 4,
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(0.3, 0.8),
		SpreadAngle = Vector2.new(180, 10),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		}),
		RotSpeed = NumberRange.new(-8, 8),
	})

	-- Sky Garden waterfall pouring off its south edge.
	waterfall(fx, -30, 86, 328, 8, Vector3.new(0, 0, -1))

	-- Out over the sea: floating islets (some with waterfalls) and clouds, for depth.
	local sky = Instance.new("Folder")
	sky.Name = "Skyline"
	sky.Parent = scenery
	for i, it in Landscape.SkyIslets do
		floatingIslet(sky, it.x, it.y, it.z, it.r, i, it.falls)
	end
	local clouds = {
		{ -260, 260, -300, 1.4 }, { 250, 280, -150, 1.2 }, { -380, 240, 100, 1.6 }, { 380, 300, 250, 1.3 },
		{ 0, 320, -620, 1.8 }, { -200, 290, 480, 1.2 }, { 260, 250, 520, 1 }, { 520, 270, -420, 1.5 },
		{ -540, 300, -120, 1.7 }, { 120, 340, 40, 1.1 },
	}
	for i, c in clouds do
		cloud(sky, c[1], c[2], c[3], c[4], i)
	end
	buildLandscape(scenery)
	buildDetails(scenery)
	buildHills(scenery)
end

----------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------
-- the garden houses and Greenhollow Gardens

-- Each garden house has its own plant theme for its planters and potted plants.
local PLOT_THEMES = {
	{ name = "Rose Cottage", kind = "flower", bloom = { 230, 50, 70 }, leaf = { 60, 140, 60 } },
	{ name = "Marigold House", kind = "flower", bloom = { 255, 150, 40 }, leaf = { 70, 150, 60 } },
	{ name = "Sunflower Lodge", kind = "sunflower", bloom = { 255, 210, 40 }, leaf = { 80, 160, 60 } },
	{ name = "Fernery", kind = "fern", bloom = { 90, 190, 90 }, leaf = { 60, 150, 70 } },
	{ name = "Mint Conservatory", kind = "mushroom", bloom = { 90, 210, 200 }, leaf = { 240, 240, 230 } },
	{ name = "Bluebell Barn", kind = "flower", bloom = { 90, 130, 240 }, leaf = { 60, 140, 70 } },
	{ name = "Lilac Loft", kind = "tree", bloom = { 180, 130, 240 }, leaf = { 110, 80, 55 } },
	{ name = "Blossom Hall", kind = "tree", bloom = { 255, 170, 205 }, leaf = { 110, 80, 55 } },
}

-- A plant in the house's theme standing on the ground at world point p (y = its base).
local function themePlant(parent: Instance, theme: any, p: Vector3, scale: number, seed: number)
	local bloom = rgb(theme.bloom[1], theme.bloom[2], theme.bloom[3])
	local leaf = rgb(theme.leaf[1], theme.leaf[2], theme.leaf[3])
	local x, y, z = p.X, p.Y, p.Z
	if theme.kind == "sunflower" then
		cylinder(parent, "Stem", 4.5 * scale, 0.35 * scale, x, y + 2.25 * scale, z, leaf)
		local head = part(parent, "Bloom", Vector3.new(0.4, 2.2, 2.2) * scale, CFrame.new(x, y + 4.8 * scale, z) * CFrame.Angles(0, seed, math.rad(20)), bloom, Enum.Material.SmoothPlastic)
		head.Shape = Enum.PartType.Cylinder
		ball(parent, "Seeds", 1.1 * scale, x, y + 4.8 * scale, z, rgb(110, 70, 40))
	elseif theme.kind == "fern" then
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2 + seed
			part(parent, "Frond", Vector3.new(0.3, 0.2, 3) * scale, CFrame.new(x, y + 1.2 * scale, z) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, 0, -1.3 * scale), bloom, Enum.Material.Grass)
		end
	elseif theme.kind == "mushroom" then
		cylinder(parent, "MushroomStem", 2 * scale, 0.8 * scale, x, y + 1 * scale, z, leaf)
		local cap = ball(parent, "MushroomCap", 2.4 * scale, x, y + 2.2 * scale, z, bloom, Enum.Material.SmoothPlastic)
		cap.Size = Vector3.new(2.6, 1.4, 2.6) * scale
	elseif theme.kind == "tree" then
		cylinder(parent, "Trunk", 3 * scale, 0.5 * scale, x, y + 1.5 * scale, z, leaf, Enum.Material.Wood)
		ball(parent, "Canopy", 3 * scale, x, y + 3.6 * scale, z, bloom, Enum.Material.Grass)
		ball(parent, "Canopy", 2 * scale, x + 0.9 * scale, y + 4.3 * scale, z - 0.5 * scale, bloom, Enum.Material.Grass)
	else
		cylinder(parent, "Stem", 2 * scale, 0.25 * scale, x, y + 1 * scale, z, leaf)
		ball(parent, "Bloom", 1.2 * scale, x, y + 2.2 * scale, z, bloom)
		ball(parent, "Leaf", 0.8 * scale, x + 0.45 * scale, y + 1.1 * scale, z, leaf, Enum.Material.Grass)
	end
end

-- Jungle plants for the garden houses and Greenhollow's lanes (all built on the ground at p).
-- (a function: Color3 only exists once useApi has run under Lune)
local function jungleGreen(): Color3
	return rgb(45, 135, 60)
end
local function monstera(parent: Instance, p: Vector3, scale: number, seed: number)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2 + seed
		local tilt = math.rad(25 + (k % 2) * 20)
		local stem = CFrame.new(p) * CFrame.Angles(0, a, 0)
		deco(part(parent, "LeafStem", Vector3.new(0.25, 3.2, 0.25) * scale, stem * CFrame.new(0, 1.6 * scale, -0.6 * scale) * CFrame.Angles(-tilt, 0, 0), rgb(70, 140, 60), Enum.Material.Grass))
		local leaf = deco(part(parent, "BigLeaf", Vector3.new(2.8, 0.2, 3.8) * scale, stem * CFrame.new(0, 3 * scale, -2.2 * scale) * CFrame.Angles(-tilt * 0.6, 0, 0), jungleGreen(), Enum.Material.Grass))
		leaf.Shape = Enum.PartType.Cylinder
		leaf.Size = Vector3.new(0.2, 3.6, 3.6) * scale
		leaf.CFrame = leaf.CFrame * CFrame.Angles(0, 0, math.rad(90))
	end
end

local function bamboo(parent: Instance, p: Vector3, height: number, seed: number)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + seed
		local x, z = p.X + math.cos(a) * 0.9, p.Z + math.sin(a) * 0.9
		local h = height * (0.75 + hash(seed + k) * 0.35)
		cylinder(parent, "Bamboo", h, 0.6, x, p.Y + h / 2, z, rgb(150, 190, 80), Enum.Material.Wood)
		for j = 1, 2 do
			cylinder(parent, "BambooJoint", 0.25, 0.75, x, p.Y + h * j / 3, z, rgb(110, 150, 60), Enum.Material.Wood)
		end
		ball(parent, "BambooLeaves", 2.2, x, p.Y + h + 0.4, z, rgb(90, 170, 70), Enum.Material.Grass)
	end
end

local function banana(parent: Instance, p: Vector3, scale: number, seed: number)
	local h = 6 * scale
	cylinder(parent, "BananaTrunk", h, 1 * scale, p.X, p.Y + h / 2, p.Z, rgb(120, 140, 70), Enum.Material.Grass)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2 + seed
		local cf = CFrame.new(p.X, p.Y + h, p.Z) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, -2.6 * scale)
		deco(part(parent, "BananaLeaf", Vector3.new(1.6, 0.2, 5.4) * scale, cf, rgb(80, 170, 60), Enum.Material.Grass))
	end
	ball(parent, "Bananas", 1 * scale, p.X + 0.6 * scale, p.Y + h - 0.6 * scale, p.Z, rgb(250, 220, 70))
end

-- A vine hanging from top (world point) down `length` studs, with leaves along it.
local function vine(parent: Instance, top: Vector3, length: number, seed: number)
	deco(part(parent, "Vine", Vector3.new(0.25, length, 0.25), CFrame.new(top - Vector3.new(0, length / 2, 0)), rgb(60, 130, 50), Enum.Material.Grass))
	for k = 1, 3 do
		local y = top.Y - length * k / 3.5
		ball(parent, "VineLeaf", 0.9, top.X + (hash(seed + k) - 0.5) * 0.8, y, top.Z + (hash(seed + k * 2) - 0.5) * 0.8, jungleGreen(), Enum.Material.Grass).CanCollide = false
	end
end

-- A garden house: a timber-and-glass conservatory in the plot's colour, with the soil beds near
-- its doors, the display pads at the back and its own plant theme in the planters and pots. The
-- doorway (facing the avenue) is the gate: laser curtain, lock button and owner sign.
-- Part names (Floor, Border, Soil/SoilN, Pads/PadN, Greenhouse/Roof, Gate/Laser/LockButton/
-- PillarCap, Sign, SpawnPoint) are what PlotService, SnatchService and the plot skins look for.
local function buildPlot(plots: Instance, index: number)
	local cx, cz, d = MapBuilder.plotPlacement(index)
	local colorInfo = MapBuilder.PlotColors[index]
	local color = rgb(colorInfo[2], colorInfo[3], colorInfo[4])
	local theme = PLOT_THEMES[index]
	local S = MapBuilder.PlotSize
	local half = S / 2
	local wallH = 14
	local wood = rgb(150, 105, 70)
	local frame = rgb(245, 242, 235)
	local DOOR = 14 -- doorway width

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- a plot streams in whole
	plot:SetAttribute("Index", index)
	plot:SetAttribute("ColorName", colorInfo[1])
	plot:SetAttribute("Inward", d)
	plot:SetAttribute("Theme", theme.name)
	plot.Parent = plots

	-- u = towards the doors (the lane), v = along the lane; the house is turned a little
	local facing, along = MapBuilder.plotAxes(index)
	local rot = MapBuilder.plotRot(index)
	local function w(u: number, y: number, v: number): Vector3
		return Vector3.new(cx, y, cz) + facing * u + along * v
	end
	-- a frame at a world point, turned with the house (parts' X runs along the lane's cross axis)
	local function frameAt(p: Vector3): CFrame
		return CFrame.new(p) * rot
	end
	-- a part whose local X runs along u and Z along v
	local function box(name: string, size: Vector3, u: number, y: number, v: number, color_: Color3, material: any?, props: { [string]: any }?): BasePart
		return part(plot, name, size, frameAt(w(u, y, v)), color_, material, props)
	end

	-- floor: a stone path down the middle, a coloured trim, tiles round the beds
	local floor = box("Floor", Vector3.new(S + 4, 1, S + 4), 0, 0.5, 0, rgb(205, 195, 175), Enum.Material.Slate)
	plot.PrimaryPart = floor
	box("Border", Vector3.new(S + 4.4, 1.1, 1.2), 0, 0.55, -half - 1.4, color, Enum.Material.SmoothPlastic)
	box("Border", Vector3.new(S + 4.4, 1.1, 1.2), 0, 0.55, half + 1.4, color, Enum.Material.SmoothPlastic)
	box("Rug", Vector3.new(4, 0.12, 10), -3.6, 1.06, 0, color, Enum.Material.Fabric)

	-- walls: a wooden base course with glass above, timber posts, and the doorway at +u
	local gh = Instance.new("Model")
	gh.Name = "Greenhouse"
	gh.Parent = plot
	local function wallRun(u0: number, v0: number, u1: number, v1: number)
		local a, b = w(u0, 0, v0), w(u1, 0, v1)
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local look = CFrame.lookAt(mid, b)
		part(gh, "WallBase", Vector3.new(1.2, 4, len), look + Vector3.new(0, 3, 0), wood, Enum.Material.WoodPlanks)
		part(gh, "Glass", Vector3.new(0.4, wallH - 5, len), look + Vector3.new(0, 5 + (wallH - 5) / 2, 0), rgb(200, 235, 255), Enum.Material.Glass, { Transparency = 0.55 })
		part(gh, "WallCap", Vector3.new(1.6, 0.8, len), look + Vector3.new(0, wallH + 1, 0), frame, Enum.Material.Wood)
		local n = math.max(1, math.floor(len / 10))
		for k = 0, n do
			local p = a + (b - a) * (k / n)
			cylinder(gh, "Frame", wallH, 1, p.X, 1 + wallH / 2, p.Z, frame, Enum.Material.Wood)
		end
	end
	local e = half + 1.5
	local BACK = 12 -- the back doorway: walk in from the back path too
	wallRun(-e, -e, -e, -BACK / 2) -- back, either side of the back doorway
	wallRun(-e, BACK / 2, -e, e)
	wallRun(-e, -e, e, -e) -- sides
	wallRun(-e, e, e, e)
	wallRun(e, -e, e, -DOOR / 2) -- front, either side of the doorway
	wallRun(e, DOOR / 2, e, e)
	-- the roof: two glass slopes on white ribs, a ridge in the plot's colour
	local rise = 10
	local slopeLen = math.sqrt((e + 1) ^ 2 + rise ^ 2)
	local tilt = math.atan(rise / (e + 1))
	for _, side in { -1, 1 } do
		-- u runs along world X, so each slope tilts about X
		local mid = w(0, wallH + 1.5 + rise / 2, side * (e + 1) / 2)
		part(gh, "Roof", Vector3.new(S + 6, 0.5, slopeLen + 1), frameAt(mid) * CFrame.Angles(side * tilt, 0, 0), rgb(200, 240, 255), Enum.Material.Glass, { Transparency = 0.5 })
		for k = -3, 3 do
			local rib = w(k * (S + 4) / 6, wallH + 1.5 + rise / 2, side * (e + 1) / 2)
			part(gh, "Rib", Vector3.new(0.8, 0.8, slopeLen + 1.2), frameAt(rib) * CFrame.Angles(side * tilt, 0, 0), frame, Enum.Material.Wood)
		end
	end
	local ridge = part(gh, "RoofTrim", Vector3.new(S + 7, 1.4, 1.4), frameAt(w(0, wallH + 1.5 + rise + 0.3, 0)), color, Enum.Material.SmoothPlastic)
	ridge.Shape = Enum.PartType.Cylinder
	for _, u in { -(half + 3.5), half + 3.5 } do
		local fp = w(u, wallH + 1.5 + rise + 0.6, 0)
		ball(gh, "Finial", 2.2, fp.X, fp.Y, fp.Z, color, Enum.Material.Neon)
	end
	-- gable ends: the triangle above each end wall, filled with glass
	for _, u in { -e, e } do
		for _, side in { -1, 1 } do
			local a = w(u, wallH + 1.5, side * (e + 1))
			local foot = w(u, wallH + 1.5, 0)
			-- one wedge per half-gable: tall edge at the ridge, sloping out to the eave
			local size = Vector3.new(0.4, rise, (a - foot).Magnitude)
			local wcf = CFrame.lookAt((foot + a) / 2 + Vector3.new(0, rise / 2, 0), (foot + a) / 2 + Vector3.new(0, rise / 2, 0) + (a - foot).Unit)
			-- the front gable (over the doors) is painted in the plot's colour; the back one is glass
			local front = u > 0
			local wedgePart = wedge(gh, "Gable", size, wcf, if front then color else rgb(200, 235, 255), if front then Enum.Material.WoodPlanks else Enum.Material.Glass)
			wedgePart.Transparency = if front then 0 else 0.5
		end
	end

	-- the back doorway's timber frame
	for _, v in { -BACK / 2 - 0.6, BACK / 2 + 0.6 } do
		local bp = w(-e, 0, v)
		cylinder(gh, "BackPost", wallH, 1.2, bp.X, 1 + wallH / 2, bp.Z, frame, Enum.Material.Wood)
	end
	part(gh, "BackLintel", Vector3.new(1.6, 1.4, BACK + 2.4), frameAt(w(-e, wallH, 0)), frame, Enum.Material.Wood)
	box("BackStep", Vector3.new(3, 0.6, BACK + 1), -e - 2, 0.8, 0, rgb(205, 195, 175), Enum.Material.Slate)

	-- a round window and a little bargeboard trim in the painted front gable
	local gw = part(gh, "GableWindow", Vector3.new(0.5, 4, 4), frameAt(w(e + 0.3, wallH + 1.5 + rise * 0.4, 0)), rgb(255, 225, 150), Enum.Material.Neon)
	gw.Shape = Enum.PartType.Cylinder
	local gwFrame = part(gh, "GableWindowFrame", Vector3.new(0.4, 5.2, 5.2), frameAt(w(e + 0.2, wallH + 1.5 + rise * 0.4, 0)), frame, Enum.Material.Wood)
	gwFrame.Shape = Enum.PartType.Cylinder

	-- soil beds, each in a wooden frame
	local soil = Instance.new("Folder")
	soil.Name = "Soil"
	soil.Parent = plot
	for tile = 1, 12 do
		local u, v = MapBuilder.soilLocal(tile)
		local s_ = part(soil, "Soil" .. tile, Vector3.new(7, 1.2, 7), frameAt(w(u, 1.1, v)), rgb(110, 75, 50), Enum.Material.Ground)
		s_:SetAttribute("Tile", tile)
		box("BedFrame", Vector3.new(7.8, 1.4, 0.5), u, 1.2, v - 3.65, wood, Enum.Material.WoodPlanks)
		box("BedFrame", Vector3.new(7.8, 1.4, 0.5), u, 1.2, v + 3.65, wood, Enum.Material.WoodPlanks)
	end

	-- display pads on a raised marble stage at the back
	box("Stage", Vector3.new(19, 0.6, S - 2), -14.5, 1.3, 0, rgb(240, 235, 225), Enum.Material.Marble)
	local pads = Instance.new("Folder")
	pads.Name = "Pads"
	pads.Parent = plot
	for pad = 1, 12 do
		local u, v = MapBuilder.padLocal(pad)
		local p = cylinder(pads, "Pad" .. pad, 1, 6.5, 0, 0, 0, rgb(250, 250, 250), Enum.Material.Marble)
		p.CFrame = frameAt(w(u, 2, v)) * CFrame.Angles(0, 0, math.rad(90))
		p.Name = "Pad" .. pad
		p:SetAttribute("Pad", pad)
		p:SetAttribute("Bonus", pad > 8)
		if pad > 8 then
			p.Transparency = 0.7
		end
		local rim = cylinder(pads, "Rim" .. pad, 0.4, 7.1, 0, 0, 0, color, Enum.Material.Neon)
		rim.CFrame = frameAt(w(u, 1.75, v)) * CFrame.Angles(0, 0, math.rad(90))
	end

	-- the house's own decor: planters of its theme along the side walls, potted plants in the
	-- corners, hanging lanterns, a bench, shelves of pots, a watering can
	for _, side in { -1, 1 } do
		local pv = side * (half - 1.5)
		box("Planter", Vector3.new(16, 1.6, 2.4), 8, 1.8, pv, wood, Enum.Material.WoodPlanks)
		box("PlanterSoil", Vector3.new(15, 0.3, 1.8), 8, 2.6, pv, rgb(90, 60, 40), Enum.Material.Ground)
		for k = 0, 4 do
			themePlant(plot, theme, w(1.6 + k * 3.2, 2.7, pv), 0.8, k + side)
		end
		-- a potted plant either side of the stage
		local pot = w(-half + 2, 1, side * (half - 8))
		cylinder(plot, "Pot", 2.2, 3, pot.X, 2.1, pot.Z, rgb(200, 110, 80), Enum.Material.SmoothPlastic)
		themePlant(plot, theme, pot + Vector3.new(0, 2.2, 0), 1.3, index)
		-- wall shelf with little pots
		box("Shelf", Vector3.new(10, 0.5, 1.6), -2, 8, side * (half - 0.4), wood, Enum.Material.WoodPlanks)
		for k = -1, 1 do
			local sp = w(-2 + k * 3.5, 8.25, side * (half - 0.6))
			cylinder(plot, "Pot", 1.4, 1.4, sp.X, sp.Y + 0.7, sp.Z, rgb(200, 110, 80), Enum.Material.SmoothPlastic)
			themePlant(plot, theme, sp + Vector3.new(0, 1.4, 0), 0.5, k)
		end
		-- a hanging lantern over each side of the path
		local lp = w(2, wallH - 1, side * 8)
		cylinder(plot, "LanternChain", 4, 0.15, lp.X, lp.Y + 2, lp.Z, rgb(60, 60, 65), Enum.Material.Metal)
		local glow = ball(plot, "Lantern", 1.6, lp.X, lp.Y, lp.Z, rgb(255, 225, 150), Enum.Material.Neon)
		glowLight(glow, 22, 1, rgb(255, 215, 150))
	end
	-- jungle: bamboo in the back corners, monstera by the doors, vines hanging from the roof
	for _, side in { -1, 1 } do
		bamboo(plot, w(-half + 2.5, 1, side * (half - 3)), 11, index + side)
		monstera(plot, w(half - 4, 1, side * (DOOR / 2 + 4)), 0.9, index + side)
		for k = -2, 2 do
			local vv = side * 10
			local roofY = wallH + 1.5 + rise * (1 - math.abs(vv) / (e + 1))
			vine(plot, w(k * 9, roofY - 0.4, vv), 3 + hash(index + k + side) * 3, index * 10 + k)
		end
	end
	local benchAt = w(-6, 0, -half + 4)
	part(plot, "BenchSeat", Vector3.new(6, 0.5, 2), CFrame.lookAt(benchAt + Vector3.new(0, 2.4, 0), benchAt + Vector3.new(0, 2.4, 0) + along) * CFrame.Angles(0, math.rad(90), 0), wood, Enum.Material.WoodPlanks)
	local can = w(-6, 1.8, half - 4)
	cylinder(plot, "WateringCan", 2, 1.6, can.X, can.Y, can.Z, color, Enum.Material.Metal)
	part(plot, "Spout", Vector3.new(0.3, 0.3, 2), CFrame.lookAt(can + Vector3.new(0, 0.4, 0), can + Vector3.new(0, 1.2, 0) + facing * 1.5) * CFrame.new(0, 0, -1), color, Enum.Material.Metal)

	-- the doorway: a timber arch with posts in the plot colour (the gate), the laser curtain,
	-- the lock button, a door lantern either side and the owner's sign above
	local gate = Instance.new("Model")
	gate.Name = "Gate"
	gate.Parent = plot
	for _, v in { -DOOR / 2 - 1, DOOR / 2 + 1 } do
		local pp = w(e, 0, v)
		part(gate, "Pillar", Vector3.new(2.4, wallH + 2, 2.4), frameAt(pp + Vector3.new(0, 1 + (wallH + 2) / 2, 0)), color, Enum.Material.SmoothPlastic)
		ball(gate, "PillarCap", 3, pp.X, wallH + 4, pp.Z, color, Enum.Material.Neon)
		local lamp_ = w(e + 1.6, 9, v)
		local bulb = ball(gate, "DoorLamp", 1.2, lamp_.X, lamp_.Y, lamp_.Z, rgb(255, 225, 150), Enum.Material.Neon)
		glowLight(bulb, 14, 0.8, rgb(255, 215, 150))
	end
	part(gate, "Lintel", Vector3.new(2.4, 2, DOOR + 4.4), frameAt(w(e, wallH + 2, 0)), color, Enum.Material.SmoothPlastic)
	part(gate, "Laser", Vector3.new(0.6, wallH - 2, DOOR), frameAt(w(e, 1 + (wallH - 2) / 2, 0)), rgb(255, 60, 60), Enum.Material.ForceField, { Transparency = 1, CanCollide = false, CanQuery = false })
	local buttonAt = w(e + 3, 2.5, -DOOR / 2 - 4)
	local button = part(gate, "LockButton", Vector3.new(3, 3, 3), CFrame.lookAt(buttonAt, buttonAt + facing), rgb(255, 80, 80), Enum.Material.Neon)
	part(gate, "LockPost", Vector3.new(2, 1, 2), frameAt(w(e + 3, 0.9, -DOOR / 2 - 4)), rgb(80, 80, 90), Enum.Material.Metal)
	label(button, "LOCK", 3, UDim2.fromOffset(160, 40))
	-- the doorstep and flower tubs outside
	box("Doorstep", Vector3.new(4, 0.6, DOOR + 2), e + 2.5, 0.8, 0, rgb(205, 195, 175), Enum.Material.Slate)
	for _, v in { -DOOR / 2 - 4, DOOR / 2 + 4 } do
		local tub = w(e + 3, 0, v)
		if v > 0 then
			cylinder(plot, "Tub", 2.4, 3.6, tub.X, 1.2, tub.Z, wood, Enum.Material.WoodPlanks)
			themePlant(plot, theme, tub + Vector3.new(0, 2.4, 0), 1.2, index + 3)
		end
	end

	-- owner sign over the doors (house name underneath)
	local sign = part(plot, "Sign", Vector3.new(1, 4, 22), frameAt(w(e + 1.4, wallH + 5.5, 0)), rgb(250, 245, 230), Enum.Material.WoodPlanks)
	label(sign, colorInfo[1] .. " plot - unclaimed", 4, UDim2.fromOffset(360, 70), color)
	local nameBoard = part(plot, "HouseName", Vector3.new(0.6, 1.6, 14), frameAt(w(e + 1.4, wallH + 2.6, 0)), rgb(70, 50, 35), Enum.Material.WoodPlanks)
	label(nameBoard, theme.name, 0, UDim2.fromOffset(220, 36), rgb(255, 235, 170))

	local spawnPoint = part(plot, "SpawnPoint", Vector3.new(4, 1, 4), CFrame.lookAt(w(-4, 3.5, 0), w(-4, 3.5, 0) + facing), color, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	spawnPoint:SetAttribute("Spawn", true)

	-- the jungle yard round the house: palms behind, banana plants and mossy rocks at the sides
	local yard_ = Instance.new("Model")
	yard_.Name = "JungleYard"
	yard_.Parent = plot
	for _, side in { -1, 1 } do
		local pp = w(-e - 5, 0, side * (e - 6))
		palm(yard_, pp.X, pp.Z, Vector3.new(-d, 0, side * 0.5).Unit, index * 3 + side)
		banana(yard_, w(-e - 4, 0, side * 8), 1.1, index + side)
		local rock = w(-e - 3, 0, side * (e - 14))
		ball(yard_, "MossRock", 4, rock.X, 0.8, rock.Z, rgb(110, 115, 105), Enum.Material.Slate)
		ball(yard_, "Moss", 3, rock.X, 2, rock.Z, rgb(70, 140, 60), Enum.Material.Grass)
	end
	-- onto the house's levelled pad (Landscape site "garden<i>", same x, z: checked here)
	local pad = Landscape and Landscape.Sites["garden" .. index]
	if pad then
		assert(math.abs(pad.x - cx) < 0.1 and math.abs(pad.z - cz) < 0.1, "MapBuilder.GardenPlots and Landscape.GardenPlots disagree")
		lift(plot, pad.h)
	end
end

-- Greenhollow Gardens: the farm village round the garden houses, off the city's Grand Way. The
-- green at the top of the lane has the Seed Barn (a second Seed Shop: ShopService and the client
-- handle every "Seed Shop" model), a Sell Stand, a well and a welcome arch. Branch paths (terrain
-- roads, Shared/Landscape) run from the lane to each house like the limbs of a tree, lined with
-- lanterns and little trees; a Trading Cart (a Sell Stand) stands at each junction. Fenced crop
-- fields, a barn and a silo sit on their own pads between the houses.
local function onGround(parent: Instance, name: string, build: (Instance) -> (), y: number): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	build(m)
	lift(m, y)
	return m
end

local function tradingCart(parent: Instance, x: number, y: number, z: number, facing: Vector3, seed: number)
	local cart_ = Instance.new("Model")
	cart_.Name = "Sell Stand"
	cart_.Parent = parent
	local turn = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z) + facing) * CFrame.Angles(0, math.rad(90), 0)
	local function c(u: number, h: number, v: number): CFrame
		return turn * CFrame.new(u, h, -v)
	end
	local wood = rgb(150, 105, 70)
	part(cart_, "CartBed", Vector3.new(8, 1.2, 4.6), c(0, 2.4, 0), wood, Enum.Material.WoodPlanks)
	part(cart_, "CartSide", Vector3.new(8, 1.4, 0.4), c(0, 3.6, 2.1), wood, Enum.Material.WoodPlanks)
	part(cart_, "CartSide", Vector3.new(8, 1.4, 0.4), c(0, 3.6, -2.1), wood, Enum.Material.WoodPlanks)
	for _, wu in { -2.8, 2.8 } do
		for _, wv in { -2.6, 2.6 } do
			local wheel = part(cart_, "Wheel", Vector3.new(0.5, 2.6, 2.6), c(wu, 1.3, wv) * CFrame.Angles(0, math.rad(90), 0), rgb(90, 65, 45), Enum.Material.Wood)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	for _, pu in { -3.7, 3.7 } do
		for _, pv in { -2, 2 } do
			part(cart_, "CanopyPost", Vector3.new(0.4, 6, 0.4), c(pu, 6, pv), wood, Enum.Material.Wood)
		end
	end
	local stripes = { rgb(240, 90, 90), rgb(255, 255, 255), rgb(240, 90, 90), rgb(255, 255, 255) }
	for k = 1, 4 do
		local u = -4.5 + (k - 0.5) * 2.25
		part(cart_, "Canopy", Vector3.new(2.25, 0.3, 6), c(u, 9.2, 0.3) * CFrame.Angles(math.rad(-10), 0, 0), stripes[k], Enum.Material.Fabric)
		local sc = part(cart_, "Scallop", Vector3.new(0.25, 2, 2), c(u, 8.6, 3.3) * CFrame.Angles(0, math.rad(90), 0), stripes[k], Enum.Material.Fabric)
		sc.Shape = Enum.PartType.Cylinder
		sc.CanCollide = false
	end
	local produce = { rgb(230, 60, 60), rgb(250, 200, 60), rgb(120, 200, 80), rgb(240, 140, 50), rgb(170, 120, 220) }
	for k = 0, 5 do
		local fruit = part(cart_, "Produce", Vector3.new(1.2, 1.2, 1.2), c(-3 + k * 1.2, 3.6, (k % 2) * 1.2 - 0.6), produce[(k + seed) % #produce + 1], Enum.Material.SmoothPlastic)
		fruit.Shape = Enum.PartType.Ball
	end
	part(cart_, "Crate", Vector3.new(2, 2, 2), c(5.4, 1, 1.2), wood, Enum.Material.WoodPlanks)
	part(cart_, "Crate", Vector3.new(1.6, 1.6, 1.6), c(5.6, 2.8, 1.1), wood, Enum.Material.WoodPlanks)
	local board = part(cart_, "CartSign", Vector3.new(5, 1.4, 0.3), c(0, 10.6, 3.1), rgb(70, 50, 35), Enum.Material.WoodPlanks)
	label(board, "Trading Cart", 0, UDim2.fromOffset(180, 36), rgb(255, 235, 170))
	part(cart_, "Anchor", Vector3.new(3, 1, 3), c(0, 3.4, 2.8), rgb(255, 220, 120), Enum.Material.Neon)
end

local function lanternPost(parent: Instance, x: number, y: number, z: number, toward: Vector3)
	cylinder(parent, "LanternPost", 7, 0.5, x, y + 3.5, z, rgb(60, 55, 50), Enum.Material.Metal)
	-- an arm reaching over the path with the lantern hanging from its end
	local tip = Vector3.new(x, 0, z) + toward * 1.6
	part(parent, "LanternArm", Vector3.new(0.3, 0.3, 1.8), CFrame.lookAt(Vector3.new(x, y + 6.8, z) + toward * 0.8, Vector3.new(tip.X, y + 6.8, tip.Z)), rgb(60, 55, 50), Enum.Material.Metal)
	local lantern = part(parent, "Lantern", Vector3.new(1.1, 1.4, 1.1), CFrame.new(tip.X, y + 6, tip.Z), rgb(255, 215, 140), Enum.Material.Neon)
	glowLight(lantern, 18, 0.9, rgb(255, 210, 140))
	cone(parent, "LanternCap", tip.X, y + 6.7, tip.Z, 0.8, 0.8, rgb(60, 55, 50), Enum.Material.Metal, 4)
end

local function buildGreenhollow(map: Instance)
	if not Landscape then
		return
	end
	local village = Instance.new("Model")
	village.Name = "Greenhollow"
	village.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the client reads its shop labels
	village.Parent = map
	local G = MapBuilder.Garden
	local greenSite = Landscape.Sites.greenhollow
	local gx, gz = G.x, G.z

	-- the green (built at y = 0, lifted onto its pad)
	onGround(village, "Green", function(m)
		part(m, "Green", Vector3.new(76, 0.4, 34), at(gx, 0.2, gz), rgb(205, 195, 175), Enum.Material.Slate)
		well(m, gx - 10, gz - 10)
		local barnFacing = Vector3.new(1, 0, 0)
		local seedBarn = stall(m, "Seed Shop", gx - 28, gz, barnFacing, 34, rgb(90, 190, 110))
		seedBarn.Parent = village -- found by name directly under Greenhollow (the client waits for it)
		local base = CFrame.lookAt(Vector3.new(gx - 28, 0, gz), Vector3.new(gx - 28, 0, gz) + barnFacing)
		local kiosks = Instance.new("Folder")
		kiosks.Name = "Kiosks"
		kiosks.Parent = seedBarn
		for i = 1, 11 do
			local u = -15.5 + (i - 0.5) * (31 / 11)
			local k = part(kiosks, "Kiosk" .. i, Vector3.new(2.5, 1, 2.4), base * CFrame.new(u, 4, -1), rgb(255, 250, 235), Enum.Material.SmoothPlastic)
			k:SetAttribute("Slot", i)
		end
		local timer = part(seedBarn, "RestockBoard", Vector3.new(16, 4, 0.5), base * CFrame.new(0, 19.5, 2), rgb(40, 60, 45), Enum.Material.SmoothPlastic)
		label(timer, "Restock in 5m 00s", 0, UDim2.fromOffset(260, 40), rgb(200, 255, 190))
		lift(seedBarn, greenSite.h)
		local sell = stall(m, "Sell Stand", gx + 28, gz, Vector3.new(-1, 0, 0), 16, rgb(240, 180, 60))
		part(sell, "Anchor", Vector3.new(4, 1, 4), at(gx + 25, 4, gz), rgb(255, 220, 120), Enum.Material.Neon)
		-- the welcome arch over the lane
		local ax, az = gx, gz + 24
		for _, s_ in { -1, 1 } do
			part(m, "ArchPost", Vector3.new(1.6, 16, 1.6), at(ax + s_ * 9, 8, az), rgb(130, 95, 60), Enum.Material.Wood)
			bamboo(m, Vector3.new(ax + s_ * 12, 0, az), 9, s_)
		end
		part(m, "ArchBeam", Vector3.new(21, 1.6, 1.6), at(ax, 16.2, az), rgb(130, 95, 60), Enum.Material.Wood)
		local board = part(m, "ArchSign", Vector3.new(16, 3.4, 0.5), at(ax, 13.6, az), rgb(70, 50, 35), Enum.Material.WoodPlanks)
		label(board, "Greenhollow Gardens", 0, UDim2.fromOffset(300, 50), rgb(200, 255, 190))
		for k = -4, 4 do
			ball(m, "ArchVine", 1.3, ax + k * 2.2, 15.1 - math.abs(k) * 0.15, az + 0.9, jungleGreen(), Enum.Material.Grass).CanCollide = false
		end
		signpost(m, gx + 10, gz - 14, "Sproutling City", rgb(255, 235, 170))
		-- the Task Board: today's Daily Tasks (DailyService adds the prompt)
		local bx, bz = gx - 15, gz + 12 -- (Mara stands across the lane)
		for _, s_ in { -1, 1 } do
			part(m, "BoardPost", Vector3.new(0.6, 8, 0.6), at(bx + s_ * 3.4, 4, bz), rgb(120, 85, 55), Enum.Material.Wood)
		end
		local taskBoard = part(m, "TaskBoard", Vector3.new(7.4, 4.4, 0.5), at(bx, 5.8, bz), rgb(150, 110, 70), Enum.Material.WoodPlanks)
		taskBoard:SetAttribute("TaskBoard", true)
		label(taskBoard, "Daily Tasks", 3.2, UDim2.fromOffset(200, 40), rgb(200, 255, 190))
		for k = 0, 2 do
			part(m, "Note", Vector3.new(1.8, 2.2, 0.1), at(bx - 2.2 + k * 2.2, 5.9, bz - 0.3), rgb(250, 245, 225), Enum.Material.SmoothPlastic)
		end
		part(m, "BoardRoof", Vector3.new(8.6, 0.4, 1.8), at(bx, 8.3, bz), rgb(90, 140, 80), Enum.Material.WoodPlanks)
	end, greenSite.h)

	-- the lane (the trunk): lamps on alternate sides, jungle planting along the verges
	local roadIndex: { [string]: number } = {}
	for i, def in Landscape.Roads do
		roadIndex[def.name] = i
	end
	local trunk = Landscape.RoadSamples[roadIndex["Greenhollow Lane"]]
	local laneDecor = Instance.new("Model")
	laneDecor.Name = "LaneDecor"
	laneDecor.Parent = village
	local nextAt = 0
	for k, smp in trunk do
		if smp.z > gz + 40 and smp.s >= nextAt then
			nextAt = smp.s + 30
			local side = if k % 2 == 0 then 1 else -1
			local nx, nz = -smp.tz * side, smp.tx * side
			local lx, lz = smp.x + nx * (smp.hw + 2.5), smp.z + nz * (smp.hw + 2.5)
			lanternPost(laneDecor, lx, Landscape.height(lx, lz) - 0.2, lz, Vector3.new(-nx, 0, -nz))
			local px, pz = smp.x - nx * (smp.hw + 6), smp.z - nz * (smp.hw + 6)
			if not Landscape.onRoad(px, pz, 2) then
				monstera(laneDecor, Vector3.new(px, Landscape.height(px, pz) - 0.3, pz), 0.9, k)
			end
		end
	end

	-- each branch: lanterns and little trees along it, and a trading cart at the junction
	for i, g in MapBuilder.GardenPlots do
		local samples = Landscape.RoadSamples[roadIndex["Greenhollow Branch " .. i]]
		if samples then
			local branch = Instance.new("Model")
			branch.Name = "Branch" .. i
			branch.Parent = village
			local total = samples[#samples].s
			local nextS = 10
			local flip = 1
			for _, smp in samples do
				if smp.s >= nextS and smp.s < total - 8 then
					nextS = smp.s + 11
					flip = -flip
					local nx, nz = -smp.tz * flip, smp.tx * flip
					local ox, oz = smp.x + nx * (smp.hw + 2.5), smp.z + nz * (smp.hw + 2.5)
					local oy = Landscape.height(ox, oz) - 0.2
					if flip > 0 then
						lanternPost(branch, ox, oy, oz, Vector3.new(-nx, 0, -nz))
					else
						cylinder(branch, "TreeBed", 0.5, 3.6, ox, oy + 0.25, oz, rgb(110, 80, 55), Enum.Material.Ground)
						cylinder(branch, "Trunk", 6, 0.8, ox, oy + 3, oz, rgb(105, 75, 52), Enum.Material.Wood)
						ball(branch, "Canopy", 5.4, ox, oy + 7.2, oz, rgb(70 + (i % 3) * 15, 160, 75), Enum.Material.Grass)
						ball(branch, "Canopy", 3.6, ox + 1.2, oy + 9, oz - 0.8, rgb(80, 170, 80), Enum.Material.Grass)
					end
				end
			end
			-- the cart on the far side of the lane from the branch, facing it
			local away = if g.x < G.laneX then 1 else -1
			local cx_, cz_ = G.laneX + away * 16, g.jz + 2
			tradingCart(village, cx_, Landscape.height(cx_, cz_) - 0.2, cz_, Vector3.new(-away, 0, 0), i)
		end
	end

	-- fenced crop fields, each on its own pad
	local crops = { rgb(240, 200, 70), rgb(80, 170, 70), rgb(245, 140, 40), rgb(200, 80, 90) }
	for i = 1, 3 do
		local site = Landscape.Sites["gardenfield" .. i]
		if site then
			onGround(village, "Field" .. i, function(m)
				local fx, fz = site.x, site.z
				part(m, "Field", Vector3.new(30, 0.6, 40), at(fx, 0.3, fz), rgb(110, 80, 55), Enum.Material.Ground)
				for r = 0, 5 do
					part(m, "CropRow", Vector3.new(2.4, 1, 36), at(fx - 12 + r * 4.8, 0.9, fz), crops[(i + r) % #crops + 1], Enum.Material.Grass)
				end
				for _, side in { -1, 1 } do
					part(m, "FenceRail", Vector3.new(0.4, 0.4, 42), at(fx + side * 16, 2.2, fz), rgb(150, 110, 70), Enum.Material.Wood)
					part(m, "FenceRail", Vector3.new(32, 0.4, 0.4), at(fx, 2.2, fz + side * 21), rgb(150, 110, 70), Enum.Material.Wood)
					for k = -2, 2 do
						part(m, "FencePost", Vector3.new(0.5, 3, 0.5), at(fx + side * 16, 1.5, fz + k * 10), rgb(130, 95, 60), Enum.Material.Wood)
					end
				end
				if i % 2 == 1 then
					haystack(m, fx + 22, fz - 12, 4)
				else
					scarecrow(m, fx, fz)
				end
			end, site.h)
		end
	end
	-- each house's front garden: flower beds either side of the doors, a bench, a birdbath,
	-- potted plants and lanterns at the corners of its pad
	for i, g in MapBuilder.GardenPlots do
		local site = Landscape.Sites["garden" .. i]
		local facing, along = MapBuilder.plotAxes(i)
		if site then
			onGround(village, "FrontGarden" .. i, function(m)
				local function at2(u: number, v: number): Vector3
					return Vector3.new(g.x, 0, g.z) + facing * u + along * v
				end
				for _, side in { -1, 1 } do
					local fb = at2(34, side * 17)
					flowerBed(m, fb.X, fb.Z, 5, 9, i * 4 + side)
					local pot = at2(33.5, side * 26)
					cylinder(m, "Pot", 2, 2.6, pot.X, 1, pot.Z, rgb(200, 110, 80), Enum.Material.SmoothPlastic)
					ball(m, "PotPlant", 2.8, pot.X, 3, pot.Z, rgb(80 + side * 20, 170, 80), Enum.Material.Grass)
					local corner = at2(36, side * 33)
					cylinder(m, "LanternPost", 6, 0.5, corner.X, 3, corner.Z, rgb(60, 55, 50), Enum.Material.Metal)
					local glow = ball(m, "Lantern", 1.3, corner.X, 6.4, corner.Z, rgb(255, 215, 140), Enum.Material.Neon)
					glowLight(glow, 16, 0.8, rgb(255, 210, 140))
				end
				local bp = at2(38, -9)
				bench(m, bp.X, bp.Z, facing)
				local bb = at2(39, 10)
				cylinder(m, "BirdbathStem", 2.4, 0.8, bb.X, 1.2, bb.Z, rgb(220, 215, 205), Enum.Material.Marble)
				cylinder(m, "Birdbath", 0.6, 3.4, bb.X, 2.6, bb.Z, rgb(220, 215, 205), Enum.Material.Marble)
				cylinder(m, "BirdbathWater", 0.2, 2.6, bb.X, 2.95, bb.Z, rgb(120, 200, 240), Enum.Material.Glass)
			end, site.h)
		end
	end

	-- and then load the rest of the village up: trees of every kind, bushes, flower beds,
	-- mushroom rings, rocks, benches, picnic tables and crates on all the open ground
	local decor = Instance.new("Model")
	decor.Name = "VillageDecor"
	decor.Parent = village
	local R = Landscape.Reserved[1]
	local keepOff = { "greenhollow", "gardenfield1", "gardenfield2", "gardenfield3", "gardenbarn" }
	local function clear(x: number, z: number, r: number): boolean
		if Landscape.onRoad(x, z, r + 2) then
			return false
		end
		for _, g in MapBuilder.GardenPlots do
			if (x - g.x) ^ 2 + (z - g.z) ^ 2 < (48 + r) ^ 2 then
				return false
			end
		end
		for _, name in keepOff do
			local s_ = Landscape.Sites[name]
			if s_ and (x - s_.x) ^ 2 + (z - s_.z) ^ 2 < (s_.r + 4 + r) ^ 2 then
				return false
			end
		end
		return Landscape.cityWeight(x, z) < 0.02 and Landscape.slope(x, z) < 0.6
	end
	local n = 0
	local step = 13
	for zz = R.z0 + 6, R.z1 - 6, step do
		for xx = R.x0 + 6, R.x1 - 6, step do
			n += 1
			local x = xx + (hash(n * 1.7) - 0.5) * step * 0.8
			local z = zz + (hash(n * 2.9) - 0.5) * step * 0.8
			local roll = hash(n + 0.33)
			local kind = hash(n + 0.71)
			if roll < 0.62 and clear(x, z, 3) then
				local y = Landscape.height(x, z) - 0.4
				if kind < 0.24 then
					tree(decor, x, z, 0.65 + hash(n) * 0.5, n, y)
				elseif kind < 0.34 then
					pine(decor, x, z, 0.7 + hash(n) * 0.4, n, y)
				elseif kind < 0.42 then
					local m = Instance.new("Model")
					m.Name = "Palm"
					m.Parent = decor
					palm(m, x, z, Vector3.new(hash(n + 1) - 0.5, 0, hash(n + 2) - 0.5).Unit, n)
					lift(m, y)
				elseif kind < 0.58 then
					onGround(decor, "Bush", function(m)
						bush(m, x, z, n)
					end, y)
				elseif kind < 0.7 then
					onGround(decor, "Flowers", function(m)
						flowerBed(m, x, z, 4 + hash(n) * 3, 4 + hash(n + 3) * 3, n)
					end, y)
				elseif kind < 0.76 then
					-- a fairy ring of mushrooms
					for k = 0, 5 do
						local a = k / 6 * math.pi * 2
						local mx, mz = x + math.cos(a) * 2.6, z + math.sin(a) * 2.6
						cylinder(decor, "MushroomStem", 1, 0.5, mx, y + 0.5, mz, rgb(240, 235, 220))
						local cap = ball(decor, "MushroomCap", 1.4, mx, y + 1.1, mz, if k % 2 == 0 then rgb(230, 70, 70) else rgb(250, 180, 70))
						cap.Size = Vector3.new(1.4, 0.8, 1.4)
					end
				elseif kind < 0.83 then
					for k = 0, 2 do
						ball(decor, "Rock", 2 + hash(n + k) * 2.4, x + (k - 1) * 2, y + 0.4, z + (hash(n + k * 5) - 0.5) * 2, rgb(150, 145, 135), Enum.Material.Slate)
					end
					ball(decor, "Moss", 1.6, x, y + 1.8, z, rgb(80, 150, 70), Enum.Material.Grass)
				elseif kind < 0.88 then
					onGround(decor, "Bench", function(m)
						bench(m, x, z, Vector3.new(hash(n + 4) - 0.5, 0, hash(n + 6) - 0.5).Unit)
					end, y + 0.4)
				elseif kind < 0.93 then
					-- a picnic table with a cloth and a basket
					onGround(decor, "Picnic", function(m)
						part(m, "TableTop", Vector3.new(6, 0.4, 3), at(x, 3, z), rgb(160, 115, 75), Enum.Material.WoodPlanks)
						part(m, "Cloth", Vector3.new(4, 0.1, 3.2), at(x, 3.25, z), rgb(230, 80, 80), Enum.Material.Fabric)
						for _, sv in { -1, 1 } do
							part(m, "TableLeg", Vector3.new(0.4, 3, 2.6), at(x + sv * 2.4, 1.5, z), rgb(130, 95, 60), Enum.Material.Wood)
							part(m, "Seat", Vector3.new(6, 0.3, 1), at(x, 1.7, z + sv * 2.4), rgb(160, 115, 75), Enum.Material.WoodPlanks)
						end
						part(m, "Basket", Vector3.new(1.2, 0.8, 0.9), at(x + 1, 3.6, z), rgb(190, 150, 90), Enum.Material.Fabric)
					end, y + 0.4)
				else
					onGround(decor, "Crates", function(m)
						barrel(m, x, z)
						crate(m, x + 2.4, 0, z + 0.6, 2.2, hash(n) * 3)
						crate(m, x + 2.4, 2.2, z + 0.6, 1.6, hash(n + 1) * 3)
					end, y + 0.4)
				end
			end
		end
	end

	-- a red barn and silo at the bottom of the lane
	local barnSite = Landscape.Sites.gardenbarn
	if barnSite then
		onGround(village, "Farmyard", function(m)
			barn(m, barnSite.x - 6, barnSite.z + 4, Vector3.new(0, 0, -1))
			silo(m, barnSite.x + 18, barnSite.z + 6)
			haystack(m, barnSite.x + 22, barnSite.z - 10, 4.5)
		end, barnSite.h)
	end
end

function MapBuilder.Build(parent: Instance): Instance
	if not Landscape then
		local ok, module = pcall(function()
			return require((script :: any).Parent.Landscape)
		end)
		if ok then
			Landscape = module
		end
	end
	if not City then
		local ok, module = pcall(function()
			return require((script :: any).Parent.CityBuilder)
		end)
		if ok then
			City = module
		end
	end
	if not Dungeon then
		local ok, module = pcall(function()
			return require((script :: any).Parent.DungeonBuilder)
		end)
		if ok then
			Dungeon = module
		end
	end
	if not Wilds then
		local ok, wildsModule, questModule, waystoneModule = pcall(function()
			return require((script :: any).Parent.WildsBuilder), require((script :: any).Parent.Quests), require((script :: any).Parent.Waystones)
		end)
		if ok then
			Wilds, QuestData, WaystoneData = wildsModule, questModule, waystoneModule
		end
	end
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
	buildGreenhollow(map)
	buildParade(map)
	buildPond(map)
	buildSkyGarden(map)
	buildScenery(map)
	if City then
		City.Build(map, Landscape)
	end
	if Dungeon then
		Dungeon.Build(map, Landscape)
	end
	if Wilds and QuestData and Landscape then
		Wilds.Build(map, Landscape, QuestData, {
			cottage = cottage,
			tree = tree,
			lamp = lamp,
			barrel = barrel,
			crate = crate,
			bench = bench,
			cart = cart,
			haystack = haystack,
			well = well,
			signpost = signpost,
			crystal = crystal,
			flowerBed = flowerBed,
		}, WaystoneData)
	end

	map.Parent = parent
	return map
end

return MapBuilder
