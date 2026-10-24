--!strict
-- Builds the dungeons: The Hollow Crypt (six rooms, reached through a stairway in the hilltop
-- castle's courtyard) and The Deepdelve Mines (below Gorrim's mountain camp, level 12+).
-- Geometry plus named markers only; DungeonService adds the behaviour (teleports, room
-- clearing, doors, chests, the boss). Each dungeon is the same shape of markers under its own
-- root folder (Map.Dungeon for the crypt, Map.Mines for the mines); see DungeonBuilder.Dungeons.
--
-- Service-free like MapBuilder (runs at server start and offline under Lune). The crypt sits far
-- below the world at ORIGIN; players are teleported in and out, so it never shows from above.
--
-- Markers under Map.Dungeon:
--   Crypt/Spawns/Spawn      attributes Room (number), Kind (enemy id)
--   Crypt/Doors/Door<i>     model whose PrimaryPart "Gate" blocks the way from room i to i+1
--   Crypt/Chests/Chest      attributes Chest ("vault" | "boss"), Room; prompt goes on "Base"
--   Crypt/EntryPad          where players arrive;  Crypt/ExitPortal  back to the castle
--   Crypt/BossExit          portal out of the boss room (DungeonService shows it after the kill)
--   Entrance/CryptPortal    the portal in the castle courtyard;  Entrance/ReturnPoint
-- Every room part also carries Room = i in Crypt/Rooms/Room<i> for anything that needs bounds.

local DungeonBuilder = {}

local Instance = Instance
local Vector3 = Vector3
local CFrame = CFrame
local Color3 = Color3
local Enum = Enum
local UDim2 = UDim2

function DungeonBuilder.useApi(api: any)
	Instance = api.Instance
	Vector3 = api.Vector3
	CFrame = api.CFrame
	Color3 = api.Color3
	Enum = api.Enum
	UDim2 = api.UDim2
end

DungeonBuilder.Origin = { x = -500, y = -400, z = 60 }

-- Each dungeon: where it sits (far below the world), its rooms in order (spawns are
-- { kind, count }; the boss kind is placed on the dais), its look, and its entrance.
DungeonBuilder.Dungeons = {
	{
		id = "crypt",
		root = "Dungeon",
		interior = "Crypt",
		portal = "CryptPortal",
		title = "The Hollow Crypt",
		minLevel = 1,
		origin = { x = -500, y = -400, z = 60 },
		theme = "crypt",
		entrance = { site = "castle", dx = 0, dz = 27 },
		rooms = {
			{ name = "Entry Hall", w = 44, d = 40, spawns = {} },
			{ name = "Crypt Hall", w = 64, d = 46, spawns = { { "skeleton", 4 } }, sarcophagi = true },
			{ name = "Bat Cavern", w = 58, d = 58, spawns = { { "bat", 5 }, { "skeleton", 2 } }, pillars = true },
			{ name = "Ossuary", w = 64, d = 46, spawns = { { "skeleton", 5 }, { "bat", 2 } }, niches = true },
			{ name = "Treasure Vault", w = 34, d = 30, spawns = {}, chest = "vault" },
			{ name = "Warden's Chamber", w = 84, d = 84, spawns = { { "warden", 1 } }, chest = "boss", boss = "warden" },
		},
	},
	{
		id = "mines",
		root = "Mines",
		interior = "Depths",
		portal = "MinePortal",
		title = "The Deepdelve Mines",
		minLevel = 12,
		origin = { x = 600, y = -420, z = -1200 },
		theme = "mines",
		entrance = { site = "minecamp", dx = -24, dz = 22 },
		rooms = {
			{ name = "Mine Mouth", w = 44, d = 40, spawns = {}, timbers = true },
			{ name = "Collapsed Gallery", w = 62, d = 50, spawns = { { "golem", 3 } }, timbers = true, rails = true },
			{ name = "Glowstone Cavern", w = 64, d = 64, spawns = { { "bat", 5 }, { "golem", 1 } }, pillars = true, crystals = true },
			{ name = "Lost Miners' Rest", w = 60, d = 48, spawns = { { "skeleton", 5 }, { "golem", 2 } }, timbers = true, rails = true },
			{ name = "Ore Vault", w = 36, d = 30, spawns = {}, chest = "vault", crystals = true },
			{ name = "Heart of the Mountain", w = 90, d = 90, spawns = { { "cragking", 1 } }, chest = "boss", boss = "cragking", crystals = true },
		},
	},
	{
		id = "emberdeep",
		root = "Emberdeep",
		interior = "Caldera",
		portal = "EmberPortal",
		title = "The Emberdeep Caldera",
		minLevel = 20,
		origin = { x = -1300, y = -440, z = 400 },
		theme = "fire",
		entrance = { site = "emberpeak", dx = 26, dz = -22 },
		rooms = {
			{ name = "Scorched Entry", w = 48, d = 42, spawns = {}, lavaPools = true },
			{ name = "Ash Gallery", w = 72, d = 56, spawns = { { "emberimp", 6 } }, obsidian = true },
			{ name = "River of Fire", w = 84, d = 72, spawns = { { "magmahound", 3 }, { "emberimp", 3 } }, lavaRiver = true },
			{ name = "Obsidian Hall", w = 76, d = 76, spawns = { { "cinderwraith", 4 }, { "emberimp", 2 } }, obsidian = true, lavaPools = true },
			{ name = "Forge of the Deep", w = 80, d = 62, spawns = { { "emberimp", 4 }, { "magmahound", 2 }, { "cinderwraith", 2 } }, forge = true },
			{ name = "Ember Vault", w = 42, d = 34, spawns = {}, chest = "vault", lavaPools = true },
			{ name = "Magma Lake", w = 90, d = 88, spawns = { { "magmahound", 4 }, { "cinderwraith", 3 } }, lavaRiver = true, lavaPools = true },
			{ name = "Pyrrhax's Caldera", w = 120, d = 116, spawns = { { "pyrrhax", 1 } }, chest = "boss", boss = "pyrrhax", calderaRing = true },
		},
	},
}
DungeonBuilder.Rooms = DungeonBuilder.Dungeons[1].rooms

