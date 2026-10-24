--!strict
-- Fills the open land with life and quests: the camps of the quest givers (Shared/Quests),
-- homesteads and hamlet extensions in the clearings, things to stumble on in the forests, quest
-- items, peak cairns, wind shrines, and everything on the sky isles you can reach through them.
--
-- Like MapBuilder it touches no services, so it runs at server start, from the Studio command
-- bar, and offline under Lune. MapBuilder calls Build(map, Landscape, Quests, kit), where kit
-- holds MapBuilder's own builders (cottage, tree, lamp, ...). Everything goes under Map.Wilds.
--
-- Gameplay hooks are attributes on invisible marker parts, found by the server at start-up:
--   QuestNpc (npc id)          on each person's root part (QuestService adds the Talk prompt)
--   QuestItem + QuestNodeId    a quest item to pick up
--   QuestSpot (spot id)        a place to visit
--   CampKind/CampCount/...     an enemy camp (EnemyService)
--   WindShrine (isle name)     ride the updraft up to that sky isle
--   SkyLanding (isle name)     where the updraft puts you
--   WindStone (isle name)      ride back down
--   SkyCache (isle name)       a once-per-player treasure cache

local WildsBuilder = {}

local Instance = Instance
local Vector3 = Vector3
local CFrame = CFrame
local Color3 = Color3
local Enum = Enum
local UDim2 = UDim2

function WildsBuilder.useApi(api: any)
	Instance = api.Instance
	Vector3 = api.Vector3
	CFrame = api.CFrame
	Color3 = api.Color3
	Enum = api.Enum
	UDim2 = api.UDim2
end

local L: any = nil -- Shared.Landscape
local Q: any = nil -- Shared.Quests
local K: any = nil -- MapBuilder's kit
local WS: any = nil -- Shared.Waystones

