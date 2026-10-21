--!strict
-- Builds Sproutling City (south of the garden island, across the lagoon) and its airport.
--
-- Like MapBuilder it touches no services, so it runs at server start, from the Studio command
-- bar and offline under Lune (tools/bake-map.luau passes the Roblox API table). Everything sits
-- under Map.City. Shops, cars and boats carry attributes (Shop, Vehicle) that later gameplay
-- systems look up; for now they are scenery.
--
-- Layout (studs, +Z = south). The city ground is a flat slab at y = 0 inside Landscape.City
-- (x -345..345, z 465..1155): a grid of roads with the 44-stud main avenue on x = 0 lined up
-- with the island's avenue, and blocks zoned as market street, downtown, park, apartments,
-- houses, civic, marina and harbour. The airport (Landscape.Airport) lies to the west.

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
local ASPHALT: Color3
local CONCRETE: Color3
local WHITE: Color3
local YELLOW: Color3
local CAR_COLORS: { Color3 }
local GLASS_TINTS: { Color3 }
local STONE: { Color3 }
local SHOP_STYLES: { { wall: Color3, accent: Color3 } }
initColors = function()
	ASPHALT = rgb(58, 60, 66)
	CONCRETE = rgb(205, 202, 195)
	WHITE = rgb(245, 245, 240)
	YELLOW = rgb(250, 205, 60)
	CAR_COLORS = { rgb(220, 60, 60), rgb(60, 120, 220), rgb(245, 245, 245), rgb(40, 40, 45), rgb(250, 200, 60), rgb(90, 190, 120), rgb(240, 130, 50), rgb(170, 110, 220), rgb(150, 155, 165) }
	GLASS_TINTS = { rgb(120, 175, 220), rgb(90, 200, 190), rgb(140, 150, 210), rgb(110, 190, 240), rgb(170, 200, 220) }
	STONE = { rgb(230, 225, 215), rgb(205, 200, 190), rgb(185, 190, 200), rgb(240, 235, 225) }
	SHOP_STYLES = {
		{ wall = rgb(250, 235, 210), accent = rgb(240, 120, 150) },
		{ wall = rgb(210, 235, 250), accent = rgb(60, 140, 220) },
		{ wall = rgb(235, 250, 215), accent = rgb(80, 180, 90) },
		{ wall = rgb(255, 225, 190), accent = rgb(245, 150, 50) },
		{ wall = rgb(235, 220, 250), accent = rgb(150, 100, 220) },
		{ wall = rgb(255, 245, 200), accent = rgb(220, 70, 70) },
	}
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

-- Cylinder lying along a direction (axles, fuselages): cframe's LookVector is the axis.
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

-- Text painted on one face of a part (shop signs, billboards, street signs).
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
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = textColor
	label.TextStrokeTransparency = 0.6
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

-- Local frame for a building at (x, z) whose front faces `facing`: rel(u, y, v) with u = right,
-- v = forward (towards the street).
local function frame(x: number, z: number, facing: Vector3): (number, number, number) -> CFrame
	local base = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + facing)
	return function(u: number, y: number, v: number): CFrame
		return base * CFrame.new(u, y, -v)
	end
end

----------------------------------------------------------------------------------------------
-- layout

local CITY = { x0 = -345, x1 = 345, z0 = 465, z1 = 1155 }
local AVENUES = { { x = -240, w = 28 }, { x = -120, w = 28 }, { x = 0, w = 44 }, { x = 120, w = 28 }, { x = 240, w = 28 } }
local STREETS = { { z = 490, w = 28 }, { z = 590, w = 28 }, { z = 700, w = 28 }, { z = 810, w = 28 }, { z = 920, w = 28 }, { z = 1030, w = 28 }, { z = 1130, w = 28 } }
local SIDEWALK = 6
local CURB = 0.6


-- Blocks between the roads: { x0, x1, z0, z1, ix, iz }.
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

local function streetlight(parent: Instance, x: number, z: number, arm: Vector3)
	cylinder(parent, "LightPole", 16, 0.7, x, CURB + 8, z, rgb(70, 72, 80), Enum.Material.Metal)
	local tip = Vector3.new(x, CURB + 15.6, z) + arm * 3.5
	part(parent, "LightArm", Vector3.new(0.4, 0.4, 3.6), CFrame.lookAt(Vector3.new(x, CURB + 15.6, z) + arm * 1.8, tip), rgb(70, 72, 80), Enum.Material.Metal)
	part(parent, "LightHead", Vector3.new(1.6, 0.5, 2.4), CFrame.lookAt(tip, tip + arm), rgb(255, 240, 200), Enum.Material.Neon)
end

local function trafficLight(parent: Instance, x: number, z: number, arm: Vector3)
	cylinder(parent, "SignalPole", 14, 0.8, x, CURB + 7, z, rgb(60, 62, 70), Enum.Material.Metal)
	local reach = 9
	local tip = Vector3.new(x, CURB + 13.5, z) + arm * reach
	part(parent, "SignalArm", Vector3.new(0.5, 0.5, reach), CFrame.lookAt(Vector3.new(x, CURB + 13.5, z) + arm * reach / 2, tip), rgb(60, 62, 70), Enum.Material.Metal)
	local housing = part(parent, "SignalHousing", Vector3.new(1.4, 4, 1.2), CFrame.new(tip - Vector3.new(0, 2, 0)), rgb(40, 40, 45), Enum.Material.Metal)
	for i, color in { rgb(255, 60, 50), rgb(255, 200, 40), rgb(60, 230, 90) } do
		local lamp = ball(parent, "SignalLamp", 0.9, 0, 0, 0, color, Enum.Material.Neon)
		lamp.CFrame = housing.CFrame * CFrame.new(0, 1.3 - (i - 1) * 1.3, -0.55)
		if i ~= 3 then
			lamp.Transparency = 0.55 -- only green lit
		end
	end
end

local function cityTree(parent: Instance, x: number, z: number, seed: number)
	cylinder(parent, "Planter", 1, 4, x, CURB + 0.5, z, rgb(150, 145, 140), Enum.Material.Concrete)
	cylinder(parent, "Trunk", 8, 0.9, x, CURB + 4.5, z, rgb(110, 80, 55), Enum.Material.Wood)
	local pick = hash(seed)
	local leaf = if pick < 0.2 then rgb(255, 175, 205) elseif pick < 0.32 then rgb(240, 160, 60) else rgb(70 + math.floor(hash(seed + 1) * 40), 160 + math.floor(hash(seed + 2) * 40), 70)
	ball(parent, "Canopy", 7, x, CURB + 10, z, leaf, Enum.Material.Grass)
	ball(parent, "Canopy", 4.5, x + 1.5, CURB + 12.2, z - 1, leaf, Enum.Material.Grass)
end

local function bench(parent: Instance, x: number, z: number, facing: Vector3)
	local rel = frame(x, z, facing)
	part(parent, "BenchSeat", Vector3.new(5, 0.4, 1.6), rel(0, CURB + 1.7, 0), rgb(150, 105, 70), Enum.Material.WoodPlanks)
	part(parent, "BenchBack", Vector3.new(5, 1.6, 0.3), rel(0, CURB + 2.8, -0.75), rgb(150, 105, 70), Enum.Material.WoodPlanks)
	for _, u in { -2, 2 } do
		part(parent, "BenchLeg", Vector3.new(0.4, 1.6, 1.6), rel(u, CURB + 0.8, 0), rgb(60, 60, 65), Enum.Material.Metal)
	end
end

local function hydrant(parent: Instance, x: number, z: number)
	cylinder(parent, "Hydrant", 2.4, 1, x, CURB + 1.2, z, rgb(220, 50, 45), Enum.Material.Metal)
	ball(parent, "HydrantCap", 1, x, CURB + 2.5, z, rgb(220, 50, 45), Enum.Material.Metal)
	cylinder(parent, "HydrantNozzle", 0.6, 0.5, x, CURB + 1.6, z, rgb(200, 45, 40), Enum.Material.Metal).CFrame = CFrame.new(x + 0.6, CURB + 1.6, z)
end

local function trashBin(parent: Instance, x: number, z: number)
	cylinder(parent, "Bin", 2.6, 1.8, x, CURB + 1.3, z, rgb(60, 110, 70), Enum.Material.Metal)
	cylinder(parent, "BinLid", 0.3, 2, x, CURB + 2.75, z, rgb(50, 90, 60), Enum.Material.Metal)
end

local function busStop(parent: Instance, x: number, z: number, facing: Vector3)
	local rel = frame(x, z, facing)
	part(parent, "ShelterRoof", Vector3.new(10, 0.4, 4), rel(0, CURB + 8, 0), rgb(70, 140, 220), Enum.Material.Metal)
	part(parent, "ShelterBack", Vector3.new(10, 6.5, 0.3), rel(0, CURB + 4.5, -1.8), rgb(200, 230, 255), Enum.Material.Glass, { Transparency = 0.4 })
	for _, u in { -4.8, 4.8 } do
		part(parent, "ShelterPost", Vector3.new(0.4, 7.6, 0.4), rel(u, CURB + 4, 1.7), rgb(70, 72, 80), Enum.Material.Metal)
	end
	part(parent, "ShelterSeat", Vector3.new(7, 0.4, 1.2), rel(0, CURB + 1.8, -1), rgb(150, 105, 70), Enum.Material.WoodPlanks)
	local board = part(parent, "BusSign", Vector3.new(2.4, 1.6, 0.2), rel(-6, CURB + 7, 1.8), rgb(70, 140, 220), Enum.Material.SmoothPlastic)
	sign(board, "BUS", WHITE)
	cylinder(parent, "BusSignPole", 6, 0.3, 0, 0, 0, rgb(70, 72, 80), Enum.Material.Metal).CFrame = rel(-6, CURB + 3.3, 1.8) * CFrame.Angles(0, 0, math.rad(90))
end

----------------------------------------------------------------------------------------------
-- vehicles (anchored props for now; tagged Vehicle for the driving system to come)


