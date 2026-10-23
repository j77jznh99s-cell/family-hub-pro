--!strict
-- Waystones: fast-travel checkpoints across the Isles. Touch one (its prompt) to attune it;
-- from any waystone you can then travel to every waystone you've attuned, free. The world map
-- can also send you to one from anywhere, once a minute.
--
-- Where each stands: next to a Landscape site (`site`, nudged by dx/dz), on a marker another
-- builder made (`find` = { attribute, value }), at a fixed spot (`at` = { x, y, z }), or on a
-- named sky isle (`isle`). WildsBuilder builds them; WaystoneService runs them.

local Waystones = {}

export type Waystone = {
	id: string,
	name: string,
	region: string,
	site: string?,
	dx: number?,
	dz: number?,
	find: { any }?,
	at: { number }?,
	isle: string?,
}

Waystones.List = {
	{ id = "island", name = "Garden Island Bridge", region = "Island", at = { -30, 0, 330 } },
	{ id = "market", name = "City Market", region = "Sproutling City", find = { "TravelPoint", "market" } },
	{ id = "harbour", name = "City Harbour", region = "Sproutling City", find = { "TravelPoint", "harbour" } },
	{ id = "port", name = "Airship Port", region = "Sproutling City", find = { "TravelPoint", "port" } },
	{ id = "castle", name = "Hilltop Castle", region = "The Hills", site = "castle", dx = 40, dz = -20 },
	{ id = "hamletWest", name = "West Hamlet", region = "The Hills", site = "hamletWest", dx = 0, dz = 40 },
	{ id = "hamletEast", name = "East Hamlet", region = "The Hills", site = "hamletEast", dx = 0, dz = 40 },
	{ id = "farm", name = "The Farm", region = "The Hills", site = "farm", dx = -60, dz = 0 },
	{ id = "falls", name = "Skyfall Falls", region = "The Hills", site = "falls", dx = 34, dz = 0 },
	{ id = "cape", name = "Lighthouse Cape", region = "The Hills", site = "cape", dx = -20, dz = 14 },
	{ id = "grove", name = "Ironbark's Grove", region = "The Hills", site = "grove", dx = 30, dz = 26 },
	{ id = "watch", name = "Watchtower", region = "The Hills", site = "watch", dx = 0, dz = 26 },
	{ id = "southvale", name = "Southvale", region = "The Wider Land", site = "southvale", dx = 40, dz = 0 },
	{ id = "eastmere", name = "Eastmere", region = "The Wider Land", site = "eastmere", dx = -40, dz = 0 },
	{ id = "pinecrest", name = "Pinecrest", region = "The Wider Land", site = "pinecrest", dx = 40, dz = 0 },
	{ id = "oldfort", name = "The Old Fort", region = "The Wider Land", site = "oldfort", dx = 30, dz = 20 },
	{ id = "minecamp", name = "Deepdelve Mine Camp", region = "The Mountains", site = "minecamp", dx = 24, dz = -20 },
	{ id = "observatory", name = "Pell's Observatory", region = "The Mountains", site = "observatory", dx = -24, dz = 20 },
	{ id = "hermitage", name = "Oswin's Hermitage", region = "The Mountains", site = "hermitage", dx = -22, dz = 18 },
	{ id = "windward", name = "Windward Isle", region = "The Sky Isles", isle = "Windward Isle" },
	{ id = "cloudkeeper", name = "Cloudkeeper's Rest", region = "The Sky Isles", isle = "Cloudkeeper's Rest" },
	{ id = "starfall", name = "Starfall Isle", region = "The Sky Isles", isle = "Starfall Isle" },
	{ id = "galerock", name = "Gale Rock", region = "The Sky Isles", isle = "Gale Rock" },
	{ id = "stormcrown", name = "Stormcrown", region = "The Sky Isles", isle = "Stormcrown" },
} :: { Waystone }

Waystones.ById = {} :: { [string]: Waystone }
for _, w in Waystones.List do
	Waystones.ById[w.id] = w
end

Waystones.Regions = { "Island", "Sproutling City", "The Hills", "The Wider Land", "The Mountains", "The Sky Isles" }
Waystones.MapCooldown = 60 -- seconds between fast travels started from the world map
Waystones.AttuneXP = 40

return Waystones