----------------------------------------------------------------------------------------------
-- helpers

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function c3(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function hash(n: number): number
	local s = math.sin(n * 12.9898) * 43758.5453
	return s - math.floor(s)
end

local counter = 0
local function rand(): number
	counter += 1
	return hash(counter * 0.7548776 + 0.13)
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

local function cylinder(parent: Instance, name: string, height: number, diameter: number, x: number, y: number, z: number, color: Color3, material: any?): BasePart
	local p = part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent: Instance, name: string, diameter: number, x: number, y: number, z: number, color: Color3, material: any?): BasePart
	local p = part(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(x, y, z), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function glow(parent: Instance, range: number, brightness: number, color: Color3)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = color
	light.Parent = parent
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

-- Invisible marker the server finds by attribute.
local function marker(parent: Instance, name: string, pos: Vector3, attrs: { [string]: any }): BasePart
	local p = part(parent, name, Vector3.new(2, 2, 2), CFrame.new(pos + Vector3.new(0, 1, 0)), rgb(255, 255, 255), nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	for key, value in attrs do
		p:SetAttribute(key, value)
	end
	return p
end

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

-- Lowest and highest ground in a circle.
local function groundRange(x: number, z: number, r: number): (number, number)
	local lo, hi = L.height(x, z), L.height(x, z)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		for _, f in { 0.5, 1 } do
			local h = L.height(x + math.cos(a) * r * f, z + math.sin(a) * r * f)
			lo, hi = math.min(lo, h), math.max(hi, h)
		end
	end
	return lo, hi
end

-- Builds a small structure at (x, z) on the highest ground under it, on an earth mound that
-- hides any gap on a slope.
local function onGround(parent: Instance, x: number, z: number, r: number, build: (Instance) -> ())
	local lo, hi = groundRange(x, z, r)
	raised(parent, hi, build)
	if hi - lo > 0.4 then
		local mound = cylinder(parent, "Mound", hi - lo + 3, r * 2.1, x, (hi + lo - 3) / 2, z, rgb(120, 95, 65), Enum.Material.Ground)
		mound.Name = "Mound"
	end
end

----------------------------------------------------------------------------------------------
-- finding room in the open land

local taken: { { number } } = {} -- x, z, radius of everything placed

local function clearOfTaken(x: number, z: number, r: number): boolean
	for _, t in taken do
		if (x - t[1]) ^ 2 + (z - t[2]) ^ 2 < (r + t[3]) ^ 2 then
			return false
		end
	end
	return true
end

type SpotOpts = { radius: number, maxRange: number?, roadMargin: number?, search: number?, minHeight: number?, allowSite: boolean? }

-- Nearest open, fairly flat spot to (x, z): dry land, off roads and building sites, outside the
-- city, and clear of everything already placed.
local function findSpot(x: number, z: number, o: SpotOpts): (number?, number?, number?)
	local search = o.search or 15
	for ring = 0, search do
		local count = if ring == 0 then 1 else 6 + ring * 2
		for k = 0, count - 1 do
			local a = k / count * math.pi * 2 + ring * 0.7
			local px, pz = x + math.cos(a) * ring * 16, z + math.sin(a) * ring * 16
			if not L.inPlayArea(px, pz) and L.cityWeight(px, pz) < 0.03 and clearOfTaken(px, pz, o.radius) then
				local h = L.height(px, pz)
				if h > (o.minHeight or 3) and not L.onRoad(px, pz, o.roadMargin or (o.radius * 0.6)) and (o.allowSite or not L.onSite(px, pz, o.radius + 10)) then
					local lo, hi = groundRange(px, pz, o.radius)
					if hi - lo <= (o.maxRange or 5) then
						table.insert(taken, { px, pz, o.radius })
						return px, pz, h
					end
				end
			end
		end
	end
	return nil, nil, nil
end

-- The highest open spot within `search` studs of (x, z) (cairns on the peaks).
local function findPeak(x: number, z: number, search: number): (number, number, number)
	local bx, bz, bh = x, z, -math.huge
	for dz = -search, search, 20 do
		for dx = -search, search, 20 do
			local px, pz = x + dx, z + dz
			local h = L.height(px, pz)
			if h > bh and L.slope(px, pz) < 0.7 and not L.onRoad(px, pz, 4) then
				bx, bz, bh = px, pz, h
			end
		end
	end
	table.insert(taken, { bx, bz, 10 })
	return bx, bz, bh
end

local function towardRoad(x: number, z: number): Vector3
	local _, s = L.nearestRoad(x, z)
	if s then
		local d = Vector3.new(s.x - x, 0, s.z - z)
		if d.Magnitude > 1 then
			return d.Unit
		end
	end
	return Vector3.new(0, 0, 1)
end

----------------------------------------------------------------------------------------------
-- people

-- A quest giver: a simple figure with a hat and a tool, a name tag, a "!" mark the client
-- updates per player, and an invisible root carrying the QuestNpc attribute.
local function person(parent: Instance, npc: any, x: number, y: number, z: number, facing: Vector3)
	local look = npc.look
	local m = model(parent, npc.name)
	m:SetAttribute("QuestNpc", npc.id)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local base = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z) + facing)
	local function at(u: number, h: number, v: number): CFrame
		return base * CFrame.new(u, h, -v)
	end
	local skin, shirt, pants, hair = c3(look.skin), c3(look.shirt), c3(look.pants), c3(look.hair)
	local root = part(m, "NpcRoot", Vector3.new(3, 6, 2), at(0, 3, 0), rgb(255, 255, 255), nil, { Transparency = 1, CanCollide = false })
	root:SetAttribute("QuestNpc", npc.id)
	m.PrimaryPart = root
	for _, s in { -1, 1 } do
		part(m, "Leg", Vector3.new(0.9, 2.4, 1), at(s * 0.5, 1.2, 0), pants, Enum.Material.Fabric)
		part(m, "Arm", Vector3.new(0.8, 2.3, 0.9), at(s * 1.5, 3.3, 0), shirt, Enum.Material.Fabric)
		part(m, "Hand", Vector3.new(0.7, 0.6, 0.7), at(s * 1.5, 2, 0), skin)
	end
	part(m, "Torso", Vector3.new(2.2, 2.4, 1.1), at(0, 3.6, 0), shirt, Enum.Material.Fabric)
	part(m, "Belt", Vector3.new(2.3, 0.4, 1.2), at(0, 2.5, 0), rgb(70, 50, 35), Enum.Material.Fabric)
	local head = part(m, "Head", Vector3.new(1.6, 1.6, 1.6), at(0, 5.6, 0), skin)
	part(m, "Hair", Vector3.new(1.7, 0.6, 1.7), at(0, 6.4, 0.05), hair, Enum.Material.Fabric)
	for _, s in { -1, 1 } do
		part(m, "Eye", Vector3.new(0.25, 0.3, 0.1), at(s * 0.35, 5.7, 0.82), rgb(30, 30, 35))
	end
	local hatColor = if look.hatColor then c3(look.hatColor) else hair
	if look.hat == "hood" then
		part(m, "Hood", Vector3.new(2, 2, 2), at(0, 5.9, -0.15), hatColor, Enum.Material.Fabric)
		part(m, "Cape", Vector3.new(2.3, 3.6, 0.3), at(0, 3.6, -0.7), hatColor, Enum.Material.Fabric)
		part(m, "Face", Vector3.new(1.5, 1.4, 0.2), at(0, 5.6, 0.9), skin)
	elseif look.hat == "cap" then
		part(m, "Cap", Vector3.new(1.8, 0.6, 1.8), at(0, 6.6, 0), hatColor, Enum.Material.Fabric)
		part(m, "Brim", Vector3.new(1.6, 0.2, 0.8), at(0, 6.35, 1.1), hatColor, Enum.Material.Fabric)
	elseif look.hat == "straw" then
		cylinder(m, "Brim", 0.2, 3.6, 0, 0, 0, hatColor, Enum.Material.Fabric).CFrame = at(0, 6.5, 0) * CFrame.Angles(0, 0, math.rad(90))
		cylinder(m, "Crown", 0.9, 1.8, 0, 0, 0, hatColor, Enum.Material.Fabric).CFrame = at(0, 6.9, 0) * CFrame.Angles(0, 0, math.rad(90))
	elseif look.hat == "helmet" then
		local helm = part(m, "Helmet", Vector3.new(1.9, 1.9, 1.9), at(0, 6.2, 0), hatColor, Enum.Material.Metal)
		helm.Shape = Enum.PartType.Ball
		if npc.camp == "mine" then
			local lamp = part(m, "HeadLamp", Vector3.new(0.5, 0.5, 0.3), at(0, 6.5, 0.95), rgb(255, 240, 180), Enum.Material.Neon)
			glow(lamp, 12, 1, rgb(255, 230, 160))
		end
	elseif look.hat == "goggles" then
		part(m, "Strap", Vector3.new(1.7, 0.35, 1.7), at(0, 6, 0), hatColor, Enum.Material.Fabric)
		for _, s in { -1, 1 } do
			cylinder(m, "Goggle", 0.3, 0.6, 0, 0, 0, rgb(120, 200, 255), Enum.Material.Glass).CFrame = at(s * 0.4, 6.1, 0.85) * CFrame.Angles(0, math.rad(90), 0)
		end
	elseif look.hat == "circlet" then
		part(m, "Circlet", Vector3.new(1.75, 0.25, 1.75), at(0, 6.2, 0), hatColor, Enum.Material.Neon)
	end
	-- the tool in the right hand
	local prop = look.prop
	local wood, steel = rgb(120, 85, 55), rgb(190, 195, 205)
	if prop == "bow" then
		part(m, "Bow", Vector3.new(0.25, 4.2, 0.4), at(1.9, 3.2, 0.4), wood, Enum.Material.Wood)
	elseif prop == "axe" then
		part(m, "Haft", Vector3.new(0.3, 3.6, 0.3), at(1.6, 2.6, 0.6), wood, Enum.Material.Wood)
		part(m, "AxeHead", Vector3.new(0.3, 1.1, 1.3), at(1.6, 4.2, 1), steel, Enum.Material.Metal)
	elseif prop == "staff" then
		part(m, "Staff", Vector3.new(0.3, 6, 0.3), at(1.7, 3, 0.4), wood, Enum.Material.Wood)
		local orb = part(m, "StaffOrb", Vector3.new(0.8, 0.8, 0.8), at(1.7, 6.2, 0.4), hatColor, Enum.Material.Neon)
		orb.Shape = Enum.PartType.Ball
	elseif prop == "crook" then
		part(m, "Crook", Vector3.new(0.3, 6, 0.3), at(1.7, 3, 0.4), wood, Enum.Material.Wood)
		part(m, "CrookHook", Vector3.new(0.3, 0.3, 1.2), at(1.7, 6, 0.9), wood, Enum.Material.Wood)
	elseif prop == "pick" then
		part(m, "Haft", Vector3.new(0.3, 3.6, 0.3), at(1.6, 2.6, 0.6), wood, Enum.Material.Wood)
		part(m, "PickHead", Vector3.new(0.3, 0.4, 2.6), at(1.6, 4.3, 0.6), steel, Enum.Material.Metal)
	elseif prop == "spyglass" then
		cylinder(m, "Spyglass", 2.2, 0.5, 0, 0, 0, rgb(200, 160, 70), Enum.Material.Metal).CFrame = at(1.6, 3, 0.8) * CFrame.Angles(0, math.rad(90), 0)
	elseif prop == "sword" then
		part(m, "Sword", Vector3.new(0.25, 3.6, 0.5), at(1.6, 2.4, 0.6), steel, Enum.Material.Metal)
	elseif prop == "letter" then
		part(m, "Letter", Vector3.new(1.2, 0.8, 0.1), at(1.5, 2.6, 0.6), rgb(250, 245, 225))
		part(m, "Satchel", Vector3.new(1.2, 1.2, 0.6), at(-1.4, 2.6, 0), rgb(140, 95, 60), Enum.Material.Fabric)
	end
	-- name tag and quest mark
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(200, 50)
	tag.StudsOffset = Vector3.new(0, 2.2, 0)
	tag.MaxDistance = 90
	tag.LightInfluence = 0
	tag.Parent = head
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 0.6)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.Text = npc.name
	nameLabel.TextColor3 = rgb(255, 245, 210)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Parent = tag
	local titleLabel = nameLabel:Clone()
	titleLabel.Size = UDim2.fromScale(1, 0.4)
	titleLabel.Position = UDim2.fromScale(0, 0.6)
	titleLabel.Text = npc.title
	titleLabel.TextColor3 = rgb(200, 220, 255)
	titleLabel.Parent = tag
	local mark = Instance.new("BillboardGui")
	mark.Name = "QuestMark"
	mark.Size = UDim2.fromOffset(60, 60)
	mark.StudsOffset = Vector3.new(0, 5, 0)
	mark.MaxDistance = 400
	mark.LightInfluence = 0
	mark.Parent = head
	local markLabel = Instance.new("TextLabel")
	markLabel.Name = "Text"
	markLabel.BackgroundTransparency = 1
	markLabel.Size = UDim2.fromScale(1, 1)
	markLabel.Font = Enum.Font.FredokaOne
	markLabel.TextScaled = true
	markLabel.Text = "!"
	markLabel.TextColor3 = rgb(255, 215, 60)
	markLabel.TextStrokeTransparency = 0
	markLabel.Parent = mark