local function car(parent: Instance, x: number, z: number, heading: Vector3, color: Color3, kind: string?)
	local m = model(parent, "Car")
	m:SetAttribute("Vehicle", kind or "car")
	local rel = frame(x, z, heading)
	local body = part(m, "Body", Vector3.new(4.6, 1.8, 9.6), rel(0, 1.9, 0), color, Enum.Material.SmoothPlastic)
	m.PrimaryPart = body
	part(m, "Cabin", Vector3.new(4.2, 1.8, 5), rel(0, 3.7, -0.4), rgb(60, 80, 100), Enum.Material.Glass, { Transparency = 0.2 })
	part(m, "Roof", Vector3.new(4.3, 0.3, 4.4), rel(0, 4.7, -0.4), color, Enum.Material.SmoothPlastic)
	for _, w in { { -2.2, 3 }, { 2.2, 3 }, { -2.2, -3 }, { 2.2, -3 } } do
		local wheel = part(m, "Wheel", Vector3.new(0.9, 2.3, 2.3), rel(w[1], 1.15, w[2]), rgb(30, 30, 32), Enum.Material.SmoothPlastic)
		wheel.Shape = Enum.PartType.Cylinder
	end
	for _, u in { -1.6, 1.6 } do
		part(m, "Headlight", Vector3.new(0.9, 0.5, 0.2), rel(u, 2.2, 4.85), rgb(255, 250, 220), Enum.Material.Neon)
		part(m, "Taillight", Vector3.new(0.9, 0.5, 0.2), rel(u, 2.2, -4.85), rgb(255, 50, 50), Enum.Material.Neon)
	end
	part(m, "Bumper", Vector3.new(4.8, 0.6, 0.4), rel(0, 1.2, 5), rgb(70, 70, 75), Enum.Material.Metal)
	part(m, "Bumper", Vector3.new(4.8, 0.6, 0.4), rel(0, 1.2, -5), rgb(70, 70, 75), Enum.Material.Metal)
	if kind == "taxi" then
		local roofSign = part(m, "TaxiSign", Vector3.new(2, 0.7, 0.8), rel(0, 5.2, -0.4), rgb(255, 255, 255), Enum.Material.Neon)
		sign(roofSign, "TAXI", rgb(40, 40, 40))
	elseif kind == "police" then
		part(m, "Siren", Vector3.new(0.8, 0.5, 0.8), rel(-0.6, 5.1, -0.4), rgb(255, 50, 50), Enum.Material.Neon)
		part(m, "Siren", Vector3.new(0.8, 0.5, 0.8), rel(0.6, 5.1, -0.4), rgb(60, 120, 255), Enum.Material.Neon)
	end
end

local function bus(parent: Instance, x: number, z: number, heading: Vector3)
	local m = model(parent, "Bus")
	m:SetAttribute("Vehicle", "bus")
	local rel = frame(x, z, heading)
	local body = part(m, "Body", Vector3.new(6, 7, 24), rel(0, 4.6, 0), rgb(70, 140, 220), Enum.Material.SmoothPlastic)
	m.PrimaryPart = body
	for _, u in { -3.05, 3.05 } do
		part(m, "WindowStrip", Vector3.new(0.1, 2.4, 20), rel(u, 5.8, 0.5), rgb(40, 60, 80), Enum.Material.Glass)
	end
	part(m, "Windshield", Vector3.new(5.4, 3, 0.1), rel(0, 5.8, 12.05), rgb(40, 60, 80), Enum.Material.Glass)
	part(m, "Stripe", Vector3.new(6.1, 0.8, 24.1), rel(0, 3.2, 0), WHITE, Enum.Material.SmoothPlastic)
	for _, w in { { -2.9, 8 }, { 2.9, 8 }, { -2.9, -8 }, { 2.9, -8 } } do
		local wheel = part(m, "Wheel", Vector3.new(1, 2.8, 2.8), rel(w[1], 1.4, w[2]), rgb(30, 30, 32))
		wheel.Shape = Enum.PartType.Cylinder
	end
	local dest = part(m, "Destination", Vector3.new(4, 0.9, 0.1), rel(0, 7.6, 12.06), rgb(20, 20, 20), Enum.Material.SmoothPlastic)
	sign(dest, "CITY LOOP", rgb(255, 200, 60))
end

