--!strict
-- The land around Sproutling Isles, as pure maths.
--
-- The garden island (the flat play area built from parts by MapBuilder) sits in a shallow lagoon
-- with a ragged sandy shore. Beyond it a large landmass rolls away in every direction: low hills
-- near the island, a gently rolling site for the walled city to the south, and high ridges and
-- mountains towards the coast. Curvy roads of different widths wind across all of it; the ground
-- is cut and banked so each road climbs and dips with the hills instead of lying flat.
--
-- Both sides use this module so they always agree:
--   * server/TerrainBuilder.luau fills Terrain from height()/material() and paints the roads,
--   * MapBuilder and CityBuilder place buildings, trees and props with height() and the road
--     samples,
--   * tools can sample it under Lune for previews.
-- It touches no services and no Roblox types, so it runs anywhere.

local Landscape = {}

-- Bump when the terrain shape changes, so a terrain baked into the place in Studio is rebuilt.
Landscape.Version = 6

Landscape.WaterLevel = -2
Landscape.SeaFloor = -22
Landscape.LagoonFloor = -8
-- Terrain covers this rectangle.
Landscape.Bounds = { x0 = -1500, x1 = 1500, z0 = -1350, z1 = 2350 }

-- The garden island: built from parts, so no terrain is generated inside it.
Landscape.Play = { x0 = -140, x1 = 140, z0 = -412, z1 = 352 }
Landscape.Areas = { Landscape.Play }

-- The walled city: centre and rough radius (the outline wobbles, see cityRadiusAt).
Landscape.CityCentre = { x = 20, z = 870 }
Landscape.CityRadius = 400

-- The landmass: an ellipse with a noisy coast. Mountains rise towards its edge.
local LAND = { x = -150, z = 480, rx = 1180, rz = 1760 }

-- Flat-topped sites the scenery is built on: centre, plateau radius and height (h = nil: the
-- natural ground height at the centre). Ordered, because overlapping sites are blended in order.
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
	{ name = "grove", x = -495, z = -445, r = 40, h = 34 }, -- Ironbark's clearing (field boss)
	-- the city's waterfront and the airship port
	{ name = "harbour", x = 282, z = 880, r = 58, h = 1.2 },
	{ name = "docks", x = 334, z = 640, r = 52, h = 1.2 },
	{ name = "airport", x = -660, z = 860, r = 125 },
	-- the wider world
	{ name = "southvale", x = 90, z = 1690, r = 52 },
	{ name = "eastmere", x = 780, z = 430, r = 48 },
	{ name = "pinecrest", x = -1000, z = 290, r = 50 },
	{ name = "oldfort", x = 560, z = 1420, r = 30 },
	-- mountain camps for the quests (Shared/Quests)
	{ name = "minecamp", x = -260, z = -960, r = 30 },
	{ name = "hermitage", x = 720, z = -420, r = 28 },
	{ name = "observatory", x = 280, z = -860, r = 30 },
	-- the volcanic peak above the Emberdeep Caldera (third dungeon)
	{ name = "emberpeak", x = -850, z = 1520, r = 36 },
	-- Greenhollow Gardens, the garden-house village off the city's Grand Way (MapBuilder.Garden)
	{ name = "greenhollow", x = -170, z = 1440, r = 210, h = 24 },
	-- Highcrag, the mountain village below Ember Peak; over Saltwind Pass to Saltmere on the beach
	-- (and the Tidewrack Grotto, the fourth dungeon)
	{ name = "highcrag", x = -770, z = 1615, r = 48, h = 168, ground = "LeafyGrass" },
	{ name = "windpass", x = -900, z = 1636, r = 18, h = 182 },
	{ name = "saltmere", x = -905, z = 1792, r = 50, h = 1.4 },
	{ name = "strand", x = -842, z = 1828, r = 40, h = 1.2 }, -- open beach either side of Saltmere
	{ name = "cove", x = -985, z = 1776, r = 26, h = 1.2 },
} :: { { name: string, x: number, z: number, r: number, h: number?, ground: string? } }