end

----------------------------------------------------------------------------------------------
-- camp pieces (all built round (x, z) on flat ground at y = 0)

local function campfire(f: Instance, x: number, z: number)
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		ball(f, "FireStone", 1.3, x + math.cos(a) * 2.2, 0.4, z + math.sin(a) * 2.2, rgb(120, 115, 110), Enum.Material.Rock)
	end
	for k = 0, 2 do
		part(f, "Log", Vector3.new(0.6, 0.6, 3.2), CFrame.new(x, 0.5, z) * CFrame.Angles(0, k * math.rad(60), math.rad(10)), rgb(100, 70, 45), Enum.Material.Wood)
	end
	local embers = ball(f, "Embers", 1.6, x, 0.8, z, rgb(255, 130, 40), Enum.Material.Neon)
	glow(embers, 20, 1.5, rgb(255, 150, 70))
end

local function tent(f: Instance, x: number, z: number, facing: Vector3, color: Color3)
	local base = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + facing)
	for _, s in { -1, 1 } do
		part(f, "TentSide", Vector3.new(0.3, 6.4, 8), base * CFrame.new(s * 2.2, 2.6, 0) * CFrame.Angles(0, 0, s * math.rad(-35)), color, Enum.Material.Fabric)
	end
	part(f, "TentBack", Vector3.new(6.8, 5, 0.3), base * CFrame.new(0, 2.3, 3.9), color, Enum.Material.Fabric)
	part(f, "TentPole", Vector3.new(0.3, 0.3, 8.6), base * CFrame.new(0, 5.3, 0), rgb(110, 80, 50), Enum.Material.Wood)
	part(f, "Bedroll", Vector3.new(2, 0.5, 5), base * CFrame.new(0, 0.25, 0.5), rgb(160, 60, 50), Enum.Material.Fabric)
end

local function logPile(f: Instance, x: number, z: number, turn: number)
	for row = 0, 2 do
		for k = 0, 2 - row do
			local log = cylinder(f, "Log", 1.6, 1.6, 0, 0, 0, rgb(130, 90, 55), Enum.Material.Wood)
			log.Size = Vector3.new(7, 1.6, 1.6)
			log.CFrame = CFrame.new(x, 0.8 + row * 1.4, z) * CFrame.Angles(0, turn, 0) * CFrame.new(0, 0, (k - (2 - row) / 2) * 1.65)
		end
	end
end

local function stump(f: Instance, x: number, z: number, d: number)
	cylinder(f, "Stump", 1.6, d, x, 0.8, z, rgb(120, 85, 55), Enum.Material.Wood)
	cylinder(f, "Rings", 0.1, d - 0.4, x, 1.65, z, rgb(210, 170, 120), Enum.Material.Wood)
end

local function fenceRing(f: Instance, x: number, z: number, r: number, gap: number)
	local n = math.floor(r * 2 * math.pi / 6)
	for k = 0, n - 1 do
		local a0, a1 = k / n * math.pi * 2, (k + 1) / n * math.pi * 2
		if math.abs(a0 - gap) > 0.35 then
			local p0 = Vector3.new(x + math.cos(a0) * r, 0, z + math.sin(a0) * r)
			local p1 = Vector3.new(x + math.cos(a1) * r, 0, z + math.sin(a1) * r)
			part(f, "FencePost", Vector3.new(0.5, 3, 0.5), CFrame.new(p0 + Vector3.new(0, 1.5, 0)), rgb(130, 95, 60), Enum.Material.Wood)
			local mid = (p0 + p1) / 2
			part(f, "FenceRail", Vector3.new(0.3, 0.4, (p1 - p0).Magnitude), CFrame.lookAt(mid + Vector3.new(0, 2.2, 0), p1 + Vector3.new(0, 2.2, 0)), rgb(150, 110, 70), Enum.Material.Wood)
		end
	end
end

local function sheep(f: Instance, x: number, z: number, turn: number)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, turn, 0)
	part(f, "Wool", Vector3.new(2.6, 2.2, 3.6), base * CFrame.new(0, 2.2, 0), rgb(245, 245, 240), Enum.Material.Fabric)
	part(f, "SheepHead", Vector3.new(1.2, 1.3, 1.3), base * CFrame.new(0, 2.6, -2.2), rgb(60, 55, 55), Enum.Material.Fabric)
	for _, c in { { -0.8, -1.2 }, { 0.8, -1.2 }, { -0.8, 1.2 }, { 0.8, 1.2 } } do
		part(f, "SheepLeg", Vector3.new(0.4, 1.2, 0.4), base * CFrame.new(c[1], 0.6, c[2]), rgb(60, 55, 55))
	end
end

local function cairn(f: Instance, x: number, z: number, scale: number)
	local y = 0
	for k = 0, 4 do
		local d = (3.4 - k * 0.55) * scale
		ball(f, "CairnStone", d, x + (hash(k + x) - 0.5) * 0.6, y + d * 0.4, z, rgb(150 - k * 6, 145 - k * 6, 135 - k * 6), Enum.Material.Slate)
		y += d * 0.7
	end
	part(f, "CairnFlag", Vector3.new(0.2, 2.4, 3), CFrame.new(x, y + 2.5, z + 1.5), rgb(200, 60, 60), Enum.Material.Fabric)
	part(f, "CairnPole", Vector3.new(0.3, 4, 0.3), CFrame.new(x, y + 2, z), rgb(110, 80, 50), Enum.Material.Wood)
end

local function standingStones(f: Instance, x: number, z: number, r: number, count: number)
	for k = 0, count - 1 do
		local a = k / count * math.pi * 2
		local h = 6 + hash(k + x * 0.1) * 5
		part(f, "StandingStone", Vector3.new(2.4, h, 1.6), CFrame.new(x + math.cos(a) * r, h / 2 - 0.5, z + math.sin(a) * r) * CFrame.Angles(0, -a, math.rad((hash(k) - 0.5) * 10)), rgb(140, 138, 135), Enum.Material.Slate)
	end
end

-- The wind shrine: a ring of pillars round a glowing vent; the updraft lifts you to an isle.
local function windShrine(f: Instance, x: number, z: number, isle: string)
	local m = model(f, "Wind Shrine")
	cylinder(m, "ShrineBase", 1, 22, x, 0.5, z, rgb(200, 205, 215), Enum.Material.Marble)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local px, pz = x + math.cos(a) * 9, z + math.sin(a) * 9
		cylinder(m, "ShrinePillar", 9, 1.6, px, 5.5, pz, rgb(230, 232, 240), Enum.Material.Marble)
		ball(m, "PillarOrb", 1.4, px, 10.6, pz, rgb(170, 230, 255), Enum.Material.Neon)
	end
	local vent = cylinder(m, "WindVent", 0.4, 8, x, 1.2, z, rgb(150, 220, 255), Enum.Material.Neon)
	glow(vent, 26, 1.6, rgb(150, 220, 255))
	local column = cylinder(m, "Updraft", 40, 7, x, 21, z, rgb(200, 240, 255), Enum.Material.Neon)
	column.Transparency = 0.82
	column.CanCollide = false
	column.CanQuery = false
	local sign = marker(m, "WindShrine", Vector3.new(x, 0, z), { WindShrine = isle })
	sign.Size = Vector3.new(8, 4, 8)
