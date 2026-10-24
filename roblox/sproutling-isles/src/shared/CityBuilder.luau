--!strict
-- Builds the walled fantasy city of Sproutling (south of the garden island, across the lagoon)
-- and its airship port.
--
-- Like MapBuilder it touches no services, so it runs at server start, from the Studio command
-- bar and offline under Lune (tools/bake-map.luau passes the Roblox API table). Everything sits
-- under Map.City. Shops, steeds, ships and airships carry attributes (Shop, Vehicle, Arena) that
-- the RPG systems look up; for now they are scenery.
--
-- Layout (studs, +Z = south). The city sits on gently rolling terrain round
-- Landscape.CityCentre, inside a wobbly wall that climbs and dips with the ground. Its streets
-- are the curved Landscape.Roads (different widths and heights). Landmarks take the nearest free
-- ground to where they're wanted; shops, townhouses and cottages then line every road, set back
-- and turned by varying amounts, each on a stone plinth that becomes a terrace on a slope.
-- Lanterns, carts, riders and trees fill the gaps. The waterfront and the airship port sit on
-- their own flat sites.

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
	local flare = math.rad(22)
	for _, side in { 1, -1 } do
		part(parent, "Roof", Vector3.new(len, 0.8, d + 1.6), rel(side * w / 4, y + rise / 2 + 0.35, 0) * CFrame.Angles(0, 0, -side * math.rad(45)), roof, Enum.Material.Slate)
		-- the eave kicks out at a shallower angle where the slab ends (a bell-cast curve)
		local eu, ey = side * (w / 2 + 0.55), y - 0.2
		part(parent, "Eave", Vector3.new(3, 0.6, d + 1.8), rel(eu + side * math.cos(flare) * 1.3, ey - math.sin(flare) * 1.3, 0) * CFrame.Angles(0, 0, -side * flare), roof, Enum.Material.Slate)
	end
	-- a round ridge with a ball finial over the gable
	local dark = Color3.new(roof.R * 0.75, roof.G * 0.75, roof.B * 0.75)
	tube(parent, "Ridge", d + 2, 1.2, rel(0, y + rise + 0.4, 0), dark, Enum.Material.Wood)
	local tip = rel(0, y + rise + 0.6, d / 2 + 1.1).Position
	ball(parent, "Finial", 1.5, tip.X, tip.Y, tip.Z, dark, Enum.Material.Wood)
end

-- A round brick chimney pot with a wider cap, standing at rel(u, y, v) (y = its middle).
local function chimney(parent: Instance, rel: (number, number, number) -> CFrame, u: number, y: number, v: number, height: number)
	local p = rel(u, y, v).Position
	cylinder(parent, "Chimney", height, 2.2, p.X, p.Y, p.Z, rgb(150, 100, 85), Enum.Material.Brick)
	cylinder(parent, "ChimneyCap", 0.8, 3, p.X, p.Y + height / 2 + 0.2, p.Z, rgb(110, 75, 62), Enum.Material.Brick)
end

-- A round arch on top of a door or window: a disc facing out of the front wall at rel(u, y, v).
local function arch(parent: Instance, rel: (number, number, number) -> CFrame, d: number, u: number, y: number, v: number, color: Color3, material: any?)
	tube(parent, "Arch", 0.3, d, rel(u, y, v), color, material)
end