export type Site = { name: string, x: number, z: number, r: number, h: number, ground: string? } -- ground: plateau material
Landscape.Sites = {} :: { [string]: Site }

-- Sea inlets: the east bay by the island, the city harbour and its channel out to the open sea,
-- the fishers' cove, the cape bay and a south inlet.
local BAYS = {
	{ x = 360, z = 20, r = 95 },
	{ x = 480, z = 880, r = 170 }, -- city harbour
	{ x = 640, z = 905, r = 130 },
	{ x = 800, z = 925, r = 135 },
	{ x = 960, z = 945, r = 150 },
	{ x = 470, z = 640, r = 100 }, -- fishers' cove
	{ x = 780, z = -60, r = 170 }, -- cape bay
	{ x = -330, z = -560, r = 80 },
}

-- Lagoon bridges: start on the island's beach and run outwards until they reach dry land.
-- { x, z, dx, dz }; the far end is worked out below. Landscape.Bridges holds { x0, z0, x1, z1 }.
local BRIDGE_STARTS = {
	{ -140, 60, -1, 0 },
	{ -140, -250, -1, 0 },
	{ -100, 352, 0, 1 }, -- footbridge to the city's west side
}
local GRAND_BRIDGE_START = { 0, 352, 0, 1 } -- the stone bridge to the city's north gate

-- Roads: control points (x, z) joined by smooth curves. `from` starts the road at the far end of
-- a bridge ("grand" or a Bridges index). Materials are Terrain material names.
export type RoadDef = { name: string, width: number, material: string, points: { { number } }, from: (string | number)? }
Landscape.Roads = {
	-- the city
	{ name = "Grand Way", width = 28, material = "Cobblestone", from = "grand", points = { { 15, 560 }, { -10, 650 }, { -25, 760 }, { 10, 860 }, { 32, 960 }, { 0, 1060 }, { -22, 1160 }, { 12, 1265 }, { 62, 1385 }, { 112, 1500 }, { 95, 1640 } } },
	{ name = "Market Street", width = 18, material = "Pavement", points = { { -25, 760 }, { 60, 742 }, { 150, 768 }, { 225, 822 }, { 268, 870 } } },
	{ name = "Old Town Lane", width = 14, material = "Cobblestone", points = { { 10, 860 }, { -80, 892 }, { -170, 932 }, { -238, 1002 }, { -305, 1058 }, { -385, 1056 }, { -470, 990 }, { -560, 905 } } },
	{ name = "Temple Road", width = 12, material = "Pavement", points = { { 0, 1060 }, { 92, 1092 }, { 182, 1062 }, { 248, 992 }, { 268, 930 } } },
	{ name = "Crescent", width = 10, material = "Cobblestone", points = { { -10, 650 }, { -100, 615 }, { -192, 655 }, { -245, 740 }, { -232, 842 }, { -170, 932 } } },
	{ name = "Fishers' Lane", width = 9, material = "Ground", points = { { 60, 742 }, { 110, 682 }, { 190, 632 }, { 300, 640 } } },
	{ name = "Hill Lane", width = 8, material = "Ground", points = { { -238, 1002 }, { -222, 1100 }, { -132, 1182 }, { -22, 1160 } } },
	{ name = "Footbridge Path", width = 7, material = "Ground", from = 3, points = { { -128, 560 }, { -100, 615 } } },
	-- out in the country
	{ name = "Castle Road", width = 8, material = "Cobblestone", from = 1, points = { { -405, 62 }, { -430, 60 } } },
	{ name = "Hamlet Road", width = 7, material = "Ground", from = 2, points = { { -385, -300 }, { -392, -312 } } },
	{ name = "Grove Path", width = 6, material = "Ground", points = { { -415, -365 }, { -440, -395 }, { -465, -420 } } },
	{ name = "East Hamlet Path", width = 7, material = "Ground", points = { { 362, -240 }, { 380, -262 }, { 398, -275 }, { 408, -288 } } },
	{ name = "Farm Road", width = 9, material = "Ground", points = { { 190, 632 }, { 232, 560 }, { 330, 520 }, { 425, 440 }, { 432, 345 } } },
	{ name = "Eastmere Road", width = 8, material = "Ground", points = { { 432, 345 }, { 560, 330 }, { 680, 392 }, { 752, 428 } } },
	{ name = "Watch Road", width = 8, material = "Ground", points = { { -560, 905 }, { -625, 760 }, { -640, 610 }, { -600, 470 }, { -566, 362 } } },
	{ name = "Pinecrest Road", width = 7, material = "Ground", points = { { -566, 362 }, { -700, 380 }, { -840, 330 }, { -985, 295 } } },
	{ name = "Greenhollow Lane", width = 10, material = "Ground", points = { { 62, 1385 }, { 0, 1345 }, { -60, 1295 }, { -110, 1264 }, { -150, 1253 }, { -170, 1264 }, { -170, 1340 }, { -170, 1440 }, { -170, 1540 }, { -170, 1615 } } },
	{ name = "Old Fort Track", width = 7, material = "Ground", points = { { 95, 1640 }, { 260, 1610 }, { 420, 1540 }, { 545, 1440 } } },
	-- mountain tracks up to the quest camps
	{ name = "Miners' Track", width = 7, material = "Ground", points = { { -465, -420 }, { -420, -560 }, { -380, -700 }, { -320, -850 }, { -275, -935 } } },
	{ name = "Observatory Trail", width = 7, material = "Ground", points = { { 362, -240 }, { 330, -420 }, { 250, -600 }, { 300, -760 }, { 285, -835 } } },
	{ name = "Ember Trail", width = 7, material = "Ground", points = { { -470, 990 }, { -600, 1150 }, { -720, 1330 }, { -800, 1460 }, { -830, 1500 } } },
	{ name = "Highcrag Steps", width = 8, material = "Cobblestone", points = { { -830, 1500 }, { -812, 1545 }, { -790, 1580 }, { -772, 1610 } } },
	{ name = "Saltwind Pass", width = 7, material = "Ground", points = { { -772, 1610 }, { -812, 1632 }, { -860, 1628 }, { -905, 1640 }, { -955, 1668 }, { -988, 1716 }, { -962, 1758 }, { -925, 1782 } } },
	{ name = "Hermit's Climb", width = 6, material = "Ground", points = { { 408, -288 }, { 520, -340 }, { 620, -400 }, { 700, -420 } } },
} :: { RoadDef }