end

local function chest(f: Instance, x: number, y: number, z: number, turn: number)
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, turn, 0)
	part(f, "ChestBox", Vector3.new(4, 2.4, 2.6), base * CFrame.new(0, 1.2, 0), rgb(150, 100, 55), Enum.Material.WoodPlanks)
	part(f, "ChestLid", Vector3.new(4.1, 1, 2.7), base * CFrame.new(0, 2.8, 0), rgb(130, 85, 45), Enum.Material.WoodPlanks)
	part(f, "ChestBand", Vector3.new(4.2, 3.4, 0.4), base * CFrame.new(0, 1.7, 0), rgb(220, 180, 70), Enum.Material.Metal)
	local lock = part(f, "ChestLock", Vector3.new(0.7, 0.8, 0.3), base * CFrame.new(0, 2.2, -1.4), rgb(255, 225, 120), Enum.Material.Neon)
	glow(lock, 10, 0.8, rgb(255, 225, 120))
end

----------------------------------------------------------------------------------------------
-- camps

local CAMPS: { [string]: (Instance, number, number, Vector3, number) -> () } = {}

CAMPS.ranger = function(f, x, z, face, _seed)
	-- lookout tower
	local tx, tz = x - 10, z - 6
	for _, c in { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } } do
		part(f, "TowerLeg", Vector3.new(0.9, 22, 0.9), CFrame.new(tx + c[1], 9, tz + c[2]), rgb(110, 80, 50), Enum.Material.Wood)
	end
	part(f, "Lookout", Vector3.new(9, 1, 9), CFrame.new(tx, 18, tz), rgb(150, 110, 70), Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		part(f, "LookoutRail", Vector3.new(9, 1.6, 0.4), CFrame.new(tx, 19.3, tz + s * 4.4), rgb(130, 95, 60), Enum.Material.Wood)
		part(f, "LookoutRail", Vector3.new(0.4, 1.6, 9), CFrame.new(tx + s * 4.4, 19.3, tz), rgb(130, 95, 60), Enum.Material.Wood)
	end
	part(f, "LookoutRoof", Vector3.new(10, 0.8, 10), CFrame.new(tx, 23, tz), rgb(60, 100, 60), Enum.Material.Fabric)
	part(f, "Ladder", Vector3.new(2, 18, 0.3), CFrame.new(tx, 9, tz + 3.4), rgb(140, 100, 65), Enum.Material.WoodPlanks)
	tent(f, x + 12, z - 4, face, rgb(70, 110, 70))
	tent(f, x + 4, z - 14, face, rgb(90, 120, 80))
	campfire(f, x + 2, z + 2)
	part(f, "WeaponRack", Vector3.new(6, 3, 0.6), CFrame.new(x - 4, 1.5, z + 10), rgb(120, 85, 55), Enum.Material.Wood)
	K.barrel(f, x + 14, z + 8)
end

CAMPS.woodcutter = function(f, x, z, face, seed)
	K.cottage(f, x - 6, z - 10, face, seed)
	logPile(f, x + 12, z - 6, 0.4)
	logPile(f, x + 14, z + 6, -0.3)
	for k = 0, 4 do
		stump(f, x - 16 + k * 7, z + 14 + (hash(k + seed) - 0.5) * 6, 2.4 + hash(k) * 1.4)
	end
	part(f, "ChoppingBlock", Vector3.new(3, 2, 3), CFrame.new(x + 4, 1, z + 4), rgb(120, 85, 55), Enum.Material.Wood)
	part(f, "StuckAxe", Vector3.new(0.3, 3, 0.3), CFrame.new(x + 4, 3, z + 4) * CFrame.Angles(0, 0, math.rad(25)), rgb(120, 85, 55), Enum.Material.Wood)
	campfire(f, x - 4, z + 6)
end

CAMPS.herbalist = function(f, x, z, face, seed)
	K.cottage(f, x - 4, z - 10, face, seed)
	K.flowerBed(f, x + 12, z - 4, 6, 8, seed)
	K.flowerBed(f, x + 12, z + 8, 6, 8, seed + 1)
	cylinder(f, "Cauldron", 2.6, 4, x - 2, 1.3, z + 8, rgb(50, 48, 52), Enum.Material.Metal)
	local brew = cylinder(f, "Brew", 0.3, 3.4, x - 2, 2.6, z + 8, rgb(120, 255, 150), Enum.Material.Neon)
	glow(brew, 14, 1, rgb(120, 255, 150))
	for _, s in { -1, 1 } do
		part(f, "RackPost", Vector3.new(0.4, 6, 0.4), CFrame.new(x - 14 + s * 4, 3, z + 4), rgb(110, 80, 50), Enum.Material.Wood)
	end
	part(f, "DryingRack", Vector3.new(8.4, 0.3, 0.3), CFrame.new(x - 14, 5.6, z + 4), rgb(110, 80, 50), Enum.Material.Wood)
	for k = 0, 4 do
		part(f, "DriedHerbs", Vector3.new(0.8, 1.6, 0.6), CFrame.new(x - 17.2 + k * 1.6, 4.6, z + 4), rgb(110 + k * 10, 150, 80), Enum.Material.Grass)
	end
end

CAMPS.shepherd = function(f, x, z, face, seed)
	K.cottage(f, x - 14, z - 12, face, seed)
	fenceRing(f, x + 10, z + 6, 13, math.pi)
	for k = 0, 3 do
		sheep(f, x + 6 + (k % 2) * 7, z + 2 + (k // 2) * 7, k * 1.3)
	end
	K.haystack(f, x - 6, z + 10, 5)
	K.well(f, x - 2, z - 2)
end

CAMPS.mine = function(f, x, z, face, seed)
	-- a timbered entrance in a heap of rock
	local base = CFrame.lookAt(Vector3.new(x, 0, z - 12), Vector3.new(x, 0, z - 12) + face)
	for k = 0, 5 do
		local a = k / 6 * math.pi
		part(f, "Crag", Vector3.new(8, 8 + hash(k + seed) * 6, 8), base * CFrame.new(math.cos(a) * 10, 4, 4 + math.sin(a) * 4) * CFrame.Angles(0, a, 0.2), rgb(120, 115, 108), Enum.Material.Slate)
	end
	part(f, "Crag", Vector3.new(18, 10, 10), base * CFrame.new(0, 5, 8), rgb(115, 110, 104), Enum.Material.Slate)
	part(f, "MineMouth", Vector3.new(7, 8, 0.4), base * CFrame.new(0, 4, 2.9), rgb(25, 22, 22))
	for _, s in { -1, 1 } do
		part(f, "MineBeam", Vector3.new(1, 9, 1), base * CFrame.new(s * 4, 4.5, 2.5), rgb(110, 80, 50), Enum.Material.Wood)
	end
	part(f, "MineLintel", Vector3.new(10, 1, 1.2), base * CFrame.new(0, 9.2, 2.5), rgb(110, 80, 50), Enum.Material.Wood)
	for k = 0, 5 do
		part(f, "Rail", Vector3.new(4.6, 0.3, 1.6), base * CFrame.new(0, 0.15, -2 - k * 1.8) * CFrame.Angles(0, math.rad(90), 0), rgb(120, 90, 60), Enum.Material.Wood)
	end
	for _, s in { -1, 1 } do
		part(f, "RailBar", Vector3.new(0.3, 0.3, 11), base * CFrame.new(s * 1.4, 0.45, -6.5), rgb(90, 90, 95), Enum.Material.Metal)
	end
	part(f, "Minecart", Vector3.new(3.4, 2.4, 4), base * CFrame.new(0, 1.8, -8), rgb(80, 75, 72), Enum.Material.Metal)
	local ore = part(f, "OreLoad", Vector3.new(2.8, 0.8, 3.4), base * CFrame.new(0, 3.2, -8), rgb(120, 235, 255), Enum.Material.Neon)
	glow(ore, 12, 1, rgb(120, 235, 255))
	K.lamp(f, x + 10, z - 2)
	tent(f, x - 14, z + 4, face, rgb(150, 110, 70))
	campfire(f, x + 2, z + 8)
	K.crate(f, x + 10, 0, z + 8, 3, 0.4)
	K.crate(f, x + 13, 0, z + 9, 2.4, 0.9)
end

CAMPS.hermit = function(f, x, z, face, _seed)
	cylinder(f, "StoneHut", 9, 14, x - 6, 4.5, z - 6, rgb(150, 145, 135), Enum.Material.Cobblestone)
	part(f, "HutRoof", Vector3.new(16, 1, 16), CFrame.new(x - 6, 9.4, z - 6) * CFrame.Angles(0, math.rad(45), 0), rgb(120, 100, 75), Enum.Material.Wood)
	part(f, "HutDoor", Vector3.new(3, 6, 0.4), CFrame.lookAt(Vector3.new(x - 6, 3, z - 6) + face * 7, Vector3.new(x - 6, 3, z - 6) + face * 8), rgb(100, 70, 45), Enum.Material.WoodPlanks)
	cairn(f, x + 10, z - 4, 0.9)
	standingStones(f, x + 4, z + 8, 9, 5)
	K.bench(f, x + 4, z + 2, face)
end

CAMPS.observatory = function(f, x, z, _face, _seed)
	cylinder(f, "Observatory", 20, 16, x - 8, 10, z - 8, rgb(220, 215, 205), Enum.Material.Marble)
	ball(f, "Dome", 17, x - 8, 20, z - 8, rgb(90, 120, 180), Enum.Material.Metal)
	cylinder(f, "Telescope", 12, 1.8, 0, 0, 0, rgb(200, 160, 70), Enum.Material.Metal).CFrame = CFrame.new(x - 4, 24, z - 4) * CFrame.Angles(0, math.rad(45), math.rad(35))
	-- a tethered balloon
	ball(f, "Balloon", 14, x + 14, 30, z - 2, rgb(230, 90, 70), Enum.Material.Fabric)
	part(f, "Basket", Vector3.new(4, 3, 4), CFrame.new(x + 14, 20, z - 2), rgb(160, 115, 70), Enum.Material.WoodPlanks)
	part(f, "Tether", Vector3.new(0.2, 20, 0.2), CFrame.new(x + 14, 10, z - 2), rgb(90, 80, 70), Enum.Material.Fabric)
	part(f, "Workbench", Vector3.new(6, 3, 3), CFrame.new(x + 2, 1.5, z + 8), rgb(130, 95, 60), Enum.Material.WoodPlanks)
	K.crate(f, x + 8, 0, z + 9, 3, 0.2)
	K.lamp(f, x - 2, z + 12)
end

CAMPS.fortcamp = function(f, x, z, face, _seed)
	tent(f, x - 8, z - 6, face, rgb(150, 50, 50))
	tent(f, x + 8, z - 8, face, rgb(150, 50, 50))
	campfire(f, x, z + 4)
	cylinder(f, "BannerPole", 14, 0.5, x + 14, 7, z + 6, rgb(80, 80, 85), Enum.Material.Metal)
	part(f, "Banner", Vector3.new(0.2, 5, 3.6), CFrame.new(x + 14, 11.5, z + 7.9), rgb(150, 40, 45), Enum.Material.Fabric)
	part(f, "WeaponRack", Vector3.new(6, 3, 0.6), CFrame.new(x - 12, 1.5, z + 8), rgb(120, 85, 55), Enum.Material.Wood)
	K.barrel(f, x + 6, z + 10)
end

CAMPS.courier = function(f, x, z, face, _seed)
	K.cart(f, x - 6, z - 4, math.atan2(face.X, face.Z), rgb(250, 240, 220))
	K.barrel(f, x + 6, z - 6)
	K.crate(f, x + 8, 0, z - 2, 2.6, 0.3)
	K.signpost(f, x + 4, z + 6, "Lost? Ask Pip!", rgb(255, 230, 150))
	campfire(f, x - 4, z + 8)
end

CAMPS.forge = function(f, x, z, face, _seed)
	local side = Vector3.new(-face.Z, 0, face.X)
	-- the furnace: a stone hearth glowing with coals
	local fx, fz = x - side.X * 10, z - side.Z * 10
	part(f, "Furnace", Vector3.new(8, 7, 8), CFrame.new(fx, 3.5, fz), rgb(70, 60, 58), Enum.Material.Basalt)
	part(f, "Chimney", Vector3.new(3, 12, 3), CFrame.new(fx, 13, fz), rgb(60, 52, 50), Enum.Material.Basalt)
	local coals = part(f, "Coals", Vector3.new(5, 0.6, 5), CFrame.new(fx, 7.3, fz), rgb(255, 110, 30), Enum.Material.Neon)
	glow(coals, 24, 1.6, rgb(255, 140, 60))
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 12
	fire.Parent = coals
	part(f, "Anvil", Vector3.new(2, 2.6, 4), CFrame.new(x + side.X * 2, 1.3, z + side.Z * 2), rgb(50, 50, 55), Enum.Material.Metal)
	part(f, "Quench", Vector3.new(4, 2, 3), CFrame.new(x + side.X * 7, 1, z + side.Z * 7), rgb(110, 80, 52), Enum.Material.WoodPlanks)
	part(f, "WeaponRack", Vector3.new(6, 3, 0.6), CFrame.new(x - face.X * 8, 1.5, z - face.Z * 8), rgb(110, 80, 52), Enum.Material.Wood)
	tent(f, x + side.X * 14 - face.X * 6, z + side.Z * 14 - face.Z * 6, face, rgb(140, 70, 50))
	K.barrel(f, x + side.X * 10 + face.X * 6, z + side.Z * 10 + face.Z * 6)
	-- a little lava pool for show (not the burning kind)
	local pool = part(f, "LavaPool", Vector3.new(7, 0.3, 5), CFrame.new(x - side.X * 4 + face.X * 9, 0.2, z - side.Z * 4 + face.Z * 9), rgb(255, 100, 30), Enum.Material.Neon)
	pool.CanCollide = false
	glow(pool, 16, 1, rgb(255, 120, 40))
end

CAMPS.guide = function(f, x, z, face, seed)
	local side = Vector3.new(-face.Z, 0, face.X)
	local sx, sz = x + side.X * 5, z + side.Z * 5
	K.signpost(f, sx, sz, "Sproutling City this way!", rgb(255, 230, 150))
	local lx, lz = x - side.X * 5, z - side.Z * 5
	K.lamp(f, lx, lz)
	K.flowerBed(f, x - face.X * 4 + side.X * 3, z - face.Z * 4 + side.Z * 3, 4, 3, seed)
end

CAMPS.skycamp = function(f, x, z, _face, seed)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		cylinder(f, "GazeboPillar", 9, 0.9, x - 8 + math.cos(a) * 6, 4.5, z - 6 + math.sin(a) * 6, rgb(245, 245, 250), Enum.Material.Marble)
	end
	cylinder(f, "GazeboFloor", 0.6, 15, x - 8, 0.3, z - 6, rgb(240, 240, 248), Enum.Material.Marble)
	ball(f, "GazeboDome", 14, x - 8, 9.4, z - 6, rgb(170, 210, 255), Enum.Material.Glass).Transparency = 0.3
	K.flowerBed(f, x + 8, z - 4, 6, 6, seed)
	K.lamp(f, x + 4, z + 6)
end

CAMPS.skyshrine = function(f, x, z, _face, seed)
	standingStones(f, x, z, 16, 7)
	cylinder(f, "Altar", 2, 8, x, 1, z, rgb(200, 205, 220), Enum.Material.Marble)
	K.crystal(f, x, 2, z, 1.2, rgb(170, 220, 255), seed, false)
end

----------------------------------------------------------------------------------------------
-- homesteads and things to find in the woods

local function homestead(f: Instance, x: number, z: number, seed: number)
	local face = towardRoad(x, z)
	local side = Vector3.new(-face.Z, 0, face.X)
	local spots = { Vector3.new(x, 0, z) - side * 18, Vector3.new(x, 0, z) + side * 16 + face * 4, Vector3.new(x, 0, z) - face * 22 + side * 2 }
	local houses = 2 + seed % 2
	for k = 1, houses do
		local p = spots[k]
		local turn = (hash(seed + k) - 0.5) * 0.8
		local dir = Vector3.new(face.X * math.cos(turn) - face.Z * math.sin(turn), 0, face.X * math.sin(turn) + face.Z * math.cos(turn))
		onGround(f, p.X, p.Z, 10, function(t)
			K.cottage(t, p.X, p.Z, dir, seed * 3 + k, if hash(seed + k * 2) < 0.3 then 2 else 1)
		end)
	end
	-- a patch of crops, a well or haystack and a lamp
	local fx, fz = x + face.X * 18 + side.X * 2, z + face.Z * 18 + side.Z * 2
	local fh = L.height(fx, fz)
	local crops = { rgb(240, 200, 70), rgb(80, 170, 70), rgb(245, 140, 40) }
	part(f, "Field", Vector3.new(22, 1, 14), CFrame.lookAt(Vector3.new(fx, fh - 0.3, fz), Vector3.new(fx, fh - 0.3, fz) + face), rgb(110, 80, 55), Enum.Material.Ground)
	for r = 0, 2 do
		part(f, "CropRow", Vector3.new(20, 0.8, 1.6), CFrame.lookAt(Vector3.new(fx, fh + 0.5, fz), Vector3.new(fx, fh + 0.5, fz) + face) * CFrame.new(0, 0, (r - 1) * 4), crops[(seed + r) % 3 + 1], Enum.Material.Grass)
	end
	local wx, wz = x + face.X * 2 + side.X * 2, z + face.Z * 2 + side.Z * 2
	onGround(f, wx, wz, 4, function(t)
		if seed % 2 == 0 then
			K.well(t, wx, wz)
		else
			K.haystack(t, wx, wz, 5)
		end
	end)
	local lx, lz = x + side.X * 6, z + side.Z * 6
	raised(f, L.height(lx, lz), function(t)
		K.lamp(t, lx, lz)
	end)
end

local DECOR = { "campsite", "mushrooms", "log", "stones", "wagon", "shrine" }

local function decor(f: Instance, kind: string, x: number, z: number, seed: number)
	local h = L.height(x, z)
	raised(f, h - 0.3, function(t)
		if kind == "campsite" then
			tent(t, x - 5, z, towardRoad(x, z), rgb(120 + seed % 3 * 30, 90, 70))
			campfire(t, x + 4, z + 3)
		elseif kind == "mushrooms" then
			for k = 0, 8 do
				local a = k / 9 * math.pi * 2
				local mx, mz = x + math.cos(a) * 6, z + math.sin(a) * 6
				cylinder(t, "MushroomStem", 1.4, 0.6, mx, 0.7, mz, rgb(240, 235, 220))
				local cap = ball(t, "MushroomCap", 1.6, mx, 1.6, mz, if k % 2 == 0 then rgb(220, 60, 60) else rgb(200, 150, 255), Enum.Material.SmoothPlastic)
				cap.Size = Vector3.new(1.8, 0.9, 1.8)
			end
		elseif kind == "log" then
			local log = cylinder(t, "FallenLog", 1, 2.6, 0, 0, 0, rgb(110, 80, 52), Enum.Material.Wood)
			log.Size = Vector3.new(16, 2.6, 2.6)
			log.CFrame = CFrame.new(x, 1.1, z) * CFrame.Angles(0, seed, 0)
			ball(t, "Moss", 2.4, x + 2, 2.2, z, rgb(80, 140, 60), Enum.Material.Grass)
		elseif kind == "stones" then
			standingStones(t, x, z, 8, 6)
		elseif kind == "wagon" then
			part(t, "BrokenWagon", Vector3.new(5, 1, 8), CFrame.new(x, 1.2, z) * CFrame.Angles(0, seed, math.rad(12)), rgb(140, 100, 65), Enum.Material.WoodPlanks)
			local wheel = cylinder(t, "LooseWheel", 0.5, 4, x + 4, 0.3, z + 2, rgb(110, 75, 50), Enum.Material.Wood)
			wheel.CFrame = CFrame.new(x + 4, 0.3, z + 2)
			K.crate(t, x - 4, 0, z - 3, 2.4, 0.6)
		else
			part(t, "ShrineStone", Vector3.new(3, 5, 2), CFrame.new(x, 2.5, z), rgb(170, 165, 160), Enum.Material.Slate)
			local rune = part(t, "ShrineRune", Vector3.new(1.4, 1.4, 0.2), CFrame.new(x, 3.4, z - 1.05), rgb(150, 230, 180), Enum.Material.Neon)
			glow(rune, 10, 0.8, rgb(150, 230, 180))
			K.flowerBed(t, x, z + 3, 4, 2, seed)
		end
	end)
end

----------------------------------------------------------------------------------------------
-- quest items

local function questItem(f: Instance, item: string, id: string, x: number, y: number, z: number, seed: number)
	local m = model(f, Q.Items[item].name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local color = c3(Q.Items[item].color)
	if item == "satchel" then
		part(m, "Satchel", Vector3.new(2.4, 1.6, 1.4), CFrame.new(x, y + 0.8, z) * CFrame.Angles(0, seed, 0.2), color, Enum.Material.Fabric)
		part(m, "Strap", Vector3.new(0.3, 0.2, 3), CFrame.new(x, y + 1.7, z) * CFrame.Angles(0, seed, 0), rgb(90, 60, 40), Enum.Material.Fabric)
	elseif item == "amber" then
		part(m, "Driftwood", Vector3.new(4, 1, 1), CFrame.new(x, y + 0.5, z) * CFrame.Angles(0, seed, 0), rgb(120, 85, 55), Enum.Material.Wood)
		ball(m, "Amber", 1.6, x, y + 1.3, z, color, Enum.Material.Neon)
	elseif item == "ghostcap" then
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2 + seed
			cylinder(m, "Stem", 1.2, 0.5, x + math.cos(a), y + 0.6, z + math.sin(a), rgb(235, 240, 245))
			local cap = ball(m, "Cap", 1.4, x + math.cos(a), y + 1.3, z + math.sin(a), color, Enum.Material.Neon)
			cap.Size = Vector3.new(1.6, 0.8, 1.6)
		end
	elseif item == "lamb" then
		raised(m, y, function(t)
			sheep(t, x, z, seed)
		end)
	elseif item == "glowstone" then
		part(m, "Rock", Vector3.new(4, 3, 3.4), CFrame.new(x, y + 1.2, z) * CFrame.Angles(0.2, seed, 0.1), rgb(110, 108, 104), Enum.Material.Slate)
		part(m, "Vein", Vector3.new(1.2, 2.4, 1.2), CFrame.new(x + 0.8, y + 2.2, z) * CFrame.Angles(0, seed, 0.4), color, Enum.Material.Neon)
	elseif item == "relic" then
		part(m, "RelicStone", Vector3.new(2.4, 0.8, 2.4), CFrame.new(x, y + 0.4, z), rgb(150, 145, 140), Enum.Material.Cobblestone)
		cylinder(m, "Relic", 0.3, 1.4, 0, 0, 0, color, Enum.Material.Metal).CFrame = CFrame.new(x, y + 1.6, z) * CFrame.Angles(0, seed, 0)
	else -- shard
		part(m, "Shard", Vector3.new(1, 2.6, 1), CFrame.new(x, y + 1.4, z) * CFrame.Angles(0.3, seed, 0.2), color, Enum.Material.Neon)
	end
	local node = marker(m, "QuestNode", Vector3.new(x, y, z), { QuestItem = item, QuestNodeId = id })
	node.Size = Vector3.new(3, 3, 3)
	local sparkle = ball(m, "Sparkle", 0.6, x, y + 3.4, z, color, Enum.Material.Neon)
	sparkle.CanCollide = false
	glow(sparkle, 12, 1.2, color)
end

----------------------------------------------------------------------------------------------

-- A waystone: a carved obelisk with a rune (grey until attuned; the client lights it) and a
-- floating crystal. The anchor part carries Waystone (id) for WaystoneService's prompt.
local function waystone(parent: Instance, w: any, x: number, y: number, z: number)
	local m = model(parent, "Waystone_" .. w.id)
	m:SetAttribute("Waystone", w.id)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local stone = rgb(170, 175, 190)
	cylinder(m, "WaystoneBase", 1.2, 9, x, y + 0.2, z, rgb(120, 125, 135), Enum.Material.Slate)
	part(m, "Obelisk", Vector3.new(3.2, 7, 3.2), CFrame.new(x, y + 4.3, z), stone, Enum.Material.Slate)
	part(m, "ObeliskTop", Vector3.new(2.2, 3, 2.2), CFrame.new(x, y + 9.3, z) * CFrame.Angles(0, math.rad(45), 0), stone, Enum.Material.Slate)
	for _, a in { 0, 90, 180, 270 } do
		local dir = CFrame.Angles(0, math.rad(a), 0).LookVector
		local rune = part(m, "Rune", Vector3.new(1.4, 2.4, 0.2), CFrame.lookAt(Vector3.new(x, y + 4.8, z) + dir * 1.62, Vector3.new(x, y + 4.8, z) + dir * 3), rgb(110, 110, 120), Enum.Material.Neon)
		rune.CanCollide = false
	end
	local crystal = part(m, "WayCrystal", Vector3.new(1.4, 2.2, 1.4), CFrame.new(x, y + 12.6, z) * CFrame.Angles(0, math.rad(45), math.rad(15)), rgb(150, 210, 255), Enum.Material.Neon)
	crystal.CanCollide = false
	glow(crystal, 18, 1.2, rgb(150, 210, 255))
	local anchor = marker(m, "WaystoneAnchor", Vector3.new(x, y, z), { Waystone = w.id, WaystoneName = w.name, WaystoneRegion = w.region })
	anchor.Size = Vector3.new(6, 6, 6)
	m.PrimaryPart = anchor
	-- a name over the stone
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(200, 40)
	tag.StudsOffset = Vector3.new(0, 15, 0)
	tag.MaxDistance = 120
	tag.LightInfluence = 0
	tag.Parent = anchor
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = rgb(190, 225, 255)
	text.TextStrokeTransparency = 0.3
	text.Text = "Waystone: " .. w.name
	text.Parent = tag
end

function WildsBuilder.Build(map: Instance, landscape: any, quests: any, kit: any, waystones: any?): Instance
	local existing = map:FindFirstChild("Wilds")
	if existing then
		existing:Destroy()
	end
	L, Q, K, WS = landscape, quests, kit, waystones
	counter = 0
	table.clear(taken)
	local wilds = Instance.new("Folder")
	wilds.Name = "Wilds"

	local camps = folder(wilds, "Camps")
	local items = folder(wilds, "QuestItems")
	local shrines = folder(wilds, "WindShrines")
	local skyFolder = folder(wilds, "SkyIsles")
	local npcPos: { [string]: Vector3 } = {}

	-- the named sky isles: where their top surface is
	local isles: { [string]: any } = {}
	for _, it in L.SkyIslets do
		if it.name then
			isles[it.name] = it
		end
	end

	-- quest givers and their camps
	local ids = {}
	for id in Q.Npcs do
		table.insert(ids, id)
	end
	table.sort(ids)
	for i, id in ids do
		local npc = Q.Npcs[id]
		local builder = CAMPS[npc.camp]
		if npc.fixed then
			-- placed by hand (the guide by the island's bridge to the city)
			local p, face = npc.fixed, Vector3.new(npc.facing[1], 0, npc.facing[2]).Unit
			local f = folder(camps, npc.camp .. "_" .. id)
			if builder then
				builder(f, p[1], p[3], face, i)
				lift(f, p[2])
			end
			person(f, npc, p[1], p[2], p[3], face)
			npcPos[id] = Vector3.new(p[1], p[2], p[3])
		elseif npc.isle then
			local it = isles[npc.isle]
			if it then
				local x, z, y = it.x + it.r * 0.25, it.z - it.r * 0.2, it.y + 1.5
				local f = folder(skyFolder, npc.camp .. "_" .. id)
				raised(f, y, function(t)
					builder(t, x, z, Vector3.new(0, 0, 1), i)
				end)
				person(f, npc, x + 2, y, z + 6, Vector3.new(0, 0, 1))
				npcPos[id] = Vector3.new(x, y, z)
			end
		else
			local x, z, h
			local site = npc.site and L.Sites[npc.site]
			if site then
				-- mountain camps stand on their own levelled plateau (Landscape.SiteList)
				x, z, h = site.x, site.z, site.h
				table.insert(taken, { x, z, site.r })
			else
				x, z, h = findSpot(npc.near[1], npc.near[2], { radius = 26, maxRange = 6, search = 18 })
			end
			if x and z and h then
				local face = towardRoad(x, z)
				local f = folder(camps, npc.camp .. "_" .. id)
				onGround(f, x, z, 24, function(t)
					builder(t, x, z, face, i)
				end)
				local _, hi = groundRange(x, z, 24)
				local px, pz = x + face.X * 12, z + face.Z * 12
				person(f, npc, px, hi, pz, face)
				npcPos[id] = Vector3.new(x, hi, z)
			else
				print("[WildsBuilder] no room for " .. npc.name)
			end
		end
	end

	-- enemy camps for the quests
	for _, c in Q.Camps do
		if c.isle then
			local it = isles[c.isle]
			if it then
				local y = it.y + 1.5
				local pos = if c.boss then Vector3.new(it.x - it.r * 0.25, y, it.z + it.r * 0.25) else Vector3.new(it.x, y, it.z)
				marker(skyFolder, "EnemyCamp", pos, { CampKind = c.kind, CampCount = c.count, CampSpread = it.r * 0.35, CampLeash = it.r * 0.9, Sky = true })
			end
		else
			local home = npcPos[c.npc]
			if home then
				local x, z, h = findSpot(home.X + c.offset[1], home.Z + c.offset[2], { radius = 14, maxRange = 10, search = 8 })
				if x and z and h then
					marker(camps, "EnemyCamp", Vector3.new(x, h, z), { CampKind = c.kind, CampCount = c.count, CampSpread = 10, CampLeash = 80 })
				end
			end
		end
	end

	-- quest items scattered round each camp, and across the sky isles
	local nodeCount = 0
	for _, spot in Q.ItemSpots do
		if spot.isles then
			for name, it in isles do
				for k = 1, spot.perIsle do
					nodeCount += 1
					local a = rand() * math.pi * 2
					local d = it.r * (0.35 + rand() * 0.35)
					questItem(items, spot.item, string.format("%s_%s_%d", spot.item, name, k), it.x + math.cos(a) * d, it.y + 1.5, it.z + math.sin(a) * d, nodeCount)
				end
			end
		else
			local home = npcPos[spot.npc]
			if home then
				for k = 1, spot.count do
					nodeCount += 1
					local a = rand() * math.pi * 2
					local d = 50 + rand() * (spot.spread - 50)
					local x, z, h = findSpot(home.X + math.cos(a) * d, home.Z + math.sin(a) * d, { radius = 3, maxRange = 3, search = 6, roadMargin = 3 })
					if x and z and h then
						questItem(items, spot.item, string.format("%s_%d", spot.item, k), x, h - 0.2, z, nodeCount)
					end
				end
			end
		end
	end

	-- the peak cairns Oswin sends you to
	-- (spots with `find` mark a place another builder made, e.g. the city's market square)
	local found: { [string]: Vector3 } = {}
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			for id, spot in Q.Spots do
				if spot.find and not found[id] and d:GetAttribute(spot.find[1]) == spot.find[2] then
					found[id] = d.CFrame.Position
				end
			end
		end
	end
	for id, spot in Q.Spots do
		if spot.find then
			local p = found[id]
			if p then
				marker(camps, "QuestSpot", p - Vector3.new(0, 1.5, 0), { QuestSpot = id, SpotName = spot.name })
			end
		else
			local x, z, h = findPeak(spot.near[1], spot.near[2], 160)
			local f = folder(camps, "Cairn_" .. id)
			raised(f, h - 0.5, function(t)
				cairn(t, x, z, 1.6)
			end)
			marker(f, "QuestSpot", Vector3.new(x, h, z), { QuestSpot = id, SpotName = spot.name })
		end
	end

	-- wind shrines on the ground below each named isle, and the isles' own pieces
	for name, it in isles do
		local x, z, h = findSpot(it.x, it.z, { radius = 14, maxRange = 6, search = 20 })
		if x and z and h then
			local f = folder(shrines, name)
			onGround(f, x, z, 12, function(t)
				windShrine(t, x, z, name)
			end)
			raised(f, L.height(x + 13, z + 13), function(t)
				K.signpost(t, x + 13, z + 13, name, rgb(190, 230, 255))
			end)
		end
		local y = it.y + 1.5
		local f = folder(skyFolder, name)
		marker(f, "SkyLanding", Vector3.new(it.x, y, it.z + it.r * 0.4), { SkyLanding = name })
		-- the wind stone takes you back down
		local sx, sz = it.x - it.r * 0.35, it.z + it.r * 0.45
		part(f, "WindStone", Vector3.new(3, 7, 3), CFrame.new(sx, y + 3.5, sz), rgb(220, 225, 235), Enum.Material.Marble)
		local rune = part(f, "WindRune", Vector3.new(1.6, 1.6, 0.3), CFrame.new(sx, y + 4.5, sz - 1.6), rgb(150, 220, 255), Enum.Material.Neon)
		glow(rune, 14, 1, rgb(150, 220, 255))
		marker(f, "WindStoneAnchor", Vector3.new(sx, y, sz - 2.5), { WindStone = name })
		-- a sky cache, once per player
		local cx, cz = it.x + it.r * 0.4, it.z - it.r * 0.4
		chest(f, cx, y, cz, 0.6)
		marker(f, "SkyCacheAnchor", Vector3.new(cx, y, cz), { SkyCache = name })
	end

	-- waystones: fast-travel checkpoints (Shared/Waystones)
	if WS then
		local wf = folder(wilds, "Waystones")
		local markers: { [string]: Vector3 } = {}
		for _, d in map:GetDescendants() do
			if d:IsA("BasePart") then
				for _, w in WS.List do
					if w.find and not markers[w.id] and d:GetAttribute(w.find[1]) == w.find[2] then
						markers[w.id] = d.CFrame.Position
					end
				end
			end
		end
		for _, w in WS.List do
			if w.at then
				waystone(wf, w, w.at[1], w.at[2], w.at[3])
			elseif w.isle then
				local it = isles[w.isle]
				if it then
					waystone(wf, w, it.x - it.r * 0.45, it.y + 1.5, it.z - it.r * 0.1)
				end
			elseif w.find then
				local p = markers[w.id]
				if p then
					-- beside the marker, not on top of it
					local x, z = p.X + 10, p.Z + 6
					waystone(wf, w, x, p.Y - 1, z)
				end
			elseif w.site then
				local s = L.Sites[w.site]
				if s then
					local x, z, h = findSpot(s.x + (w.dx or 0), s.z + (w.dz or 0), { radius = 6, maxRange = 3, search = 6, roadMargin = 3, minHeight = -10, allowSite = w.onSite })
					if x and z and h then
						waystone(wf, w, x, h - 0.2, z)
					else
						print("[WildsBuilder] no room for waystone " .. w.name)
					end
				end
			end
		end
	end

	-- homesteads in the open clearings
	local homes = folder(wilds, "Homesteads")
	local wanted = {
		{ -700, -100 }, { -620, 620 }, { -820, 1050 }, { -250, 1350 }, { 330, 1250 }, { 560, 560 },
		{ 720, 120 }, { -150, -820 }, { 180, -760 }, { -1050, 650 }, { 900, 1350 }, { -560, 1150 },
		{ 250, 1850 }, { -100, 2000 },
	}
	-- and extensions round the existing villages
	for _, name in { "hamletWest", "hamletEast", "southvale", "eastmere", "pinecrest", "farm" } do
		local site = L.Sites[name]
		if site then
			table.insert(wanted, { site.x + 110, site.z + 40 })
			table.insert(wanted, { site.x - 90, site.z - 80 })
		end
	end
	for k, w in wanted do
		local x, z = findSpot(w[1], w[2], { radius = 32, maxRange = 10, search = 16 })
		if x and z then
			homestead(folder(homes, "Homestead" .. k), x, z, k)
		end
	end

	-- things to stumble on in the forests and hills
	local wild = folder(wilds, "Discoveries")
	local placed = 0
	local i = 0
	while placed < 90 and i < 1400 do
		i += 1
		local x = L.Bounds.x0 + rand() * (L.Bounds.x1 - L.Bounds.x0)
		local z = L.Bounds.z0 + rand() * (L.Bounds.z1 - L.Bounds.z0)
		if L.height(x, z) > 4 then
			local px, pz = findSpot(x, z, { radius = 12, maxRange = 4, search = 2 })
			if px and pz then
				placed += 1
				decor(wild, DECOR[placed % #DECOR + 1], px, pz, placed)
			end
		end
	end

	wilds.Parent = map
	return wilds
end

return WildsBuilder