local H = 24 -- room height
local WALL = 3
local CORRIDOR = 18
local OPENING = 16

----------------------------------------------------------------------------------------------
-- helpers

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: any?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function box(parent: Instance, name: string, x: number, y0: number, z: number, sx: number, sy: number, sz: number, color: Color3, material: any?): BasePart
	return part(parent, name, Vector3.new(sx, sy, sz), CFrame.new(x, y0 + sy / 2, z), color, material)
end

local function cylinder(parent: Instance, name: string, height: number, diameter: number, x: number, y: number, z: number, color: Color3, material: any?): BasePart
	local p = part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent: Instance, name: string, d: number, x: number, y: number, z: number, color: Color3, material: any?): BasePart
	local p = part(parent, name, Vector3.new(d, d, d), CFrame.new(x, y, z), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function marker(parent: Instance, name: string, x: number, y: number, z: number): BasePart
	local p = part(parent, name, Vector3.new(2, 1, 2), CFrame.new(x, y, z), rgb(255, 255, 255))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function light(parent: Instance, range: number, brightness: number, color: Color3)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = color
	l.Parent = parent
end

local function sign(target: BasePart, text: string, color: Color3, face: any)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Fantasy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
end

-- Colours, built once Color3 is available (Lune passes it in via useApi).
local STONE: Color3, DARK: Color3, FLOOR: Color3, BONE: Color3, MOSS: Color3, FLAME: Color3, GLOW: Color3
local THEME = "crypt"
local LAVA: Color3

local function initColors(theme: string?)
	THEME = theme or "crypt"
	LAVA = rgb(255, 100, 30)
	if theme == "fire" then
		STONE = rgb(58, 48, 46)
		DARK = rgb(38, 32, 32)
		FLOOR = rgb(66, 54, 50)
		MOSS = rgb(90, 80, 78)
		GLOW = rgb(255, 130, 40)
	elseif theme == "mines" then
		STONE = rgb(110, 96, 82)
		DARK = rgb(72, 62, 54)
		FLOOR = rgb(96, 82, 68)
		MOSS = rgb(90, 120, 80)
		GLOW = rgb(110, 230, 255)
	else
		STONE = rgb(92, 88, 98)
		DARK = rgb(64, 60, 70)
		FLOOR = rgb(78, 74, 80)
		MOSS = rgb(70, 110, 60)
		GLOW = rgb(200, 140, 255)
	end
	BONE = rgb(232, 226, 210)
	FLAME = rgb(255, 160, 70)
end

local function torch(parent: Instance, x: number, y: number, z: number, out: Vector3, lit: boolean)
	box(parent, "TorchBracket", x, y - 1, z, 0.8, 1.6, 0.8, rgb(50, 50, 55), Enum.Material.Metal)
	local flame = ball(parent, "TorchFlame", 1.2, x + out.X * 0.6, y + 0.9, z + out.Z * 0.6, FLAME, Enum.Material.Neon)
	flame.CanCollide = false
	local fire = Instance.new("Fire")
	fire.Size = 2.5
	fire.Heat = 6
	fire.Color = rgb(255, 150, 60)
	fire.SecondaryColor = rgb(255, 220, 120)
	fire.Parent = flame
	if lit then
		light(flame, 26, 1.6, rgb(255, 170, 90))
	end
end

local function brazier(parent: Instance, x: number, y: number, z: number)
	cylinder(parent, "BrazierStand", 4, 1.2, x, y + 2, z, rgb(50, 50, 55), Enum.Material.Metal)
	cylinder(parent, "BrazierBowl", 1.4, 4, x, y + 4.6, z, rgb(60, 55, 55), Enum.Material.Metal)
	local coals = cylinder(parent, "BrazierCoals", 0.4, 3.4, x, y + 5.3, z, rgb(255, 110, 40), Enum.Material.Neon)
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 9
	fire.Color = rgb(255, 120, 40)
	fire.SecondaryColor = rgb(255, 210, 90)
	fire.Parent = coals
	light(coals, 34, 1.8, rgb(255, 150, 70))
end

local function bonePile(parent: Instance, x: number, y: number, z: number, seed: number)
	for k = 0, 5 do
		local a = k * 1.7 + seed
		local p = part(parent, "Bone", Vector3.new(0.5, 0.5, 2.4), CFrame.new(x + math.cos(a) * 1.2, y + 0.3 + (k % 2) * 0.4, z + math.sin(a) * 1.2) * CFrame.Angles(0, a, 0.3), BONE, Enum.Material.SmoothPlastic)
		p.CanCollide = false
	end
	ball(parent, "Skull", 1.3, x + 0.4, y + 0.9, z - 0.3, BONE)
end

local function cobweb(parent: Instance, x: number, y: number, z: number, turn: number)
	local w = part(parent, "Cobweb", Vector3.new(6, 6, 0.1), CFrame.new(x, y, z) * CFrame.Angles(0, turn, math.rad(45)), rgb(230, 230, 235), Enum.Material.Fabric)
	w.Transparency = 0.7
	w.CanCollide = false
	w.CastShadow = false
end

-- A lava slab on the floor: walkable, but it sets you burning (Hazard = "fire", HazardService).
local function lava(parent: Instance, x: number, y: number, z: number, sx: number, sz: number): BasePart
	local p = part(parent, "Lava", Vector3.new(sx, 0.4, sz), CFrame.new(x, y + 0.2, z), LAVA, Enum.Material.Neon)
	p:SetAttribute("Hazard", "fire")
	light(p, math.min(30, math.max(sx, sz) + 8), 1.2, LAVA)
	return p
end

----------------------------------------------------------------------------------------------
-- rooms

local function room(f: Instance, index: number, plan: any, cx: number, y: number, cz: number, last: boolean)
	local w, d = plan.w, plan.d
	local r = folder(f, "Room" .. index)
	r:SetAttribute("Room", index)
	r:SetAttribute("RoomName", plan.name)
	box(r, "Floor", cx, y - 2, cz, w + WALL * 2, 2, d + WALL * 2, FLOOR, Enum.Material.Slate)
	box(r, "Ceiling", cx, y + H, cz, w + WALL * 2, 2, d + WALL * 2, DARK, Enum.Material.Cobblestone)
	-- side walls
	for _, s in { -1, 1 } do
		box(r, "Wall", cx + s * (w / 2 + WALL / 2), y, cz, WALL, H, d + WALL * 2, STONE, Enum.Material.Cobblestone)
	end
	-- end walls, with an opening where a corridor joins (front = -z, back = +z)
	for _, e in { { -1, index > 0 }, { 1, not last } } do
		local ez = cz + e[1] * (d / 2 + WALL / 2)
		if e[2] then
			local side = (w - OPENING) / 2
			for _, s in { -1, 1 } do
				box(r, "Wall", cx + s * (OPENING / 2 + side / 2), y, ez, side, H, WALL, STONE, Enum.Material.Cobblestone)
			end
			box(r, "Lintel", cx, y + 16, ez, OPENING, H - 16, WALL, DARK, Enum.Material.Cobblestone)
		else
			box(r, "Wall", cx, y, ez, w, H, WALL, STONE, Enum.Material.Cobblestone)
		end
	end
	-- floor trim, moss and torches along the side walls
	for _, s in { -1, 1 } do
		box(r, "Trim", cx + s * (w / 2 - 0.5), y, cz, 1, 1, d, DARK, Enum.Material.Cobblestone)
		local n = math.max(1, math.floor(d / 16))
		for k = 1, n do
			local tz = cz - d / 2 + k * d / (n + 1)
			torch(r, cx + s * (w / 2 - 0.4), y + 9, tz, Vector3.new(-s, 0, 0), k == 1 or k == n)
		end
		box(r, "Moss", cx + s * (w / 2 - 0.2), y + 3, cz + s * d / 5, 0.3, 4, d / 3, MOSS, Enum.Material.Grass)
	end
	if THEME ~= "fire" then
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			cobweb(r, cx + c[1] * (w / 2 - 2), y + H - 3, cz + c[2] * (d / 2 - 2), c[1] * c[2] * math.rad(45))
		end
	end
	bonePile(r, cx - w / 3, y, cz + d / 3, index)
	bonePile(r, cx + w / 3, y, cz - d / 4, index + 5)
	if plan.sarcophagi then
		for k = -1, 1 do
			for _, s in { -1, 1 } do
				local sx, sz = cx + s * (w / 2 - 8), cz + k * 12
				box(r, "Sarcophagus", sx, y, sz, 5, 3.4, 10, rgb(140, 132, 125), Enum.Material.Marble)
				box(r, "SarcophagusLid", sx, y + 3.4, sz, 5.6, 0.8, 10.6, rgb(160, 152, 140), Enum.Material.Marble)
			end
		end
	end
	if plan.pillars then
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, 0 } } do
			if c[1] ~= 0 then
				cylinder(r, "Pillar", H, 5, cx + c[1] * w / 4, y + H / 2, cz + c[2] * d / 4, STONE, Enum.Material.Rock)
			end
		end
		for k = 0, 6 do
			local a = k * 0.9
			ball(r, "Rubble", 2 + (k % 3), cx + math.cos(a) * w / 3, y + 0.6, cz + math.sin(a) * d / 3, DARK, Enum.Material.Rock)
		end
		-- stalactites
		for k = 0, 8 do
			local a = k * 0.7
			local tip = part(r, "Stalactite", Vector3.new(1.4, 5, 1.4), CFrame.new(cx + math.cos(a) * w / 3.2, y + H - 2.5, cz + math.sin(a) * d / 3.2), DARK, Enum.Material.Rock)
			tip.CanCollide = false
		end
	end
	if plan.timbers then
		-- mine supports: posts and a cross-beam every few metres
		local n = math.max(2, math.floor(d / 12))
		for k = 1, n do
			local tz = cz - d / 2 + k * d / (n + 1)
			for _, s in { -1, 1 } do
				box(r, "SupportPost", cx + s * (w / 2 - 2), y, tz, 1.6, H - 2, 1.6, rgb(110, 80, 52), Enum.Material.Wood)
			end
			box(r, "SupportBeam", cx, y + H - 3, tz, w - 2, 1.6, 1.8, rgb(100, 72, 48), Enum.Material.Wood)
		end
	end
	if plan.rails then
		for _, s in { -1, 1 } do
			box(r, "Rail", cx + s * 1.6, y, cz, 0.4, 0.4, d - 4, rgb(90, 90, 95), Enum.Material.Metal)
		end
		local n = math.floor(d / 3)
		for k = 0, n - 1 do
			local sleeper = box(r, "Sleeper", cx, y - 0.1, cz - d / 2 + 2 + k * 3, 5, 0.3, 1.2, rgb(110, 80, 52), Enum.Material.Wood)
			sleeper.CanCollide = false
		end
		box(r, "Minecart", cx, y + 0.6, cz + d / 5, 4, 3, 5, rgb(80, 74, 70), Enum.Material.Metal)
		local ore = box(r, "Ore", cx, y + 3.4, cz + d / 5, 3.4, 0.8, 4.4, GLOW, Enum.Material.Neon)
		ore.CanCollide = false
	end
	if plan.crystals then
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2 + index
			local px, pz = cx + math.cos(a) * (w / 2 - 5), cz + math.sin(a) * (d / 2 - 5)
			for j = 0, 2 do
				local shard = part(r, "Crystal", Vector3.new(1.4, 4 + j * 2, 1.4), CFrame.new(px + (j - 1) * 1.4, y + 2 + j, pz) * CFrame.Angles(0.2 * (j - 1), a, 0.25 * (j - 1)), GLOW, Enum.Material.Neon)
				shard.CanCollide = false
				if j == 1 and k % 2 == 0 then
					light(shard, 24, 1.2, GLOW)
				end
			end
		end
	end
	if plan.lavaPools then
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			lava(r, cx + c[1] * w / 3.2, y, cz + c[2] * d / 3.4, math.min(14, w / 5), math.min(12, d / 5))
		end
	end
	if plan.lavaRiver then
		-- a channel of lava right across the room; cross on the two stone bridges
		lava(r, cx, y, cz, w - 1, 10)
		for _, s in { -1, 1 } do
			local bx = cx + s * w / 4
			box(r, "Bridge", bx, y + 0.3, cz, 10, 1, 14, STONE, Enum.Material.Basalt)
			for _, e in { -1, 1 } do
				box(r, "BridgeRail", bx + e * 4.6, y + 1.3, cz, 0.8, 1.6, 14, DARK, Enum.Material.Basalt)
			end
		end
	end
	if plan.obsidian then
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			local px, pz = cx + c[1] * w / 4, cz + c[2] * d / 4
			local pillar = part(r, "Obsidian", Vector3.new(5, H, 5), CFrame.new(px, y + H / 2, pz) * CFrame.Angles(0, math.rad(45), 0), rgb(30, 22, 36), Enum.Material.Glass)
			pillar.Reflectance = 0.2
			local vein = part(r, "LavaVein", Vector3.new(0.4, H - 2, 0.6), CFrame.new(px, y + H / 2, pz) * CFrame.Angles(0, math.rad(45), 0) * CFrame.new(0, 0, -2.55), LAVA, Enum.Material.Neon)
			vein.CanCollide = false
		end
	end
	if plan.forge then
		for _, s in { -1, 1 } do
			for k = -1, 1 do
				local fx, fz = cx + s * (w / 2 - 7), cz + k * (d / 3.4)
				box(r, "Forge", fx, y, fz, 7, 4, 6, DARK, Enum.Material.Basalt)
				local coals = box(r, "ForgeCoals", fx, y + 4, fz, 5, 0.6, 4, LAVA, Enum.Material.Neon)
				light(coals, 22, 1.4, LAVA)
				local fire = Instance.new("Fire")
				fire.Size = 5
				fire.Heat = 9
				fire.Parent = coals
				box(r, "Anvil", fx - s * 7, y, fz, 2, 2.6, 4, rgb(50, 50, 55), Enum.Material.Metal)
			end
		end
	end
	if plan.calderaRing then
		-- a broken ring of lava round the dais, with four ways through
		local ringR = 34
		local segs = 16
		for k = 0, segs - 1 do
			if k % 4 ~= 0 then
				local a = (k + 0.5) / segs * math.pi * 2
				local len = 2 * math.pi * ringR / segs + 1
				local p = Vector3.new(cx + math.cos(a) * ringR, y, cz + d / 6 + math.sin(a) * ringR)
				local slab = lava(r, p.X, y, p.Z, len, 8)
				slab.CFrame = CFrame.lookAt(slab.CFrame.Position, slab.CFrame.Position + Vector3.new(-math.sin(a), 0, math.cos(a)))
			end
		end
		lava(r, cx - w / 2 + 14, y, cz - d / 2 + 14, 16, 16)
		lava(r, cx + w / 2 - 14, y, cz - d / 2 + 14, 16, 16)
	end
	if plan.niches then
		for _, s in { -1, 1 } do
			for k = -2, 2 do
				local nz = cz + k * 8
				box(r, "Niche", cx + s * (w / 2 - 0.6), y + 4, nz, 1.2, 4, 5, rgb(40, 38, 44), Enum.Material.SmoothPlastic)
				for j = -1, 1 do
					ball(r, "NicheSkull", 1.2, cx + s * (w / 2 - 1), y + 4.7, nz + j * 1.4, BONE)
				end
			end
		end
	end
	return r