-- Fenced crop fields on the farm plateau (centre x, z and size w along x, d along z).
Landscape.Fields = {
	{ x = 372, z = 240, w = 34, d = 26 },
	{ x = 414, z = 240, w = 34, d = 26 },
	{ x = 372, z = 300, w = 34, d = 26 },
	{ x = 414, z = 300, w = 34, d = 26 },
}

----------------------------------------------------------------------------------------------
-- noise

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
local fbm = Landscape.fbm

----------------------------------------------------------------------------------------------
-- shape

-- Distance from (x, z) to the island's edge (0 inside it).
function Landscape.outside(x: number, z: number): number
	local p = Landscape.Play
	local dx = math.max(p.x0 - x, 0, x - p.x1)
	local dz = math.max(p.z0 - z, 0, z - p.z1)
	return math.sqrt(dx * dx + dz * dz)
end

-- True inside the garden island (built from parts, no terrain).
function Landscape.inPlayArea(x: number, z: number): boolean
	local p = Landscape.Play
	return x >= p.x0 and x <= p.x1 and z >= p.z0 and z <= p.z1
end

-- The city wall's distance from the centre in direction `angle` (radians): a wobbly ring.
function Landscape.cityRadiusAt(angle: number): number
	return Landscape.CityRadius + 42 * math.sin(3 * angle + 1.1) + 26 * math.sin(5 * angle + 2.3) + 14 * math.sin(9 * angle + 0.4)
end

-- 1 inside the city, fading to 0 just past its walls.
function Landscape.cityWeight(x: number, z: number): number
	local dx, dz = x - Landscape.CityCentre.x, z - Landscape.CityCentre.z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < Landscape.CityRadius - 90 then
		return 1
	end
	local r = Landscape.cityRadiusAt(math.atan2(dz, dx))
	return 1 - smoothstep(r - 30, r + 90, dist)
