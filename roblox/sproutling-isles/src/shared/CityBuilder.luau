--!strict
-- Builds the walled fantasy city of Sproutling (south of the garden island, across the lagoon)
-- and its airship port.
--
-- Like MapBuilder it touches no services, so it runs at server start, from the Studio command
-- bar and offline under Lune (tools/bake-map.luau passes the Roblox API table). Everything sits
-- under Map.City. Shops, steeds, ships and airships carry attributes (Shop, Vehicle, Arena) that
-- the RPG systems look up; for now they are scenery.
--
-- Layout (studs, +Z = south). The city ground is a flat slab at y = 0 inside Landscape.City
-- (x -345..345, z 465..1155): a grid of cobbled streets with the 44-stud Grand Way on x = 0
-- lined up with the island's avenue. Blocks are zoned as the market row, the guild quarter
-- (Adventurers' Guild, cathedral, mage tower, market square, treasury, arena), townhouses,
-- cottages, the royal gardens, town hall and library, barracks, temple, fishing docks and the
-- harbour. Walls with towers and gates ring the landward sides. The airship port lies west.

local CityBuilder = {}

local Instance = Instance
local Vector3 = Vector3
local CFrame = CFrame
local Color3 = Color3
local Enum = Enum
local UDim2 = UDim2

local initColors: () -> () -- defined below, once rgb() exists

function CityBuilder.useApi(api: any)
	Instance = api.Instance
	Vector3 = api.Vector3
	CFrame = api.CFrame
	Color3 = api.Color3
	Enum = api.Enum
	UDim2 = api.UDim2
	initColors()
end

----------------------------------------------------------------------------------------------
-- helpers

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Colour constants, built once the Color3 API is available (Lune passes it in via useApi).
local COBBLE: Color3
local FLAGSTONE: Color3
local STONE: Color3
local DARKSTONE: Color3
local TIMBER: Color3
local WHITE: Color3
local IRON: Color3
local GOLD: Color3
local LANTERN: Color3
local PLASTER: { Color3 }
local ROOFS: { Color3 }
local BANNERS: { Color3 }
local COATS: { Color3 }
initColors = function()
	COBBLE = rgb(128, 122, 116)
	FLAGSTONE = rgb(196, 186, 168)
	STONE = rgb(214, 206, 190)
	DARKSTONE = rgb(170, 162, 150)
	TIMBER = rgb(96, 66, 46)
	WHITE = rgb(248, 245, 236)
	IRON = rgb(55, 55, 60)
	GOLD = rgb(235, 190, 70)
	LANTERN = rgb(255, 205, 120)
	PLASTER = { rgb(245, 232, 205), rgb(238, 214, 190), rgb(225, 235, 215), rgb(250, 240, 220), rgb(232, 220, 235), rgb(240, 222, 200) }
	ROOFS = { rgb(170, 70, 55), rgb(70, 85, 120), rgb(85, 110, 90), rgb(120, 85, 70), rgb(150, 95, 60), rgb(95, 80, 110) }
	BANNERS = { rgb(200, 55, 60), rgb(55, 90, 180), rgb(60, 140, 90), rgb(220, 170, 50), rgb(130, 70, 160) }
	COATS = { rgb(120, 80, 50), rgb(60, 45, 35), rgb(230, 225, 215), rgb(160, 120, 80), rgb(90, 90, 95) }
end

local function hash(n: number): number
	local s = math.sin(n * 12.9898) * 43758.5453
	return s - math.floor(s)
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

local function box(parent: Instance, name: string, x: number, y0: number, z: number, sx: number, sy: number, sz: number, color: Color3, material: any?): BasePart
	return part(parent, name, Vector3.new(sx, sy, sz), at(x, y0 + sy / 2, z), color, material)
end

local function cylinder(parent: Instance, name: string, height: number, diameter: number, x: number, y: number, z: number, color: Color3, material: any?): BasePart
	local p = part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Cylinder lying along a direction: cframe's LookVector is the axis.
local function tube(parent: Instance, name: string, length: number, diameter: number, cframe: CFrame, color: Color3, material: any?): BasePart
	local p = part(parent, name, Vector3.new(length, diameter, diameter), cframe * CFrame.Angles(0, math.rad(90), 0), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent: Instance, name: string, diameter: number, x: number, y: number, z: number, color: Color3, material: any?): BasePart
	local p = part(parent, name, Vector3.new(diameter, diameter, diameter), at(x, y, z), color, material)
	p.Shape = Enum.PartType.Ball
	return p
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

-- A solid-looking triangle (a, b, c) made of two thin WedgeParts (the usual Roblox technique).
local function triangle(parent: Instance, name: string, a: Vector3, b: Vector3, c: Vector3, color: Color3, material: any?, thickness: number?)
	local th = thickness or 0.6
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	-- make a the corner opposite the longest edge (bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	wedge(parent, name, Vector3.new(th, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), color, material)
	wedge(parent, name, Vector3.new(th, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, material)
end

-- Pointed roof/spire: an n-sided pyramid of triangles on a base whose half-width is `radius`,
-- apex at y + height. Four-sided spires are aligned with the X/Z axes.
local function cone(parent: Instance, name: string, x: number, y: number, z: number, radius: number, height: number, color: Color3, material: any?, sides: number?)
	local n = sides or 6
	local circum = radius / math.cos(math.pi / n)
	local offset = if n == 4 then math.pi / 4 else 0
	local apex = Vector3.new(x, y + height, z)
	for i = 0, n - 1 do
		local a0, a1 = offset + i / n * math.pi * 2, offset + (i + 1) / n * math.pi * 2
		local p0 = Vector3.new(x + math.cos(a0) * circum, y, z + math.sin(a0) * circum)
		local p1 = Vector3.new(x + math.cos(a1) * circum, y, z + math.sin(a1) * circum)
		triangle(parent, name, p0, p1, apex, color, material)
	end
end

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function glowLight(parent: Instance, range: number, brightness: number, color: Color3)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = color
	light.Parent = parent
end

-- Text painted on one face of a part (shop signs, banners, plaques).
local function sign(target: BasePart, text: string, textColor: Color3, face: any?, background: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	if background then
		label.BackgroundColor3 = background
	end
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Fantasy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = textColor
	label.TextStrokeTransparency = 0.5
	label.Parent = gui
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Local frame for something at (x, z) whose front faces `facing`: rel(u, y, v) with u = right,
-- v = forward (towards the street).
local function frame(x: number, z: number, facing: Vector3): (number, number, number) -> CFrame
	local base = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + facing)
	return function(u: number, y: number, v: number): CFrame
		return base * CFrame.new(u, y, -v)
	end
end

-- Steep (45 degree) gable roof whose ridge runs along the local v axis, so the gable end faces
-- the street. Sits on walls w wide (u) and d deep (v) whose top is at height y. An attic prism
-- (a square turned 45 degrees about v, its lower half hidden in the walls) fills the gables.
local function gableFront(parent: Instance, rel: (number, number, number) -> CFrame, w: number, d: number, y: number, wall: Color3, roof: Color3)
	local rise = w / 2
	local attic = math.sqrt(2) * rise
	part(parent, "Attic", Vector3.new(attic, attic, d - 0.2), rel(0, y, 0) * CFrame.Angles(0, 0, math.rad(45)), wall, Enum.Material.Plaster)
	local len = math.sqrt(2) * rise + 1.6
	for _, side in { 1, -1 } do
		part(parent, "Roof", Vector3.new(len, 0.8, d + 1.6), rel(side * w / 4, y + rise / 2 + 0.35, 0) * CFrame.Angles(0, 0, -side * math.rad(45)), roof, Enum.Material.Slate)
	end
	part(parent, "Ridge", Vector3.new(1, 1, d + 2), rel(0, y + rise + 0.4, 0), roof, Enum.Material.Wood)
end

-- Steep gable roof whose ridge runs along u (gables on the sides), for long halls.
local function gableSide(parent: Instance, rel: (number, number, number) -> CFrame, w: number, d: number, y: number, wall: Color3, roof: Color3, wallMaterial: any?)
	local rise = d / 2
	local attic = math.sqrt(2) * rise
	part(parent, "Attic", Vector3.new(w - 0.2, attic, attic), rel(0, y, 0) * CFrame.Angles(math.rad(45), 0, 0), wall, wallMaterial or Enum.Material.Plaster)
	local len = math.sqrt(2) * rise + 1.6
	for _, side in { 1, -1 } do
		part(parent, "Roof", Vector3.new(w + 1.6, 0.9, len), rel(0, y + rise / 2 + 0.35, side * d / 4) * CFrame.Angles(-side * math.rad(45), 0, 0), roof, Enum.Material.Slate)
	end
end

----------------------------------------------------------------------------------------------
-- layout

local CITY = { x0 = -345, x1 = 345, z0 = 465, z1 = 1155 }
local AVENUES = { { x = -240, w = 24 }, { x = -120, w = 24 }, { x = 0, w = 44 }, { x = 120, w = 24 }, { x = 240, w = 24 } }
local STREETS = { { z = 490, w = 24 }, { z = 590, w = 24 }, { z = 700, w = 24 }, { z = 810, w = 24 }, { z = 920, w = 24 }, { z = 1030, w = 24 }, { z = 1130, w = 24 } }
local PAVE = 0.4 -- block flagstones sit this far above the street cobbles
local EDGE = 4 -- flagstone margin before buildings start

-- Blocks between the streets: { x0, x1, z0, z1, ix, iz }.
local function blocks(): { { number } }
	local xs = { CITY.x0 }
	for _, a in AVENUES do
		table.insert(xs, a.x - a.w / 2)
		table.insert(xs, a.x + a.w / 2)
	end
	table.insert(xs, CITY.x1)
	local zs = {}
	for _, s in STREETS do
		table.insert(zs, s.z - s.w / 2)
		table.insert(zs, s.z + s.w / 2)
	end
	local out = {}
	for iz = 1, #STREETS - 1 do
		for ix = 1, #AVENUES + 1 do
			table.insert(out, { xs[ix * 2 - 1], xs[ix * 2], zs[iz * 2], zs[iz * 2 + 1], ix, iz })
		end
	end
	return out
end

----------------------------------------------------------------------------------------------
-- street furniture

local function lanternPost(parent: Instance, x: number, z: number)
	cylinder(parent, "LanternPost", 11, 0.7, x, PAVE + 5.5, z, IRON, Enum.Material.Metal)
	box(parent, "LanternCap", x, PAVE + 12.6, z, 1.8, 0.5, 1.8, IRON, Enum.Material.Metal)
	box(parent, "Lantern", x, PAVE + 10.6, z, 1.3, 2, 1.3, LANTERN, Enum.Material.Neon)
	cone(parent, "LanternRoof", x, PAVE + 13.1, z, 1.2, 1.2, IRON, Enum.Material.Metal, 4)
end

local function cityTree(parent: Instance, x: number, z: number, seed: number)
	cylinder(parent, "TreeBed", 0.6, 4.4, x, PAVE + 0.3, z, rgb(110, 80, 55), Enum.Material.Ground)
	cylinder(parent, "Trunk", 8, 1, x, PAVE + 4, z, rgb(105, 75, 52), Enum.Material.Wood)
	local pick = hash(seed)
	local leaf = if pick < 0.18 then rgb(255, 178, 205) elseif pick < 0.3 then rgb(235, 160, 60) else rgb(70 + math.floor(hash(seed + 1) * 40), 155 + math.floor(hash(seed + 2) * 45), 70)
	ball(parent, "Canopy", 7, x, PAVE + 9.5, z, leaf, Enum.Material.Grass)
	ball(parent, "Canopy", 4.6, x + 1.5, PAVE + 11.8, z - 1, leaf, Enum.Material.Grass)
end

local function bench(parent: Instance, x: number, z: number, facing: Vector3)
	local rel = frame(x, z, facing)
	part(parent, "BenchSeat", Vector3.new(5, 0.5, 1.6), rel(0, PAVE + 1.7, 0), rgb(140, 100, 65), Enum.Material.WoodPlanks)
	part(parent, "BenchBack", Vector3.new(5, 1.6, 0.4), rel(0, PAVE + 2.8, -0.75), rgb(140, 100, 65), Enum.Material.WoodPlanks)
	for _, u in { -2, 2 } do
		part(parent, "BenchLeg", Vector3.new(0.5, 1.6, 1.6), rel(u, PAVE + 0.8, 0), DARKSTONE, Enum.Material.Cobblestone)
	end
end

local function barrel(parent: Instance, x: number, y: number, z: number)
	cylinder(parent, "Barrel", 3.4, 2.8, x, y + 1.7, z, rgb(145, 98, 58), Enum.Material.WoodPlanks)
	cylinder(parent, "Hoop", 0.35, 2.95, x, y + 2.7, z, IRON, Enum.Material.Metal)
	cylinder(parent, "Hoop", 0.35, 2.95, x, y + 0.7, z, IRON, Enum.Material.Metal)
end

local function crate(parent: Instance, x: number, y: number, z: number, size: number, turn: number)
	part(parent, "Crate", Vector3.new(size, size, size), CFrame.new(x, y + size / 2, z) * CFrame.Angles(0, turn, 0), rgb(185, 140, 88), Enum.Material.WoodPlanks)
end

local function well(parent: Instance, x: number, z: number)
	cylinder(parent, "WellWall", 3, 7, x, PAVE + 1.5, z, STONE, Enum.Material.Cobblestone)
	cylinder(parent, "WellWater", 0.4, 5.6, x, PAVE + 2.8, z, rgb(70, 160, 210), Enum.Material.Glass)
	for _, s in { -1, 1 } do
		box(parent, "WellPost", x + s * 3, PAVE + 1.5, z, 0.6, 7, 0.6, TIMBER, Enum.Material.Wood)
	end
	cone(parent, "WellRoof", x, PAVE + 8.5, z, 5, 3.4, ROOFS[1], Enum.Material.Slate, 4)
end

local function marketStall(parent: Instance, x: number, z: number, facing: Vector3, color: Color3, seed: number)
	local rel = frame(x, z, facing)
	part(parent, "StallCounter", Vector3.new(8, 3.2, 3), rel(0, PAVE + 1.6, 0), rgb(150, 105, 68), Enum.Material.WoodPlanks)
	for _, u in { -3.8, 3.8 } do
		for _, v in { -2.5, 1.4 } do
			part(parent, "StallPost", Vector3.new(0.5, 8, 0.5), rel(u, PAVE + 4, v), TIMBER, Enum.Material.Wood)
		end
	end
	for i = 1, 4 do
		part(parent, "StallCanopy", Vector3.new(2.2, 0.3, 5.4), rel(-3.3 + (i - 1) * 2.2, PAVE + 8.2, -0.5) * CFrame.Angles(math.rad(-12), 0, 0), if i % 2 == 0 then WHITE else color, Enum.Material.Fabric)
	end
	local goods = { rgb(230, 60, 60), rgb(250, 200, 60), rgb(120, 200, 80), rgb(240, 140, 50), rgb(170, 120, 220) }
	for i = 1, 5 do
		local g = part(parent, "Goods", Vector3.new(1.3, 1.3, 1.3), rel(-3 + i * 1.2, PAVE + 3.8, 0.2), goods[(seed + i) % #goods + 1], Enum.Material.SmoothPlastic)
		g.Shape = Enum.PartType.Ball
	end
end

local function banner(parent: Instance, x: number, y: number, z: number, facing: Vector3, color: Color3, length: number)
	local rel = frame(x, z, facing)
	part(parent, "BannerRod", Vector3.new(4.6, 0.3, 0.3), rel(0, y, 0.4), IRON, Enum.Material.Metal)
	part(parent, "Banner", Vector3.new(4, length, 0.2), rel(0, y - length / 2, 0.4), color, Enum.Material.Fabric)
	part(parent, "BannerTrim", Vector3.new(4, 0.6, 0.25), rel(0, y - length + 0.3, 0.4), GOLD, Enum.Material.Fabric)
end

----------------------------------------------------------------------------------------------
-- steeds, ships and airships (anchored props for now; tagged Vehicle for the riding system)


local function horse(parent: Instance, x: number, z: number, heading: Vector3, coat: Color3, saddled: boolean): Model
	local m = model(parent, "Horse")
	m:SetAttribute("Vehicle", "horse")
	local rel = frame(x, z, heading)
	local body = part(m, "Body", Vector3.new(2.6, 2.8, 6.4), rel(0, 4.6, 0), coat, Enum.Material.SmoothPlastic)
	m.PrimaryPart = body
	part(m, "Neck", Vector3.new(1.6, 3.6, 1.8), rel(0, 6.6, 3.2) * CFrame.Angles(math.rad(-35), 0, 0), coat)
	part(m, "Head", Vector3.new(1.4, 1.5, 3), rel(0, 8.1, 4.6) * CFrame.Angles(math.rad(25), 0, 0), coat)
	part(m, "Mane", Vector3.new(0.5, 3.6, 1.8), rel(0, 7, 2.6) * CFrame.Angles(math.rad(-35), 0, 0), rgb(40, 32, 28), Enum.Material.Fabric)
	part(m, "Tail", Vector3.new(0.6, 3, 0.8), rel(0, 4.4, -3.6) * CFrame.Angles(math.rad(25), 0, 0), rgb(40, 32, 28), Enum.Material.Fabric)
	for _, l in { { -0.8, 2.4 }, { 0.8, 2.4 }, { -0.8, -2.4 }, { 0.8, -2.4 } } do
		part(m, "Leg", Vector3.new(0.7, 3.4, 0.7), rel(l[1], 1.7, l[2]), coat)
		part(m, "Hoof", Vector3.new(0.8, 0.5, 0.9), rel(l[1], 0.25, l[2]), rgb(40, 35, 30))
	end
	if saddled then
		part(m, "Saddle", Vector3.new(2.8, 0.6, 2.4), rel(0, 6.2, 0.2), rgb(120, 40, 35), Enum.Material.Fabric)
		part(m, "Blanket", Vector3.new(2.9, 1.4, 2.8), rel(0, 5.6, 0.2), BANNERS[2], Enum.Material.Fabric)
	end
	return m
end

local function carriage(parent: Instance, x: number, z: number, heading: Vector3, trim: Color3)
	local m = model(parent, "Carriage")
	m:SetAttribute("Vehicle", "carriage")
	local rel = frame(x, z, heading)
	local cab = part(m, "Cabin", Vector3.new(5, 5, 7), rel(0, 4.6, -2), rgb(70, 45, 35), Enum.Material.WoodPlanks)
	m.PrimaryPart = cab
	part(m, "CabinTrim", Vector3.new(5.2, 0.6, 7.2), rel(0, 7.2, -2), trim, Enum.Material.SmoothPlastic)
	part(m, "Roof", Vector3.new(5.6, 0.5, 7.6), rel(0, 7.6, -2), rgb(50, 35, 30), Enum.Material.Wood)
	for _, u in { -2.55, 2.55 } do
		part(m, "Window", Vector3.new(0.1, 2, 2.6), rel(u, 5.4, -2), LANTERN, Enum.Material.Glass)
	end
	part(m, "DriverBench", Vector3.new(4.4, 0.6, 2), rel(0, 5.4, 2.4), rgb(70, 45, 35), Enum.Material.WoodPlanks)
	for _, w in { { -2.8, 0.6, 1.6 }, { 2.8, 0.6, 1.6 }, { -2.8, -4.4, 2.2 }, { 2.8, -4.4, 2.2 } } do
		local wheel = part(m, "Wheel", Vector3.new(0.5, w[3] * 2, w[3] * 2), rel(w[1], w[3], w[2]), TIMBER, Enum.Material.Wood)
		wheel.Shape = Enum.PartType.Cylinder
	end
	part(m, "Shaft", Vector3.new(0.4, 0.4, 7), rel(0, 3.2, 6), TIMBER, Enum.Material.Wood)
	local lamp = part(m, "Lamp", Vector3.new(0.8, 1, 0.8), rel(2.7, 6.6, 1.4), LANTERN, Enum.Material.Neon)
	lamp.Name = "Lamp"
	horse(m, (rel(-1.6, 0, 9)).Position.X, (rel(-1.6, 0, 9)).Position.Z, heading, COATS[1], false).Parent = m
	horse(m, (rel(1.6, 0, 9)).Position.X, (rel(1.6, 0, 9)).Position.Z, heading, COATS[3], false).Parent = m
end

local function cart(parent: Instance, x: number, z: number, heading: Vector3, seed: number)
	local m = model(parent, "Cart")
	m:SetAttribute("Vehicle", "cart")
	local rel = frame(x, z, heading)
	local bed = part(m, "CartBed", Vector3.new(4.6, 0.8, 7), rel(0, 2.4, -1), rgb(150, 105, 68), Enum.Material.WoodPlanks)
	m.PrimaryPart = bed
	for _, s in { -2.3, 2.3 } do
		part(m, "CartSide", Vector3.new(0.4, 1.6, 7), rel(s, 3.4, -1), rgb(130, 90, 58), Enum.Material.WoodPlanks)
		local wheel = part(m, "Wheel", Vector3.new(0.5, 3.6, 3.6), rel(s * 1.2, 1.8, -1), TIMBER, Enum.Material.Wood)
		wheel.Shape = Enum.PartType.Cylinder
	end
	for i = 0, 2 do
		crate(m, (rel(-1, 0, -3 + i * 2.4)).Position.X, 2.8, (rel(-1, 0, -3 + i * 2.4)).Position.Z, 1.8, hash(seed + i))
	end
	barrel(m, (rel(1.2, 0, -1)).Position.X, 2.8, (rel(1.2, 0, -1)).Position.Z)
	part(m, "Shaft", Vector3.new(0.4, 0.4, 6), rel(0, 2.6, 4.8), TIMBER, Enum.Material.Wood)
	horse(m, (rel(0, 0, 8.6)).Position.X, (rel(0, 0, 8.6)).Position.Z, heading, COATS[seed % #COATS + 1], false).Parent = m
end

-- Sailing ships: "rowboat", "sloop" or "galleon".
local function ship(parent: Instance, x: number, z: number, heading: Vector3, kind: string, sailColor: Color3)
	local m = model(parent, "Ship")
	m:SetAttribute("Vehicle", kind)
	local rel = frame(x, z, heading)
	local water = -2
	local hullColor = rgb(110, 72, 45)
	if kind == "rowboat" then
		local hull = part(m, "Hull", Vector3.new(4, 1.6, 8), rel(0, water + 0.4, 0), hullColor, Enum.Material.WoodPlanks)
		m.PrimaryPart = hull
		wedge(m, "Bow", Vector3.new(4, 1.6, 3), rel(0, water + 0.4, 5.5) * CFrame.Angles(0, 0, math.pi), hullColor, Enum.Material.WoodPlanks)
		part(m, "Thwart", Vector3.new(3.6, 0.3, 1), rel(0, water + 1.2, 0), rgb(160, 120, 80), Enum.Material.WoodPlanks)
		for _, s in { -1, 1 } do
			part(m, "Oar", Vector3.new(6, 0.25, 0.4), rel(s * 3.2, water + 1.1, 0) * CFrame.Angles(0, 0, s * math.rad(-15)), rgb(160, 120, 80), Enum.Material.Wood)
		end
		return
	end
	local big = kind == "galleon"
	local L, W, H = if big then 64 else 26, if big then 16 else 8, if big then 8 else 4
	local hull = part(m, "Hull", Vector3.new(W, H, L), rel(0, water + H / 2 - 1.5, 0), hullColor, Enum.Material.WoodPlanks)
	m.PrimaryPart = hull
	wedge(m, "Bow", Vector3.new(W, H, L * 0.22), rel(0, water + H / 2 - 1.5, L / 2 + L * 0.11) * CFrame.Angles(0, 0, math.pi), hullColor, Enum.Material.WoodPlanks)
	part(m, "Stripe", Vector3.new(W + 0.1, H * 0.15, L + 0.1), rel(0, water + H - 2.4, 0), GOLD, Enum.Material.SmoothPlastic)
	part(m, "Deck", Vector3.new(W - 0.6, 0.4, L), rel(0, water + H - 1.3, 0), rgb(175, 135, 90), Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		part(m, "Rail", Vector3.new(0.4, 1.4, L), rel(s * (W / 2 - 0.2), water + H - 0.4, 0), hullColor, Enum.Material.WoodPlanks)
	end
	if big then
		-- raised aftcastle with windows and lantern, and a forecastle
		part(m, "Aftcastle", Vector3.new(W, 7, 14), rel(0, water + H + 2, -L / 2 + 7), hullColor, Enum.Material.WoodPlanks)
		part(m, "SternWindows", Vector3.new(W - 3, 2, 0.3), rel(0, water + H + 2.4, -L / 2 - 0.1), LANTERN, Enum.Material.Neon)
		part(m, "Forecastle", Vector3.new(W - 2, 4, 9), rel(0, water + H + 0.6, L / 2 - 6), hullColor, Enum.Material.WoodPlanks)
		local sternLamp = part(m, "SternLantern", Vector3.new(1.4, 2, 1.4), rel(0, water + H + 7, -L / 2 - 0.8), LANTERN, Enum.Material.Neon)
		glowLight(sternLamp, 18, 1, LANTERN)
		for i, v in { -14, 4, 20 } do
			local mh = if i == 2 then 46 else 36
			part(m, "Mast", Vector3.new(1.2, mh, 1.2), rel(0, water + H + mh / 2 - 1, v), rgb(120, 85, 55), Enum.Material.Wood)
			for k = 0, 1 do
				local sy = water + H + 9 + k * (mh * 0.38)
				local sw = 18 - k * 4
				part(m, "Yard", Vector3.new(sw + 2, 0.6, 0.6), rel(0, sy + 5.5, v), rgb(120, 85, 55), Enum.Material.Wood)
				part(m, "Sail", Vector3.new(sw, 10, 0.4), rel(0, sy, v + 0.6) * CFrame.Angles(math.rad(-6), 0, 0), WHITE, Enum.Material.Fabric)
				if k == 0 then
					part(m, "SailEmblem", Vector3.new(sw * 0.4, 4, 0.45), rel(0, sy, v + 0.65) * CFrame.Angles(math.rad(-6), 0, 0), sailColor, Enum.Material.Fabric)
				end
			end
			part(m, "Pennant", Vector3.new(0.2, 1.4, 4), rel(0, water + H + mh, v - 2), sailColor, Enum.Material.Fabric)
		end
		part(m, "Bowsprit", Vector3.new(0.8, 0.8, 18), rel(0, water + H + 2, L / 2 + 10) * CFrame.Angles(math.rad(18), 0, 0), rgb(120, 85, 55), Enum.Material.Wood)
	else
		part(m, "Cabin", Vector3.new(W - 2, 3, 7), rel(0, water + H + 0.2, -L / 2 + 5), hullColor, Enum.Material.WoodPlanks)
		part(m, "Mast", Vector3.new(0.8, 24, 0.8), rel(0, water + H + 11, 2), rgb(120, 85, 55), Enum.Material.Wood)
		wedge(m, "Sail", Vector3.new(0.3, 18, 10), rel(0, water + H + 11, -3.5) * CFrame.Angles(0, math.pi, 0), WHITE, Enum.Material.Fabric)
		wedge(m, "Jib", Vector3.new(0.3, 14, 7), rel(0, water + H + 9, 6), sailColor, Enum.Material.Fabric)
	end
end

local function airship(parent: Instance, x: number, y: number, z: number, heading: Vector3, color: Color3)
	local m = model(parent, "Airship")
	m:SetAttribute("Vehicle", "airship")
	m:SetAttribute("Bob", "float")
	local rel = frame(x, z, heading)
	local envelope = tube(m, "Envelope", 48, 18, rel(0, y + 16, 0), color, Enum.Material.Fabric)
	m.PrimaryPart = envelope
	ball(m, "EnvelopeNose", 18, 0, 0, 0, color, Enum.Material.Fabric).CFrame = rel(0, y + 16, 24)
	ball(m, "EnvelopeTail", 18, 0, 0, 0, color, Enum.Material.Fabric).CFrame = rel(0, y + 16, -24)
	for k = -2, 2 do
		tube(m, "Rib", 1, 18.4, rel(0, y + 16, k * 10), GOLD, Enum.Material.Fabric)
	end
	-- tail fins
	part(m, "FinTop", Vector3.new(0.6, 9, 9), rel(0, y + 26, -28), color, Enum.Material.Fabric)
	part(m, "FinSide", Vector3.new(16, 0.6, 8), rel(0, y + 16, -29), color, Enum.Material.Fabric)
	-- gondola: a small ship hull hung under the envelope
	part(m, "Gondola", Vector3.new(7, 3.6, 24), rel(0, y + 2, 0), rgb(110, 72, 45), Enum.Material.WoodPlanks)
	wedge(m, "GondolaBow", Vector3.new(7, 3.6, 5), rel(0, y + 2, 14.5) * CFrame.Angles(0, 0, math.pi), rgb(110, 72, 45), Enum.Material.WoodPlanks)
	part(m, "GondolaRail", Vector3.new(7.2, 1, 24.2), rel(0, y + 4.3, 0), GOLD, Enum.Material.SmoothPlastic)
	part(m, "Cabin", Vector3.new(5.6, 3, 8), rel(0, y + 5.3, -5), rgb(130, 90, 58), Enum.Material.WoodPlanks)
	part(m, "CabinWindows", Vector3.new(5.8, 1, 6), rel(0, y + 5.6, -5), LANTERN, Enum.Material.Neon)
	for _, c in { { -3.3, 9 }, { 3.3, 9 }, { -3.3, -9 }, { 3.3, -9 } } do
		local a = rel(c[1], y + 4, c[2]).Position
		local b = rel(c[1] * 1.8, y + 10, c[2] * 1.2).Position
		deco(part(m, "Rigging", Vector3.new(0.2, 0.2, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), rgb(90, 80, 70), Enum.Material.Fabric))
	end
	for _, s in { -1, 1 } do
		tube(m, "EngineArm", 6, 0.6, rel(s * 5, y + 4, -9) * CFrame.Angles(0, math.rad(90), 0), IRON, Enum.Material.Metal)
		part(m, "Propeller", Vector3.new(1, 7, 0.3), rel(s * 8, y + 4, -12), rgb(150, 110, 70), Enum.Material.Wood)
		part(m, "Propeller", Vector3.new(7, 1, 0.3), rel(s * 8, y + 4, -12), rgb(150, 110, 70), Enum.Material.Wood)
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
		end
	end
end

----------------------------------------------------------------------------------------------
-- buildings

-- Timber-framed shop: plastered walls, a jettied upper floor, a front gable, a hanging sign and
-- an invisible ShopAnchor where the shop system will put its prompt. `id` is the Shop attribute.
local function shop(parent: Instance, x: number, z: number, w: number, facing: Vector3, name: string, id: string, seed: number)
	local m = model(parent, "Shop")
	m:SetAttribute("Shop", id)
	local rel = frame(x, z, facing)
	local wall = PLASTER[seed % #PLASTER + 1]
	local roof = ROOFS[(seed * 5) % #ROOFS + 1]
	local d = 18
	-- ground floor (stone) and the jettied timber upper floor
	part(m, "Ground", Vector3.new(w, 8, d), rel(0, PAVE + 4, 0), STONE, Enum.Material.Cobblestone)
	part(m, "Upper", Vector3.new(w + 1, 8, d + 1.6), rel(0, PAVE + 12, 0.8), wall, Enum.Material.Plaster)
	for _, u in { -w / 2 - 0.3, -w / 6, w / 6, w / 2 + 0.3 } do
		part(m, "Post", Vector3.new(0.7, 8, 0.4), rel(u, PAVE + 12, d / 2 + 1.7), TIMBER, Enum.Material.Wood)
	end
	part(m, "Beam", Vector3.new(w + 1.4, 0.8, 0.5), rel(0, PAVE + 8.2, d / 2 + 1.7), TIMBER, Enum.Material.Wood)
	part(m, "Beam", Vector3.new(w + 1.4, 0.7, 0.5), rel(0, PAVE + 15.8, d / 2 + 1.7), TIMBER, Enum.Material.Wood)
	for _, s in { -1, 1 } do
		part(m, "Brace", Vector3.new(0.5, 8.6, 0.35), rel(s * w / 3, PAVE + 12, d / 2 + 1.75) * CFrame.Angles(0, 0, s * math.rad(35)), TIMBER, Enum.Material.Wood)
	end
	gableFront(m, rel, w + 1, d + 1.6, PAVE + 16, wall, roof)
	-- shop window, door and shutters
	part(m, "ShopWindow", Vector3.new(w * 0.45, 4.2, 0.3), rel(-w * 0.18, PAVE + 4, d / 2 + 0.1), LANTERN, Enum.Material.Glass)
	part(m, "WindowFrame", Vector3.new(w * 0.45 + 1, 0.6, 0.5), rel(-w * 0.18, PAVE + 1.8, d / 2 + 0.2), TIMBER, Enum.Material.Wood)
	part(m, "Door", Vector3.new(3.6, 6.4, 0.4), rel(w * 0.28, PAVE + 3.2, d / 2 + 0.2), rgb(110, 70, 45), Enum.Material.WoodPlanks)
	part(m, "DoorArch", Vector3.new(4.4, 0.8, 0.5), rel(w * 0.28, PAVE + 6.6, d / 2 + 0.25), DARKSTONE, Enum.Material.Cobblestone)
	for _, u in { -w / 4, w / 4 } do
		part(m, "UpperWindow", Vector3.new(2.6, 3, 0.3), rel(u, PAVE + 12.4, d / 2 + 1.75), rgb(80, 105, 130), Enum.Material.Glass)
		part(m, "WindowBox", Vector3.new(3.2, 0.8, 1), rel(u, PAVE + 10.6, d / 2 + 2.1), TIMBER, Enum.Material.WoodPlanks)
		local flowers = { rgb(255, 110, 150), rgb(255, 225, 90), rgb(170, 130, 255) }
		for k = 1, 3 do
			local bloom = part(m, "Bloom", Vector3.new(0.8, 0.8, 0.8), rel(u - 1.6 + k * 0.8, PAVE + 11.3, d / 2 + 2.2), flowers[(seed + k) % 3 + 1])
			bloom.Shape = Enum.PartType.Ball
		end
	end
	part(m, "Chimney", Vector3.new(2, 8, 2), rel(w / 3, PAVE + 20, -d / 4), rgb(150, 100, 85), Enum.Material.Brick)
	-- hanging sign on an iron bracket, readable from both directions along the street
	local bracket = part(m, "SignBracket", Vector3.new(0.3, 0.3, 4), rel(-w / 2 + 1, PAVE + 9.4, d / 2 + 3.6), IRON, Enum.Material.Metal)
	bracket.Name = "SignBracket"
	local board = part(m, "HangingSign", Vector3.new(0.4, 3, 6), rel(-w / 2 + 1, PAVE + 7.6, d / 2 + 4.6), rgb(150, 105, 65), Enum.Material.WoodPlanks)
	sign(board, name, rgb(255, 235, 170), Enum.NormalId.Left)
	sign(board, name, rgb(255, 235, 170), Enum.NormalId.Right)
	local overDoor = part(m, "NameBoard", Vector3.new(w * 0.7, 2, 0.4), rel(0, PAVE + 7.2, d / 2 + 0.3), rgb(60, 45, 35), Enum.Material.WoodPlanks)
	sign(overDoor, name, GOLD)
	local anchor = part(m, "ShopAnchor", Vector3.new(4, 4, 4), rel(w * 0.28, PAVE + 2.5, d / 2 + 4), WHITE, nil, { Transparency = 1, CanCollide = false })
	anchor:SetAttribute("Shop", id)
	-- trade-specific details out front
	if id == "blacksmith" then
		box(m, "Anvil", (rel(-w * 0.2, 0, d / 2 + 4)).Position.X, PAVE, (rel(-w * 0.2, 0, d / 2 + 4)).Position.Z, 1.4, 2.2, 2.6, IRON, Enum.Material.Metal)
		local forge = box(m, "Forge", (rel(-w * 0.38, 0, d / 2 + 3.4)).Position.X, PAVE, (rel(-w * 0.38, 0, d / 2 + 3.4)).Position.Z, 3, 2.6, 3, rgb(120, 110, 100), Enum.Material.Cobblestone)
		local coals = box(m, "Coals", forge.CFrame.Position.X, PAVE + 2.6, forge.CFrame.Position.Z, 2.2, 0.4, 2.2, rgb(255, 120, 40), Enum.Material.Neon)
		glowLight(coals, 14, 1.4, rgb(255, 140, 60))
	elseif id == "alchemist" then
		for k = 0, 2 do
			local bottle = part(m, "Potion", Vector3.new(1, 1.6, 1), rel(-w * 0.3 + k * 1.6, PAVE + 7, d / 2 + 0.6), ({ rgb(120, 255, 160), rgb(255, 90, 160), rgb(120, 170, 255) })[k + 1], Enum.Material.Neon)
			bottle.Shape = Enum.PartType.Cylinder
		end
	elseif id == "tavern" then
		barrel(m, (rel(-w * 0.35, 0, d / 2 + 3)).Position.X, PAVE, (rel(-w * 0.35, 0, d / 2 + 3)).Position.Z)
		barrel(m, (rel(-w * 0.2, 0, d / 2 + 3)).Position.X, PAVE, (rel(-w * 0.2, 0, d / 2 + 3)).Position.Z)
	end
	return m
end

-- Tall, narrow timber townhouse with a jetty on every upper floor.
local function townhouse(parent: Instance, x: number, z: number, w: number, d: number, floors: number, facing: Vector3, seed: number)
	local m = model(parent, "Townhouse")
	local rel = frame(x, z, facing)
	local wall = PLASTER[(seed * 3) % #PLASTER + 1]
	local roof = ROOFS[seed % #ROOFS + 1]
	part(m, "Ground", Vector3.new(w, 7, d), rel(0, PAVE + 3.5, 0), STONE, Enum.Material.Cobblestone)
	part(m, "Door", Vector3.new(3, 5.6, 0.3), rel(-w / 4, PAVE + 2.8, d / 2 + 0.15), rgb(105, 65, 42), Enum.Material.WoodPlanks)
	part(m, "Window", Vector3.new(3, 2.6, 0.3), rel(w / 4, PAVE + 3.8, d / 2 + 0.15), rgb(80, 105, 130), Enum.Material.Glass)
	local y = PAVE + 7
	local jut = 0
	for f = 1, floors - 1 do
		jut += 0.8
		part(m, "Floor", Vector3.new(w + jut * 0.6, 7, d + jut), rel(0, y + 3.5, jut / 2), wall, Enum.Material.Plaster)
		part(m, "Beam", Vector3.new(w + jut * 0.6 + 0.4, 0.6, 0.4), rel(0, y + 0.3, d / 2 + jut + 0.1), TIMBER, Enum.Material.Wood)
		for _, u in { -w / 2, 0, w / 2 } do
			part(m, "Post", Vector3.new(0.6, 7, 0.35), rel(u, y + 3.5, d / 2 + jut + 0.1), TIMBER, Enum.Material.Wood)
		end
		for _, u in { -w / 4, w / 4 } do
			part(m, "Window", Vector3.new(2.4, 2.8, 0.3), rel(u, y + 3.8, d / 2 + jut + 0.05), if (seed + f + u) % 3 == 0 then LANTERN else rgb(80, 105, 130), Enum.Material.Glass)
		end
		y += 7
	end
	gableFront(m, rel, w + jut * 0.6, d + jut, y, wall, roof)
	part(m, "Chimney", Vector3.new(1.8, 6, 1.8), rel(w / 4, y + w / 3, -d / 4), rgb(150, 100, 85), Enum.Material.Brick)
end

local function cottageHome(parent: Instance, x: number, z: number, facing: Vector3, seed: number)
	local m = model(parent, "Cottage")
	local rel = frame(x, z, facing)
	local wall = PLASTER[seed % #PLASTER + 1]
	local roof = ROOFS[(seed * 7) % #ROOFS + 1]
	local W, D, H = 16, 12, 9
	part(m, "Walls", Vector3.new(W, H, D), rel(0, PAVE + H / 2, 0), wall, Enum.Material.Plaster)
	for _, u in { -W / 2, -2.4, 2.4, W / 2 } do
		part(m, "Timber", Vector3.new(0.7, H, 0.4), rel(u, PAVE + H / 2, D / 2 + 0.1), TIMBER, Enum.Material.Wood)
	end
	part(m, "Timber", Vector3.new(W, 0.7, 0.4), rel(0, PAVE + H - 0.3, D / 2 + 0.1), TIMBER, Enum.Material.Wood)
	gableSide(m, rel, W, D, PAVE + H, wall, roof)
	part(m, "Door", Vector3.new(3.2, 6, 0.3), rel(0, PAVE + 3, D / 2 + 0.15), rgb(110, 70, 45), Enum.Material.WoodPlanks)
	for _, u in { -5, 5 } do
		part(m, "Window", Vector3.new(2.6, 2.6, 0.3), rel(u, PAVE + 5, D / 2 + 0.15), LANTERN, Enum.Material.Glass)
	end
	part(m, "Chimney", Vector3.new(2, 7, 2), rel(W / 3, PAVE + H + 4, -D / 4), rgb(150, 100, 85), Enum.Material.Brick)
	-- front garden with a low stone wall and herb beds
	part(m, "Garden", Vector3.new(W + 2, 0.2, 8), rel(0, PAVE + 0.1, D / 2 + 4.5), rgb(110, 180, 85), Enum.Material.Grass)
	for _, s in { -1, 1 } do
		part(m, "GardenWall", Vector3.new(W / 2 - 1.5, 1.6, 0.8), rel(s * (W / 4 + 1.1), PAVE + 0.8, D / 2 + 8.6), DARKSTONE, Enum.Material.Cobblestone)
		part(m, "HerbBed", Vector3.new(4, 0.6, 3), rel(s * 5, PAVE + 0.3, D / 2 + 4), rgb(110, 75, 50), Enum.Material.Ground)
		for k = 0, 2 do
			local herb = part(m, "Herb", Vector3.new(1.1, 1.1, 1.1), rel(s * 5 - 1.4 + k * 1.4, PAVE + 1, D / 2 + 4), if (seed + k) % 2 == 0 then rgb(90, 180, 80) else rgb(170, 130, 230))
			herb.Shape = Enum.PartType.Ball
		end
	end
end

-- Long stone hall with buttresses, a side-gabled roof, corner turrets and a sign board.
local function guildHall(parent: Instance, x: number, z: number, w: number, d: number, facing: Vector3, name: string, accent: Color3): Model
	local m = model(parent, name)
	local rel = frame(x, z, facing)
	local H = 18
	part(m, "Walls", Vector3.new(w, H, d), rel(0, PAVE + H / 2, 0), STONE, Enum.Material.Cobblestone)
	gableSide(m, rel, w, d, PAVE + H, STONE, ROOFS[2], Enum.Material.Cobblestone)
	for k = 0, 4 do
		local u = -w / 2 + 2 + k * (w - 4) / 4
		part(m, "Buttress", Vector3.new(2, H - 2, 3), rel(u, PAVE + (H - 2) / 2, d / 2 + 1.2), DARKSTONE, Enum.Material.Cobblestone)
		if k < 4 then
			local wu = u + (w - 4) / 8
			part(m, "TallWindow", Vector3.new(2.6, 8, 0.3), rel(wu, PAVE + 10, d / 2 + 0.15), rgb(90, 120, 170), Enum.Material.Glass)
			part(m, "WindowArch", Vector3.new(3.2, 0.8, 0.4), rel(wu, PAVE + 14.2, d / 2 + 0.2), DARKSTONE, Enum.Material.Cobblestone)
		end
	end
	part(m, "Doors", Vector3.new(7, 10, 0.5), rel(0, PAVE + 5, d / 2 + 0.25), rgb(95, 60, 40), Enum.Material.WoodPlanks)
	part(m, "DoorArch", Vector3.new(9, 1.4, 0.8), rel(0, PAVE + 10.6, d / 2 + 0.4), DARKSTONE, Enum.Material.Cobblestone)
	part(m, "Steps", Vector3.new(12, 1, 4), rel(0, PAVE + 0.5, d / 2 + 2), DARKSTONE, Enum.Material.Cobblestone)
	for _, s in { -1, 1 } do
		local tx, tz = (rel(s * w / 2, 0, d / 2)).Position.X, (rel(s * w / 2, 0, d / 2)).Position.Z
		cylinder(m, "Turret", H + 8, 6, tx, PAVE + (H + 8) / 2, tz, STONE, Enum.Material.Cobblestone)
		cone(m, "TurretRoof", tx, PAVE + H + 8, tz, 4, 7, ROOFS[2], Enum.Material.Slate, 6)
		banner(m, (rel(s * 6, 0, d / 2 + 0.3)).Position.X, PAVE + 16, (rel(s * 6, 0, d / 2 + 0.3)).Position.Z, facing, accent, 7)
	end
	local board = part(m, "NameBoard", Vector3.new(math.min(w * 0.6, 30), 2.6, 0.5), rel(0, PAVE + 12.4, d / 2 + 0.6), rgb(50, 40, 35), Enum.Material.WoodPlanks)
	sign(board, name, GOLD)
	return m
end

local function cathedral(parent: Instance, cx: number, cz: number, facing: Vector3)
	local m = model(parent, "Cathedral")
	local rel = frame(cx, cz, facing)
	local W, D, H = 30, 64, 30
	part(m, "Nave", Vector3.new(W, H, D), rel(0, PAVE + H / 2, -4), STONE, Enum.Material.Cobblestone)
	gableFront(m, rel, W, D, PAVE + H, STONE, ROOFS[2])
	for _, s in { -1, 1 } do
		part(m, "Aisle", Vector3.new(10, 16, D - 10), rel(s * (W / 2 + 5), PAVE + 8, -6), DARKSTONE, Enum.Material.Cobblestone)
		part(m, "AisleRoof", Vector3.new(12, 0.8, D - 8), rel(s * (W / 2 + 5), PAVE + 17, -6) * CFrame.Angles(0, 0, s * math.rad(-20)), ROOFS[2], Enum.Material.Slate)
		for k = 0, 5 do
			local v = -D / 2 + 6 + k * (D - 14) / 5
			part(m, "Buttress", Vector3.new(2, 20, 2.4), rel(s * (W / 2 + 10.6), PAVE + 10, v - 4), DARKSTONE, Enum.Material.Cobblestone)
			part(m, "StainedGlass", Vector3.new(0.3, 9, 2.4), rel(s * (W / 2 + 0.1), PAVE + 22, v - 4), ({ rgb(90, 140, 255), rgb(255, 90, 120), rgb(255, 210, 80), rgb(120, 220, 140) })[k % 4 + 1], Enum.Material.Neon)
		end
	end
	-- twin west towers with spires, a rose window and great doors
	for _, s in { -1, 1 } do
		local tx, tz = (rel(s * (W / 2 + 4), 0, D / 2 + 2)).Position.X, (rel(s * (W / 2 + 4), 0, D / 2 + 2)).Position.Z
		box(m, "Tower", tx, PAVE, tz, 12, 52, 12, STONE, Enum.Material.Cobblestone)
		box(m, "Belfry", tx, PAVE + 44, tz, 12.6, 1, 12.6, DARKSTONE, Enum.Material.Cobblestone)
		part(m, "BelfryOpening", Vector3.new(4, 6, 12.8), CFrame.new(tx, PAVE + 48, tz), rgb(40, 35, 40), Enum.Material.SmoothPlastic)
		cone(m, "Spire", tx, PAVE + 52, tz, 8.6, 26, ROOFS[2], Enum.Material.Slate, 4)
		ball(m, "SpireOrb", 1.6, tx, PAVE + 78.6, tz, GOLD, Enum.Material.Metal)
	end
	local rose = cylinder(m, "RoseWindow", 0.6, 12, 0, 0, 0, rgb(255, 120, 170), Enum.Material.Neon)
	rose.CFrame = rel(0, PAVE + 22, D / 2 - 3.6) * CFrame.Angles(0, math.rad(90), 0)
	local roseInner = cylinder(m, "RoseInner", 0.7, 6, 0, 0, 0, rgb(120, 160, 255), Enum.Material.Neon)
	roseInner.CFrame = rel(0, PAVE + 22, D / 2 - 3.5) * CFrame.Angles(0, math.rad(90), 0)
	part(m, "GreatDoors", Vector3.new(9, 14, 0.6), rel(0, PAVE + 7, D / 2 - 3.7), rgb(95, 60, 40), Enum.Material.WoodPlanks)
	part(m, "Portal", Vector3.new(13, 2, 1.4), rel(0, PAVE + 15, D / 2 - 3.4), DARKSTONE, Enum.Material.Cobblestone)
	-- crossing tower over the middle of the nave
	local cxp, czp = (rel(0, 0, -6)).Position.X, (rel(0, 0, -6)).Position.Z
	box(m, "CrossingTower", cxp, PAVE + H, czp, 14, 18, 14, STONE, Enum.Material.Cobblestone)
	cone(m, "CrossingSpire", cxp, PAVE + H + 18, czp, 10, 30, ROOFS[2], Enum.Material.Slate, 8)
	ball(m, "CrossingOrb", 2, cxp, PAVE + H + 48.8, czp, GOLD, Enum.Material.Metal)
	-- rounded apse at the east end
	local ax, az = (rel(0, 0, -D / 2 - 4)).Position.X, (rel(0, 0, -D / 2 - 4)).Position.Z
	cylinder(m, "Apse", 24, 26, ax, PAVE + 12, az, STONE, Enum.Material.Cobblestone)
	cone(m, "ApseRoof", ax, PAVE + 24, az, 14, 9, ROOFS[2], Enum.Material.Slate, 8)
	part(m, "Steps", Vector3.new(20, 1.2, 6), rel(0, PAVE + 0.6, D / 2 + 1), DARKSTONE, Enum.Material.Cobblestone)
end

local function mageTower(parent: Instance, x: number, z: number)
	local m = model(parent, "Mage Tower")
	local stone = rgb(190, 185, 210)
	local roof = rgb(90, 60, 150)
	local y = PAVE
	for i, t in { { 26, 30 }, { 21, 28 }, { 16, 26 } } do
		local d, h = t[1], t[2]
		cylinder(m, "Tier", h, d, x, y + h / 2, z, stone, Enum.Material.Cobblestone)
		cylinder(m, "Balcony", 1, d + 4, x, y + h, z, rgb(150, 145, 170), Enum.Material.Cobblestone)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2 + i
			part(m, "GlowWindow", Vector3.new(1.6, 4, 0.4), CFrame.lookAt(Vector3.new(x + math.cos(a) * d / 2, y + h * 0.55, z + math.sin(a) * d / 2), Vector3.new(x + math.cos(a) * d, y + h * 0.55, z + math.sin(a) * d)), rgb(170, 120, 255), Enum.Material.Neon)
		end
		y += h
	end
	cone(m, "Spire", x, y + 1, z, 12, 34, roof, Enum.Material.Slate, 8)
	local orb = ball(m, "ArcaneOrb", 4, x, y + 40, z, rgb(170, 120, 255), Enum.Material.Neon)
	glowLight(orb, 40, 2, rgb(170, 120, 255))
	part(m, "Door", Vector3.new(5, 8, 0.6), CFrame.new(x, PAVE + 4, z - 13.2), rgb(70, 50, 90), Enum.Material.WoodPlanks)
	local plaque = part(m, "NameBoard", Vector3.new(10, 2, 0.4), CFrame.new(x, PAVE + 9.4, z - 13.4) * CFrame.Angles(0, math.pi, 0), rgb(50, 35, 70), Enum.Material.SmoothPlastic)
	sign(plaque, "Mage Tower", rgb(220, 190, 255))
	-- three floating rune stones that the client bobs
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		local rune = model(m, "RuneStone")
		local stoneP = part(rune, "Rune", Vector3.new(2.4, 4, 1), CFrame.new(x + math.cos(a) * 22, PAVE + 22 + k * 6, z + math.sin(a) * 22) * CFrame.Angles(0, a, math.rad(10)), rgb(150, 140, 170), Enum.Material.Slate)
		rune.PrimaryPart = stoneP
		part(rune, "Glyph", Vector3.new(1, 2, 1.1), stoneP.CFrame, rgb(190, 140, 255), Enum.Material.Neon)
		rune:SetAttribute("Bob", true)
	end
end

local function marketSquare(parent: Instance, x0: number, x1: number, z0: number, z1: number)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	box(parent, "Square", cx, PAVE, cz, x1 - x0 - 2, 0.1, z1 - z0 - 2, rgb(210, 195, 170), Enum.Material.Slate)
	-- three-tier fountain
	cylinder(parent, "FountainBasin", 2.4, 26, cx, PAVE + 1.2, cz, STONE, Enum.Material.Cobblestone)
	cylinder(parent, "FountainWater", 0.4, 23, cx, PAVE + 2.3, cz, rgb(80, 170, 225), Enum.Material.Glass).Transparency = 0.2
	cylinder(parent, "FountainStem", 8, 3, cx, PAVE + 5, cz, STONE, Enum.Material.Cobblestone)
	cylinder(parent, "FountainBowl", 1.2, 12, cx, PAVE + 8.6, cz, STONE, Enum.Material.Cobblestone)
	cylinder(parent, "FountainBowl", 1, 6, cx, PAVE + 11.6, cz, STONE, Enum.Material.Cobblestone)
	cylinder(parent, "FountainJet", 3, 1, cx, PAVE + 13.5, cz, rgb(200, 240, 255), Enum.Material.Neon).Transparency = 0.4
	-- stalls in a ring and a notice board
	local colors = { rgb(200, 55, 60), rgb(55, 90, 180), rgb(60, 140, 90), rgb(220, 170, 50), rgb(130, 70, 160), rgb(230, 120, 60) }
	local r = math.min(x1 - x0, z1 - z0) / 2 - 14
	for k = 0, 7 do
		local a = (k + 0.5) / 8 * math.pi * 2
		local sx, sz = cx + math.cos(a) * r, cz + math.sin(a) * r
		marketStall(parent, sx, sz, Vector3.new(cx - sx, 0, cz - sz).Unit, colors[k % #colors + 1], k)
	end
	local board = box(parent, "NoticeBoard", cx, PAVE + 2, cz - 18, 8, 5, 0.6, rgb(130, 90, 58), Enum.Material.WoodPlanks)
	sign(board, "Bounties & Quests", rgb(60, 40, 25), Enum.NormalId.Back, rgb(235, 220, 180))
	for _, s in { -1, 1 } do
		box(parent, "NoticePost", cx + s * 4.2, PAVE, cz - 18, 0.6, 7.5, 0.6, TIMBER, Enum.Material.Wood)
	end
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		lanternPost(parent, cx + c[1] * (r - 6), cz + c[2] * (r - 6))
	end
end

-- Round arena with tiered stands, sand floor and gates; Arena attribute marks the PvP zone.
local function arena(parent: Instance, x0: number, x1: number, z0: number, z1: number)
	local m = model(parent, "Arena")
	m:SetAttribute("Arena", true)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local R = math.min(x1 - x0, z1 - z0) / 2 - 3
	cylinder(m, "ArenaFloor", 0.6, (R - 14) * 2, cx, PAVE + 0.3, cz, rgb(225, 200, 150), Enum.Material.Sand)
	local segs = 20
	for k = 0, segs - 1 do
		local a = (k + 0.5) / segs * math.pi * 2
		local gate = k % 5 == 0
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local arc = 2 * math.pi * R / segs + 0.6
		for tier = 0, 2 do
			if not gate or tier > 0 then
				local rr = R - 12 + tier * 4
				local p = Vector3.new(cx, 0, cz) + dir * rr
				part(m, "Stand", Vector3.new(2 * math.pi * rr / segs + 0.6, 3 + tier * 3, 4), CFrame.lookAt(Vector3.new(p.X, PAVE + (3 + tier * 3) / 2, p.Z), Vector3.new(p.X, PAVE + (3 + tier * 3) / 2, p.Z) + dir), if tier % 2 == 0 then STONE else DARKSTONE, Enum.Material.Cobblestone)
			end
		end
		local p = Vector3.new(cx, 0, cz) + dir * R
		local wallH = if gate then 6 else 16
		part(m, "OuterWall", Vector3.new(arc, wallH, 2.4), CFrame.lookAt(Vector3.new(p.X, PAVE + if gate then 13 else 8, p.Z), Vector3.new(p.X, PAVE + if gate then 13 else 8, p.Z) + dir), STONE, Enum.Material.Cobblestone)
		if gate then
			part(m, "Portcullis", Vector3.new(arc - 2, 10, 0.4), CFrame.lookAt(Vector3.new(p.X, PAVE + 5, p.Z), Vector3.new(p.X, PAVE + 5, p.Z) + dir), IRON, Enum.Material.DiamondPlate).Transparency = 0.3
			local pole = Vector3.new(cx, 0, cz) + dir * (R + 1.6)
			cylinder(m, "FlagPole", 10, 0.4, pole.X, PAVE + 21, pole.Z, IRON, Enum.Material.Metal)
			part(m, "Flag", Vector3.new(0.2, 3, 5), CFrame.new(pole.X, PAVE + 24.5, pole.Z + 2.6), BANNERS[(k // 5) % #BANNERS + 1], Enum.Material.Fabric)
		end
	end
	local board = box(m, "ArenaSign", cx, PAVE + 17, z0 + 2, 18, 3, 0.6, rgb(50, 40, 35), Enum.Material.WoodPlanks)
	sign(board, "The Arena", GOLD, Enum.NormalId.Back)
end

local function clockTower(parent: Instance, x: number, z: number, facing: Vector3)
	box(parent, "ClockTower", x, PAVE, z, 12, 46, 12, STONE, Enum.Material.Cobblestone)
	box(parent, "ClockBand", x, PAVE + 34, z, 12.8, 1, 12.8, DARKSTONE, Enum.Material.Cobblestone)
	local face = cylinder(parent, "ClockFace", 0.5, 8, 0, 0, 0, WHITE, Enum.Material.SmoothPlastic)
	local base = CFrame.lookAt(Vector3.new(x, PAVE + 39, z) + facing * 6.2, Vector3.new(x, PAVE + 39, z) + facing * 7)
	face.CFrame = base * CFrame.Angles(0, math.rad(90), 0)
	part(parent, "HourHand", Vector3.new(0.4, 2.6, 0.2), base * CFrame.new(0, 1.1, -0.3), IRON, Enum.Material.Metal)
	part(parent, "MinuteHand", Vector3.new(3.4, 0.3, 0.2), base * CFrame.new(1.5, 0, -0.35), IRON, Enum.Material.Metal)
	cone(parent, "ClockSpire", x, PAVE + 46, z, 8.6, 18, ROOFS[1], Enum.Material.Slate, 4)
	ball(parent, "ClockOrb", 1.4, x, PAVE + 64.6, z, GOLD, Enum.Material.Metal)
end

local function trainingYard(parent: Instance, x: number, z: number, w: number, d: number)
	box(parent, "YardDirt", x, PAVE, z, w, 0.2, d, rgb(170, 140, 100), Enum.Material.Ground)
	for k = 0, 3 do
		local dx = x - w / 2 + 6 + k * (w - 12) / 3
		box(parent, "DummyPost", dx, PAVE, z, 0.6, 7, 0.6, TIMBER, Enum.Material.Wood)
		box(parent, "DummyArms", dx, PAVE + 5, z, 5, 0.5, 0.5, TIMBER, Enum.Material.Wood)
		ball(parent, "DummySack", 3, dx, PAVE + 4.6, z, rgb(210, 190, 140), Enum.Material.Fabric)
		ball(parent, "DummyHead", 2, dx, PAVE + 7.2, z, rgb(210, 190, 140), Enum.Material.Fabric)
	end
	box(parent, "WeaponRack", x, PAVE, z - d / 2 + 2, 10, 4, 1, TIMBER, Enum.Material.WoodPlanks)
	for k = 0, 4 do
		box(parent, "RackSword", x - 4 + k * 2, PAVE + 1, z - d / 2 + 2.6, 0.3, 6, 0.3, rgb(200, 205, 215), Enum.Material.Metal)
	end
	for k = 0, 1 do
		local tx = x - w / 2 + 4 + k * 6
		cylinder(parent, "Target", 0.6, 5, 0, 0, 0, rgb(240, 240, 230), Enum.Material.Fabric).CFrame = CFrame.new(tx, PAVE + 3.5, z + d / 2 - 3) * CFrame.Angles(0, math.rad(90), 0)
		cylinder(parent, "Bullseye", 0.7, 2, 0, 0, 0, rgb(220, 50, 50), Enum.Material.Fabric).CFrame = CFrame.new(tx, PAVE + 3.5, z + d / 2 - 3.05) * CFrame.Angles(0, math.rad(90), 0)
	end
end

local function temple(parent: Instance, x: number, z: number, facing: Vector3)
	local m = model(parent, "Temple of Healing")
	local rel = frame(x, z, facing)
	local marble = rgb(245, 242, 235)
	part(m, "Base", Vector3.new(40, 3, 36), rel(0, PAVE + 1.5, 0), marble, Enum.Material.Marble)
	part(m, "Hall", Vector3.new(30, 18, 26), rel(0, PAVE + 12, -2), marble, Enum.Material.Marble)
	for k = 0, 5 do
		cylinder(m, "Column", 16, 2.2, 0, 0, 0, marble, Enum.Material.Marble).CFrame = rel(-15 + k * 6, PAVE + 11, 15) * CFrame.Angles(0, 0, math.rad(90))
	end
	part(m, "Entablature", Vector3.new(36, 3, 34), rel(0, PAVE + 20.5, 0), marble, Enum.Material.Marble)
	cylinder(m, "Drum", 6, 20, 0, 0, 0, marble, Enum.Material.Marble).CFrame = rel(0, PAVE + 25, -2) * CFrame.Angles(0, 0, math.rad(90))
	ball(m, "Dome", 20, 0, 0, 0, rgb(120, 200, 190), Enum.Material.Metal).CFrame = rel(0, PAVE + 28, -2)
	local flame = ball(m, "SacredFlame", 2.4, 0, 0, 0, rgb(140, 255, 210), Enum.Material.Neon)
	flame.CFrame = rel(0, PAVE + 39.5, -2)
	glowLight(flame, 30, 1.4, rgb(140, 255, 210))
	local plaque = part(m, "NameBoard", Vector3.new(18, 2, 0.4), rel(0, PAVE + 20.5, 17.2), rgb(40, 60, 70), Enum.Material.SmoothPlastic)
	sign(plaque, "Temple of Healing", rgb(190, 255, 230))
end

local function gardens(parent: Instance, x0: number, x1: number, z0: number, z1: number)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local w, d = x1 - x0 - 2 * EDGE, z1 - z0 - 2 * EDGE
	box(parent, "Lawn", cx, PAVE, cz, w, 0.2, d, rgb(105, 185, 80), Enum.Material.Grass)
	box(parent, "GravelPath", cx, PAVE, cz, 6, 0.3, d, rgb(225, 210, 180), Enum.Material.Pebble)
	box(parent, "GravelPath", cx, PAVE, cz, w, 0.3, 6, rgb(225, 210, 180), Enum.Material.Pebble)
	-- clipped hedges framing four parterres, each with a topiary and rose bed
	for _, qx in { -1, 1 } do
		for _, qz in { -1, 1 } do
			local px, pz = cx + qx * w / 4, cz + qz * d / 4
			local pw, pd = w / 2 - 12, d / 2 - 12
			for _, e in { { 0, -pd / 2, pw, 1.6 }, { 0, pd / 2, pw, 1.6 }, { -pw / 2, 0, 1.6, pd }, { pw / 2, 0, 1.6, pd } } do
				box(parent, "Hedge", px + e[1], PAVE, pz + e[2], e[3], 3, e[4], rgb(60, 130, 60), Enum.Material.Grass)
			end
			cylinder(parent, "TopiaryPot", 1.4, 3, px, PAVE + 0.7, pz, STONE, Enum.Material.Cobblestone)
			ball(parent, "Topiary", 5, px, PAVE + 4, pz, rgb(70, 150, 70), Enum.Material.Grass)
			ball(parent, "Topiary", 3.4, px, PAVE + 7.6, pz, rgb(70, 150, 70), Enum.Material.Grass)
			for k = 0, 5 do
				local rose = ball(parent, "Rose", 1.2, px - pw / 2 + 3 + k * (pw - 6) / 5, PAVE + 1.2, pz + pd / 2 - 3, ({ rgb(230, 50, 70), rgb(255, 160, 190), rgb(255, 240, 240) })[k % 3 + 1])
				rose.Name = "Rose"
			end
		end
	end
	-- central statue of a knight on a plinth, and a gazebo
	box(parent, "Plinth", cx, PAVE, cz, 6, 4, 6, STONE, Enum.Material.Marble)
	box(parent, "StatueLegs", cx, PAVE + 4, cz, 2, 3, 1.2, rgb(160, 170, 175), Enum.Material.Metal)
	box(parent, "StatueBody", cx, PAVE + 7, cz, 2.6, 3, 1.4, rgb(160, 170, 175), Enum.Material.Metal)
	ball(parent, "StatueHead", 1.6, cx, PAVE + 10.8, cz, rgb(160, 170, 175), Enum.Material.Metal)
	part(parent, "StatueSword", Vector3.new(0.4, 6, 0.3), CFrame.new(cx + 1.6, PAVE + 9.6, cz) * CFrame.Angles(0, 0, math.rad(-15)), rgb(200, 205, 215), Enum.Material.Metal)
	local gx, gz = cx + w / 4, cz - d / 4
	cylinder(parent, "GazeboFloor", 1, 14, gx, PAVE + 0.5, gz, WHITE, Enum.Material.Marble)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		cylinder(parent, "GazeboPillar", 9, 0.8, gx + math.cos(a) * 6, PAVE + 5.5, gz + math.sin(a) * 6, WHITE, Enum.Material.Marble)
	end
	cone(parent, "GazeboRoof", gx, PAVE + 10, gz, 8.5, 5, rgb(90, 150, 110), Enum.Material.Slate, 6)
	local sb = box(parent, "GardenSign", cx, PAVE, z0 + EDGE + 1, 16, 4, 1, rgb(60, 110, 70), Enum.Material.WoodPlanks)
	sign(sb, "Royal Gardens", WHITE, Enum.NormalId.Back)
end

----------------------------------------------------------------------------------------------
-- districts

local MARKET = {
	{ "Blacksmith", "blacksmith" }, { "Armorer", "armorer" }, { "Alchemist", "alchemist" }, { "Beast Tamer", "tamer" },
	{ "Stables", "stable" }, { "The Gilded Tankard", "tavern" }, { "Fletcher", "fletcher" }, { "Enchanter", "enchanter" },
	{ "Cook & Larder", "cook" }, { "Tailor", "tailor" }, { "Herbalist", "herbalist" }, { "Cartographer", "maps" },
}

local function furnish(f: Instance, b: { number }, seed: number)
	local x0, x1, z0, z1 = b[1], b[2], b[3], b[4]
	for _, c in { { x0 + 1.5, z0 + 1.5 }, { x1 - 1.5, z0 + 1.5 }, { x0 + 1.5, z1 - 1.5 }, { x1 - 1.5, z1 - 1.5 } } do
		lanternPost(f, c[1], c[2])
	end
	local w = x1 - x0
	local n = math.max(1, math.floor(w / 34))
	for k = 1, n do
		local x = x0 + k * w / (n + 1)
		cityTree(f, x, z0 + 2, seed * 7 + k)
		cityTree(f, x, z1 - 2, seed * 11 + k)
	end
	bench(f, x0 + w * 0.5 + 6, z0 + 2, Vector3.new(0, 0, -1))
	barrel(f, x0 + w * 0.5 - 5, PAVE, z0 + 2)
end

local function marketRow(f: Instance, b: { number }, index: number)
	local x0, x1, z0, z1 = b[1], b[2], b[3], b[4]
	local inner = x1 - x0 - 2 * EDGE
	local count = if inner > 80 then 3 else 2
	local shopW = inner / count - 3
	for k = 1, count do
		local n = (index - 1) * 2 + k
		local x = x0 + EDGE + (k - 0.5) * (inner / count)
		local a = MARKET[(n - 1) % #MARKET + 1]
		local c = MARKET[(n + 5) % #MARKET + 1]
		shop(f, x, z0 + EDGE + 9, shopW, Vector3.new(0, 0, -1), a[1], a[2], n)
		shop(f, x, z1 - EDGE - 9, shopW, Vector3.new(0, 0, 1), c[1], c[2] .. "2", n + 3)
	end
end

local function townhouseRow(f: Instance, b: { number }, seed: number)
	local x0, x1, z0, z1 = b[1], b[2], b[3], b[4]
	local inner = x1 - x0 - 2 * EDGE
	local count = math.floor(inner / 15)
	local w = inner / count - 1
	for k = 1, count do
		local x = x0 + EDGE + (k - 0.5) * (inner / count)
		townhouse(f, x, z0 + EDGE + 8, w, 14, 3 + (seed + k) % 2, Vector3.new(0, 0, -1), seed * 13 + k)
		townhouse(f, x, z1 - EDGE - 8, w, 14, 2 + (seed * 3 + k) % 3, Vector3.new(0, 0, 1), seed * 17 + k)
	end
	box(f, "Courtyard", (x0 + x1) / 2, PAVE, (z0 + z1) / 2, inner, 0.15, (z1 - z0) - 2 * EDGE - 34, rgb(110, 180, 85), Enum.Material.Grass)
	well(f, (x0 + x1) / 2, (z0 + z1) / 2)
end

local function cottageRow(f: Instance, b: { number }, seed: number)
	local x0, x1, z0, z1 = b[1], b[2], b[3], b[4]
	local inner = x1 - x0 - 2 * EDGE
	local count = math.max(2, math.floor(inner / 24))
	for k = 1, count do
		local x = x0 + EDGE + (k - 0.5) * (inner / count)
		cottageHome(f, x, z0 + EDGE + 16, Vector3.new(0, 0, -1), seed * 3 + k)
		cottageHome(f, x, z1 - EDGE - 16, Vector3.new(0, 0, 1), seed * 5 + k)
	end
	box(f, "Orchard", (x0 + x1) / 2, PAVE, (z0 + z1) / 2, inner, 0.15, 12, rgb(110, 185, 85), Enum.Material.Grass)
	for k = 0, 3 do
		cityTree(f, x0 + EDGE + 8 + k * (inner - 16) / 3, (z0 + z1) / 2, seed * 19 + k)
	end
end

local function harbour(f: Instance, x0: number, x1: number, z0: number, z1: number, seed: number)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local w, d = x1 - x0 - 2 * EDGE, z1 - z0 - 2 * EDGE
	box(f, "Quay", cx, PAVE, cz, w, 0.2, d, rgb(160, 150, 138), Enum.Material.Cobblestone)
	-- timber warehouse
	local wx = x0 + EDGE + 16
	local rel = frame(wx, cz, Vector3.new(1, 0, 0))
	local wh = model(f, "Warehouse")
	part(wh, "Walls", Vector3.new(d - 10, 14, 26), rel(0, PAVE + 7, 0), rgb(150, 100, 65), Enum.Material.WoodPlanks)
	gableSide(wh, rel, d - 10, 26, PAVE + 14, rgb(150, 100, 65), ROOFS[seed % #ROOFS + 1], Enum.Material.WoodPlanks)
	for k = -1, 1 do
		part(wh, "LoadingDoor", Vector3.new(8, 9, 0.4), rel(k * (d - 10) / 3.2, PAVE + 4.5, 13.2), rgb(110, 70, 45), Enum.Material.WoodPlanks)
	end
	local board = part(wh, "NameBoard", Vector3.new(16, 2.4, 0.4), rel(0, PAVE + 11, 13.3), rgb(60, 45, 35), Enum.Material.WoodPlanks)
	sign(board, "Harbour Stores", GOLD)
	-- cargo: crate and barrel stacks
	for k = 0, 5 do
		local sx, sz = x0 + EDGE + 42 + (k % 2) * 10, z0 + EDGE + 8 + (k // 2) * (d - 16) / 2
		for layer = 0, (k + seed) % 3 do
			crate(f, sx, PAVE + layer * 4, sz, 4, hash(k + layer + seed) * 0.4)
		end
		barrel(f, sx + 4.5, PAVE, sz + 3)
		barrel(f, sx + 4.5, PAVE, sz - 1)
	end
	-- treadwheel crane on the quay edge
	local qx, qz = x1 - EDGE - 6, cz
	box(f, "CraneBase", qx, PAVE, qz, 8, 2, 8, DARKSTONE, Enum.Material.Cobblestone)
	box(f, "CraneMast", qx, PAVE + 2, qz, 1.6, 22, 1.6, TIMBER, Enum.Material.Wood)
	part(f, "CraneJib", Vector3.new(1, 1, 24), CFrame.lookAt(Vector3.new(qx + 8, PAVE + 22, qz), Vector3.new(qx + 20, PAVE + 26, qz)), TIMBER, Enum.Material.Wood)
	local wheel = cylinder(f, "Treadwheel", 2.4, 10, 0, 0, 0, rgb(150, 110, 70), Enum.Material.WoodPlanks)
	wheel.CFrame = CFrame.new(qx - 3, PAVE + 7, qz) * CFrame.Angles(0, math.rad(90), 0)
	box(f, "CraneRope", qx + 19, PAVE + 12, qz, 0.25, 14, 0.25, rgb(90, 80, 70), Enum.Material.Fabric)
	crate(f, qx + 19, PAVE + 9, qz, 3, 0.2)
	for k = 0, 9 do
		cylinder(f, "Bollard", 2, 1.4, x1 - 2, PAVE + 1, z0 + 6 + k * (z1 - z0 - 12) / 9, IRON, Enum.Material.Metal)
	end
	-- jetty and moored ship
	box(f, "Jetty", x1 + 26, 0.2, cz, 52, 0.8, 7, rgb(160, 115, 75), Enum.Material.WoodPlanks)
	for j = 0, 4 do
		cylinder(f, "Piling", 6, 1.1, x1 + 4 + j * 11, -2.5, cz + 3.8, TIMBER, Enum.Material.Wood)
	end
	ship(f, x1 + 30, cz + (if seed % 2 == 0 then 18 else 11), Vector3.new(1, 0, 0), if seed % 2 == 0 then "galleon" else "sloop", BANNERS[seed % #BANNERS + 1])
end

local function fishingDocks(f: Instance, x0: number, x1: number, z0: number, z1: number)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local w, d = x1 - x0 - 2 * EDGE, z1 - z0 - 2 * EDGE
	box(f, "Boardwalk", cx, PAVE, cz, w, 0.3, d, rgb(175, 135, 95), Enum.Material.WoodPlanks)
	-- fishmonger's stall and net racks
	marketStall(f, x0 + EDGE + 10, cz - 14, Vector3.new(1, 0, 0), rgb(60, 130, 200), 3)
	marketStall(f, x0 + EDGE + 10, cz + 4, Vector3.new(1, 0, 0), rgb(240, 180, 60), 5)
	for k = 0, 2 do
		local nx = x0 + EDGE + 28 + k * 12
		box(f, "NetPost", nx - 4, PAVE, cz + 22, 0.5, 7, 0.5, TIMBER, Enum.Material.Wood)
		box(f, "NetPost", nx + 4, PAVE, cz + 22, 0.5, 7, 0.5, TIMBER, Enum.Material.Wood)
		part(f, "FishingNet", Vector3.new(8, 5, 0.15), CFrame.new(nx, PAVE + 4, cz + 22), rgb(150, 140, 110), Enum.Material.Fabric, { Transparency = 0.35 })
	end
	local hut = model(f, "Shipwright")
	local rel = frame(x0 + EDGE + 40, cz - 10, Vector3.new(0, 0, -1))
	part(hut, "Walls", Vector3.new(22, 11, 16), rel(0, PAVE + 5.5, 0), rgb(150, 100, 65), Enum.Material.WoodPlanks)
	gableSide(hut, rel, 22, 16, PAVE + 11, rgb(150, 100, 65), ROOFS[4], Enum.Material.WoodPlanks)
	local board = part(hut, "NameBoard", Vector3.new(12, 2, 0.4), rel(0, PAVE + 8.6, 8.3), rgb(60, 45, 35), Enum.Material.WoodPlanks)
	sign(board, "Shipwright", GOLD)
	hut:SetAttribute("Shop", "shipwright")
	local wrightAnchor = part(hut, "ShopAnchor", Vector3.new(4, 4, 4), rel(-6, PAVE + 2.5, 11), WHITE, nil, { Transparency = 1, CanCollide = false })
	wrightAnchor:SetAttribute("Shop", "shipwright")
	-- finger piers with rowboats and a sloop
	for k = 0, 3 do
		local pz = z0 + 10 + k * (z1 - z0 - 20) / 3
		box(f, "Pier", x1 + 18, 0.2, pz, 36, 0.8, 4.6, rgb(165, 120, 80), Enum.Material.WoodPlanks)
		for j = 0, 2 do
			cylinder(f, "Piling", 6, 1, x1 + 3 + j * 13, -2.5, pz + 2.6, TIMBER, Enum.Material.Wood)
		end
		if k == 3 then
			ship(f, x1 + 22, pz + 8, Vector3.new(1, 0, 0), "sloop", BANNERS[3])
		else
			ship(f, x1 + 14 + k * 4, pz + 5, Vector3.new(1, 0, 0.2).Unit, "rowboat", WHITE)
		end
	end
end

----------------------------------------------------------------------------------------------
-- streets, walls and bridges

local function buildStreets(city: Instance)
	local streets = folder(city, "Streets")
	local w, d = CITY.x1 - CITY.x0, CITY.z1 - CITY.z0
	local cx, cz = (CITY.x0 + CITY.x1) / 2, (CITY.z0 + CITY.z1) / 2
	box(streets, "Cobbles", cx, -1, cz, w, 1, d, COBBLE, Enum.Material.Cobblestone)
	for _, e in { { cx, CITY.z0, w + 2, 2 }, { cx, CITY.z1, w + 2, 2 }, { CITY.x0, cz, 2, d }, { CITY.x1, cz, 2, d } } do
		box(streets, "SeaWall", e[1], -10, e[2], e[3], 10.8, e[4], DARKSTONE, Enum.Material.Cobblestone)
	end
	-- a paler gutter line down the middle of every street
	local main = AVENUES[3]
	for _, a in AVENUES do
		box(streets, "Gutter", a.x, 0, cz, if a == main then 3 else 1.6, 0.05, d - 4, rgb(150, 145, 138), Enum.Material.Slate)
	end
	for _, s in STREETS do
		box(streets, "Gutter", cx, 0, s.z, w - 4, 0.05, 1.6, rgb(150, 145, 138), Enum.Material.Slate)
	end
end

local function wallRun(f: Instance, a: Vector3, b: Vector3)
	local dir = (b - a).Unit
	local length = (b - a).Magnitude
	if length < 2 then
		return
	end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(Vector3.new(mid.X, 0, mid.Z), Vector3.new(mid.X, 0, mid.Z) + dir)
	part(f, "Wall", Vector3.new(5, 16, length), cf * CFrame.new(0, 8, 0), STONE, Enum.Material.Cobblestone)
	part(f, "WallWalk", Vector3.new(5.6, 0.6, length), cf * CFrame.new(0, 16.3, 0), DARKSTONE, Enum.Material.Cobblestone)
	local n = math.floor(length / 5)
	for k = 0, n - 1 do
		local v = -length / 2 + (k + 0.5) * (length / n)
		part(f, "Merlon", Vector3.new(1.2, 2.4, 2.4), cf * CFrame.new(2.2, 17.8, v), STONE, Enum.Material.Cobblestone)
	end
end

local function wallTower(f: Instance, x: number, z: number, banner_: Color3)
	cylinder(f, "WallTower", 24, 12, x, 12, z, STONE, Enum.Material.Cobblestone)
	cylinder(f, "TowerRim", 1.4, 13.4, x, 24.2, z, DARKSTONE, Enum.Material.Cobblestone)
	cone(f, "TowerRoof", x, 24.9, z, 8.6, 12, ROOFS[1], Enum.Material.Slate, 8)
	cylinder(f, "FlagPole", 6, 0.35, x, 40, z, IRON, Enum.Material.Metal)
	part(f, "Flag", Vector3.new(0.2, 2.6, 4.4), CFrame.new(x, 41.6, z + 2.3), banner_, Enum.Material.Fabric)
end

local function gatehouse(f: Instance, x: number, z: number, along: Vector3, opening: number)
	local side = Vector3.new(-along.Z, 0, along.X)
	for _, s in { -1, 1 } do
		local p = Vector3.new(x, 0, z) + along * s * (opening / 2 + 6)
		box(f, "GateTower", p.X, 0, p.Z, 12, 28, 12, STONE, Enum.Material.Cobblestone)
		cone(f, "GateRoof", p.X, 28, p.Z, 8.6, 12, ROOFS[1], Enum.Material.Slate, 4)
		local torch = box(f, "GateTorch", p.X + side.X * 6.4 - along.X * s * 3, 9, p.Z + side.Z * 6.4 - along.Z * s * 3, 1, 1.6, 1, LANTERN, Enum.Material.Neon)
		glowLight(torch, 18, 1.2, LANTERN)
	end
	local lintel = part(f, "GateArch", Vector3.new(opening + 2, 8, 8), CFrame.lookAt(Vector3.new(x, 20, z), Vector3.new(x, 20, z) + side), STONE, Enum.Material.Cobblestone)
	lintel.Name = "GateArch"
	local plaque = part(f, "GateSign", Vector3.new(opening * 0.7, 3, 0.4), CFrame.lookAt(Vector3.new(x, 20, z) + side * 4.3, Vector3.new(x, 20, z) + side * 6), rgb(50, 40, 35), Enum.Material.WoodPlanks)
	sign(plaque, "Sproutling", GOLD)
	sign(plaque, "Sproutling", GOLD, Enum.NormalId.Back)
	for k = -2, 2 do
		local bar = Vector3.new(x, 0, z) + along * k * (opening / 5)
		part(f, "Portcullis", Vector3.new(0.5, 6, 0.5), CFrame.new(bar.X, 13, bar.Z), IRON, Enum.Material.Metal)
	end
end

local function buildWalls(city: Instance)
	local f = folder(city, "Walls")
	local x0, x1, z0, z1 = CITY.x0 + 2.5, CITY.x1 - 2.5, CITY.z0 + 2.5, CITY.z1 - 2.5
	local main = 30 -- half width of the north gate opening (main bridge)
	-- north wall with the main gate and a postern for the footbridge
	wallRun(f, Vector3.new(x0, 0, z0), Vector3.new(-156, 0, z0))
	wallRun(f, Vector3.new(-144, 0, z0), Vector3.new(-main - 12, 0, z0))
	wallRun(f, Vector3.new(main + 12, 0, z0), Vector3.new(x1 - 92, 0, z0))
	gatehouse(f, 0, z0, Vector3.new(1, 0, 0), main * 2)
	-- west wall with the gate to the airship port bridge
	wallRun(f, Vector3.new(x0, 0, z0), Vector3.new(x0, 0, 700 - 32))
	wallRun(f, Vector3.new(x0, 0, 700 + 32), Vector3.new(x0, 0, z1))
	gatehouse(f, x0, 700, Vector3.new(0, 0, 1), 40)
	-- south wall (the east side is open harbour)
	wallRun(f, Vector3.new(x0, 0, z1), Vector3.new(x1 - 92, 0, z1))
	for i, p in { { x0, z0 }, { x0, z1 }, { -172, z0 }, { x1 - 92, z0 }, { x1 - 92, z1 }, { x0, 900 }, { -200, z1 }, { 0, z1 }, { 150, z1 } } do
		wallTower(f, p[1], p[2], BANNERS[i % #BANNERS + 1])
	end
end

-- Stone bridge with arches underneath, parapets, lanterns and statues at the ends.
local function stoneBridge(city: Instance, a: Vector3, b: Vector3, width: number)
	local f = model(city, "StoneBridge")
	local dir = (b - a).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local length = (b - a).Magnitude
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(Vector3.new(mid.X, 0, mid.Z), Vector3.new(mid.X, 0, mid.Z) + dir)
	part(f, "Deck", Vector3.new(width, 2, length), cf * CFrame.new(0, -0.6, 0), COBBLE, Enum.Material.Cobblestone)
	for _, s in { -1, 1 } do
		part(f, "Parapet", Vector3.new(1.4, 3, length), cf * CFrame.new(s * (width / 2 - 0.7), 1.9, 0), STONE, Enum.Material.Cobblestone)
		local n = math.floor(length / 26)
		for k = 0, n do
			local v = -length / 2 + k * (length / n)
			local p = (cf * CFrame.new(s * (width / 2 - 0.7), 0, v)).Position
			lanternPost(f, p.X, p.Z)
		end
	end
	-- arches: piers in the water and curved spans between them
	local spans = math.max(2, math.floor(length / 34))
	for k = 0, spans do
		local v = -length / 2 + k * (length / spans)
		part(f, "Pier", Vector3.new(width - 4, 12, 6), cf * CFrame.new(0, -7.6, v), DARKSTONE, Enum.Material.Cobblestone)
	end
	for k = 0, spans - 1 do
		local v0 = -length / 2 + k * (length / spans) + 3
		local v1 = v0 + length / spans - 6
		local segs = 6
		for i = 0, segs - 1 do
			local t0, t1 = i / segs, (i + 1) / segs
			local y0 = -1.6 - math.sin(t0 * math.pi) * 0 - (1 - math.sin(t0 * math.pi)) * 5
			local y1 = -1.6 - (1 - math.sin(t1 * math.pi)) * 5
			local p0 = cf * CFrame.new(0, y0, v0 + (v1 - v0) * t0)
			local p1 = cf * CFrame.new(0, y1, v0 + (v1 - v0) * t1)
			part(f, "ArchRib", Vector3.new(width - 2, 1.4, (p1.Position - p0.Position).Magnitude + 0.4), CFrame.lookAt((p0.Position + p1.Position) / 2, p1.Position), STONE, Enum.Material.Cobblestone)
		end
	end
	-- statues of lions at both ends
	for _, e in { a + dir * 3, b - dir * 3 } do
		for _, s in { -1, 1 } do
			local p = e + side * s * (width / 2 + 2)
			box(f, "StatuePlinth", p.X, 0, p.Z, 4, 4, 4, STONE, Enum.Material.Marble)
			box(f, "LionBody", p.X, 4, p.Z, 2.4, 2.4, 3.6, GOLD, Enum.Material.Metal)
			ball(f, "LionMane", 2.8, p.X, 7, p.Z, GOLD, Enum.Material.Metal)
		end
	end
end

----------------------------------------------------------------------------------------------
-- the airship port (Landscape.Airport)

local function mooringTower(f: Instance, x: number, z: number, h: number)
	for _, c in { { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } } do
		box(f, "TowerLeg", x + c[1], 0, z + c[2], 1.4, h, 1.4, TIMBER, Enum.Material.Wood)
	end
	for k = 1, math.floor(h / 10) do
		box(f, "TowerBrace", x, k * 10 - 1, z - 4, 9, 0.8, 0.8, TIMBER, Enum.Material.Wood)
		box(f, "TowerBrace", x, k * 10 - 1, z + 4, 9, 0.8, 0.8, TIMBER, Enum.Material.Wood)
		box(f, "TowerBrace", x - 4, k * 10 - 1, z, 0.8, 0.8, 9, TIMBER, Enum.Material.Wood)
		box(f, "TowerBrace", x + 4, k * 10 - 1, z, 0.8, 0.8, 9, TIMBER, Enum.Material.Wood)
	end
	box(f, "TowerDeck", x, h, z, 12, 1, 12, rgb(170, 125, 85), Enum.Material.WoodPlanks)
	box(f, "Ladder", x, 0, z - 4.8, 2, h, 0.3, rgb(150, 110, 70), Enum.Material.WoodPlanks)
	local beacon = box(f, "Beacon", x, h + 1, z, 1.4, 2, 1.4, LANTERN, Enum.Material.Neon)
	glowLight(beacon, 24, 1.2, LANTERN)
end

local function airshipPort(city: Instance)
	local f = folder(city, "AirshipPort")
	local A = { x0 = -760, x1 = -425, z0 = 540, z1 = 1120 }
	local cx, cz = (A.x0 + A.x1) / 2, (A.z0 + A.z1) / 2
	box(f, "Field", cx, -1, cz, A.x1 - A.x0, 1, A.z1 - A.z0, rgb(115, 185, 85), Enum.Material.Grass)
	for _, e in { { cx, A.z0, A.x1 - A.x0 + 2, 2 }, { cx, A.z1, A.x1 - A.x0 + 2, 2 }, { A.x0, cz, 2, A.z1 - A.z0 }, { A.x1, cz, 2, A.z1 - A.z0 } } do
		box(f, "SeaWall", e[1], -10, e[2], e[3], 10.4, e[4], DARKSTONE, Enum.Material.Cobblestone)
	end
	-- cobbled road from the bridge, and a plaza
	box(f, "Road", -510, 0, 700, 170, 0.2, 22, COBBLE, Enum.Material.Cobblestone)
	box(f, "Plaza", -560, 0, 830, 120, 0.2, 280, rgb(190, 180, 160), Enum.Material.Cobblestone)
	-- mooring towers with airships
	local colors = { rgb(200, 60, 60), rgb(60, 110, 200), rgb(220, 170, 50), rgb(120, 70, 170) }
	for k, p in { { -600, 650 }, { -660, 790 }, { -600, 930 }, { -660, 1060 } } do
		mooringTower(f, p[1], p[2], 40)
		airship(f, p[1], 32, p[2] + 2, Vector3.new(0, 0, 1), colors[k])
	end
	-- the shipyard hall and the port inn
	local hall = model(f, "Skyward Shipyard")
	local rel = frame(-470, 870, Vector3.new(-1, 0, 0))
	part(hall, "Walls", Vector3.new(90, 22, 40), rel(0, 11, 0), rgb(150, 100, 65), Enum.Material.WoodPlanks)
	gableSide(hall, rel, 90, 40, 22, rgb(150, 100, 65), ROOFS[2], Enum.Material.WoodPlanks)
	part(hall, "BayDoor", Vector3.new(30, 18, 0.5), rel(0, 9, 20.2), rgb(110, 70, 45), Enum.Material.WoodPlanks)
	local board = part(hall, "NameBoard", Vector3.new(30, 3, 0.5), rel(0, 20, 20.3), rgb(60, 45, 35), Enum.Material.WoodPlanks)
	sign(board, "Skyward Shipyard", GOLD)
	hall:SetAttribute("Shop", "airships")
	local yardAnchor = part(hall, "ShopAnchor", Vector3.new(4, 4, 4), rel(-12, 2.5, 23), WHITE, nil, { Transparency = 1, CanCollide = false })
	yardAnchor:SetAttribute("Shop", "airships")
	shop(f, -500, 620, 22, Vector3.new(-1, 0, 0), "The Cloud's Rest Inn", "inn", 2)
	for _, p in f:GetChildren() do
		if p:IsA("Model") and p.Name == "Shop" then
			for _, q in p:GetDescendants() do
				if q:IsA("BasePart") then
					q.CFrame = q.CFrame - Vector3.new(0, PAVE, 0)
				end
			end
		end
	end
	-- cargo, carts and a windsock
	for k = 0, 7 do
		crate(f, -540 + (k % 4) * 5, 0, 760 + (k // 4) * 5, 4, hash(k) * 0.5)
	end
	cart(f, -520, 980, Vector3.new(0, 0, -1), 2)
	cart(f, -540, 1000, Vector3.new(0, 0, 1), 4)
	cylinder(f, "WindsockPole", 12, 0.4, -720, 6, 600, IRON, Enum.Material.Metal)
	part(f, "Windsock", Vector3.new(1.6, 1.6, 5), CFrame.new(-720, 11.6, 603) * CFrame.Angles(math.rad(-10), 0, 0), rgb(250, 120, 40), Enum.Material.Fabric)
	-- a few trees round the field edge
	for k = 0, 9 do
		cityTree(f, -740 + (k % 2) * 20, 580 + k * 55, 300 + k)
	end
end

----------------------------------------------------------------------------------------------

function CityBuilder.Build(map: Instance): Instance
	local existing = map:FindFirstChild("City")
	if existing then
		existing:Destroy()
	end
	local city = Instance.new("Folder")
	city.Name = "City"

	buildStreets(city)
	local blocksFolder = folder(city, "Blocks")
	for i, b in blocks() do
		local ix, iz = b[5], b[6]
		local f = folder(blocksFolder, string.format("Block_%d_%d", ix, iz))
		local x0, x1, z0, z1 = b[1], b[2], b[3], b[4]
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		box(f, "Flagstones", cx, 0, cz, x1 - x0, PAVE, z1 - z0, FLAGSTONE, Enum.Material.Slate)
		local special = false
		if iz == 1 then
			marketRow(f, b, ix)
		elseif ix == 6 and iz == 2 then
			fishingDocks(f, x0, x1, z0, z1)
			special = true
		elseif ix == 6 then
			harbour(f, x0, x1, z0, z1, iz)
			special = true
		elseif ix == 2 and (iz == 3 or iz == 4) then
			gardens(f, x0, x1, z0, z1)
			special = true
		elseif ix == 3 and iz == 2 then
			local hall = guildHall(f, cx, cz + 6, x1 - x0 - 2 * EDGE - 8, 30, Vector3.new(0, 0, -1), "Adventurers' Guild", BANNERS[1])
			hall:SetAttribute("Shop", "guild")
			marketStall(f, x0 + EDGE + 8, z1 - EDGE - 6, Vector3.new(0, 0, -1), BANNERS[4], 1)
		elseif ix == 4 and iz == 2 then
			mageTower(f, cx, cz)
		elseif ix == 3 and iz == 3 then
			cathedral(f, cx, cz + 4, Vector3.new(0, 0, -1))
			special = true
		elseif ix == 4 and iz == 3 then
			marketSquare(f, x0, x1, z0, z1)
			special = true
		elseif ix == 3 and iz == 4 then
			local hall = guildHall(f, cx, cz, x1 - x0 - 2 * EDGE - 8, 30, Vector3.new(0, 0, -1), "Royal Treasury", BANNERS[4])
			hall:SetAttribute("Shop", "bank")
		elseif ix == 4 and iz == 4 then
			arena(f, x0, x1, z0, z1)
			special = true
		elseif ix == 3 and iz == 5 then
			guildHall(f, cx - 6, cz, x1 - x0 - 2 * EDGE - 24, 30, Vector3.new(0, 0, -1), "Town Hall", BANNERS[3])
			clockTower(f, x1 - EDGE - 8, cz, Vector3.new(0, 0, -1))
		elseif ix == 4 and iz == 5 then
			local lib = guildHall(f, cx, cz, x1 - x0 - 2 * EDGE - 8, 30, Vector3.new(0, 0, -1), "Grand Library", BANNERS[5])
			lib:SetAttribute("Shop", "library")
		elseif ix == 5 and iz == 5 then
			local barracks = guildHall(f, cx, z0 + EDGE + 16, x1 - x0 - 2 * EDGE - 8, 26, Vector3.new(0, 0, -1), "Barracks", BANNERS[2])
			barracks:SetAttribute("Shop", "trainer")
			trainingYard(f, cx, z1 - EDGE - 18, x1 - x0 - 2 * EDGE - 8, 28)
		elseif ix == 5 and iz == 6 then
			temple(f, cx, cz, Vector3.new(0, 0, -1))
		elseif ix == 1 or (ix == 2 and iz >= 5) then
			cottageRow(f, b, i)
		else
			townhouseRow(f, b, i)
		end
		if not special then
			furnish(f, b, i)
		end
	end

	-- traffic: carriages, carts and saddled horses at hitching posts
	local traffic = folder(city, "Traffic")
	local n = 0
	for _, a in AVENUES do
		for si = 1, #STREETS - 1 do
			local z0, z1 = STREETS[si].z + STREETS[si].w / 2, STREETS[si + 1].z - STREETS[si + 1].w / 2
			n += 1
			local roll = hash(n + 0.3)
			local sgn = if n % 2 == 0 then 1 else -1
			local px, pz = a.x + sgn * (a.w / 2 - 4), z0 + 20 + hash(n) * (z1 - z0 - 40)
			if roll < 0.35 then
				carriage(traffic, px, pz, Vector3.new(0, 0, sgn), BANNERS[n % #BANNERS + 1])
			elseif roll < 0.7 then
				cart(traffic, px, pz, Vector3.new(0, 0, sgn), n)
			elseif roll < 0.9 then
				horse(traffic, px, pz, Vector3.new(sgn, 0, 0), COATS[n % #COATS + 1], true)
			end
		end
	end

	buildWalls(city)
	stoneBridge(city, Vector3.new(0, 0, 330), Vector3.new(0, 0, CITY.z0), 40)
	stoneBridge(city, Vector3.new(CITY.x0, 0, 700), Vector3.new(-425, 0, 700), 26)

	-- out in the harbour bay: a galleon under sail, a sloop and fishing boats
	local bay = folder(city, "Bay")
	ship(bay, 430, 900, Vector3.new(0, 0, -1), "galleon", BANNERS[1])
	ship(bay, 405, 1040, Vector3.new(-0.4, 0, -1).Unit, "sloop", BANNERS[3])
	ship(bay, 400, 760, Vector3.new(0.3, 0, 1).Unit, "rowboat", WHITE)
	ship(bay, 415, 720, Vector3.new(-0.6, 0, 1).Unit, "rowboat", WHITE)

	airshipPort(city)

	city.Parent = map
	return city
end

if Color3 then
	initColors()
end

return CityBuilder
