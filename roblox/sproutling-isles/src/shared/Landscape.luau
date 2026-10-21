--!strict
-- The hills around Sproutling Isles, as pure maths.
--
-- The play area (the flat island built from parts by MapBuilder) sits in a shallow lagoon. Beyond
-- the lagoon, Roblox Terrain rises into a ring of grassy hills with a few flat-topped sites for the
-- castle, hamlets, farm and waterfall cliff, then falls away to open sea.
--
-- Both sides use this module so they always agree:
--   * server/TerrainBuilder.luau fills Terrain from height()/material() at server start,
--   * MapBuilder places buildings and trees on the hills with height(),
--   * tools can sample it under Lune for previews.
-- It touches no services and no Roblox types, so it runs anywhere.

local Landscape = {}

Landscape.WaterLevel = -2
Landscape.SeaFloor = -22
Landscape.LagoonFloor = -8
-- Terrain covers this rectangle.
Landscape.Bounds = { x0 = -800, x1 = 800, z0 = -800, z1 = 1420 }

-- Flat areas built from parts by MapBuilder/CityBuilder. No terrain is generated inside them;
-- the lagoon wraps around all three.
Landscape.Play = { x0 = -262, x1 = 262, z0 = -412, z1 = 352 } -- the garden island (sand edge)
Landscape.City = { x0 = -345, x1 = 345, z0 = 465, z1 = 1155 }
Landscape.Airport = { x0 = -760, x1 = -425, z0 = 540, z1 = 1120 }
Landscape.Areas = { Landscape.Play, Landscape.City, Landscape.Airport }

-- Flat-topped sites the scenery is built on: centre, plateau radius and height. Ordered, because
-- overlapping sites (the waterfall cliff and its pool) are blended in this order.
Landscape.SiteList = {
	{ name = "castle", x = -495, z = 60, r = 50, h = 50 },
	{ name = "hamletWest", x = -400, z = -330, r = 50, h = 26 },
	{ name = "hamletEast", x = 420, z = -300, r = 48, h = 30 },
	{ name = "farm", x = 400, z = 270, r = 72, h = 18 },
	{ name = "falls", x = 0, z = -585, r = 48, h = 62 },
	{ name = "fallsPool", x = 0, z = -515, r = 22, h = -6 },
	{ name = "cape", x = 585, z = -60, r = 26, h = 38 },
	{ name = "watch", x = -560, z = 330, r = 30, h = 44 },
	{ name = "ruins", x = 620, z = 430, r = 26, h = 30 },
}
Landscape.Sites = {} :: { [string]: { name: string, x: number, z: number, r: number, h: number } }
for _, s in Landscape.SiteList do
	Landscape.Sites[s.name] = s
end

-- Gaps in the hill ring where the sea comes through (harbour bay to the east, a south inlet).
local BAYS = {
	{ x = 360, z = 20, r = 95 },
	{ x = 440, z = 820, r = 130 }, -- city harbour
	{ x = -330, z = -560, r = 80 },
}

-- Winding cobblestone paths (lists of x, z points), painted into the terrain surface.
Landscape.Paths = {
	-- west bridge up to the castle gate
	{ { -352, 60 }, { -378, 70 }, { -405, 62 }, { -430, 60 } },
	-- north-west bridge up to the west hamlet
	{ { -360, -250 }, { -372, -280 }, { -385, -300 }, { -392, -312 } },
	-- north-east shore up to the east hamlet
	{ { 362, -240 }, { 380, -262 }, { 398, -275 }, { 408, -288 } },
	-- south-east shore up to the farm
	{ { 340, 222 }, { 352, 240 }, { 356, 255 } },
}

-- Lagoon bridges: from the island's beach to the hill shore (x, z, x, z).
Landscape.Bridges = {
	{ -262, 60, -352, 60 },
	{ -262, -250, -360, -250 },
	{ -150, 352, -150, 465 }, -- footbridge to the city
}

-- Fenced crop fields on the farm plateau (centre x, z and size w along x, d along z).
Landscape.Fields = {
	{ x = 372, z = 240, w = 34, d = 26 },
	{ x = 414, z = 240, w = 34, d = 26 },
	{ x = 372, z = 300, w = 34, d = 26 },
	{ x = 414, z = 300, w = 34, d = 26 },
}

local function clamp(v: number, lo: number, hi: number): number
	return if v < lo then lo elseif v > hi then hi else v
end