-- Steep gable roof whose ridge runs along u (gables on the sides), for long halls.
local function gableSide(parent: Instance, rel: (number, number, number) -> CFrame, w: number, d: number, y: number, wall: Color3, roof: Color3, wallMaterial: any?)
	local rise = d / 2
	local attic = math.sqrt(2) * rise
	part(parent, "Attic", Vector3.new(w - 0.2, attic, attic), rel(0, y, 0) * CFrame.Angles(math.rad(45), 0, 0), wall, wallMaterial or Enum.Material.Plaster)
	local len = math.sqrt(2) * rise + 1.6
	local flare = math.rad(22)
	for _, side in { 1, -1 } do
		part(parent, "Roof", Vector3.new(w + 1.6, 0.9, len), rel(0, y + rise / 2 + 0.35, side * d / 4) * CFrame.Angles(-side * math.rad(45), 0, 0), roof, Enum.Material.Slate)
		local ev, ey = side * (d / 2 + 0.55), y - 0.2
		part(parent, "Eave", Vector3.new(w + 1.8, 0.7, 3), rel(0, ey - math.sin(flare) * 1.3, ev + side * math.cos(flare) * 1.3) * CFrame.Angles(-side * flare, 0, 0), roof, Enum.Material.Slate)
	end
	tube(parent, "Ridge", w + 2, 1.3, rel(0, y + rise + 0.45, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.new(roof.R * 0.75, roof.G * 0.75, roof.B * 0.75), Enum.Material.Wood)
end

----------------------------------------------------------------------------------------------
-- layout

local PAVE = 0.4 -- floors sit this far above a lot's base
local EDGE = 4 -- margin inside a waterfront or garden lot

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
			local post = rel(u, PAVE + 4, v).Position
			cylinder(parent, "StallPost", 8, 0.6, post.X, post.Y, post.Z, TIMBER, Enum.Material.Wood)
		end
	end
	-- a striped canopy with a scalloped front edge
	for i = 1, 4 do
		local u = -3.3 + (i - 1) * 2.2
		local stripe = if i % 2 == 0 then WHITE else color
		part(parent, "StallCanopy", Vector3.new(2.2, 0.3, 5.4), rel(u, PAVE + 8.2, -0.5) * CFrame.Angles(math.rad(-12), 0, 0), stripe, Enum.Material.Fabric)
		for _, k in { -0.55, 0.55 } do
			deco(tube(parent, "Scallop", 0.25, 1.1, rel(u + k, PAVE + 7.5, 2.2), stripe, Enum.Material.Fabric))
		end
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
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- animated whole on the client
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
	part(m, "Door", Vector3.new(3.6, 5.4, 0.4), rel(w * 0.28, PAVE + 2.7, d / 2 + 0.2), rgb(110, 70, 45), Enum.Material.WoodPlanks)
	arch(m, rel, 4.6, w * 0.28, PAVE + 5.4, d / 2 + 0.1, DARKSTONE, Enum.Material.Cobblestone)
	arch(m, rel, 3.6, w * 0.28, PAVE + 5.4, d / 2 + 0.25, rgb(110, 70, 45), Enum.Material.WoodPlanks)
	for _, u in { -w / 4, w / 4 } do
		part(m, "UpperWindow", Vector3.new(2.6, 3, 0.3), rel(u, PAVE + 12.4, d / 2 + 1.75), rgb(80, 105, 130), Enum.Material.Glass)
		part(m, "WindowBox", Vector3.new(3.2, 0.8, 1), rel(u, PAVE + 10.6, d / 2 + 2.1), TIMBER, Enum.Material.WoodPlanks)
		local flowers = { rgb(255, 110, 150), rgb(255, 225, 90), rgb(170, 130, 255) }
		for k = 1, 3 do
			local bloom = part(m, "Bloom", Vector3.new(0.8, 0.8, 0.8), rel(u - 1.6 + k * 0.8, PAVE + 11.3, d / 2 + 2.2), flowers[(seed + k) % 3 + 1])
			bloom.Shape = Enum.PartType.Ball
		end
	end
	chimney(m, rel, w / 3, PAVE + 20, -d / 4, 8)
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
	part(m, "Door", Vector3.new(3, 4.6, 0.3), rel(-w / 4, PAVE + 2.3, d / 2 + 0.15), rgb(105, 65, 42), Enum.Material.WoodPlanks)
	arch(m, rel, 3, -w / 4, PAVE + 4.6, d / 2 + 0.15, rgb(105, 65, 42), Enum.Material.WoodPlanks)
	part(m, "Window", Vector3.new(3, 2, 0.3), rel(w / 4, PAVE + 3.5, d / 2 + 0.15), rgb(80, 105, 130), Enum.Material.Glass)
	arch(m, rel, 3, w / 4, PAVE + 4.5, d / 2 + 0.15, rgb(80, 105, 130), Enum.Material.Glass)
	local y = PAVE + 7
	local jut = 0
	for f = 1, floors - 1 do
		jut += 0.8
		part(m, "Floor", Vector3.new(w + jut * 0.6, 7, d + jut), rel(0, y + 3.5, jut / 2), wall, Enum.Material.Plaster)
		part(m, "Beam", Vector3.new(w + jut * 0.6 + 0.4, 0.6, 0.4), rel(0, y + 0.3, d / 2 + jut + 0.1), TIMBER, Enum.Material.Wood)
		part(m, "Post", Vector3.new(0.6, 7, 0.35), rel(0, y + 3.5, d / 2 + jut + 0.1), TIMBER, Enum.Material.Wood)
		-- round corner posts
		for _, u in { -1, 1 } do
			local post = rel(u * (w + jut * 0.6) / 2, y + 3.5, d / 2 + jut).Position
			cylinder(m, "Post", 7, 0.9, post.X, post.Y, post.Z, TIMBER, Enum.Material.Wood)
		end
		for _, u in { -w / 4, w / 4 } do
			part(m, "Window", Vector3.new(2.4, 2.8, 0.3), rel(u, y + 3.8, d / 2 + jut + 0.05), if (seed + f + u) % 3 == 0 then LANTERN else rgb(80, 105, 130), Enum.Material.Glass)
		end
		y += 7
	end
	gableFront(m, rel, w + jut * 0.6, d + jut, y, wall, roof)
	chimney(m, rel, w / 4, y + w / 3, -d / 4, 6)
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
	part(m, "Door", Vector3.new(3.2, 5, 0.3), rel(0, PAVE + 2.5, D / 2 + 0.15), rgb(110, 70, 45), Enum.Material.WoodPlanks)
	arch(m, rel, 3.2, 0, PAVE + 5, D / 2 + 0.15, rgb(110, 70, 45), Enum.Material.WoodPlanks)
	for _, u in { -5, 5 } do
		part(m, "Window", Vector3.new(2.6, 2.2, 0.3), rel(u, PAVE + 4.8, D / 2 + 0.15), LANTERN, Enum.Material.Glass)
		arch(m, rel, 2.6, u, PAVE + 5.9, D / 2 + 0.15, LANTERN, Enum.Material.Glass)
	end
	chimney(m, rel, W / 3, PAVE + H + 4, -D / 4, 7)
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

-- Makes a hall a working shop: the Shop attribute plus a counter anchor in front of its doors.
local function hallShop(hall: Model, id: string)
	hall:SetAttribute("Shop", id)
	local doors = hall:FindFirstChild("Doors") :: BasePart?
	if doors then
		local anchor = part(hall, "ShopAnchor", Vector3.new(4, 4, 4), doors.CFrame * CFrame.new(0, -2.5, -3.5), WHITE, nil, { Transparency = 1, CanCollide = false })
		anchor:SetAttribute("Shop", id)
	end
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
		rune.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- animated whole on the client
	end
end

-- A leaderboard on two posts; LeaderboardService fills in boards by their Leaderboard attribute.
local function leaderBoard(parent: Instance, x: number, z: number, facing: Vector3, stat: string, title: string)
	local rel = frame(x, z, facing)
	for _, s in { -1, 1 } do
		part(parent, "BoardPost", Vector3.new(0.8, 15, 0.8), rel(s * 6.5, 7.5, 0), TIMBER, Enum.Material.Wood)
	end
	local header = part(parent, "BoardHeader", Vector3.new(14, 2.4, 0.6), rel(0, 15, 0), GOLD, Enum.Material.Metal)
	sign(header, title, rgb(60, 40, 20))
	local backing = part(parent, "LeaderboardBoard", Vector3.new(12, 11, 0.6), rel(0, 8, 0), rgb(60, 50, 45), Enum.Material.WoodPlanks)
	backing:SetAttribute("Leaderboard", stat)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(260, 280)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Parent = backing
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 0.25
	text.BackgroundColor3 = rgb(35, 28, 24)
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = rgb(255, 240, 200)
	text.Text = title .. "\n\nLoading..."
	text.Parent = gui
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
	leaderBoard(parent, x1 - 9, z0 + 9, Vector3.new(0, 0, 1), "level", "Highest Levels")
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
			if not gate then
				local rr = R - 12 + tier * 4
				local p = Vector3.new(cx, 0, cz) + dir * rr
				part(m, "Stand", Vector3.new(2 * math.pi * rr / segs + 0.6, 3 + tier * 3, 4), CFrame.lookAt(Vector3.new(p.X, PAVE + (3 + tier * 3) / 2, p.Z), Vector3.new(p.X, PAVE + (3 + tier * 3) / 2, p.Z) + dir), if tier % 2 == 0 then STONE else DARKSTONE, Enum.Material.Cobblestone)
			end
		end
		local p = Vector3.new(cx, 0, cz) + dir * R
		local wallH = if gate then 6 else 16
		part(m, "OuterWall", Vector3.new(arc, wallH, 2.4), CFrame.lookAt(Vector3.new(p.X, PAVE + if gate then 13 else 8, p.Z), Vector3.new(p.X, PAVE + if gate then 13 else 8, p.Z) + dir), STONE, Enum.Material.Cobblestone)
		if gate then
			-- the portcullis is raised: walk straight in
			local bars = part(m, "Portcullis", Vector3.new(arc - 2, 3, 0.4), CFrame.lookAt(Vector3.new(p.X, PAVE + 11.5, p.Z), Vector3.new(p.X, PAVE + 11.5, p.Z) + dir), IRON, Enum.Material.DiamondPlate)
			bars.Transparency = 0.3
			bars.CanCollide = false
			local pole = Vector3.new(cx, 0, cz) + dir * (R + 1.6)
			cylinder(m, "FlagPole", 10, 0.4, pole.X, PAVE + 21, pole.Z, IRON, Enum.Material.Metal)
			part(m, "Flag", Vector3.new(0.2, 3, 5), CFrame.new(pole.X, PAVE + 24.5, pole.Z + 2.6), BANNERS[(k // 5) % #BANNERS + 1], Enum.Material.Fabric)
		end
	end
	local board = box(m, "ArenaSign", cx, PAVE + 17, z0 + 2, 18, 3, 0.6, rgb(50, 40, 35), Enum.Material.WoodPlanks)
	sign(board, "The Arena", GOLD, Enum.NormalId.Back)
	-- gameplay: the floor's centre and size (ArenaService), and the gate where trials start
	local centre = part(m, "ArenaCenter", Vector3.new(1, 1, 1), CFrame.new(cx, PAVE + 0.5, cz), WHITE, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	centre:SetAttribute("ArenaCenter", true)
	centre:SetAttribute("ArenaRadius", R - 15)
	local gateDir = Vector3.new(math.cos(math.pi * 2 * 0.5 / segs), 0, math.sin(math.pi * 2 * 0.5 / segs))
	local gatePos = Vector3.new(cx, 0, cz) + gateDir * (R + 4)
	local gate = part(m, "ArenaGate", Vector3.new(4, 6, 4), CFrame.new(gatePos.X, PAVE + 3, gatePos.Z), rgb(200, 60, 50), Enum.Material.Fabric)
	gate:SetAttribute("ArenaGate", true)
	local gateSign = part(m, "GateBanner", Vector3.new(0.4, 4, 3), CFrame.lookAt(Vector3.new(gatePos.X, PAVE + 9, gatePos.Z), Vector3.new(gatePos.X, PAVE + 9, gatePos.Z) + gateDir), rgb(200, 60, 50), Enum.Material.Fabric)
	sign(gateSign, "Trials", GOLD, Enum.NormalId.Front)
	leaderBoard(m, x0 + 8, z1 - 8, Vector3.new(0, 0, 1), "arena", "Arena Champions")
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
-- waterfront

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
	sign(board, "Boatwright", GOLD)
	wh:SetAttribute("Shop", "boats")
	local boatAnchor = part(wh, "ShopAnchor", Vector3.new(4, 4, 4), rel(0, PAVE + 2.5, 16), WHITE, nil, { Transparency = 1, CanCollide = false })
	boatAnchor:SetAttribute("Shop", "boats")
	-- the sailmaker's stall on the quay, for paint and trim
	local sx, sz = x0 + EDGE + 40, z1 - EDGE - 6
	marketStall(f, sx, sz, Vector3.new(0, 0, -1), rgb(80, 150, 220), seed + 4)
	local sailSign = part(f, "SailmakerSign", Vector3.new(8, 1.6, 0.3), CFrame.new(sx, PAVE + 9.4, sz + 0.5), rgb(60, 45, 35), Enum.Material.WoodPlanks)
	sign(sailSign, "Sailmaker", GOLD, Enum.NormalId.Front)
	local sailAnchor = part(f, "ShopAnchor", Vector3.new(4, 4, 4), CFrame.new(sx, PAVE + 2.5, sz - 3), WHITE, nil, { Transparency = 1, CanCollide = false })
	sailAnchor:SetAttribute("Shop", "sailmaker")
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
		box(f, "GateTower", p.X, -4, p.Z, 12, 32, 12, STONE, Enum.Material.Cobblestone)
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

-- Moves every part under `root` up by dy.
local function lift(root: Instance, dy: number)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame + Vector3.new(0, dy, 0)
		end
	end
end

-- Builds something made for flat ground at y = 0, then raises it by dy into `parent`.
local function raised(parent: Instance, dy: number, build: (Instance) -> ())
	local tmp = Instance.new("Folder")
	build(tmp)
	lift(tmp, dy)
	for _, c in tmp:GetChildren() do
		c.Parent = parent
	end
	tmp:Destroy()
end

-- Stone bridge from a to b (Y = deck height at each end) with arches, parapets, lanterns and lions.
local function stoneBridge(city: Instance, a: Vector3, b: Vector3, width: number)
	local f = model(city, "StoneBridge")
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local dir = flat.Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local length = (b - a).Magnitude
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, mid + (b - a))
	part(f, "Deck", Vector3.new(width, 2, length), cf * CFrame.new(0, -0.6, 0), COBBLE, Enum.Material.Cobblestone)
	for _, s in { -1, 1 } do
		part(f, "Parapet", Vector3.new(1.4, 3, length), cf * CFrame.new(s * (width / 2 - 0.7), 1.9, 0), STONE, Enum.Material.Cobblestone)
		local n = math.floor(length / 26)
		for k = 0, n do
			local p = (cf * CFrame.new(s * (width / 2 - 0.7), 0, -length / 2 + k * (length / n))).Position
			raised(f, p.Y, function(t)
				lanternPost(t, p.X, p.Z)
			end)
		end
	end
	-- piers down into the water, with arched ribs between them
	local spans = math.max(2, math.floor(length / 34))
	for k = 0, spans do
		local p = (cf * CFrame.new(0, -1.6, -length / 2 + k * (length / spans))).Position
		local bottom = -14
		part(f, "Pier", Vector3.new(width - 4, p.Y - bottom, 6), CFrame.lookAt(Vector3.new(p.X, (p.Y + bottom) / 2, p.Z), Vector3.new(p.X, (p.Y + bottom) / 2, p.Z) + dir), DARKSTONE, Enum.Material.Cobblestone)
	end
	for k = 0, spans - 1 do
		local v0 = -length / 2 + k * (length / spans) + 3
		local v1 = v0 + length / spans - 6
		local segs = 6
		for i = 0, segs - 1 do
			local t0, t1 = i / segs, (i + 1) / segs
			local p0 = cf * CFrame.new(0, -1.6 - (1 - math.sin(t0 * math.pi)) * 5, -(v0 + (v1 - v0) * t0))
			local p1 = cf * CFrame.new(0, -1.6 - (1 - math.sin(t1 * math.pi)) * 5, -(v0 + (v1 - v0) * t1))
			part(f, "ArchRib", Vector3.new(width - 2, 1.4, (p1.Position - p0.Position).Magnitude + 0.4), CFrame.lookAt((p0.Position + p1.Position) / 2, p1.Position), STONE, Enum.Material.Cobblestone)
		end
	end
	-- lions at both ends
	for _, e in { a + dir * 3, b - dir * 3 } do
		for _, s in { -1, 1 } do
			local p = e + side * s * (width / 2 + 2)
			box(f, "StatuePlinth", p.X, p.Y - 1, p.Z, 4, 5, 4, STONE, Enum.Material.Marble)
			box(f, "LionBody", p.X, p.Y + 4, p.Z, 2.4, 2.4, 3.6, GOLD, Enum.Material.Metal)
			ball(f, "LionMane", 2.8, p.X, p.Y + 7, p.Z, GOLD, Enum.Material.Metal)
		end
	end
end

----------------------------------------------------------------------------------------------
-- the airship port, built round (cx, cz) on flat ground at y = 0

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

local function airshipPort(f: Instance, cx: number, cz: number)
	box(f, "Plaza", cx + 25, -0.6, cz, 90, 1, 190, rgb(190, 180, 160), Enum.Material.Cobblestone)
	-- mooring towers with airships
	local colors = { rgb(200, 60, 60), rgb(60, 110, 200), rgb(220, 170, 50), rgb(120, 70, 170) }
	for k, p in { { -45, -105 }, { -95, -35 }, { -45, 35 }, { -95, 105 } } do
		mooringTower(f, cx + p[1], cz + p[2], 40)
		airship(f, cx + p[1], 32, cz + p[2] + 2, Vector3.new(0, 0, 1), colors[k])
	end
	-- the shipyard hall and the port inn
	local hall = model(f, "Skyward Shipyard")
	local rel = frame(cx + 92, cz + 25, Vector3.new(-1, 0, 0))
	part(hall, "Walls", Vector3.new(90, 22, 40), rel(0, 11, 0), rgb(150, 100, 65), Enum.Material.WoodPlanks)
	gableSide(hall, rel, 90, 40, 22, rgb(150, 100, 65), ROOFS[2], Enum.Material.WoodPlanks)
	part(hall, "BayDoor", Vector3.new(30, 18, 0.5), rel(0, 9, 20.2), rgb(110, 70, 45), Enum.Material.WoodPlanks)
	local board = part(hall, "NameBoard", Vector3.new(30, 3, 0.5), rel(0, 20, 20.3), rgb(60, 45, 35), Enum.Material.WoodPlanks)
	sign(board, "Skyward Shipyard", GOLD)
	hall:SetAttribute("Shop", "airships")
	local yardAnchor = part(hall, "ShopAnchor", Vector3.new(4, 4, 4), rel(-12, 2.5, 23), WHITE, nil, { Transparency = 1, CanCollide = false })
	yardAnchor:SetAttribute("Shop", "airships")
	raised(f, -PAVE, function(t)
		shop(t, cx + 80, cz - 75, 22, Vector3.new(-1, 0, 0), "The Cloud's Rest Inn", "inn", 2)
	end)
	-- the Aerie Workshop: flying machines and their paint loft
	local aerie = model(f, "Aerie Workshop")
	local arel = frame(cx + 20, cz + 116, Vector3.new(0, 0, -1))
	part(aerie, "Walls", Vector3.new(44, 16, 22), arel(0, 8, 0), rgb(205, 195, 175), Enum.Material.Plaster)
	gableSide(aerie, arel, 44, 22, 16, rgb(205, 195, 175), ROOFS[3], Enum.Material.Plaster)
	part(aerie, "HangarDoor", Vector3.new(18, 12, 0.5), arel(-8, 6, 11.2), rgb(110, 70, 45), Enum.Material.WoodPlanks)
	local aboard = part(aerie, "NameBoard", Vector3.new(22, 2.6, 0.5), arel(0, 14, 11.3), rgb(60, 45, 35), Enum.Material.WoodPlanks)
	sign(aboard, "Aerie Workshop", GOLD)
	for _, s in { -1, 1 } do
		part(aerie, "DisplayWing", Vector3.new(14, 0.3, 4), arel(s * 9, 18.5, 2) * CFrame.Angles(0, 0, s * math.rad(-12)), rgb(240, 230, 210), Enum.Material.Fabric)
	end
	local craftAnchor = part(aerie, "ShopAnchor", Vector3.new(4, 4, 4), arel(-8, 2.5, 14), WHITE, nil, { Transparency = 1, CanCollide = false })
	craftAnchor:SetAttribute("Shop", "aircraft")
	local loftAnchor = part(aerie, "ShopAnchor", Vector3.new(4, 4, 4), arel(14, 2.5, 14), WHITE, nil, { Transparency = 1, CanCollide = false })
	loftAnchor:SetAttribute("Shop", "aeriepaint")
	local loftSign = part(aerie, "LoftSign", Vector3.new(10, 1.6, 0.4), arel(14, 7, 11.3), rgb(60, 45, 35), Enum.Material.WoodPlanks)
	sign(loftSign, "Paint Loft", GOLD)
	-- cargo, carts and a windsock
	for k = 0, 7 do
		crate(f, cx + 10 + (k % 4) * 5, 0, cz - 60 + (k // 4) * 5, 4, hash(k) * 0.5)
	end
	cart(f, cx + 40, cz + 80, Vector3.new(0, 0, -1), 2)
	cart(f, cx + 20, cz + 95, Vector3.new(0, 0, 1), 4)
	cylinder(f, "WindsockPole", 12, 0.4, cx - 100, 6, cz - 100, IRON, Enum.Material.Metal)
	part(f, "Windsock", Vector3.new(1.6, 1.6, 5), CFrame.new(cx - 100, 11.6, cz - 97) * CFrame.Angles(math.rad(-10), 0, 0), rgb(250, 120, 40), Enum.Material.Fabric)
end

----------------------------------------------------------------------------------------------
-- placing things on the rolling ground

local L: any = nil -- Shared.Landscape, passed to Build
local C = { x = 0, z = 0 }
local WALL_IN = 15 -- the wall runs this far inside Landscape.cityRadiusAt

local counter = 0
local function rand(): number
	counter += 1
	return hash(counter * 0.6180339 + 0.37)
end

-- occupancy: 3-stud cells taken by lots, so nothing overlaps
local OCC = 3
local occupied: { [number]: boolean } = {}
local function occKey(x: number, z: number): number
	return math.floor(x / OCC) * 100000 + math.floor(z / OCC)
end

type Lot = { x: number, z: number, facing: Vector3, w: number, back: number, front: number }

-- Calls fn at points over a lot's footprint (u across, v from back to front); stops on false.
local function eachPoint(lot: Lot, step: number, pad: number, fn: (number, number) -> boolean): boolean
	local rx, rz = -lot.facing.Z, lot.facing.X
	local fx, fz = lot.facing.X, lot.facing.Z
	local u0, u1 = -lot.w / 2 - pad, lot.w / 2 + pad
	local v0, v1 = lot.back - pad, lot.front + pad
	local nu = math.max(1, math.ceil((u1 - u0) / step))
	local nv = math.max(1, math.ceil((v1 - v0) / step))
	for i = 0, nu do
		local u = u0 + (u1 - u0) * i / nu
		for j = 0, nv do
			local v = v0 + (v1 - v0) * j / nv
			if not fn(lot.x + rx * u + fx * v, lot.z + rz * u + fz * v) then
				return false
			end
		end
	end
	return true
end

local function insideWalls(x: number, z: number, margin: number): boolean
	local dx, dz = x - C.x, z - C.z
	return math.sqrt(dx * dx + dz * dz) < L.cityRadiusAt(math.atan2(dz, dx)) - WALL_IN - margin
end

local function distFromCentre(x: number, z: number): number
	return math.sqrt((x - C.x) ^ 2 + (z - C.z) ^ 2)
end

type Survey = { clear: number?, maxRange: number?, water: boolean?, inside: boolean? }

-- Is the lot free, off the roads, dry and not too steep? Also returns the lowest and highest ground.
local function survey(lot: Lot, opts: Survey): (boolean, number, number)
	local lo, hi = math.huge, -math.huge
	local clear = opts.clear or 1.5
	local ok = eachPoint(lot, 3, 0, function(x, z)
		if occupied[occKey(x, z)] then
			return false
		end
		if (L.nearestRoad(x, z)) < clear then
			return false
		end
		if opts.inside and not insideWalls(x, z, 4) then
			return false
		end
		local h = L.height(x, z)
		if not opts.water and h < 1.4 then
			return false
		end
		lo, hi = math.min(lo, h), math.max(hi, h)
		return true
	end)
	if ok and hi - lo > (opts.maxRange or 9) then
		ok = false
	end
	return ok, lo, hi
end

local function claim(lot: Lot)
	eachPoint(lot, 1.5, 1.5, function(x, z)
		occupied[occKey(x, z)] = true
		return true
	end)
end

local function towardRoad(x: number, z: number): Vector3
	local _, sample = L.nearestRoad(x, z)
	if sample then
		local d = Vector3.new(sample.x - x, 0, sample.z - z)
		if d.Magnitude > 0.1 then
			return d.Unit
		end
	end
	return Vector3.new(0, 0, -1)
end

-- Builds a lot (made for flat ground at y = 0) at the top of its slope, on a stone plinth that
-- levels it: on a hillside the plinth becomes a terrace wall. Ships stay down on the water.
-- Stone ramps from the top of a lot's plinth down to the ground beyond its edges, wherever the
-- drop is more than a step: "front" (towards the street) or "all" four sides.
local function addRamps(unit: Instance, lot: Lot, top: number, sides: string)
	local f = lot.facing
	local r = Vector3.new(-f.Z, 0, f.X)
	local origin = Vector3.new(lot.x, 0, lot.z)
	local centre = origin + f * ((lot.front + lot.back) / 2)
	local depth = lot.front - lot.back
	local edges: { { any } } = { { f, origin + f * lot.front, lot.w } }
	if sides == "all" then
		table.insert(edges, { -f, origin + f * lot.back, lot.w })
		table.insert(edges, { r, centre + r * (lot.w / 2), depth })
		table.insert(edges, { -r, centre - r * (lot.w / 2), depth })
	end
	for _, e in edges do
		local dir: Vector3, edge: Vector3, span: number = e[1], e[2], e[3]
		local beyond = edge + dir * 3
		local drop = top - L.height(beyond.X, beyond.Z)
		if drop > 1.2 then
			local length = math.max(6, drop * 2.2)
			local width = math.clamp(span * 0.35, 8, 14)
			local mid = edge + dir * (length / 2 + 0.5)
			wedge(unit, "Ramp", Vector3.new(width, drop, length), CFrame.lookAt(Vector3.new(mid.X, top - drop / 2, mid.Z), Vector3.new(mid.X, top - drop / 2, mid.Z) + dir), DARKSTONE, Enum.Material.Cobblestone)
		end
	end
end

local function buildLot(parent: Instance, name: string, lot: Lot, lo: number, hi: number, builder: (Instance) -> (), plinthColor: Color3?, plinthMaterial: any?, fixedY: number?, ramps: string?): Instance
	local unit = folder(parent, name)
	builder(unit)
	local y = fixedY or (hi + 0.1)
	lift(unit, y)
	for _, d in unit:GetDescendants() do
		if d:IsA("Model") and d.Name == "Ship" then
			lift(d, -y)
		end
	end
	if not fixedY then
		local bottom = lo - 3
		local top = y + PAVE - 0.05
		local cv = (lot.back + lot.front) / 2
		local cf = CFrame.lookAt(Vector3.new(lot.x, 0, lot.z), Vector3.new(lot.x + lot.facing.X, 0, lot.z + lot.facing.Z)) * CFrame.new(0, (top + bottom) / 2, -cv)
		part(unit, "Plinth", Vector3.new(lot.w + 1, top - bottom, lot.front - lot.back + 1), cf, plinthColor or FLAGSTONE, plinthMaterial or Enum.Material.Slate)
		if ramps then
			addRamps(unit, lot, top, ramps)
		end
	end
	return unit
end

type LandmarkOpts = { fixed: Vector3?, maxRange: number?, y: number?, water: boolean?, force: boolean?, inside: boolean? }

-- A big building near (x, z): searches outward in rings for the first free, dry spot.
local function landmark(parent: Instance, name: string, x: number, z: number, w: number, back: number, front: number, builder: (Instance, number, number, Vector3) -> (), opts: LandmarkOpts?): Lot?
	local o: LandmarkOpts = opts or {}
	for ring = 0, 16 do
		local count = if ring == 0 then 1 else 8 + ring * 2
		for k = 0, count - 1 do
			local a = k / count * math.pi * 2 + ring
			local px, pz = x + math.cos(a) * ring * 12, z + math.sin(a) * ring * 12
			local facing = o.fixed or towardRoad(px, pz)
			local lot: Lot = { x = px, z = pz, facing = facing, w = w, back = back, front = front }
			local ok, lo, hi = true, 0, 0
			if not o.force then
				ok, lo, hi = survey(lot, { clear = 3, maxRange = o.maxRange or 16, water = o.water, inside = if o.inside == nil then true else o.inside })
			end
			if ok then
				claim(lot)
				buildLot(parent, name, lot, lo, hi, function(u)
					builder(u, px, pz, facing)
				end, DARKSTONE, Enum.Material.Cobblestone, o.y, "all")
				return lot
			end
			if o.force then
				return nil
			end
		end
	end
	print("[CityBuilder] no room for " .. name)
	return nil
end

-- An invisible marker the server looks up by attribute (fast travel, training dummies).
local function marker(parent: Instance, name: string, x: number, y: number, z: number, attribute: string, value: any)
	local p = part(parent, name, Vector3.new(1, 1, 1), CFrame.new(x, y + 0.5, z), WHITE, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	p:SetAttribute(attribute, value)
end

----------------------------------------------------------------------------------------------
-- districts

local MARKET = {
	{ "Blacksmith", "blacksmith" }, { "Armorer", "armorer" }, { "Alchemist", "alchemist" }, { "Beast Tamer", "tamer" },
	{ "Stables", "stable" }, { "The Gilded Tankard", "tavern" }, { "Fletcher", "fletcher" }, { "Enchanter", "enchanter" },
	{ "Cook & Larder", "cook" }, { "Tailor", "tailor" }, { "Herbalist", "herbalist" }, { "Cartographer", "maps" },
	{ "Carriage Works", "carriages" }, { "Coachpaint Atelier", "coachpaint" },
}
local shopsPlaced = 0

local KINDS = {
	shop = { w0 = 20, w1 = 26, back = -9.5, front = 10.6, set0 = 3.5, set1 = 6, range = 8 },
	townhouse = { w0 = 12, w1 = 16, back = -7.5, front = 9.6, set0 = 1.5, set1 = 5, range = 8 },
	cottage = { w0 = 18, w1 = 18, back = -6.5, front = 15.5, set0 = 1, set1 = 7, range = 10 },
}

-- Which kind of house goes beside a road at (x, z), or nil for none.
local function cityPick(main: boolean): (number, number) -> string?
	return function(x: number, z: number): string?
		if not insideWalls(x, z, 6) then
			return nil
		end
		local d = distFromCentre(x, z)
		local r = rand()
		if d < 200 then
			if shopsPlaced < #MARKET * 2 and (main or r < 0.3) then
				return "shop"
			end
			return "townhouse"
		elseif d < 300 then
			return if r < 0.6 then "townhouse" else "cottage"
		end
		return if r < 0.85 then "cottage" elseif r < 0.95 then "townhouse" else nil
	end
end

local function countryPick(x: number, z: number): string?
	if L.cityWeight(x, z) > 0.05 or L.onSite(x, z, 40) or rand() > 0.09 then
		return nil
	end
	return "cottage"
end

-- Houses along both sides of a road, set back by varying amounts and turned a little, so the
-- frontage follows the curve without lining up.
local function frontage(parent: Instance, roadIndex: number, pick: (number, number) -> string?, inside: boolean)
	local samples = L.RoadSamples[roadIndex]
	local total = samples[#samples].s
	for _, side in { 1, -1 } do
		local idx = 1
		local s = rand() * 8
		while s < total do
			while idx < #samples and samples[idx].s < s do
				idx += 1
			end
			local smp = samples[idx]
			local nx, nz = -smp.tz * side, smp.tx * side
			local kind = pick(smp.x + nx * (smp.hw + 12), smp.z + nz * (smp.hw + 12))
			if not kind then
				s += if inside then 8 else 30
				continue
			end
			local K = KINDS[kind]
			local w = K.w0 + (K.w1 - K.w0) * rand()
			local setback = K.set0 + (K.set1 - K.set0) * rand()
			local off = smp.hw + setback + K.front
			local turn = (rand() - 0.5) * 0.2
			local c, sn = math.cos(turn), math.sin(turn)
			local fx, fz = -nx, -nz
			local facing = Vector3.new(fx * c - fz * sn, 0, fx * sn + fz * c)
			local lot: Lot = { x = smp.x + nx * off, z = smp.z + nz * off, facing = facing, w = w, back = K.back, front = K.front }
			local ok, lo, hi = survey(lot, { clear = 1, maxRange = K.range, inside = inside })
			if ok then
				claim(lot)
				local seed = math.floor(rand() * 1000)
				if kind == "shop" then
					shopsPlaced += 1
					local entry = MARKET[(shopsPlaced - 1) % #MARKET + 1]
					local id = if shopsPlaced > #MARKET then entry[2] .. "2" else entry[2]
					buildLot(parent, "Shop", lot, lo, hi, function(u)
						shop(u, lot.x, lot.z, w, facing, entry[1], id, seed)
					end, nil, nil, nil, "front")
				elseif kind == "townhouse" then
					buildLot(parent, "Townhouse", lot, lo, hi, function(u)
						townhouse(u, lot.x, lot.z, w, 14, 2 + seed % 3, facing, seed)
					end)
				else
					buildLot(parent, "Cottage", lot, lo, hi, function(u)
						cottageHome(u, lot.x, lot.z, facing, seed)
					end, rgb(110, 175, 85), Enum.Material.Grass)
				end
				s += w + 1 + rand() * (if kind == "cottage" then 12 elseif kind == "shop" then 2 else 4)
			else
				s += 4
			end
		end
	end
end

-- Back lanes: houses in the gaps behind the street fronts, turned every which way, the way old
-- towns fill in over the centuries.
local function backfill(parent: Instance)
	local i = 0
	for gz = C.z - 440, C.z + 440, 19 do
		for gx = C.x - 440, C.x + 440, 19 do
			i += 1
			local x, z = gx + (hash(i * 3.1) - 0.5) * 12, gz + (hash(i * 5.3) - 0.5) * 12
			if hash(i + 0.13) < 0.75 and insideWalls(x, z, 10) then
				local d = distFromCentre(x, z)
				local kind = if d < 260 and hash(i + 0.29) < 0.7 then "townhouse" else "cottage"
				local K = KINDS[kind]
				local base = towardRoad(x, z)
				local turn = (hash(i + 0.53) - 0.5) * 1.4
				local c, sn = math.cos(turn), math.sin(turn)
				local facing = Vector3.new(base.X * c - base.Z * sn, 0, base.X * sn + base.Z * c)
				local w = K.w0 + (K.w1 - K.w0) * hash(i + 0.71)
				local lot: Lot = { x = x, z = z, facing = facing, w = w, back = K.back, front = K.front }
				local ok, lo, hi = survey(lot, { clear = 2, maxRange = K.range, inside = true })
				if ok then
					claim(lot)
					local seed = 500 + i
					if kind == "townhouse" then
						buildLot(parent, "Townhouse", lot, lo, hi, function(u)
							townhouse(u, x, z, w, 14, 2 + seed % 2, facing, seed)
						end)
					else
						buildLot(parent, "Cottage", lot, lo, hi, function(u)
							cottageHome(u, x, z, facing, seed)
						end, rgb(110, 175, 85), Enum.Material.Grass)
					end
				end
			end
		end
	end
end

-- Lanterns along the city roads, carts and riders on them.
local function streetLife(city: Instance)
	local lamps = folder(city, "Lanterns")
	local traffic = folder(city, "Traffic")
	local n = 0
	for roadIndex, samples in L.RoadSamples do
		local cityRoad = roadIndex <= 8
		local total = samples[#samples].s
		local idx = 1
		local s = 10
		while s < total do
			while idx < #samples and samples[idx].s < s do
				idx += 1
			end
			local smp = samples[idx]
			n += 1
			local side = if n % 2 == 0 then 1 else -1
			local nx, nz = -smp.tz * side, smp.tx * side
			if cityRoad and insideWalls(smp.x, smp.z, 0) then
				local lx, lz = smp.x + nx * (smp.hw + 1.4), smp.z + nz * (smp.hw + 1.4)
				if not occupied[occKey(lx, lz)] then
					raised(lamps, L.height(lx, lz) - PAVE, function(t)
						lanternPost(t, lx, lz)
					end)
				end
			end
			if n % 3 == 0 and (cityRoad or rand() < 0.25) then
				local px, pz = smp.x + nx * smp.hw * 0.45, smp.z + nz * smp.hw * 0.45
				local heading = Vector3.new(smp.tx * side, 0, smp.tz * side)
				local roll = rand()
				raised(traffic, smp.y, function(t)
					if roll < 0.3 and smp.hw > 6 then
						carriage(t, px, pz, heading, BANNERS[n % #BANNERS + 1])
					elseif roll < 0.65 then
						cart(t, px, pz, heading, n)
					else
						horse(t, px, pz, heading, COATS[n % #COATS + 1], true)
					end
				end)
			end
			s += if cityRoad then 30 + rand() * 12 else 90 + rand() * 60
		end
	end
end

-- Trees, wells and benches in the gaps between houses.
local function greenery(city: Instance)
	local f = folder(city, "Greenery")
	local i = 0
	for gz = C.z - 440, C.z + 440, 17 do
		for gx = C.x - 440, C.x + 440, 17 do
			i += 1
			local x, z = gx + (hash(i * 1.7) - 0.5) * 12, gz + (hash(i * 2.3) - 0.5) * 12
			if insideWalls(x, z, 4) then
				local lot: Lot = { x = x, z = z, facing = Vector3.new(0, 0, 1), w = 6, back = -3, front = 3 }
				local roll = hash(i + 0.41)
				local ok = roll < 0.42 and survey(lot, { clear = 2.5, maxRange = 3 })
				if ok then
					claim(lot)
					local h = L.height(x, z)
					raised(f, h - PAVE, function(t)
						if roll < 0.035 then
							well(t, x, z)
						elseif roll < 0.06 then
							bench(t, x, z, towardRoad(x, z))
						else
							cityTree(t, x, z, i)
						end
					end)
				end
			end
		end
	end
end

-- The wall: a wobbly ring that climbs and dips with the ground, open to the harbour, with a
-- gatehouse wherever a road passes through.
local function buildWalls(city: Instance)
	local f = folder(city, "Walls")
	local n = 92
	local pts = {}
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local r = L.cityRadiusAt(a) - WALL_IN
		pts[i + 1] = Vector3.new(C.x + math.cos(a) * r, 0, C.z + math.sin(a) * r)
	end
	local status: { [number]: string } = {}
	local crossing: { [number]: any } = {}
	for i = 1, n do
		local p0, p1 = pts[i], pts[i % n + 1]
		local why = "wall"
		for t = 0, 1, 0.25 do
			local x, z = p0.X + (p1.X - p0.X) * t, p0.Z + (p1.Z - p0.Z) * t
			local d, smp = L.nearestRoad(x, z)
			if L.height(x, z) < 1.4 then
				why = "water"
				break
			elseif d < 7 then
				why = "road"
				crossing[i] = smp
				break
			end
		end
		status[i] = why
		if why == "wall" then
			local h0, h1 = L.height(p0.X, p0.Z), L.height(p1.X, p1.Z)
			local len = (p1 - p0).Magnitude + 1.5
			local mid = (p0 + p1) / 2
			local base, top = math.min(h0, h1) - 4, math.max(h0, h1) + 15
			local cf = CFrame.lookAt(Vector3.new(mid.X, 0, mid.Z), Vector3.new(p1.X, 0, p1.Z))
			part(f, "Wall", Vector3.new(5, top - base, len), cf * CFrame.new(0, (top + base) / 2, 0), STONE, Enum.Material.Cobblestone)
			part(f, "WallWalk", Vector3.new(5.6, 0.6, len), cf * CFrame.new(0, top + 0.3, 0), DARKSTONE, Enum.Material.Cobblestone)
			local m = math.floor(len / 5)
			for k = 0, m - 1 do
				part(f, "Merlon", Vector3.new(1.2, 2.4, 2.4), cf * CFrame.new(2.2, top + 1.8, -len / 2 + (k + 0.5) * (len / m)), STONE, Enum.Material.Cobblestone)
			end
		end
	end
	for i = 1, n do
		local prev = status[(i - 2) % n + 1]
		local p = pts[i]
		local h = L.height(p.X, p.Z)
		if h > 1.4 and (status[i] == "wall" or prev == "wall") and (status[i] ~= prev or i % 5 == 0) then
			raised(f, h - 2, function(t)
				wallTower(t, p.X, p.Z, BANNERS[i % #BANNERS + 1])
			end)
		end
	end
	-- one gatehouse per run of road gaps, centred on the road
	for i = 1, n do
		if status[i] == "road" and status[(i - 2) % n + 1] ~= "road" then
			local j = i
			while status[j % n + 1] == "road" and j - i < 4 do
				j += 1
			end
			local smp = crossing[(i + (j - i) // 2 - 1) % n + 1] or crossing[i]
			if smp then
				local along = Vector3.new(-smp.tz, 0, smp.tx)
				raised(f, smp.y, function(t)
					gatehouse(t, smp.x, smp.z, along, smp.hw * 2 + 6)
				end)
			end
		end
	end
end

----------------------------------------------------------------------------------------------

function CityBuilder.Build(map: Instance, landscape: any): Instance
	local existing = map:FindFirstChild("City")
	if existing then
		existing:Destroy()
	end
	L = landscape
	C = { x = L.CityCentre.x, z = L.CityCentre.z }
	counter = 0
	shopsPlaced = 0
	table.clear(occupied)
	local city = Instance.new("Folder")
	city.Name = "City"
	local sites = L.Sites

	-- landmarks first, each on the nearest free ground to where it's wanted
	local quarter = folder(city, "Landmarks")
	landmark(quarter, "MarketSquare", 118, 832, 100, -45, 45, function(u, x, z)
		marketSquare(u, x - 50, x + 50, z - 45, z + 45)
		marker(u, "TravelPoint", x, PAVE, z - 30, "TravelPoint", "market")
	end, { fixed = Vector3.new(0, 0, 1) })
	landmark(quarter, "Arena", -120, 760, 96, -43, 43, function(u, x, z)
		arena(u, x - 48, x + 48, z - 43, z + 43)
	end, { fixed = Vector3.new(0, 0, 1), maxRange = 18 })
	landmark(quarter, "Cathedral", 150, 965, 56, -50, 41, function(u, x, z, facing)
		cathedral(u, x, z, facing)
	end, { maxRange = 18 })
	landmark(quarter, "MageTower", -45, 990, 40, -20, 20, function(u, x, z)
		mageTower(u, x, z)
	end, { fixed = Vector3.new(0, 0, 1) })
	landmark(quarter, "Guild", 85, 612, 74, -16, 19, function(u, x, z, facing)
		local hall = guildHall(u, x, z, 66, 30, facing, "Adventurers' Guild", BANNERS[1])
		hallShop(hall, "guild")
	end)
	landmark(quarter, "Treasury", 60, 905, 64, -16, 19, function(u, x, z, facing)
		local hall = guildHall(u, x, z, 56, 30, facing, "Royal Treasury", BANNERS[4])
		hallShop(hall, "bank")
	end)
	landmark(quarter, "TownHall", -115, 1060, 78, -16, 19, function(u, x, z, facing)
		local rel = frame(x, z, facing)
		guildHall(u, (rel(-8, 0, 0)).Position.X, (rel(-8, 0, 0)).Position.Z, 52, 30, facing, "Town Hall", BANNERS[3])
		clockTower(u, (rel(29, 0, 0)).Position.X, (rel(29, 0, 0)).Position.Z, facing)
	end)
	landmark(quarter, "Library", -170, 820, 64, -16, 19, function(u, x, z, facing)
		local lib = guildHall(u, x, z, 56, 30, facing, "Grand Library", BANNERS[5])
		hallShop(lib, "library")
	end)
	landmark(quarter, "Barracks", 110, 1185, 88, -36, 36, function(u, x, z)
		local barracks = guildHall(u, x, z - 20, 80, 26, Vector3.new(0, 0, -1), "Barracks", BANNERS[2])
		hallShop(barracks, "trainer")
		trainingYard(u, x, z + 18, 80, 28)
		for k = 0, 3 do
			marker(u, "DummySpot", x - 30 + k * 20, PAVE, z + 12, "DummySpot", true)
		end
	end, { fixed = Vector3.new(0, 0, 1) })
	landmark(quarter, "Temple", 230, 1100, 42, -18, 18, function(u, x, z, facing)
		temple(u, x, z, facing)
	end)
	landmark(quarter, "RoyalGardens", -60, 700, 66, -36, 36, function(u, x, z)
		gardens(u, x - 33, x + 33, z - 36, z + 36)
	end, { fixed = Vector3.new(0, 0, 1), maxRange = 22 })
	-- the waterfront sits on its own flat shore sites
	local hs, ds = sites.harbour, sites.docks
	landmark(quarter, "Harbour", hs.x, hs.z, 96, -40, 40, function(u, x, z)
		harbour(u, x - 48, x + 48, z - 40, z + 40, 3)
		marker(u, "TravelPoint", x - 20, PAVE, z, "TravelPoint", "harbour")
	end, { fixed = Vector3.new(0, 0, 1), force = true, y = hs.h - PAVE + 0.1 })
	landmark(quarter, "FishingDocks", ds.x, ds.z, 88, -35, 35, function(u, x, z)
		fishingDocks(u, x - 44, x + 44, z - 35, z + 35)
		marker(u, "TravelPoint", x - 20, PAVE, z, "TravelPoint", "docks")
	end, { fixed = Vector3.new(0, 0, 1), force = true, y = ds.h - PAVE + 0.1 })

	-- houses and shops along every road, the main streets first
	local houses = folder(city, "Houses")
	for i = 1, 8 do
		frontage(houses, i, cityPick(i <= 2), true)
	end
	backfill(houses)
	-- farmsteads here and there along the country roads
	local farms = folder(city, "Farmsteads")
	for i = 1, #L.Roads do
		frontage(farms, i, countryPick, false)
	end

	streetLife(city)
	greenery(city)
	buildWalls(city)

	-- the stone bridge from the island to the north gate
	local gb = L.GrandBridge
	local first = L.RoadSamples[1][1]
	stoneBridge(city, Vector3.new(gb[1], 0.6, gb[2]), Vector3.new(gb[3], first.y + 0.4, gb[4]), 34)

	-- out on the water: a galleon in the harbour channel, a sloop and fishing boats
	local bay = folder(city, "Bay")
	ship(bay, 470, 900, Vector3.new(0, 0, -1), "galleon", BANNERS[1])
	ship(bay, 660, 930, Vector3.new(1, 0, -0.2).Unit, "sloop", BANNERS[3])
	ship(bay, 440, 640, Vector3.new(0.3, 0, 1).Unit, "rowboat", WHITE)
	ship(bay, 470, 680, Vector3.new(-0.6, 0, 1).Unit, "rowboat", WHITE)
	ship(bay, 880, 960, Vector3.new(-1, 0, 0.1).Unit, "galleon", BANNERS[2])

	-- the airship port on its plateau west of the city
	local port = folder(city, "AirshipPort")
	local ps = sites.airport
	raised(port, ps.h, function(t)
		airshipPort(t, ps.x, ps.z)
		marker(t, "TravelPoint", ps.x + 25, 0, ps.z, "TravelPoint", "port")
	end)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2 + 0.3
		local x, z = ps.x + math.cos(a) * 150, ps.z + math.sin(a) * 150
		if not L.onRoad(x, z, 4) then
			raised(port, L.height(x, z) - PAVE, function(t)
				cityTree(t, x, z, 300 + k)
			end)
		end
	end

	city.Parent = map
	return city
end

if Color3 then
	initColors()
end

return CityBuilder