local function boat(parent: Instance, x: number, z: number, heading: Vector3, kind: string, color: Color3)
	local m = model(parent, "Boat")
	m:SetAttribute("Vehicle", kind)
	local rel = frame(x, z, heading)
	local water = -2
	if kind == "speedboat" then
		local hull = part(m, "Hull", Vector3.new(5, 2.4, 12), rel(0, water + 0.6, -1), color, Enum.Material.SmoothPlastic)
		m.PrimaryPart = hull
		wedge(m, "Bow", Vector3.new(5, 2.4, 5), rel(0, water + 0.6, 7.5) * CFrame.Angles(0, 0, math.pi), color)
		part(m, "Deck", Vector3.new(4.6, 0.3, 11), rel(0, water + 1.9, -1), WHITE, Enum.Material.SmoothPlastic)
		part(m, "Windscreen", Vector3.new(4.2, 1.4, 0.2), rel(0, water + 2.7, 2.5) * CFrame.Angles(math.rad(-25), 0, 0), rgb(150, 200, 230), Enum.Material.Glass, { Transparency = 0.3 })
		part(m, "Seat", Vector3.new(3.6, 1, 1.6), rel(0, water + 2.4, -1), rgb(240, 240, 240), Enum.Material.Fabric)
		part(m, "Motor", Vector3.new(1.4, 2.6, 1.4), rel(0, water + 1.4, -7.4), rgb(40, 40, 45), Enum.Material.Metal)
	elseif kind == "sailboat" then
		local hull = part(m, "Hull", Vector3.new(6, 2.6, 16), rel(0, water + 0.7, -1), WHITE, Enum.Material.SmoothPlastic)
		m.PrimaryPart = hull
		wedge(m, "Bow", Vector3.new(6, 2.6, 6), rel(0, water + 0.7, 10) * CFrame.Angles(0, 0, math.pi), WHITE)
		part(m, "Stripe", Vector3.new(6.1, 0.5, 16.1), rel(0, water + 1.4, -1), color, Enum.Material.SmoothPlastic)
		part(m, "Deck", Vector3.new(5.6, 0.3, 15), rel(0, water + 2.05, -1), rgb(190, 150, 100), Enum.Material.WoodPlanks)
		part(m, "Mast", Vector3.new(0.6, 22, 0.6), rel(0, water + 13, 1), rgb(200, 200, 205), Enum.Material.Metal)
		wedge(m, "Sail", Vector3.new(0.2, 18, 9), rel(0, water + 12, -3.5) * CFrame.Angles(0, math.pi, 0), WHITE, Enum.Material.Fabric)
		wedge(m, "Jib", Vector3.new(0.2, 14, 6), rel(0, water + 10, 4.6), color, Enum.Material.Fabric)
	elseif kind == "yacht" then
		local hull = part(m, "Hull", Vector3.new(12, 5, 40), rel(0, water + 1.5, -2), WHITE, Enum.Material.SmoothPlastic)
		m.PrimaryPart = hull
		wedge(m, "Bow", Vector3.new(12, 5, 12), rel(0, water + 1.5, 24) * CFrame.Angles(0, 0, math.pi), WHITE)
		part(m, "HullStripe", Vector3.new(12.1, 0.8, 40.1), rel(0, water + 2.4, -2), color, Enum.Material.SmoothPlastic)
		part(m, "Deck", Vector3.new(11, 0.4, 40), rel(0, water + 4.2, -2), rgb(190, 150, 100), Enum.Material.WoodPlanks)
		part(m, "Cabin", Vector3.new(9, 4.5, 18), rel(0, water + 6.6, -3), WHITE, Enum.Material.SmoothPlastic)
		part(m, "CabinGlass", Vector3.new(9.2, 1.6, 16), rel(0, water + 7.2, -3), rgb(40, 60, 80), Enum.Material.Glass)
		part(m, "Bridge", Vector3.new(7, 3, 9), rel(0, water + 10.4, -1), WHITE, Enum.Material.SmoothPlastic)
		part(m, "BridgeGlass", Vector3.new(7.2, 1.2, 7), rel(0, water + 10.8, -0.5), rgb(40, 60, 80), Enum.Material.Glass)
		cylinder(m, "Radar", 3, 0.4, 0, 0, 0, rgb(200, 200, 205), Enum.Material.Metal).CFrame = rel(0, water + 13.4, -3) * CFrame.Angles(0, 0, math.rad(90))
	elseif kind == "tug" then
		local hull = part(m, "Hull", Vector3.new(9, 4, 20), rel(0, water + 1, 0), rgb(200, 60, 50), Enum.Material.SmoothPlastic)
		m.PrimaryPart = hull
		part(m, "Fender", Vector3.new(9.6, 1.4, 20.6), rel(0, water + 2.4, 0), rgb(30, 30, 32), Enum.Material.Fabric)
		part(m, "House", Vector3.new(6.5, 5, 7), rel(0, water + 5.5, 2), WHITE, Enum.Material.SmoothPlastic)
		part(m, "HouseGlass", Vector3.new(6.7, 1.4, 7.2), rel(0, water + 6.8, 2), rgb(40, 60, 80), Enum.Material.Glass)
		cylinder(m, "Funnel", 5, 2.4, 0, 0, 0, rgb(250, 200, 60), Enum.Material.Metal).CFrame = rel(0, water + 9, -3) * CFrame.Angles(0, 0, math.rad(90))
	elseif kind == "cargo" then
		local hull = part(m, "Hull", Vector3.new(26, 10, 110), rel(0, water + 2, 0), rgb(40, 70, 120), Enum.Material.Metal)
		m.PrimaryPart = hull
		wedge(m, "Bow", Vector3.new(26, 10, 20), rel(0, water + 2, 65) * CFrame.Angles(0, 0, math.pi), rgb(40, 70, 120), Enum.Material.Metal)
		part(m, "Waterline", Vector3.new(26.2, 2, 110.2), rel(0, water - 2, 0), rgb(170, 50, 45), Enum.Material.Metal)
		part(m, "Deck", Vector3.new(25, 0.6, 108), rel(0, water + 7.2, 0), rgb(150, 50, 45), Enum.Material.Metal)
		part(m, "Superstructure", Vector3.new(22, 16, 12), rel(0, water + 15.4, -44), WHITE, Enum.Material.Metal)
		part(m, "BridgeWindows", Vector3.new(22.2, 2, 12.2), rel(0, water + 21, -44), rgb(40, 60, 80), Enum.Material.Glass)
		cylinder(m, "Stack", 8, 4, 0, 0, 0, rgb(250, 200, 60), Enum.Material.Metal).CFrame = rel(0, water + 27, -48) * CFrame.Angles(0, 0, math.rad(90))
		local colors = { rgb(220, 70, 60), rgb(60, 130, 220), rgb(250, 190, 50), rgb(90, 180, 110), rgb(240, 130, 50) }
		for row = 0, 5 do
			for col = -1, 1 do
				for layer = 0, (row + col) % 2 do
					part(m, "Container", Vector3.new(7.6, 7.6, 15.6), rel(col * 8, water + 11.4 + layer * 7.8, -24 + row * 16), colors[(row * 3 + col + layer) % #colors + 1], Enum.Material.Metal)
				end
			end
		end
	end
end

local function airliner(parent: Instance, x: number, z: number, heading: Vector3, livery: Color3)
	local m = model(parent, "Plane")
	m:SetAttribute("Vehicle", "plane")
	local rel = frame(x, z, heading)
	local y = 7
	local body = tube(m, "Fuselage", 56, 7, rel(0, y, 0), WHITE, Enum.Material.SmoothPlastic)
	m.PrimaryPart = body
	ball(m, "Nose", 7, 0, 0, 0, WHITE).CFrame = rel(0, y, 28)
	part(m, "Cockpit", Vector3.new(4.4, 1.2, 1.4), rel(0, y + 1.6, 30.4) * CFrame.Angles(math.rad(25), 0, 0), rgb(40, 60, 80), Enum.Material.Glass)
	wedge(m, "TailCone", Vector3.new(6.8, 6.8, 10), rel(0, y + 0.1, -33) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, math.pi), WHITE)
	part(m, "Windows", Vector3.new(7.1, 0.8, 46), rel(0, y + 1.3, 1), rgb(40, 60, 80), Enum.Material.Glass)
	part(m, "Cheatline", Vector3.new(7.1, 0.9, 56), rel(0, y - 0.3, 0), livery, Enum.Material.SmoothPlastic)
	for _, side in { -1, 1 } do
		part(m, "Wing", Vector3.new(30, 1, 10), rel(side * 17, y - 1.6, -1) * CFrame.Angles(0, side * math.rad(-18), 0), rgb(220, 222, 228), Enum.Material.SmoothPlastic)
		part(m, "Winglet", Vector3.new(0.6, 4, 3), rel(side * 31.5, y + 0.4, -6), livery, Enum.Material.SmoothPlastic)
		tube(m, "Engine", 7, 3.6, rel(side * 11, y - 3.6, 2), rgb(200, 202, 208), Enum.Material.Metal)
		part(m, "Stabilizer", Vector3.new(12, 0.6, 5), rel(side * 7, y + 1, -29) * CFrame.Angles(0, side * math.rad(-15), 0), rgb(220, 222, 228))
		local gear = part(m, "Gear", Vector3.new(1, 2.2, 2.2), rel(side * 3, 1.1, -2), rgb(30, 30, 32))
		gear.Shape = Enum.PartType.Cylinder
	end
	part(m, "Fin", Vector3.new(0.8, 11, 9), rel(0, y + 8, -29) * CFrame.Angles(math.rad(20), 0, 0), livery, Enum.Material.SmoothPlastic)
	local noseGear = part(m, "Gear", Vector3.new(1, 2, 2), rel(0, 1, 22), rgb(30, 30, 32))
	noseGear.Shape = Enum.PartType.Cylinder
end

local function propPlane(parent: Instance, x: number, z: number, heading: Vector3, color: Color3)
	local m = model(parent, "Plane")
	m:SetAttribute("Vehicle", "propplane")
	local rel = frame(x, z, heading)
	local y = 3.2
	local body = part(m, "Fuselage", Vector3.new(3.4, 3.4, 16), rel(0, y, 0), color, Enum.Material.SmoothPlastic)
	m.PrimaryPart = body
	part(m, "Canopy", Vector3.new(3, 1.6, 4), rel(0, y + 2.2, 2), rgb(60, 90, 120), Enum.Material.Glass)
	part(m, "Wing", Vector3.new(26, 0.5, 4.5), rel(0, y + 1.6, 2), WHITE, Enum.Material.SmoothPlastic)
	part(m, "Tailplane", Vector3.new(9, 0.4, 2.6), rel(0, y + 0.6, -7), WHITE)
	part(m, "Fin", Vector3.new(0.4, 4, 3), rel(0, y + 2.6, -7), color)
	cylinder(m, "Spinner", 1.4, 1.4, 0, 0, 0, rgb(240, 240, 240)).CFrame = rel(0, y, 8.6) * CFrame.Angles(0, math.rad(90), 0)
	part(m, "Propeller", Vector3.new(7, 0.6, 0.2), rel(0, y, 9.2), rgb(40, 40, 45), Enum.Material.Metal)
	for _, u in { -2, 2 } do
		local wheel = part(m, "Wheel", Vector3.new(0.6, 1.6, 1.6), rel(u, 0.8, 3), rgb(30, 30, 32))
		wheel.Shape = Enum.PartType.Cylinder
	end
end

local function helicopter(parent: Instance, x: number, z: number, heading: Vector3, color: Color3, y0: number?)
	local m = model(parent, "Helicopter")
	m:SetAttribute("Vehicle", "helicopter")
	local rel = frame(x, z, heading)
	local y = (y0 or 0) + 4
	local body = ball(m, "Cabin", 7, 0, 0, 0, color, Enum.Material.SmoothPlastic)
	body.CFrame = rel(0, y, 1)
	m.PrimaryPart = body
	ball(m, "Bubble", 5, 0, 0, 0, rgb(60, 90, 120), Enum.Material.Glass).CFrame = rel(0, y + 0.6, 3)
	part(m, "Boom", Vector3.new(1, 1, 11), rel(0, y + 0.8, -6), color)
	part(m, "TailFin", Vector3.new(0.3, 3, 2), rel(0, y + 2, -11.3), color)
	part(m, "Rotor", Vector3.new(0.8, 0.2, 22), rel(0, y + 4.2, 1), rgb(40, 40, 45), Enum.Material.Metal)
	part(m, "Rotor", Vector3.new(22, 0.2, 0.8), rel(0, y + 4.2, 1), rgb(40, 40, 45), Enum.Material.Metal)
	cylinder(m, "Mast", 1.4, 0.6, 0, 0, 0, rgb(60, 60, 65)).CFrame = rel(0, y + 3.5, 1) * CFrame.Angles(0, 0, math.rad(90))
	for _, u in { -2.4, 2.4 } do
		part(m, "Skid", Vector3.new(0.4, 0.4, 8), rel(u, (y0 or 0) + 0.3, 1), rgb(60, 60, 65), Enum.Material.Metal)
		part(m, "Strut", Vector3.new(0.3, 1.6, 0.3), rel(u, (y0 or 0) + 1.1, 1), rgb(60, 60, 65), Enum.Material.Metal)
	end
end

----------------------------------------------------------------------------------------------
-- buildings


local function skyscraper(parent: Instance, x: number, z: number, w: number, d: number, height: number, seed: number)
	local m = model(parent, "Tower")
	local tint = GLASS_TINTS[seed % #GLASS_TINTS + 1]
	local stone = STONE[(seed * 3) % #STONE + 1]
	-- podium with lobby glass and an entrance canopy
	box(m, "Podium", x, CURB, z, w, 10, d, stone, Enum.Material.Concrete)
	box(m, "LobbyGlass", x, CURB + 1, z, w + 0.2, 6, d - 6, rgb(60, 90, 110), Enum.Material.Glass)
	box(m, "LobbyGlass", x, CURB + 1, z, w - 6, 6, d + 0.2, rgb(60, 90, 110), Enum.Material.Glass)
	box(m, "Canopy", x, CURB + 7.5, z - d / 2 - 2, 14, 0.6, 5, stone, Enum.Material.Concrete)
	-- tower, optionally with a setback for the top third
	local sections = if height > 90 then { { w - 4, d - 4, height * 0.66 }, { w - 12, d - 12, height * 0.34 } } else { { w - 4, d - 4, height } }
	local y = CURB + 10
	for si, sec in sections do
		local sw, sd, sh = sec[1], sec[2], sec[3]
		box(m, "Glass", x, y, z, sw, sh, sd, tint, Enum.Material.Glass)
		local floors = math.floor(sh / 6)
		for f = 1, floors do
			box(m, "FloorBand", x, y + f * 6 - 0.6, z, sw + 0.6, 0.7, sd + 0.6, stone, Enum.Material.Concrete)
		end
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			box(m, "Fin", x + c[1] * (sw / 2), y, z + c[2] * (sd / 2), 1.4, sh, 1.4, stone, Enum.Material.Concrete)
		end
		for _, u in { -1, 1 } do
			box(m, "Mullion", x + u * sw / 6, y, z - sd / 2, 0.5, sh, 0.5, stone, Enum.Material.Concrete)
			box(m, "Mullion", x + u * sw / 6, y, z + sd / 2, 0.5, sh, 0.5, stone, Enum.Material.Concrete)
		end
		y += sh
		if si < #sections then
			box(m, "Setback", x, y - 0.6, z, sw + 1, 1.2, sd + 1, stone, Enum.Material.Concrete)
		end
	end
	-- roof: parapet, plant, and either an antenna or a helipad
	local top = sections[#sections]
	box(m, "Parapet", x, y, z, top[1] + 1, 1.6, top[2] + 1, stone, Enum.Material.Concrete)
	box(m, "RoofPlant", x - top[1] / 5, y + 1.6, z, 6, 3, 5, rgb(150, 150, 155), Enum.Material.Metal)
	box(m, "RoofPlant", x + top[1] / 5, y + 1.6, z + 2, 4, 2.4, 4, rgb(150, 150, 155), Enum.Material.Metal)
	if seed % 3 == 0 and top[1] >= 22 then
		cylinder(m, "Helipad", 0.6, math.min(top[1], top[2]) - 4, x, y + 1.9, z, rgb(70, 72, 80), Enum.Material.Concrete)
		for _, u in { -2.5, 2.5 } do
			box(m, "HelipadH", x + u, y + 2.2, z, 1, 0.1, 8, WHITE)
		end
		box(m, "HelipadH", x, y + 2.2, z, 5, 0.1, 1, WHITE)
		if seed % 2 == 0 then
			helicopter(m, x, z, Vector3.new(0, 0, 1), rgb(220, 60, 60), y + 2.2)
		end
	else
		cylinder(m, "Antenna", 22, 0.8, x, y + 1.6 + 11, z, rgb(200, 200, 205), Enum.Material.Metal)
		ball(m, "AntennaLight", 1.4, x, y + 23.6, z, rgb(255, 50, 50), Enum.Material.Neon)
	end
	-- a vertical neon sign on some towers
	if seed % 4 == 1 then
		local signPart = deco(box(m, "NeonSign", x + w / 2 + 0.8, CURB + 16, z, 1.2, 26, 5, rgb(30, 30, 40), Enum.Material.SmoothPlastic))
		sign(signPart, if seed % 8 == 1 then "HOTEL" else "SPROUT CO", rgb(255, 120, 200), Enum.NormalId.Right)
		sign(signPart, if seed % 8 == 1 then "HOTEL" else "SPROUT CO", rgb(255, 120, 200), Enum.NormalId.Left)
	end
end

local function apartment(parent: Instance, x: number, z: number, w: number, d: number, floors: number, facing: Vector3, seed: number)
	local m = model(parent, "Apartment")
	local rel = frame(x, z, facing)
	local walls = { rgb(190, 100, 80), rgb(225, 200, 160), rgb(160, 175, 190), rgb(220, 160, 120), rgb(200, 210, 190) }
	local wall = walls[seed % #walls + 1]
	local trim = rgb(240, 238, 230)
	local h = floors * 7 + 2
	part(m, "Walls", Vector3.new(w, h, d), rel(0, CURB + h / 2, 0), wall, Enum.Material.Brick)
	for f = 0, floors - 1 do
		local fy = CURB + 2 + f * 7 + 3.5
		part(m, "WindowBand", Vector3.new(w - 4, 3.4, 0.3), rel(0, fy, d / 2 + 0.1), rgb(60, 85, 110), Enum.Material.Glass)
		part(m, "WindowBand", Vector3.new(w - 4, 3.4, 0.3), rel(0, fy, -d / 2 - 0.1), rgb(60, 85, 110), Enum.Material.Glass)
		part(m, "WindowBand", Vector3.new(0.3, 3.4, d - 4), rel(w / 2 + 0.1, fy, 0), rgb(60, 85, 110), Enum.Material.Glass)
		part(m, "WindowBand", Vector3.new(0.3, 3.4, d - 4), rel(-w / 2 - 0.1, fy, 0), rgb(60, 85, 110), Enum.Material.Glass)
		if f > 0 then
			part(m, "Ledge", Vector3.new(w + 0.6, 0.5, d + 0.6), rel(0, CURB + 2 + f * 7, 0), trim, Enum.Material.Concrete)
			if f % 2 == 1 then
				for _, u in { -w / 4, w / 4 } do
					part(m, "Balcony", Vector3.new(6, 0.5, 2.6), rel(u, fy - 1.8, d / 2 + 1.3), trim, Enum.Material.Concrete)
					part(m, "BalconyRail", Vector3.new(6, 1.6, 0.2), rel(u, fy - 0.8, d / 2 + 2.5), rgb(60, 62, 70), Enum.Material.Metal)
				end
			end
		end
	end
	part(m, "Door", Vector3.new(4, 5.5, 0.3), rel(0, CURB + 2.75, d / 2 + 0.2), rgb(90, 60, 45), Enum.Material.WoodPlanks)
	part(m, "Awning", Vector3.new(7, 0.4, 3), rel(0, CURB + 6.2, d / 2 + 1.5), rgb(40, 90, 70), Enum.Material.Fabric)
	part(m, "Cornice", Vector3.new(w + 1.2, 1.2, d + 1.2), rel(0, CURB + h + 0.6, 0), trim, Enum.Material.Concrete)
	-- a classic rooftop water tank
	if seed % 2 == 0 then
		local tx, tz = (rel(w / 4, 0, -d / 5)).Position.X, (rel(w / 4, 0, -d / 5)).Position.Z
		for _, c in { { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } } do
			box(m, "TankLeg", tx + c[1], CURB + h + 1.2, tz + c[2], 0.4, 3, 0.4, rgb(80, 70, 60), Enum.Material.Wood)
		end
		cylinder(m, "Tank", 5, 5, tx, CURB + h + 6.7, tz, rgb(150, 110, 75), Enum.Material.WoodPlanks)
		cylinder(m, "TankLid", 0.6, 5.4, tx, CURB + h + 9.5, tz, rgb(110, 85, 60), Enum.Material.Wood)
	end
end


-- Two-storey shop. `id` is the Shop attribute later gameplay uses to find it.
local function shop(parent: Instance, x: number, z: number, w: number, facing: Vector3, name: string, id: string, seed: number)
	local m = model(parent, "Shop")
	m:SetAttribute("Shop", id)
	local style = SHOP_STYLES[seed % #SHOP_STYLES + 1]
	local rel = frame(x, z, facing)
	local d = 18
	part(m, "Walls", Vector3.new(w, 17, d), rel(0, CURB + 8.5, 0), style.wall, Enum.Material.Plaster)
	part(m, "Storefront", Vector3.new(w - 4, 7, 0.3), rel(0, CURB + 4.5, d / 2 + 0.1), rgb(170, 215, 240), Enum.Material.Glass, { Transparency = 0.2 })
	part(m, "Door", Vector3.new(4, 7, 0.4), rel(0, CURB + 3.5, d / 2 + 0.25), rgb(60, 62, 70), Enum.Material.Glass)
	part(m, "Frame", Vector3.new(w - 3, 0.8, 0.5), rel(0, CURB + 8.2, d / 2 + 0.2), style.accent, Enum.Material.SmoothPlastic)
	local stripes = math.max(4, math.floor(w / 4))
	for i = 1, stripes do
		local u = -w / 2 + 1 + (i - 0.5) * ((w - 2) / stripes)
		part(m, "Awning", Vector3.new((w - 2) / stripes, 0.4, 4.4), rel(u, CURB + 9.2, d / 2 + 2) * CFrame.Angles(math.rad(-16), 0, 0), if i % 2 == 0 then WHITE else style.accent, Enum.Material.Fabric)
	end
	local board = part(m, "SignBoard", Vector3.new(w - 6, 3.2, 0.5), rel(0, CURB + 12.4, d / 2 + 0.3), style.accent, Enum.Material.SmoothPlastic)
	sign(board, name, WHITE)
	for _, u in { -w / 3, 0, w / 3 } do
		part(m, "UpperWindow", Vector3.new(3.4, 3.4, 0.3), rel(u, CURB + 13, d / 2 + 0.1), rgb(70, 95, 120), Enum.Material.Glass).CFrame = rel(u, CURB + 14, d / 2 + 0.1)
	end
	part(m, "Cornice", Vector3.new(w + 1, 1, d + 1), rel(0, CURB + 17.5, 0), style.accent, Enum.Material.SmoothPlastic)
	-- where the shop's prompt/counter will go (invisible marker for the shop system)
	local anchor = part(m, "ShopAnchor", Vector3.new(4, 4, 4), rel(0, CURB + 2.5, d / 2 + 4), WHITE, nil, { Transparency = 1, CanCollide = false })
	anchor:SetAttribute("Shop", id)
	-- window display: a few coloured boxes behind the glass
	for i = 1, 3 do
		part(m, "Display", Vector3.new(2, 2, 2), rel(-w / 2 + 3 + i * 2.6, CURB + 1.6, d / 2 - 1.5), Color3.new(style.accent.R + (1 - style.accent.R) * i * 0.2, style.accent.G + (1 - style.accent.G) * i * 0.2, style.accent.B + (1 - style.accent.B) * i * 0.2), Enum.Material.SmoothPlastic)
	end
	return m
end

local function house(parent: Instance, x: number, z: number, facing: Vector3, seed: number)
	local m = model(parent, "House")
	local rel = frame(x, z, facing)
	local walls = { rgb(245, 240, 230), rgb(210, 230, 245), rgb(250, 230, 200), rgb(225, 245, 220), rgb(245, 215, 215) }
	local roofs = { rgb(70, 75, 90), rgb(160, 70, 60), rgb(80, 110, 160), rgb(110, 90, 80) }
	local wall = walls[seed % #walls + 1]
	local roof = roofs[(seed * 7) % #roofs + 1]
	local W, D, H, rise = 16, 13, 9, 5
	part(m, "Walls", Vector3.new(W, H, D), rel(0, CURB + H / 2, 0), wall, Enum.Material.WoodPlanks)
	local attic = math.sqrt(2) * rise
	part(m, "Attic", Vector3.new(W - 0.2, attic, attic), rel(0, CURB + H, 0) * CFrame.Angles(math.rad(45), 0, 0), wall, Enum.Material.WoodPlanks)
	local slope = math.atan(rise / (D / 2))
	local len = math.sqrt(rise * rise + (D / 2) ^ 2) + 1.5
	for _, side in { 1, -1 } do
		part(m, "Roof", Vector3.new(W + 1.6, 0.7, len), rel(0, CURB + H + rise / 2 + 0.3, side * D / 4) * CFrame.Angles(-side * slope, 0, 0), roof, Enum.Material.Slate)
	end
	part(m, "Door", Vector3.new(3, 6, 0.3), rel(-3, CURB + 3, D / 2 + 0.15), rgb(120, 70, 50), Enum.Material.WoodPlanks)
	part(m, "Porch", Vector3.new(6, 0.5, 3), rel(-3, CURB + 0.25, D / 2 + 1.5), rgb(190, 185, 180), Enum.Material.Concrete)
	for _, u in { 2.5, 6 } do
		part(m, "Window", Vector3.new(2.6, 2.8, 0.3), rel(u, CURB + 5, D / 2 + 0.15), rgb(90, 130, 170), Enum.Material.Glass)
		part(m, "Shutter", Vector3.new(0.8, 2.8, 0.2), rel(u - 1.8, CURB + 5, D / 2 + 0.2), roof, Enum.Material.WoodPlanks)
	end
	-- garage and driveway on the left
	part(m, "Garage", Vector3.new(9, 7, 11), rel(-W / 2 - 4.5, CURB + 3.5, -1), wall, Enum.Material.WoodPlanks)
	part(m, "GarageRoof", Vector3.new(9.6, 0.6, 11.6), rel(-W / 2 - 4.5, CURB + 7.3, -1), roof, Enum.Material.Slate)
	part(m, "GarageDoor", Vector3.new(7, 5.5, 0.3), rel(-W / 2 - 4.5, CURB + 2.75, 4.6), rgb(235, 235, 230), Enum.Material.DiamondPlate)
	part(m, "Driveway", Vector3.new(8, 0.2, 10), rel(-W / 2 - 4.5, CURB + 0.1, 9.5), rgb(175, 172, 168), Enum.Material.Concrete)
	-- lawn, picket fence and mailbox
	part(m, "Lawn", Vector3.new(W + 2, 0.2, 9), rel(1, CURB + 0.1, D / 2 + 5.5), rgb(110, 185, 85), Enum.Material.Grass)
	part(m, "FenceRail", Vector3.new(W, 0.3, 0.2), rel(1, CURB + 2, D / 2 + 10), WHITE, Enum.Material.WoodPlanks)
	for k = 0, 6 do
		part(m, "Picket", Vector3.new(0.4, 2.6, 0.3), rel(-W / 2 + 2 + k * (W / 6), CURB + 1.3, D / 2 + 10), WHITE, Enum.Material.WoodPlanks)
	end
	part(m, "MailboxPost", Vector3.new(0.4, 3.6, 0.4), rel(-W / 2 + 0.5, CURB + 1.8, D / 2 + 10.5), rgb(110, 80, 55), Enum.Material.Wood)
	part(m, "Mailbox", Vector3.new(1, 1, 1.8), rel(-W / 2 + 0.5, CURB + 3.9, D / 2 + 10.5), rgb(60, 90, 160), Enum.Material.Metal)
	if seed % 2 == 0 then
		car(m, (rel(-W / 2 - 4.5, 0, 9)).Position.X, (rel(-W / 2 - 4.5, 0, 9)).Position.Z, facing, CAR_COLORS[seed % #CAR_COLORS + 1])
		for _, p in m:GetChildren() do
			if p:IsA("Model") and p.Name == "Car" then
				for _, q in p:GetDescendants() do
					if q:IsA("BasePart") then
						q.CFrame = q.CFrame + Vector3.new(0, CURB, 0)
					end
				end
			end
		end
	end
end

-- Civic building with columns and a pediment-ish roof (City Hall, Museum).
local function civic(parent: Instance, x: number, z: number, w: number, d: number, facing: Vector3, name: string, color: Color3)
	local m = model(parent, name)
	local rel = frame(x, z, facing)
	local stone = rgb(240, 236, 226)
	part(m, "Steps", Vector3.new(w * 0.7, 2, 6), rel(0, CURB + 1, d / 2 + 3), stone, Enum.Material.Marble)
	part(m, "Base", Vector3.new(w, 2.4, d), rel(0, CURB + 1.2, 0), stone, Enum.Material.Marble)
	part(m, "Hall", Vector3.new(w - 6, 22, d - 8), rel(0, CURB + 13.4, -2), color, Enum.Material.Concrete)
	local cols = 8
	for i = 0, cols - 1 do
		local u = -w / 2 + 4 + i * (w - 8) / (cols - 1)
		cylinder(m, "Column", 20, 2.2, 0, 0, 0, stone, Enum.Material.Marble).CFrame = rel(u, CURB + 12.4, d / 2 - 2) * CFrame.Angles(0, 0, math.rad(90))
	end
	part(m, "Entablature", Vector3.new(w, 3, d), rel(0, CURB + 24, 0), stone, Enum.Material.Marble)
	local attic = math.sqrt(2) * 5
	part(m, "Pediment", Vector3.new(attic, attic, w - 1), rel(0, CURB + 27.5, d / 2 - 3) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(45)), stone, Enum.Material.Marble)
	cylinder(m, "Drum", 6, 16, 0, 0, 0, stone, Enum.Material.Marble).CFrame = rel(0, CURB + 28.5, -4) * CFrame.Angles(0, 0, math.rad(90))
	ball(m, "Dome", 16, 0, 0, 0, color, Enum.Material.Metal).CFrame = rel(0, CURB + 31.5, -4)
	local plaque = part(m, "Plaque", Vector3.new(w * 0.5, 2.4, 0.4), rel(0, CURB + 24, d / 2 + 0.3), rgb(40, 50, 70), Enum.Material.SmoothPlastic)
	sign(plaque, name, rgb(255, 225, 140))
	cylinder(m, "FlagPole", 16, 0.4, 0, 0, 0, rgb(200, 200, 205), Enum.Material.Metal).CFrame = rel(w / 2 - 2, CURB + 8, d / 2 + 4) * CFrame.Angles(0, 0, math.rad(90))
	part(m, "Flag", Vector3.new(5, 3, 0.15), rel(w / 2 + 0.6, CURB + 14.5, d / 2 + 4), rgb(90, 190, 110), Enum.Material.Fabric)
end

-- Service building (fire station, police, hospital): box, big doors, sign, roof light.
local function service(parent: Instance, x: number, z: number, w: number, d: number, facing: Vector3, name: string, color: Color3, doors: number)
	local m = model(parent, name)
	local rel = frame(x, z, facing)
	part(m, "Walls", Vector3.new(w, 16, d), rel(0, CURB + 8, 0), rgb(235, 232, 225), Enum.Material.Brick)
	part(m, "Band", Vector3.new(w + 0.4, 3, d + 0.4), rel(0, CURB + 14, 0), color, Enum.Material.SmoothPlastic)
	for i = 0, doors - 1 do
		local u = -w / 2 + (i + 0.5) * (w / doors)
		part(m, "BayDoor", Vector3.new(w / doors - 3, 9, 0.3), rel(u, CURB + 4.5, d / 2 + 0.15), rgb(200, 205, 215), Enum.Material.DiamondPlate)
	end
	local board = part(m, "SignBoard", Vector3.new(w * 0.7, 2.6, 0.4), rel(0, CURB + 14, d / 2 + 0.4), color, Enum.Material.SmoothPlastic)
	sign(board, name, WHITE)
	part(m, "Roof", Vector3.new(w + 1, 1, d + 1), rel(0, CURB + 16.5, 0), rgb(110, 110, 115), Enum.Material.Concrete)
	ball(m, "RoofBeacon", 1.6, 0, 0, 0, color, Enum.Material.Neon).CFrame = rel(w / 2 - 3, CURB + 18, 0)
end

----------------------------------------------------------------------------------------------
-- streets

local function buildStreets(city: Instance)
	local streets = folder(city, "Streets")
	local w, d = CITY.x1 - CITY.x0, CITY.z1 - CITY.z0
	local cx, cz = (CITY.x0 + CITY.x1) / 2, (CITY.z0 + CITY.z1) / 2
	box(streets, "Asphalt", cx, -1, cz, w, 1, d, ASPHALT, Enum.Material.Asphalt)
	-- sea wall round the city edge
	for _, e in { { cx, CITY.z0, w + 2, 2 }, { cx, CITY.z1, w + 2, 2 }, { CITY.x0, cz, 2, d }, { CITY.x1, cz, 2, d } } do
		box(streets, "SeaWall", e[1], -10, e[2], e[3], 10.8, e[4], rgb(170, 165, 158), Enum.Material.Cobblestone)
	end

	-- lane markings
	local marks = folder(streets, "Markings")
	for _, a in AVENUES do
		for si = 1, #STREETS - 1 do
			local z0, z1 = STREETS[si].z + STREETS[si].w / 2, STREETS[si + 1].z - STREETS[si + 1].w / 2
			local len = z1 - z0
			if a.w > 30 then
				for _, off in { -0.5, 0.5 } do
					box(marks, "CenterLine", a.x + off, 0, (z0 + z1) / 2, 0.4, 0.06, len - 4, YELLOW)
				end
				for _, lane in { -11, 11 } do
					for k = 0, math.floor(len / 14) - 1 do
						box(marks, "LaneDash", a.x + lane, 0, z0 + 7 + k * 14, 0.4, 0.06, 6, WHITE)
					end
				end
			else
				for k = 0, math.floor(len / 14) - 1 do
					box(marks, "LaneDash", a.x, 0, z0 + 7 + k * 14, 0.4, 0.06, 6, WHITE)
				end
			end
		end
	end
	for _, s in STREETS do
		local xs = { CITY.x0 }
		for _, a in AVENUES do
			table.insert(xs, a.x - a.w / 2)
			table.insert(xs, a.x + a.w / 2)
		end
		table.insert(xs, CITY.x1)
		for k = 1, #xs - 1, 2 do
			local x0, x1 = xs[k], xs[k + 1]
			for j = 0, math.floor((x1 - x0) / 14) - 1 do
				box(marks, "LaneDash", x0 + 7 + j * 14, 0, s.z, 6, 0.06, 0.4, WHITE)
			end
		end
	end
	-- zebra crossings and signals at every main-avenue junction
	local main = AVENUES[3]
	for _, s in STREETS do
		for _, sgn in { -1, 1 } do
			for k = -4, 4 do
				box(marks, "Zebra", main.x + k * 4.4, 0, s.z + sgn * (s.w / 2 + 3), 2.2, 0.06, 5, WHITE)
			end
			for k = -2, 2 do
				box(marks, "Zebra", main.x + sgn * (main.w / 2 + 3), 0, s.z + k * 4.8, 5, 0.06, 2.4, WHITE)
			end
		end
		trafficLight(streets, main.x - main.w / 2 - 2, s.z - s.w / 2 - 2, Vector3.new(1, 0, 0))
		trafficLight(streets, main.x + main.w / 2 + 2, s.z + s.w / 2 + 2, Vector3.new(-1, 0, 0))
	end
end

----------------------------------------------------------------------------------------------
-- blocks

local MARKET = {
	{ "Pet Shop", "pets" }, { "Tool Shop", "tools" }, { "Ability Dojo", "abilities" }, { "Vehicle Dealer", "vehicles" },
	{ "Cafe Sprout", "cafe" }, { "City Bank", "bank" }, { "Gear & Blasters", "weapons" }, { "Toy Box", "toys" },
	{ "Arcade", "arcade" }, { "Ice Cream", "icecream" }, { "Boutique", "clothes" }, { "Bakery", "bakery" },
}

local function furnish(blockFolder: Instance, b: { number }, seed: number)
	local x0, x1, z0, z1 = b[1], b[2], b[3], b[4]
	-- corner streetlights, trees along the curb, a bench, bin and hydrant
	for _, c in { { x0 + 1.5, z0 + 1.5, -1, -1 }, { x1 - 1.5, z0 + 1.5, 1, -1 }, { x0 + 1.5, z1 - 1.5, -1, 1 }, { x1 - 1.5, z1 - 1.5, 1, 1 } } do
		streetlight(blockFolder, c[1], c[2], Vector3.new(c[3], 0, 0))
	end
	local w = x1 - x0
	for k = 1, math.max(1, math.floor(w / 30)) do
		local x = x0 + k * w / (math.floor(w / 30) + 1)
		cityTree(blockFolder, x, z0 + 2.5, seed * 7 + k)
		cityTree(blockFolder, x, z1 - 2.5, seed * 11 + k)
	end
	bench(blockFolder, x0 + w * 0.5 + 5, z0 + 2.2, Vector3.new(0, 0, -1))
	trashBin(blockFolder, x0 + w * 0.5 - 4, z0 + 2)
	hydrant(blockFolder, x1 - 6, z1 - 2)
end

local function marketBlock(f: Instance, b: { number }, index: number)
	local x0, x1, z0, z1 = b[1], b[2], b[3], b[4]
	local w = x1 - x0
	local inner = w - 2 * SIDEWALK
	local count = if inner > 80 then 3 else 2
	local shopW = inner / count - 2
	for k = 1, count do
		local n = (index - 1) * 2 + k
		local entry = MARKET[(n - 1) % #MARKET + 1]
		local x = x0 + SIDEWALK + (k - 0.5) * (inner / count)
		shop(f, x, z0 + SIDEWALK + 9, shopW, Vector3.new(0, 0, -1), entry[1], entry[2], n)
		shop(f, x, z1 - SIDEWALK - 9, shopW, Vector3.new(0, 0, 1), MARKET[(n + 5) % #MARKET + 1][1], MARKET[(n + 5) % #MARKET + 1][2] .. "2", n + 3)
	end
end

local function downtownBlock(f: Instance, b: { number }, seed: number)
	local x0, x1, z0, z1 = b[1], b[2], b[3], b[4]
	local cx = (x0 + x1) / 2
	local inner = x1 - x0 - 2 * SIDEWALK
	local depth = z1 - z0 - 2 * SIDEWALK
	local tw = inner / 2 - 4
	for k, side in { -1, 1 } do
		local h = 70 + math.floor(hash(seed * 5 + k) * 120)
		skyscraper(f, cx + side * (tw / 2 + 2), (z0 + z1) / 2, tw, math.min(depth - 4, 34), h, seed * 2 + k)
	end
	-- plaza strip between the towers
	box(f, "Plaza", cx, CURB, (z0 + z1) / 2, 6, 0.1, depth, rgb(220, 205, 180), Enum.Material.Slate)
end

local function apartmentBlock(f: Instance, b: { number }, seed: number)
	local x0, x1, z0, z1 = b[1], b[2], b[3], b[4]
	local inner = x1 - x0 - 2 * SIDEWALK
	local count = if inner > 80 then 3 else 2
	local aw = inner / count - 3
	for k = 1, count do
		local x = x0 + SIDEWALK + (k - 0.5) * (inner / count)
		apartment(f, x, z0 + SIDEWALK + 11, aw, 18, 4 + (seed + k) % 5, Vector3.new(0, 0, -1), seed + k)
		apartment(f, x, z1 - SIDEWALK - 11, aw, 18, 3 + (seed * 2 + k) % 5, Vector3.new(0, 0, 1), seed + k + 7)
	end
end

local function houseBlock(f: Instance, b: { number }, seed: number)
	local x0, x1, z0, z1 = b[1], b[2], b[3], b[4]
	local inner = x1 - x0 - 2 * SIDEWALK
	local count = math.max(2, math.floor(inner / 34))
	for k = 1, count do
		local x = x0 + SIDEWALK + (k - 0.5) * (inner / count) + 4
		house(f, x, z0 + SIDEWALK + 18, Vector3.new(0, 0, -1), seed * 3 + k)
		house(f, x, z1 - SIDEWALK - 18, Vector3.new(0, 0, 1), seed * 5 + k)
	end
	-- back gardens between the two rows
	box(f, "Gardens", (x0 + x1) / 2, CURB, (z0 + z1) / 2, inner, 0.15, 14, rgb(110, 185, 85), Enum.Material.Grass)
end

local function park(f: Instance, x0: number, x1: number, z0: number, z1: number)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local w, d = x1 - x0 - 2 * SIDEWALK, z1 - z0 - 2 * SIDEWALK
	box(f, "Lawn", cx, CURB, cz, w, 0.2, d, rgb(110, 190, 85), Enum.Material.Grass)
	box(f, "Path", cx, CURB, cz, 6, 0.3, d, rgb(220, 205, 175), Enum.Material.Slate)
	box(f, "Path", cx, CURB, cz, w, 0.3, 6, rgb(220, 205, 175), Enum.Material.Slate)
	-- pond with a fountain jet
	local px, pz = cx - w / 4, cz - d / 4
	cylinder(f, "PondRim", 1, 30, px, CURB + 0.5, pz, rgb(190, 185, 175), Enum.Material.Cobblestone)
	cylinder(f, "PondWater", 1, 27, px, CURB + 0.6, pz, rgb(80, 170, 220), Enum.Material.Glass).Transparency = 0.2
	cylinder(f, "Jet", 6, 1.2, px, CURB + 3.5, pz, rgb(220, 245, 255), Enum.Material.Neon).Transparency = 0.4
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		local lily = cylinder(f, "Lily", 0.2, 3, px + math.cos(a) * 8, CURB + 1.15, pz + math.sin(a) * 8, rgb(90, 170, 80), Enum.Material.Grass)
		lily.CanCollide = false
	end
	-- bandstand
	local bx, bz = cx + w / 4, cz - d / 4
	cylinder(f, "Bandstand", 1.4, 18, bx, CURB + 0.7, bz, WHITE, Enum.Material.Marble)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		cylinder(f, "BandPillar", 9, 0.8, bx + math.cos(a) * 8, CURB + 5.5, bz + math.sin(a) * 8, WHITE, Enum.Material.Marble)
	end
	for i, dd in { 20, 15, 10, 5 } do
		cylinder(f, "BandRoof", 1.2, dd, bx, CURB + 10 + i * 1.1, bz, rgb(90, 160, 110), Enum.Material.Slate)
	end
	-- playground
	local gx, gz = cx - w / 4, cz + d / 4
	box(f, "PlayMat", gx, CURB, gz, 26, 0.3, 22, rgb(240, 130, 60), Enum.Material.Fabric)
	box(f, "SlideTower", gx - 6, CURB, gz, 4, 6, 4, rgb(70, 140, 220), Enum.Material.Plastic)
	wedge(f, "Slide", Vector3.new(2.6, 6, 9), CFrame.new(gx - 6, CURB + 3, gz + 6.5), rgb(250, 200, 50), Enum.Material.Plastic)
	box(f, "SwingBar", gx + 6, CURB + 8, gz, 10, 0.6, 0.6, rgb(220, 60, 60), Enum.Material.Metal)
	for _, u in { -4.8, 4.8 } do
		box(f, "SwingLeg", gx + 6 + u, CURB, gz, 0.6, 8.3, 0.6, rgb(220, 60, 60), Enum.Material.Metal)
	end
	for _, u in { -2, 2 } do
		box(f, "SwingRope", gx + 6 + u, CURB + 2.6, gz, 0.15, 5.4, 0.15, rgb(60, 60, 65), Enum.Material.Metal)
		box(f, "SwingSeat", gx + 6 + u, CURB + 2.2, gz, 1.6, 0.3, 1, rgb(40, 40, 45), Enum.Material.Plastic)
	end
	-- statue of a Sproutling on a plinth at the crossing
	box(f, "Plinth", cx, CURB, cz, 5, 4, 5, rgb(200, 195, 185), Enum.Material.Marble)
	ball(f, "StatueBody", 4, cx, CURB + 6.2, cz, rgb(130, 200, 120), Enum.Material.Metal)
	ball(f, "StatueLeaf", 2, cx + 0.8, CURB + 8.6, cz, rgb(110, 180, 100), Enum.Material.Metal)
	-- trees, benches and lamps
	local n = 0
	for gxk = -2, 2 do
		for gzk = -3, 3 do
			n += 1
			local x, z = cx + gxk * (w / 5.2), cz + gzk * (d / 7.2)
			local onPath = math.abs(x - cx) < 6 or math.abs(z - cz) < 6
			local nearFeature = (math.abs(x - px) < 18 and math.abs(z - pz) < 18) or (math.abs(x - bx) < 14 and math.abs(z - bz) < 14) or (math.abs(x - gx) < 16 and math.abs(z - gz) < 14)
			if not onPath and not nearFeature and hash(n + 3) < 0.75 then
				local leaf = if hash(n) < 0.25 then rgb(255, 175, 205) else rgb(70 + math.floor(hash(n + 1) * 40), 160 + math.floor(hash(n + 2) * 40), 70)
				cylinder(f, "Trunk", 9, 1.2, x, CURB + 4.5, z, rgb(110, 80, 55), Enum.Material.Wood)
				ball(f, "Canopy", 9, x, CURB + 11, z, leaf, Enum.Material.Grass)
				ball(f, "Canopy", 6, x + 2, CURB + 13.5, z - 1, leaf, Enum.Material.Grass)
			end
		end
	end
	for _, s in { { cx - 5, cz - d / 6, 1, 0 }, { cx + 5, cz + d / 6, -1, 0 }, { cx + w / 6, cz + 5, 0, -1 }, { cx - w / 6, cz - 5, 0, 1 } } do
		bench(f, s[1], s[2], Vector3.new(s[3], 0, s[4]))
	end
	local sb = box(f, "ParkSign", cx, CURB, z0 + SIDEWALK + 1, 16, 4, 1, rgb(60, 120, 70), Enum.Material.WoodPlanks)
	sign(sb, "Central Park", WHITE, Enum.NormalId.Back)
end

local function harbour(f: Instance, x0: number, x1: number, z0: number, z1: number)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local w, d = x1 - x0 - 2 * SIDEWALK, z1 - z0 - 2 * SIDEWALK
	box(f, "Yard", cx, CURB, cz, w, 0.2, d, rgb(150, 150, 150), Enum.Material.Concrete)
	-- warehouses along the inland side
	for k = 0, 1 do
		local wz = z0 + SIDEWALK + 26 + k * (d / 2)
		local wx = x0 + SIDEWALK + 18
		box(f, "Warehouse", wx, CURB, wz, 30, 16, 40, rgb(170, 95, 70), Enum.Material.Brick)
		box(f, "WarehouseRoof", wx, CURB + 16, wz, 31, 1, 41, rgb(110, 115, 120), Enum.Material.DiamondPlate)
		for j = -1, 1 do
			box(f, "RollDoor", wx + 15.1, CURB, wz + j * 12, 0.3, 9, 8, rgb(200, 205, 210), Enum.Material.DiamondPlate)
		end
		local board = box(f, "WarehouseSign", wx + 15.3, CURB + 11, wz, 0.4, 3, 20, rgb(40, 60, 90), Enum.Material.SmoothPlastic)
		sign(board, "HARBOUR " .. (k + 1), WHITE, Enum.NormalId.Right)
	end
	-- container stacks
	local colors = { rgb(220, 70, 60), rgb(60, 130, 220), rgb(250, 190, 50), rgb(90, 180, 110), rgb(240, 130, 50), rgb(150, 100, 200) }
	local n = 0
	for row = 0, 5 do
		for col = 0, 1 do
			local stack = 1 + (row + col) % 3
			for layer = 0, stack - 1 do
				n += 1
				local c = box(f, "Container", x0 + SIDEWALK + 46 + col * 9, CURB + layer * 8.6, z0 + SIDEWALK + 12 + row * (d - 24) / 5, 8.4, 8.4, 18, colors[n % #colors + 1], Enum.Material.Metal)
				c:SetAttribute("Climbable", true)
			end
		end
	end
	-- two gantry cranes on the quay
	for k = 0, 1 do
		local qz = z0 + SIDEWALK + d * (0.3 + k * 0.4)
		local qx = x1 - SIDEWALK - 8
		for _, c in { { -6, -8 }, { 6, -8 }, { -6, 8 }, { 6, 8 } } do
			box(f, "CraneLeg", qx + c[1], CURB, qz + c[2], 1.6, 44, 1.6, rgb(240, 180, 40), Enum.Material.Metal)
		end
		box(f, "CraneBeam", qx + 18, CURB + 44, qz, 60, 3, 3.4, rgb(240, 180, 40), Enum.Material.Metal)
		box(f, "CraneBeam", qx, CURB + 44, qz, 14, 3, 18, rgb(240, 180, 40), Enum.Material.Metal)
		box(f, "CraneCab", qx + 4, CURB + 39, qz, 5, 4, 5, WHITE, Enum.Material.Metal)
		box(f, "Trolley", qx + 30, CURB + 42.5, qz, 4, 2, 4, rgb(60, 60, 65), Enum.Material.Metal)
		box(f, "Cable", qx + 30, CURB + 22, qz, 0.3, 20.5, 0.3, rgb(40, 40, 45), Enum.Material.Metal)
		box(f, "Spreader", qx + 30, CURB + 20.6, qz, 8, 1.2, 16, rgb(60, 60, 65), Enum.Material.Metal)
	end
	-- bollards on the quay edge
	for k = 0, 9 do
		cylinder(f, "Bollard", 2, 1.4, x1 - 2.5, CURB + 1, z0 + 8 + k * (z1 - z0 - 16) / 9, rgb(50, 50, 55), Enum.Material.Metal)
	end
end

local function marina(f: Instance, x0: number, x1: number, z0: number, z1: number)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local w, d = x1 - x0 - 2 * SIDEWALK, z1 - z0 - 2 * SIDEWALK
	box(f, "Boardwalk", cx, CURB, cz, w, 0.3, d, rgb(180, 140, 100), Enum.Material.WoodPlanks)
	-- ferry terminal building
	local tx = x0 + SIDEWALK + 22
	box(f, "Terminal", tx, CURB, cz, 34, 12, d - 20, rgb(235, 240, 245), Enum.Material.Concrete)
	box(f, "TerminalGlass", tx, CURB + 2, cz, 34.4, 7, d - 26, rgb(110, 170, 210), Enum.Material.Glass)
	box(f, "TerminalRoof", tx + 3, CURB + 12, cz, 42, 1.2, d - 14, rgb(60, 140, 200), Enum.Material.Metal)
	box(f, "TerminalRoofTop", tx, CURB + 13.2, cz, 24, 3, d - 30, rgb(235, 240, 245), Enum.Material.Concrete)
	local board = box(f, "TerminalSign", tx + 17.3, CURB + 9.4, cz, 0.4, 2.6, 22, rgb(60, 140, 200), Enum.Material.SmoothPlastic)
	sign(board, "FERRY & MARINA", WHITE, Enum.NormalId.Right)
	-- finger piers out into the bay with moored boats
	for k = 0, 3 do
		local pz = z0 + 14 + k * (z1 - z0 - 28) / 3
		box(f, "Pier", x1 + 22, 0.2, pz, 44, 0.8, 5, rgb(170, 125, 85), Enum.Material.WoodPlanks)
		for j = 0, 3 do
			cylinder(f, "Piling", 6, 1, x1 + 4 + j * 12, -2.5, pz + 2.8, rgb(110, 80, 55), Enum.Material.Wood)
		end
		local kinds = { "speedboat", "sailboat", "speedboat", "yacht" }
		local kind = kinds[k + 1]
		local colors = { rgb(220, 60, 60), rgb(60, 120, 220), rgb(250, 190, 50), rgb(90, 180, 110) }
		boat(f, x1 + 24, pz + (if kind == "yacht" then 12 else 7), Vector3.new(1, 0, 0), kind, colors[k + 1])
	end
end

----------------------------------------------------------------------------------------------
-- waterfront, bridges and the airport

local function promenade(city: Instance)
	local f = folder(city, "Promenade")
	local z = CITY.z0 + 6
	box(f, "Promenade", (CITY.x0 + CITY.x1) / 2, 0, z, CITY.x1 - CITY.x0, CURB, 12, rgb(215, 200, 175), Enum.Material.Slate)
	box(f, "Railing", (CITY.x0 + CITY.x1) / 2, CURB + 3, CITY.z0 + 0.6, CITY.x1 - CITY.x0, 0.4, 0.4, rgb(60, 62, 70), Enum.Material.Metal)
	for k = 0, 34 do
		local x = CITY.x0 + 5 + k * ((CITY.x1 - CITY.x0 - 10) / 34)
		if math.abs(x) > 26 then
			box(f, "RailPost", x, CURB, CITY.z0 + 0.6, 0.4, 3.2, 0.4, rgb(60, 62, 70), Enum.Material.Metal)
		end
	end
	for k = 0, 9 do
		local x = CITY.x0 + 20 + k * ((CITY.x1 - CITY.x0 - 40) / 9)
		if math.abs(x) > 30 then
			streetlight(f, x, z - 3, Vector3.new(0, 0, -1))
			bench(f, x + 8, z - 3, Vector3.new(0, 0, -1))
		end
	end
end

local function roadBridge(city: Instance, a: Vector3, b: Vector3, width: number, pylons: boolean)
	local f = model(city, "RoadBridge")
	local dir = (b - a).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local length = (b - a).Magnitude
	local mid = (a + b) / 2
	local deckY = 0.4
	part(f, "Deck", Vector3.new(width, 1.6, length), CFrame.lookAt(Vector3.new(mid.X, deckY - 0.8, mid.Z), Vector3.new(b.X, deckY - 0.8, b.Z)), ASPHALT, Enum.Material.Asphalt)
	for _, sgn in { -1, 1 } do
		local edge = mid + side * sgn * (width / 2 - 2)
		part(f, "Walkway", Vector3.new(4, 0.6, length), CFrame.lookAt(Vector3.new(edge.X, deckY + 0.3, edge.Z), Vector3.new(edge.X, deckY + 0.3, edge.Z) + dir), CONCRETE, Enum.Material.Concrete)
		local rail = mid + side * sgn * (width / 2)
		part(f, "Parapet", Vector3.new(0.8, 2.6, length), CFrame.lookAt(Vector3.new(rail.X, deckY + 1.3, rail.Z), Vector3.new(rail.X, deckY + 1.3, rail.Z) + dir), CONCRETE, Enum.Material.Concrete)
		local n = math.floor(length / 30)
		for k = 0, n do
			local p = a + dir * (k * length / n) + side * sgn * (width / 2 - 0.5)
			streetlight(f, p.X, p.Z, -side * sgn)
		end
	end
	for _, off in { -0.5, 0.5 } do
		local c = mid + side * off
		part(f, "CenterLine", Vector3.new(0.4, 0.06, length - 4), CFrame.lookAt(Vector3.new(c.X, deckY + 0.03, c.Z), Vector3.new(c.X, deckY + 0.03, c.Z) + dir), YELLOW)
	end
	-- piers
	local n = math.floor(length / 40)
	for k = 1, n - 1 do
		local p = a + dir * (k * length / n)
		part(f, "Pier", Vector3.new(width - 8, 10, 6), CFrame.lookAt(Vector3.new(p.X, deckY - 6.6, p.Z), Vector3.new(p.X, deckY - 6.6, p.Z) + dir), CONCRETE, Enum.Material.Concrete)
	end
	if pylons then
		-- a cable-stayed pylon in the middle with fanned cables
		local top = 62
		for _, sgn in { -1, 1 } do
			local leg = mid + side * sgn * (width / 2 + 2)
			part(f, "Pylon", Vector3.new(3.4, top + 10, 3.4), CFrame.new(leg.X, top / 2 - 5, leg.Z), WHITE, Enum.Material.Concrete)
			ball(f, "PylonLight", 1.4, leg.X, top + 1, leg.Z, rgb(255, 60, 60), Enum.Material.Neon)
			for _, dsg in { -1, 1 } do
				for k = 1, 5 do
					local anchor = mid + dir * dsg * (k * length / 12) + side * sgn * (width / 2 - 0.5)
					local from = Vector3.new(leg.X, top - k * 4, leg.Z)
					local to = Vector3.new(anchor.X, deckY + 2.6, anchor.Z)
					deco(part(f, "Cable", Vector3.new(0.3, 0.3, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), WHITE, Enum.Material.Metal))
				end
			end
		end
		local beam = mid + Vector3.new(0, top - 2, 0)
		part(f, "PylonBeam", Vector3.new(width + 8, 3, 3), CFrame.lookAt(beam, beam + side) * CFrame.Angles(0, math.rad(90), 0), WHITE, Enum.Material.Concrete)
		local banner = part(f, "Welcome", Vector3.new(width - 4, 5, 0.6), CFrame.lookAt(Vector3.new(mid.X, top - 9, mid.Z), Vector3.new(mid.X, top - 9, mid.Z) - dir), rgb(60, 150, 90), Enum.Material.SmoothPlastic)
		sign(banner, "Welcome to Sproutling City", WHITE)
		sign(banner, "Garden Isles", WHITE, Enum.NormalId.Back)
	end
end

local function airport(city: Instance)
	local f = folder(city, "Airport")
	local A = { x0 = -760, x1 = -425, z0 = 540, z1 = 1120 }
	local cx, cz = (A.x0 + A.x1) / 2, (A.z0 + A.z1) / 2
	box(f, "Field", cx, -1, cz, A.x1 - A.x0, 1, A.z1 - A.z0, rgb(120, 185, 90), Enum.Material.Grass)
	for _, e in { { cx, A.z0, A.x1 - A.x0 + 2, 2 }, { cx, A.z1, A.x1 - A.x0 + 2, 2 }, { A.x0, cz, 2, A.z1 - A.z0 }, { A.x1, cz, 2, A.z1 - A.z0 } } do
		box(f, "SeaWall", e[1], -10, e[2], e[3], 10.4, e[4], rgb(170, 165, 158), Enum.Material.Cobblestone)
	end
	-- runway with markings and edge lights
	local rx, rz0, rz1 = -680, 570, 1090
	local rlen = rz1 - rz0
	box(f, "Runway", rx, 0, (rz0 + rz1) / 2, 44, 0.2, rlen, rgb(55, 57, 62), Enum.Material.Asphalt)
	for k = 0, math.floor(rlen / 30) - 2 do
		box(f, "RunwayDash", rx, 0.2, rz0 + 40 + k * 30, 1, 0.06, 14, WHITE)
	end
	for _, z in { rz0 + 8, rz1 - 8 } do
		for k = -4, 4 do
			if k ~= 0 then
				box(f, "Threshold", rx + k * 4.4, 0.2, z, 2.2, 0.06, 12, WHITE)
			end
		end
	end
	for k = 0, math.floor(rlen / 26) do
		for _, sgn in { -1, 1 } do
			deco(ball(f, "EdgeLight", 0.8, rx + sgn * 23, 0.6, rz0 + k * 26, if k == 0 or k == math.floor(rlen / 26) then rgb(255, 60, 60) else rgb(255, 245, 200), Enum.Material.Neon))
		end
	end
	-- taxiway, apron and connectors
	box(f, "Taxiway", -610, 0, (rz0 + rz1) / 2, 18, 0.18, rlen - 60, rgb(70, 72, 78), Enum.Material.Asphalt)
	for _, z in { rz0 + 60, (rz0 + rz1) / 2, rz1 - 60 } do
		box(f, "Connector", -645, 0, z, 52, 0.18, 16, rgb(70, 72, 78), Enum.Material.Asphalt)
		box(f, "TaxiLine", -645, 0.2, z, 52, 0.06, 0.5, YELLOW)
	end
	box(f, "TaxiLine", -610, 0.2, (rz0 + rz1) / 2, 0.5, 0.06, rlen - 60, YELLOW)
	box(f, "Apron", -520, 0, 830, 150, 0.18, 330, rgb(180, 180, 182), Enum.Material.Concrete)
	-- terminal with jet bridges
	local tx = -455
	box(f, "Terminal", tx, 0, 830, 34, 16, 240, rgb(235, 240, 245), Enum.Material.Concrete)
	box(f, "TerminalGlass", tx - 17.1, 2, 830, 0.4, 10, 230, rgb(110, 170, 210), Enum.Material.Glass)
	box(f, "TerminalRoof", tx - 3, 16, 830, 44, 1.4, 250, rgb(60, 140, 200), Enum.Material.Metal)
	local board = box(f, "TerminalSign", tx - 17.4, 12, 830, 0.4, 3, 60, rgb(60, 140, 200), Enum.Material.SmoothPlastic)
	sign(board, "SPROUTLING INTERNATIONAL", WHITE, Enum.NormalId.Left)
	for k = -1, 1 do
		local gz = 830 + k * 80
		box(f, "JetBridge", tx - 32, 6, gz, 30, 5, 5, rgb(200, 205, 210), Enum.Material.Metal)
		box(f, "JetBridgeLeg", tx - 44, 0, gz, 1.4, 6, 1.4, rgb(90, 90, 95), Enum.Material.Metal)
		box(f, "GateLine", -520, 0.2, gz, 70, 0.06, 0.5, YELLOW)
	end
	local liveries = { rgb(220, 60, 60), rgb(60, 140, 220), rgb(90, 180, 110) }
	for k = -1, 1 do
		airliner(f, -531, 830 + k * 80 - 4, Vector3.new(1, 0, 0), liveries[k + 2])
	end
	-- control tower
	local ctx, ctz = -470, 620
	cylinder(f, "TowerShaft", 60, 8, ctx, 30, ctz, rgb(235, 235, 238), Enum.Material.Concrete)
	cylinder(f, "TowerCab", 8, 16, ctx, 64, ctz, rgb(90, 150, 190), Enum.Material.Glass)
	cylinder(f, "TowerDeck", 1, 18, ctx, 60, ctz, rgb(200, 200, 205), Enum.Material.Concrete)
	cylinder(f, "TowerRoof", 1.6, 18, ctx, 68.8, ctz, rgb(200, 200, 205), Enum.Material.Concrete)
	cylinder(f, "TowerMast", 10, 0.6, ctx, 74.6, ctz, rgb(200, 200, 205), Enum.Material.Metal)
	local beacon = deco(ball(f, "TowerBeacon", 1.4, ctx, 80, ctz, rgb(255, 60, 60), Enum.Material.Neon))
	glowLight(beacon, 30, 1.5, rgb(255, 80, 80))
	-- hangar with small planes and a helicopter
	local hx, hz = -520, 1060
	box(f, "Hangar", hx, 0, hz, 80, 22, 50, rgb(200, 205, 212), Enum.Material.DiamondPlate)
	for k = 1, 4 do
		box(f, "HangarRoof", hx, 22 + k * 1.6, hz, 80 - k * 12, 1.6, 50.4, rgb(180, 185, 192), Enum.Material.DiamondPlate)
	end
	box(f, "HangarDoor", hx - 40.2, 0, hz, 0.4, 18, 40, rgb(70, 140, 220), Enum.Material.DiamondPlate)
	propPlane(f, -570, 1030, Vector3.new(-1, 0, 0), rgb(250, 190, 50))
	propPlane(f, -570, 1080, Vector3.new(-1, 0, 0), rgb(220, 70, 90))
	helicopter(f, -480, 660, Vector3.new(-1, 0, 0), rgb(60, 140, 220))
	box(f, "Helipad", -480, 0, 660, 22, 0.2, 22, rgb(70, 72, 80), Enum.Material.Concrete)
	-- windsock
	cylinder(f, "WindsockPole", 10, 0.4, -720, 5, 600, rgb(200, 200, 205), Enum.Material.Metal)
	part(f, "Windsock", Vector3.new(1.6, 1.6, 5), CFrame.new(-720, 9.6, 603) * CFrame.Angles(math.rad(-10), 0, 0), rgb(250, 120, 40), Enum.Material.Fabric)
	-- parking with cars by the terminal road
	for k = 0, 11 do
		car(f, -431, 720 + k * 18, Vector3.new(-1, 0, 0), CAR_COLORS[k % #CAR_COLORS + 1])
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
		box(f, "Sidewalk", cx, 0, cz, x1 - x0, CURB, z1 - z0, CONCRETE, Enum.Material.Concrete)
		local special = false
		if iz == 1 then
			marketBlock(f, b, ix)
		elseif ix == 6 and iz <= 2 then
			marina(f, x0, x1, z0, z1)
			special = true
		elseif ix == 6 then
			harbour(f, x0, x1, z0, z1)
			special = true
		elseif ix == 2 and (iz == 3 or iz == 4) then
			park(f, x0, x1, z0, z1)
			special = true
		elseif (ix == 3 or ix == 4) and iz >= 2 and iz <= 4 then
			downtownBlock(f, b, i)
		elseif ix == 3 and iz == 5 then
			civic(f, cx, cz, x1 - x0 - 2 * SIDEWALK - 4, z1 - z0 - 2 * SIDEWALK - 10, Vector3.new(0, 0, -1), "City Hall", rgb(120, 170, 210))
		elseif ix == 4 and iz == 5 then
			civic(f, cx, cz, x1 - x0 - 2 * SIDEWALK - 4, z1 - z0 - 2 * SIDEWALK - 10, Vector3.new(0, 0, -1), "Museum", rgb(200, 150, 90))
		elseif ix == 5 and iz == 5 then
			service(f, cx, z0 + SIDEWALK + 14, x1 - x0 - 2 * SIDEWALK - 4, 24, Vector3.new(0, 0, -1), "Fire Station", rgb(220, 60, 50), 3)
			service(f, cx, z1 - SIDEWALK - 14, x1 - x0 - 2 * SIDEWALK - 4, 24, Vector3.new(0, 0, 1), "Police", rgb(60, 110, 220), 2)
		elseif ix == 5 and iz == 6 then
			service(f, cx, cz, x1 - x0 - 2 * SIDEWALK - 4, z1 - z0 - 2 * SIDEWALK - 8, Vector3.new(0, 0, -1), "Hospital", rgb(240, 240, 245), 2)
		elseif ix == 1 or (ix == 2 and iz >= 5) then
			houseBlock(f, b, i)
		else
			apartmentBlock(f, b, i)
		end
		if not special then
			furnish(f, b, i)
		end
	end

	-- traffic: parked cars along the avenues and a couple of buses
	local traffic = folder(city, "Traffic")
	local n = 0
	for ai, a in AVENUES do
		for si = 1, #STREETS - 1 do
			local z0, z1 = STREETS[si].z + STREETS[si].w / 2, STREETS[si + 1].z - STREETS[si + 1].w / 2
			for k = 0, 2 do
				n += 1
				if hash(n + 0.3) < 0.7 then
					local sgn = if k % 2 == 0 then 1 else -1
					local kind = if hash(n) < 0.15 then "taxi" elseif hash(n) > 0.95 then "police" else nil
					local color = if kind == "taxi" then rgb(250, 200, 40) elseif kind == "police" then rgb(240, 240, 245) else CAR_COLORS[n % #CAR_COLORS + 1]
					car(traffic, a.x + sgn * (a.w / 2 - 3.2), z0 + 14 + k * ((z1 - z0 - 28) / 2), Vector3.new(0, 0, sgn), color, kind)
				end
			end
		end
		if ai == 3 then
			bus(traffic, a.x + a.w / 2 - 4, 650, Vector3.new(0, 0, 1))
			busStop(traffic, a.x + a.w / 2 + 3, 640, Vector3.new(-1, 0, 0))
			bus(traffic, a.x - a.w / 2 + 4, 980, Vector3.new(0, 0, -1))
			busStop(traffic, a.x - a.w / 2 - 3, 990, Vector3.new(1, 0, 0))
		end
	end

	promenade(city)
	roadBridge(city, Vector3.new(0, 0, 330), Vector3.new(0, 0, CITY.z0), 44, true)
	roadBridge(city, Vector3.new(CITY.x0, 0, 700), Vector3.new(-425, 0, 700), 28, false)

	-- out in the harbour bay: a cargo ship and a tug
	local bay = folder(city, "Bay")
	boat(bay, 420, 900, Vector3.new(0, 0, -1), "cargo", rgb(40, 70, 120))
	boat(bay, 395, 1010, Vector3.new(-0.4, 0, -1).Unit, "tug", rgb(200, 60, 50))
	boat(bay, 400, 760, Vector3.new(0.3, 0, 1).Unit, "sailboat", rgb(240, 120, 150))

	airport(city)

	city.Parent = map
	return city
end

if Color3 then
	initColors()
end

return CityBuilder
