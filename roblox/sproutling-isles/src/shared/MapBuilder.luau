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

-- Shared.DungeonBuilder (The Hollow Crypt), same arrangement.
local Dungeon: any = nil
function MapBuilder.useDungeon(module: any)
	Dungeon = module
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

-- Hollow Harvest: 14 marker points for Wisp Lanterns to spawn at (EventService picks 10 of them
-- at random each Fog). Placed along the avenue north of the Plaza (towards the Pond) and south of
-- the Parade (towards the Sky Garden's ground footprint), well clear of the Plaza's ~65-stud
-- radius, the Pond (centred z = -300), the Parade belt (z 79.5-90.5) and every plot's footprint
-- (plots sit at |x| = 105-205; these markers stay within |x| <= 12, so they never overlap a plot
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
	local beam = rgb(110, 75, 50)
	local floors = storeys or 1
	local W, D, H, rise = 16, 12, 10 * floors, 6

	part(model, "Footing", Vector3.new(W + 1, 1.4, D + 1), rel(0, 0.7, 0), rgb(150, 145, 140), Enum.Material.Cobblestone)
	part(model, "Walls", Vector3.new(W, H, D), rel(0, H / 2 + 1, 0), wall, Enum.Material.Plaster)
	-- attic: a prism rotated 45 degrees whose lower half hides inside the walls, filling the gables
	local attic = math.sqrt(2) * rise
	part(model, "Attic", Vector3.new(W - 0.2, attic, attic), rel(0, H + 1, 0) * CFrame.Angles(math.rad(45), 0, 0), wall, Enum.Material.Plaster)
	-- timber frame on the front face
	for _, u in { -W / 2 + 0.4, -2.6, 2.6, W / 2 - 0.4 } do
		part(model, "Timber", Vector3.new(0.8, H, 0.5), rel(u, H / 2 + 1, D / 2 + 0.1), beam, Enum.Material.Wood)
	end
	part(model, "Timber", Vector3.new(W, 0.8, 0.5), rel(0, H + 0.8, D / 2 + 0.1), beam, Enum.Material.Wood)
	part(model, "Timber", Vector3.new(W, 0.6, 0.5), rel(0, 5.6, D / 2 + 0.1), beam, Enum.Material.Wood)
	for floor = 2, floors do
		local y0 = (floor - 1) * 10
		part(model, "Timber", Vector3.new(W, 0.8, 0.5), rel(0, y0 + 1, D / 2 + 0.1), beam, Enum.Material.Wood)
		for _, u in { -4.5, 0, 4.5 } do
			part(model, "WindowFrame", Vector3.new(3, 3.4, 0.3), rel(u, y0 + 6.5, D / 2 + 0.15), beam, Enum.Material.Wood)
			part(model, "Window", Vector3.new(2.2, 2.6, 0.3), rel(u, y0 + 6.5, D / 2 + 0.25), rgb(255, 215, 140), Enum.Material.Neon)
			part(model, "Shutter", Vector3.new(1, 3.2, 0.25), rel(u - 2, y0 + 6.5, D / 2 + 0.2), roof, Enum.Material.WoodPlanks)
		end
	end
	if awning then
		for i = 1, 4 do
			local u = -W / 2 + (i - 0.5) * (W / 4)
			part(model, "Awning", Vector3.new(W / 4, 0.5, 4), rel(u, 9.4, D / 2 + 2) * CFrame.Angles(math.rad(-18), 0, 0), if i % 2 == 0 then rgb(255, 255, 255) else awning, Enum.Material.Fabric)
		end
	end
	-- roof: two tilted slabs and a ridge
	local slope = math.atan(rise / (D / 2))
	local length = math.sqrt(rise * rise + (D / 2) ^ 2) + 2
	for _, side in { 1, -1 } do
		part(model, "Roof", Vector3.new(W + 2, 0.9, length), rel(0, H + 1 + rise / 2 + 0.4, side * D / 4) * CFrame.Angles(-side * slope, 0, 0), roof, Enum.Material.Slate)
	end
	part(model, "Ridge", Vector3.new(W + 2.4, 1, 1), rel(0, H + 1 + rise + 0.5, 0), Color3.new(roof.R * 0.75, roof.G * 0.75, roof.B * 0.75), Enum.Material.Wood)
	part(model, "Chimney", Vector3.new(2.2, 7, 2.2), rel(W / 2 - 3.5, H + rise, -D / 4), rgb(170, 110, 90), Enum.Material.Brick)
	-- door, lit windows and window boxes
	part(model, "Door", Vector3.new(3.4, 6.2, 0.4), rel(0, 4.1, D / 2 + 0.2), rgb(120, 80, 55), Enum.Material.WoodPlanks)
	local knob = ball(model, "Knob", 0.4, 0, 0, 0, rgb(240, 200, 90), Enum.Material.Metal)
	knob.CFrame = rel(1.1, 4, D / 2 + 0.45)
	for _, u in { -5.3, 5.3 } do
		part(model, "WindowFrame", Vector3.new(3.4, 3.4, 0.3), rel(u, 7, D / 2 + 0.15), beam, Enum.Material.Wood)
		local pane = part(model, "Window", Vector3.new(2.6, 2.6, 0.3), rel(u, 7, D / 2 + 0.25), rgb(255, 210, 130), Enum.Material.Neon)
		if u > 0 then
			glowLight(pane, 14, 0.8, rgb(255, 200, 130))
		end
		part(model, "WindowBox", Vector3.new(3.6, 0.9, 1), rel(u, 5, D / 2 + 0.6), rgb(150, 100, 70), Enum.Material.Wood)
		for i = 1, 4 do
			local flowerColors = { rgb(255, 110, 150), rgb(255, 225, 90), rgb(170, 130, 255), rgb(255, 255, 255) }
			local bloom = ball(model, "WindowBloom", 0.8, 0, 0, 0, flowerColors[(i + seed) % 4 + 1])
			bloom.CFrame = rel(u - 1.65 + i * 0.66, 5.7, D / 2 + 0.7)
		end
	end
	-- a little lantern by the door
	local lantern = ball(model, "DoorLantern", 0.9, 0, 0, 0, rgb(255, 215, 140), Enum.Material.Neon)
	lantern.CFrame = rel(-2.6, 8.4, D / 2 + 0.8)
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
	yard(details, -160, -250, Vector3.new(0, 0, 1), 25)
	yard(details, 160, -250, Vector3.new(0, 0, 1), 26)
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
	well(details, -135, -262)
	cart(details, 135, -264, math.rad(70), rgb(120, 200, 80))
	bench(details, -125, -248, Vector3.new(0, 0, -1))
	-- farm by the windmill
	haystack(details, 90, 272, 6)
	haystack(details, 96, 282, 4.5)
	haystack(details, 132, 238, 5)
	-- signposts
	signpost(details, -30, -232, "Wishing Pond", rgb(160, 230, 255))
	signpost(details, 30, 104, "Sky Garden", rgb(220, 200, 255))
	signpost(details, -30, -78, "Seed Shop", rgb(200, 255, 200))

	-- beach palms leaning out to sea
	local palms = { { -252, -300, -1 }, { -254, -120, -1 }, { -252, 200, -1 }, { 252, -260, 1 }, { 254, -80, 1 }, { 252, 150, 1 }, { 253, 290, 1 } }
	for i, pt in palms do
		palm(details, pt[1], pt[2], Vector3.new(pt[3], 0, (hash(i) - 0.5) * 0.6).Unit, i)
	end
	for i, x in { -150, -40, 70, 180 } do
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

-- Distant snow-capped peak (out past the sea edge, mostly seen through the haze).
local function peak(parent: Instance, x: number, z: number, scale: number, seed: number)
	local model = Instance.new("Model")
	model.Name = "Peak"
	model.Parent = parent
	local y = -10
	local r = 140 * scale
	for i = 1, 11 do
		local h = 15 * scale
		local snow = i >= 9
		local color = if snow then rgb(245, 248, 255) elseif i >= 7 then rgb(165 + i * 2, 160 + i * 2, 175) else rgb(110 + i * 8, 140 + i * 6, 115)
		local ox, oz = (hash(seed + i) - 0.5) * 24 * scale, (hash(seed * 2 + i) - 0.5) * 24 * scale
		deco(cylinder(model, "Layer", h, r * 2, x + ox, y + h / 2, z + oz, color, if snow then Enum.Material.Snow else Enum.Material.Rock))
		y += h
		r *= 0.82
	end
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
	hill(land, -205, -355, 34, 4, 1)
	hill(land, 205, -355, 30, 4, 2)
	local elderBase = hill(land, -210, 300, 30, 3, 3, false)
	elderTree(land, -210, elderBase, 300)
	hill(land, 205, 305, 26, 3, 4)

	-- town: two-storey shop houses beside the Plaza, more cottages at the north corners
	local town = scenery:FindFirstChild("Village") or land
	cottage(town, -80, -95, Vector3.new(1, 0, 0), 21, 2, rgb(90, 190, 110))
	cottage(town, 80, -95, Vector3.new(-1, 0, 0), 22, 2, rgb(240, 120, 150))
	cottage(town, -80, 120, Vector3.new(1, 0, 0), 23, 2, rgb(90, 160, 255))
	cottage(town, 80, 120, Vector3.new(-1, 0, 0), 24, 2, rgb(255, 180, 60))
	cottage(town, -160, -250, Vector3.new(0, 0, 1), 25)
	cottage(town, 160, -250, Vector3.new(0, 0, 1), 26)
	cottage(town, -138, -300, Vector3.new(0.6, 0, 0.8).Unit, 27, 2)
	cottage(town, 138, -300, Vector3.new(-0.6, 0, 0.8).Unit, 28, 2)

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
			x, z = (f * 2 - 1) * 250, if i % 4 == 0 then -402 else 342
		else
			x, z = if i % 4 == 1 then -253 else 253, -400 + f * 740
		end
		ball(land, "Boulder", 4 + hash(i) * 6, x + (hash(i + 2) - 0.5) * 6, -0.5, z, rgb(160, 150, 140), Enum.Material.Rock)
	end

	-- the harbour pier and boats in the east bay
	local coast = Instance.new("Folder")
	coast.Name = "Coast"
	coast.Parent = scenery
	-- (the castle, lighthouse and ruins now stand on the terrain hills, see buildHills)

	part(coast, "Pier", Vector3.new(80, 1, 10), at(290, 1.5, 20), rgb(160, 115, 75), Enum.Material.WoodPlanks)
	for i = 0, 7 do
		for _, side in { -1, 1 } do
			cylinder(coast, "Piling", 8, 1.2, 254 + i * 10, -2.5, 20 + side * 5.2, rgb(110, 80, 55), Enum.Material.Wood)
		end
	end
	lamp(coast, 328, 26)
	boat(coast, 300, 38, math.rad(80), rgb(240, 90, 90))
	boat(coast, 318, 2, math.rad(100), rgb(90, 150, 240))
	boat(coast, 380, 70, math.rad(30), rgb(255, 210, 80))

	-- distant mountains ringing the horizon
	local horizon = Instance.new("Folder")
	horizon.Name = "Horizon"
	horizon.Parent = scenery
	local peaks = {
		{ -820, -500, 1.2 }, { -900, 100, 1.5 }, { -1150, 800, 1.3 }, { 850, -300, 1.4 },
		{ 900, 350, 1.2 }, { -200, -1000, 1.6 }, { 350, -950, 1.3 }, { 150, 1750, 1.4 }, { -600, 1650, 1.2 },
	}
	for i, pk in peaks do
		peak(horizon, pk[1], pk[2], pk[3], i)
	end
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

local function nearPath(x: number, z: number, margin: number): boolean
	for _, path in Landscape.Paths do
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			local abx, abz = b[1] - a[1], b[2] - a[2]
			local t = math.clamp(((x - a[1]) * abx + (z - a[2]) * abz) / (abx * abx + abz * abz), 0, 1)
			local dx, dz = x - (a[1] + abx * t), z - (a[2] + abz * t)
			if dx * dx + dz * dz < margin * margin then
				return true
			end
		end
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
			if not Landscape.inPlayArea(x, z) then
				local h = Landscape.height(x, z)
				local slope = Landscape.slope(x, z)
				local dense = Landscape.fbm(x / 90 + 11, z / 90 - 4)
				if h > 3 and slope < 0.75 and not Landscape.onSite(x, z, 10) and not nearPath(x, z, 8) then
					if dense > 0.55 and hash(i + 0.5) < 0.45 then
						if hash(i + 0.9) < (if h > 28 then 0.6 else 0.3) then
							pines += 1
							pine(wild, x, z, 0.9 + hash(i) * 0.7, i, h - 0.6)
						else
							broadleaf += 1
							tree(wild, x, z, 0.9 + hash(i) * 0.6, i, h - 0.6)
						end
					elseif hash(i + 0.2) < 0.12 then
						local flowers = { rgb(255, 120, 160), rgb(255, 230, 100), rgb(255, 255, 255), rgb(180, 140, 255) }
						for k = 1, 4 do
							ball(wild, "Wildflower", 0.9, x + (hash(i + k) - 0.5) * 4, h + 0.3, z + (hash(i + k * 3) - 0.5) * 4, flowers[(i + k) % 4 + 1])
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
	local islets = {
		{ -340, 110, -120, 38, true }, { 360, 140, 60, 45, true }, { -300, 170, 260, 30, false },
		{ 320, 95, -330, 28, true }, { -150, 190, -520, 34, true }, { 180, 150, -500, 26, false },
		{ 520, 210, 1250, 32, false }, { -420, 230, -380, 22, false }, { 440, 210, 330, 24, false },
		{ 75, 125, 375, 10, false }, { -70, 112, 330, 8, false },
	}
	for i, it in islets do
		floatingIslet(sky, it[1], it[2] + 60, it[3], it[4], i, it[5]) -- +60 clears the terrain hills
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
	buildScenery(map)
	if City then
		City.Build(map)
	end
	if Dungeon then
		Dungeon.Build(map, Landscape)
	end

	map.Parent = parent
	return map
end

return MapBuilder