end

-- How far (x, z) is towards the coast: 0 at the land's centre, about 1 at the shore.
local function landRadius(x: number, z: number): number
	local ex, ez = (x - LAND.x) / LAND.rx, (z - LAND.z) / LAND.rz
	return math.sqrt(ex * ex + ez * ez) + (fbm(x / 260 - 31, z / 260 + 12) - 0.5) * 0.22
end

-- Inland ground before the lagoon, the sea, sites and roads are applied.
local function landHeight(x: number, z: number): number
	local n1 = fbm(x / 170, z / 170)
	local h = 12 + 66 * n1 ^ 1.35
	-- small bumps everywhere so nothing is perfectly smooth
	local bumps = (fbm(x / 45 + 9, z / 45 + 2) - 0.5) * 8
	-- ridges and mountains towards the coast
	local e = landRadius(x, z)
	local ridge = 1 - math.abs(2 * fbm(x / 320 + 5, z / 320 - 8) - 1)
	h += 170 * smoothstep(0.6, 0.9, e) * ridge * ridge
	-- the city: gently rolling ground, still uneven
	local c = Landscape.cityWeight(x, z)
	if c > 0 then
		local hc = 7 + 22 * fbm(x / 230 - 4, z / 230 + 6)
		h += (hc - h) * c
		bumps *= 1 - 0.6 * c
	end
	return h + bumps
end

-- Ground with the lagoon, coast and bays, before sites and roads.
local function baseHeight(x: number, z: number): number
	local h = landHeight(x, z)
	local lagoon = Landscape.LagoonFloor
	-- the lagoon round the island, with a ragged sandy shore
	local d = Landscape.outside(x, z) + (fbm(x / 80 + 21, z / 80 - 3) - 0.5) * 90
	if d < 20 then
		h = -0.5
	elseif d < 46 then
		h = -0.5 + (lagoon + 0.5) * smoothstep(20, 46, d)
	else
		h = lagoon + (h - lagoon) * smoothstep(46, 200, d)
	end
	-- coast and inlets
	local k = 1 - smoothstep(0.93, 1.03, landRadius(x, z))
	for _, b in BAYS do
		local dist = math.sqrt((x - b.x) ^ 2 + (z - b.z) ^ 2)
		if dist < b.r * 1.25 then
			k = math.min(k, smoothstep(b.r * 0.55, b.r * 1.25, dist))
		end
	end
	return Landscape.SeaFloor + (h - Landscape.SeaFloor) * k
end

-- Sites get their height (natural ground at the centre unless given).
for _, s in Landscape.SiteList do
	local site = s :: any
	if site.h == nil then
		site.h = math.floor(baseHeight(s.x, s.z) + 0.5)
	end
	Landscape.Sites[s.name] = site :: Site
end

-- Ground with the site plateaus, before roads.
local function siteHeight(x: number, z: number): number
	local h = baseHeight(x, z)
	for _, s in Landscape.SiteList do
		local dist = math.sqrt((x - s.x) ^ 2 + (z - s.z) ^ 2)
		if dist < s.r * 1.9 then
			local w = 1 - smoothstep(s.r, s.r * 1.9, dist)
			h += ((s.h :: number) - h) * w
		end
	end
	return h
end

----------------------------------------------------------------------------------------------
-- bridges

local function bridgeEnd(start: { number }): { number }
	local x, z, dx, dz = start[1], start[2], start[3], start[4]
	local run = 0
	for step = 1, 120 do
		local px, pz = x + dx * step * 4, z + dz * step * 4
		if siteHeight(px, pz) > 1.6 then
			run += 1
			if run >= 3 then
				return { x, z, px, pz }
			end
		else
			run = 0
		end
	end
	return { x, z, x + dx * 120, z + dz * 120 }
end

Landscape.Bridges = {} :: { { number } }
for i, b in BRIDGE_STARTS do
	Landscape.Bridges[i] = bridgeEnd(b)
end
Landscape.GrandBridge = bridgeEnd(GRAND_BRIDGE_START)