end

local function corridor(f: Instance, index: number, x: number, y: number, z0: number, z1: number)
	local c = folder(f, "Corridor" .. index)
	local len = z1 - z0
	local cz = (z0 + z1) / 2
	box(c, "Floor", x, y - 2, cz, OPENING + WALL * 2, 2, len, FLOOR, Enum.Material.Slate)
	box(c, "Ceiling", x, y + 16, cz, OPENING + WALL * 2, 2, len, DARK, Enum.Material.Cobblestone)
	for _, s in { -1, 1 } do
		box(c, "Wall", x + s * (OPENING / 2 + WALL / 2), y, cz, WALL, 16, len, STONE, Enum.Material.Cobblestone)
		torch(c, x + s * (OPENING / 2 - 0.4), y + 8, cz, Vector3.new(-s, 0, 0), s == 1)
	end
	return c
end

-- Portcullis blocking the corridor from room `index` to the next one.
local function door(f: Instance, index: number, x: number, y: number, z: number): Model
	local m = Instance.new("Model")
	m.Name = "Door" .. index
	m:SetAttribute("Room", index)
	local gate = box(m, "Gate", x, y, z, OPENING, 16, 1.2, rgb(40, 40, 45), Enum.Material.Metal)
	gate.Transparency = 1
	m.PrimaryPart = gate
	for k = 0, 7 do
		local bar = box(m, "Bar", x - OPENING / 2 + 1 + k * (OPENING - 2) / 7, y, z, 0.6, 16, 0.6, rgb(55, 55, 60), Enum.Material.Metal)
		bar.CanCollide = false
	end
	for _, by in { 4, 10 } do
		local cross = box(m, "Crossbar", x, y + by, z, OPENING, 0.6, 0.6, rgb(55, 55, 60), Enum.Material.Metal)
		cross.CanCollide = false
	end
	m.Parent = f
	return m