local function smoothstep(e0: number, e1: number, v: number): number
	local t = clamp((v - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end
Landscape.smoothstep = smoothstep

local function hash2(ix: number, iz: number): number
	local s = math.sin(ix * 127.1 + iz * 311.7) * 43758.5453
	return s - math.floor(s)
end

local function valueNoise(x: number, z: number): number
	local ix, iz = math.floor(x), math.floor(z)
	local fx, fz = x - ix, z - iz
	local ux, uz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
	local a, b = hash2(ix, iz), hash2(ix + 1, iz)
	local c, d = hash2(ix, iz + 1), hash2(ix + 1, iz + 1)
	return (a + (b - a) * ux) * (1 - uz) + (c + (d - c) * ux) * uz
end

-- Fractal noise in 0..1.
function Landscape.fbm(x: number, z: number): number
	local total, amp, norm = 0, 1, 0
	for _ = 1, 4 do
		total += valueNoise(x, z) * amp
		norm += amp
		amp *= 0.5
		x, z = x * 2.03 + 17.1, z * 2.03 - 9.7
	end
	return total / norm
end

-- Distance from (x, z) to the nearest flat area's edge (0 inside one).
function Landscape.outside(x: number, z: number): number
	local best = math.huge
	for _, p in Landscape.Areas do
		local dx = math.max(p.x0 - x, 0, x - p.x1)
		local dz = math.max(p.z0 - z, 0, z - p.z1)
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return best
end

-- True inside the island, the city or the airport (built from parts, no terrain).
function Landscape.inPlayArea(x: number, z: number): boolean
	for _, p in Landscape.Areas do
		if x >= p.x0 and x <= p.x1 and z >= p.z0 and z <= p.z1 then
			return true
		end
	end
	return false
end

-- Terrain surface height at (x, z).
function Landscape.height(x: number, z: number): number
	local d = Landscape.outside(x, z)
	if d <= 0 then
		return Landscape.LagoonFloor
	end
	local n1 = Landscape.fbm(x / 170, z / 170)
	local n2 = Landscape.fbm(x / 260 + 40, z / 260 - 13)
	local hill = 12 + 66 * n1 ^ 1.35
	local rise = smoothstep(50, 200, d) -- lagoon first, then a gentle slope up
	local edge = 250 + 110 * n2
	local fall = 1 - smoothstep(edge - 40, edge + 70, d) -- outer coast
	local bay = 1
	for _, b in BAYS do
		local dist = math.sqrt((x - b.x) ^ 2 + (z - b.z) ^ 2)
		bay = math.min(bay, smoothstep(b.r * 0.55, b.r * 1.25, dist))
	end
	local land = (hill - Landscape.LagoonFloor) * rise * fall * bay
	local h = Landscape.LagoonFloor + land - (Landscape.LagoonFloor - Landscape.SeaFloor) * (1 - fall)
	for _, s in Landscape.SiteList do
		local dist = math.sqrt((x - s.x) ^ 2 + (z - s.z) ^ 2)
		if dist < s.r * 1.9 then
			local w = 1 - smoothstep(s.r, s.r * 1.9, dist)
			h += (s.h - h) * w
		end
	end
	return h
end

-- Steepness: how much the height changes per stud around (x, z).
function Landscape.slope(x: number, z: number): number
	local e = 4
	local dx = Landscape.height(x + e, z) - Landscape.height(x - e, z)
	local dz = Landscape.height(x, z + e) - Landscape.height(x, z - e)
	return math.sqrt(dx * dx + dz * dz) / (2 * e)
end

-- Surface material name for (x, z) at height h ("Sand", "Grass", "LeafyGrass", "Rock", ...).
function Landscape.material(x: number, z: number, h: number): string
	if h < 1.5 then
		return "Sand"
	end
	local s = Landscape.slope(x, z)
	if s > 0.95 then
		return "Rock"
	elseif s > 0.7 then
		return "Ground"
	end
	if Landscape.fbm(x / 60 + 3, z / 60 + 7) > 0.58 then
		return "LeafyGrass"
	end
	return "Grass"
end

-- True if (x, z) is inside a site's plateau (keep trees off building sites).
function Landscape.onSite(x: number, z: number, margin: number?): boolean
	for _, s in Landscape.SiteList do
		if math.sqrt((x - s.x) ^ 2 + (z - s.z) ^ 2) < s.r + (margin or 0) then
			return true
		end
	end
	return false
end

return Landscape