----------------------------------------------------------------------------------------------
-- roads

export type RoadSample = { x: number, z: number, y: number, tx: number, tz: number, hw: number, s: number, road: number }
Landscape.RoadSamples = {} :: { { RoadSample } } -- per road, in Landscape.Roads order
Landscape.RoadMaterial = {} :: { string }

local SPACING = 3.5
local SHOULDER = 26 -- widest bank either side of a road
local CELL = 32
local grid: { [number]: { RoadSample } } = {}

local function cellKey(ix: number, iz: number): number
	return ix * 65536 + iz
end

local function catmull(p0: { number }, p1: { number }, p2: { number }, p3: { number }, t: number): (number, number)
	local t2, t3 = t * t, t * t * t
	local function c(a: number, b: number, cc: number, d: number): number
		return 0.5 * ((2 * b) + (-a + cc) * t + (2 * a - 5 * b + 4 * cc - d) * t2 + (-a + 3 * b - 3 * cc + d) * t3)
	end
	return c(p0[1], p1[1], p2[1], p3[1]), c(p0[2], p1[2], p2[2], p3[2])
end

local function buildRoad(index: number, def: RoadDef)
	local pts = table.clone(def.points)
	if def.from == "grand" then
		local b = Landscape.GrandBridge
		table.insert(pts, 1, { b[3], b[4] })
	elseif type(def.from) == "number" then
		local b = Landscape.Bridges[def.from :: number]
		table.insert(pts, 1, { b[3], b[4] })
	end
	-- dense points along the curve
	local raw: { { number } } = {}
	for i = 1, #pts - 1 do
		local p0, p1, p2, p3 = pts[math.max(1, i - 1)], pts[i], pts[i + 1], pts[math.min(#pts, i + 2)]
		local len = math.sqrt((p2[1] - p1[1]) ^ 2 + (p2[2] - p1[2]) ^ 2)
		local n = math.max(2, math.ceil(len / SPACING))
		for k = 0, n - 1 do
			local x, z = catmull(p0, p1, p2, p3, k / n)
			table.insert(raw, { x, z })
		end
	end
	table.insert(raw, pts[#pts])
	-- heights follow the ground, smoothed so the road rolls instead of jumping
	local hs = {}
	for i, p in raw do
		hs[i] = siteHeight(p[1], p[2])
	end
	for _ = 1, 3 do
		local out = {}
		for i = 1, #hs do
			local sum, n = 0, 0
			for j = math.max(1, i - 9), math.min(#hs, i + 9) do
				sum += hs[j]
				n += 1
			end
			out[i] = sum / n
		end
		hs = out
	end
	local samples: { RoadSample } = {}
	local s = 0
	local seed = index * 1.7
	for i, p in raw do
		local q = raw[math.min(#raw, i + 1)]
		local r = raw[math.max(1, i - 1)]
		local tx, tz = q[1] - r[1], q[2] - r[2]
		local tl = math.sqrt(tx * tx + tz * tz)
		if tl < 1e-6 then
			tx, tz, tl = 0, 1, 1
		end
		if i > 1 then
			s += math.sqrt((p[1] - raw[i - 1][1]) ^ 2 + (p[2] - raw[i - 1][2]) ^ 2)
		end
		-- the width swells and narrows a little along the way
		local hw = def.width / 2 * (1 + 0.14 * math.sin(s / 37 + seed) + 0.06 * math.sin(s / 11 + seed * 3))
		local sample: RoadSample = { x = p[1], z = p[2], y = math.max(hs[i], 0.8), tx = tx / tl, tz = tz / tl, hw = hw, s = s, road = index }
		table.insert(samples, sample)
		local reach = hw + SHOULDER
		for ix = math.floor((p[1] - reach) / CELL), math.floor((p[1] + reach) / CELL) do
			for iz = math.floor((p[2] - reach) / CELL), math.floor((p[2] + reach) / CELL) do
				local key = cellKey(ix, iz)
				local list = grid[key]
				if not list then
					list = {}
					grid[key] = list
				end
				table.insert(list, sample)
			end
		end
	end
	Landscape.RoadSamples[index] = samples
	Landscape.RoadMaterial[index] = def.material
end

for i, def in Landscape.Roads do
	buildRoad(i, def)
end

-- The nearest road to (x, z): distance from its edge (negative on the road) and the sample.
function Landscape.nearestRoad(x: number, z: number): (number, RoadSample?)
	local list = grid[cellKey(math.floor(x / CELL), math.floor(z / CELL))]
	if not list then
		return math.huge, nil
	end
	local best, bestSample = math.huge, nil
	for _, sample in list do
		local d = math.sqrt((x - sample.x) ^ 2 + (z - sample.z) ^ 2) - sample.hw
		if d < best then
			best, bestSample = d, sample
		end
	end
	return best, bestSample
end

-- True if (x, z) is on a road or within `margin` studs of one.
function Landscape.onRoad(x: number, z: number, margin: number?): boolean
	local d = Landscape.nearestRoad(x, z)
	return d < (margin or 0)
end

----------------------------------------------------------------------------------------------
-- the surface

-- Terrain surface height at (x, z).
function Landscape.height(x: number, z: number): number
	local h = siteHeight(x, z)
	local d, sample = Landscape.nearestRoad(x, z)
	if sample and d < SHOULDER then
		if d <= 0 then
			return sample.y
		end
		-- deeper cuts and fills get wider banks
		local bank = math.min(SHOULDER, 5 + math.abs(h - sample.y) * 1.4)
		if d < bank then
			return sample.y + (h - sample.y) * smoothstep(0, bank, d)
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
	local d, sample = Landscape.nearestRoad(x, z)
	if sample and d < -0.5 then
		return Landscape.RoadMaterial[sample.road]
	end
	if h < 1.5 then
		return "Sand"
	end
	-- a village terrace high on the mountain keeps its own ground (grass, not bare rock)
	for _, site in Landscape.SiteList do
		if site.ground and (x - site.x) ^ 2 + (z - site.z) ^ 2 < (site.r + 4) ^ 2 then
			return site.ground
		end
	end
	local s = Landscape.slope(x, z)
	if s > 0.95 or h > 150 then
		return "Rock"
	elseif s > 0.7 or (sample ~= nil and d < 1.5) or h > 120 then
		return "Ground"
	end
	if Landscape.fbm(x / 60 + 3, z / 60 + 7) > 0.58 then
		return "LeafyGrass"
	end
	return "Grass"
end

----------------------------------------------------------------------------------------------
-- sky isles

-- Floating islets (MapBuilder builds them). Named ones can be reached through the wind shrines
-- once a player earns the Skyward Charm, and hold quests, caches and storm wisps (WildsBuilder).
-- { x, base y, z, radius, waterfall?, name? }; y rises to stay well clear of the land below.
local ISLETS: { { any } } = {
	{ -340, 170, -120, 38, true, "Windward Isle" },
	{ 360, 200, 60, 45, true, "Cloudkeeper's Rest" },
	{ -300, 230, 260, 30, false },
	{ 320, 155, -330, 28, true },
	{ -150, 250, -520, 34, true, "Starfall Isle" },
	{ 180, 210, -500, 26, false },
	{ 520, 270, 1250, 32, false, "Gale Rock" },
	{ -420, 290, -380, 22, false },
	{ 440, 270, 330, 24, false },
	{ 75, 185, 375, 10, false },
	{ -70, 172, 330, 8, false },
	{ -640, 380, 1480, 60, true, "Stormcrown" },
}

export type Islet = { x: number, y: number, z: number, r: number, falls: boolean, name: string? }
Landscape.SkyIslets = {} :: { Islet }
for _, it in ISLETS do
	local x, z, r = it[1], it[3], it[4]
	local ground = Landscape.height(x, z)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		ground = math.max(ground, Landscape.height(x + math.cos(a) * r * 1.3, z + math.sin(a) * r * 1.3))
	end
	table.insert(Landscape.SkyIslets, { x = x, y = math.max(it[2], ground + 75), z = z, r = r, falls = it[5], name = it[6] })
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