end

local function chest(f: Instance, kind: string, index: number, x: number, y: number, z: number)
	local m = Instance.new("Model")
	m.Name = "Chest"
	m:SetAttribute("Chest", kind)
	m:SetAttribute("Room", index)
	local wood = if kind == "boss" then rgb(90, 50, 110) else rgb(120, 78, 45)
	local base = box(m, "Base", x, y, z, 6, 3.4, 4, wood, Enum.Material.WoodPlanks)
	m.PrimaryPart = base
	box(m, "Lid", x, y + 3.4, z, 6.2, 1.4, 4.2, wood, Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		box(m, "Band", x + s * 2, y, z, 0.5, 4.9, 4.3, rgb(225, 185, 70), Enum.Material.Metal)
	end
	local lock = box(m, "Lock", x, y + 2.4, z - 2.15, 1, 1.2, 0.4, rgb(225, 185, 70), Enum.Material.Metal)
	light(lock, 14, 1, if kind == "boss" then rgb(200, 140, 255) else rgb(255, 210, 120))
	m.Parent = f
end

local function portal(f: Instance, name: string, x: number, y: number, z: number, color: Color3, visible: boolean): BasePart
	local p = box(f, name, x, y, z, 10, 12, 1, color, Enum.Material.Neon)
	p.Transparency = if visible then 0.35 else 1
	p.CanCollide = false
	p:SetAttribute("Active", visible)
	light(p, 22, 1.4, color)
	box(f, name .. "Frame", x, y + 12, z, 12, 1.4, 1.6, rgb(120, 115, 125), Enum.Material.Cobblestone)
	for _, s in { -1, 1 } do
		box(f, name .. "Frame", x + s * 5.6, y, z, 1.2, 12, 1.6, rgb(120, 115, 125), Enum.Material.Cobblestone)
	end
	return p
end

local function boss(f: Instance, cx: number, y: number, cz: number, w: number, d: number)
	-- raised dais, a ring of pale slabs, braziers and tattered banners
	cylinder(f, "Dais", 1, 30, cx, y + 0.5, cz + d / 6, rgb(110, 104, 112), Enum.Material.Cobblestone)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		box(f, "RingSlab", cx + math.cos(a) * 26, y, cz + math.sin(a) * 26, 6, 0.2, 6, rgb(150, 140, 135), Enum.Material.Slate)
	end
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		brazier(f, cx + c[1] * (w / 2 - 8), y, cz + c[2] * (d / 2 - 8))
		cylinder(f, "Pillar", H, 6, cx + c[1] * (w / 2 - 16), y + H / 2, cz + c[2] * (d / 2 - 16), STONE, Enum.Material.Rock)
	end
	for _, s in { -1, 1 } do
		for k = -1, 1 do
			local banner = box(f, "TatteredBanner", cx + s * (w / 2 - 0.4), y + 8, cz + k * 20, 0.3, 12, 5, rgb(90, 30, 40), Enum.Material.Fabric)
			banner.CanCollide = false
		end
	end
	local throne = box(f, "Throne", cx, y + 1, cz + d / 2 - 8, 10, 12, 4, rgb(70, 66, 74), Enum.Material.Cobblestone)
	throne.Name = "Throne"
	for k = 0, 4 do
		ball(f, "ThroneSkull", 1.6, cx - 4 + k * 2, y + 13.6, cz + d / 2 - 8, BONE)
	end
end

----------------------------------------------------------------------------------------------

local function buildOne(map: Instance, def: any, landscape: any): Instance
	initColors(def.theme)
	local existing = map:FindFirstChild(def.root)
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = def.root
	root:SetAttribute("Title", def.title)
	root:SetAttribute("MinLevel", def.minLevel)
	local crypt = folder(root, def.interior)
	local rooms = folder(crypt, "Rooms")
	local spawns = folder(crypt, "Spawns")
	local doors = folder(crypt, "Doors")
	local chests = folder(crypt, "Chests")

	local O = def.origin
	local x, y = O.x, O.y
	local cursor = O.z
	local plans = def.rooms
	for i, plan in plans do
		local index = i - 1
		local cz = cursor + plan.d / 2 + WALL
		local last = i == #plans
		room(rooms, index, plan, x, y, cz, last)
		-- spawn markers spread over the back two thirds of the room; the boss on the dais
		local n = 0
		for _, s in plan.spawns do
			for _ = 1, s[2] do
				n += 1
				local isBoss = s[1] == plan.boss
				local sx = if isBoss then x else x + ((n % 3) - 1) * (plan.w / 4)
				local sz = if isBoss then cz + plan.d / 6 else cz + ((n // 3) % 3 - 0.5) * (plan.d / 4)
				local m = marker(spawns, "Spawn", sx, y + 0.5, sz)
				m:SetAttribute("Room", index)
				m:SetAttribute("Kind", s[1])
				if isBoss then
					m:SetAttribute("Boss", true)
				end
			end
		end
		if plan.chest then
			chest(chests, plan.chest, index, x, y, if plan.boss then cz + plan.d / 2 - 18 else cz + 4)
		end
		if plan.boss then
			boss(rooms, x, y, cz, plan.w, plan.d)
			portal(crypt, "BossExit", x + plan.w / 2 - 14, y, cz + plan.d / 2 - 4, rgb(120, 220, 255), false)
		end
		if index == 0 then
			marker(crypt, "EntryPad", x, y + 3, cz - plan.d / 2 + 8)
			portal(crypt, "ExitPortal", x - plan.w / 2 + 10, y, cz - plan.d / 2 + 1.5, GLOW, true)
			local plaque = box(crypt, "Plaque", x, y + 13, cz - plan.d / 2 + 0.4, 18, 3, 0.4, rgb(40, 35, 45), Enum.Material.Slate)
			sign(plaque, def.title, rgb(220, 200, 255), Enum.NormalId.Back)
		end
		cursor = cz + plan.d / 2 + WALL
		if not last then
			door(doors, index, x, y, cursor + 0.6)
			corridor(rooms, index, x, y, cursor, cursor + CORRIDOR)
			cursor += CORRIDOR
		end
	end

	-- the way in: a stairwell with an arch and a portal at the entrance site
	local entrance = folder(root, "Entrance")
	local site = landscape and landscape.Sites and landscape.Sites[def.entrance.site]
	if site then
		local ex, ey, ez = site.x + def.entrance.dx, site.h + 0.4, site.z + def.entrance.dz
		for _, e in { { 0, -5.5, 12, 1 }, { 0, 5.5, 12, 1 }, { -5.5, 0, 1, 10 }, { 5.5, 0, 1, 10 } } do
			if e[2] ~= -5.5 then
				box(entrance, "StairWall", ex + e[1], ey, ez + e[2], e[3], 2.4, e[4], DARK, Enum.Material.Cobblestone)
			end
		end
		box(entrance, "Pit", ex, ey - 0.3, ez, 10, 0.2, 10, rgb(15, 12, 20), Enum.Material.SmoothPlastic)
		for k = 0, 3 do
			box(entrance, "Step", ex, ey - 0.2 - k * 0.1, ez - 4 + k * 2.4, 9.6, 0.2, 2.2, rgb(70, 66, 72), Enum.Material.Slate)
		end
		for _, s in { -1, 1 } do
			box(entrance, "ArchPillar", ex + s * 5.5, ey, ez - 6, 1.6, 10, 1.6, STONE, Enum.Material.Cobblestone)
			local flame = ball(entrance, "ArchFlame", 1, ex + s * 5.5, ey + 10.8, ez - 6, GLOW, Enum.Material.Neon)
			light(flame, 16, 1.2, GLOW)
		end
		local lintel = box(entrance, "ArchLintel", ex, ey + 10, ez - 6, 12.6, 2, 1.8, STONE, Enum.Material.Cobblestone)
		sign(lintel, def.title, rgb(220, 200, 255), Enum.NormalId.Front)
		if def.minLevel > 1 then
			local note = box(entrance, "LevelPlaque", ex, ey + 7.6, ez - 6, 6, 1.4, 0.4, rgb(40, 35, 30), Enum.Material.WoodPlanks)
			sign(note, "Level " .. def.minLevel .. "+", rgb(255, 210, 120), Enum.NormalId.Front)
		end
		local p = box(entrance, def.portal, ex, ey - 0.1, ez, 9, 0.6, 9, GLOW, Enum.Material.Neon)
		p.Transparency = 0.3
		p.CanCollide = false
		light(p, 18, 1.4, GLOW)
		marker(entrance, "ReturnPoint", ex + 11, ey + 3, ez)
	end

	root.Parent = map
	return root
end

-- Builds every dungeon (Map.Dungeon, Map.Mines). `landscape` is Shared.Landscape (entrances).
function DungeonBuilder.Build(map: Instance, landscape: any): Instance
	local first: Instance? = nil
	for _, def in DungeonBuilder.Dungeons do
		local root = buildOne(map, def, landscape)
		first = first or root
	end
	return first :: Instance
end

return DungeonBuilder
