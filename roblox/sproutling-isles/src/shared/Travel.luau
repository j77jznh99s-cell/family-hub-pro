--!strict
-- Fast travel by airship (Skyward Shipyard at the airship port) and by sea (the Shipwright at
-- the fishing docks). Destinations are ground points; the server adds a little height.
-- Hill heights come from Shared.Landscape sites so they stay in step with the terrain.

local Landscape = require(script.Parent.Landscape)

local Travel = {}

export type Destination = { id: string, name: string, modes: { [string]: boolean }, pos: Vector3 }

local sites = Landscape.Sites

Travel.Prices = { air = 40, sea = 25 }

-- City positions are fallbacks: the server moves them to the TravelPoint markers CityBuilder
-- leaves in the map (see TravelService).
Travel.Destinations = {
	{ id = "plaza", name = "Garden Island Plaza", modes = { air = true }, pos = Vector3.new(0, 1, 30) },
	{ id = "market", name = "Sproutling City Market Square", modes = { air = true }, pos = Vector3.new(118, 20, 832) },
	{ id = "port", name = "Airship Port", modes = { air = true }, pos = Vector3.new(sites.airport.x + 25, sites.airport.h + 1, sites.airport.z) },
	{ id = "castle", name = "Hilltop Castle Gate", modes = { air = true }, pos = Vector3.new(sites.castle.x + 48, sites.castle.h + 1, sites.castle.z) },
	{ id = "hamletWest", name = "West Hamlet", modes = { air = true }, pos = Vector3.new(sites.hamletWest.x + 6, sites.hamletWest.h + 1, sites.hamletWest.z + 6) },
	{ id = "hamletEast", name = "East Hamlet", modes = { air = true }, pos = Vector3.new(sites.hamletEast.x + 6, sites.hamletEast.h + 1, sites.hamletEast.z + 6) },
	{ id = "farm", name = "The Farm", modes = { air = true }, pos = Vector3.new(sites.farm.x, sites.farm.h + 1, sites.farm.z + 50) },
	{ id = "grove", name = "Edge of Ironbark's Grove", modes = { air = true }, pos = Vector3.new(sites.grove.x + 34, sites.grove.h + 1, sites.grove.z) },
	{ id = "southvale", name = "Southvale (highland village)", modes = { air = true }, pos = Vector3.new(sites.southvale.x + 6, sites.southvale.h + 1, sites.southvale.z + 6) },
	{ id = "eastmere", name = "Eastmere (mountain village)", modes = { air = true }, pos = Vector3.new(sites.eastmere.x + 6, sites.eastmere.h + 1, sites.eastmere.z + 6) },
	{ id = "pinecrest", name = "Pinecrest (western woods)", modes = { air = true }, pos = Vector3.new(sites.pinecrest.x + 6, sites.pinecrest.h + 1, sites.pinecrest.z + 6) },
	{ id = "oldfort", name = "The Old Fort", modes = { air = true }, pos = Vector3.new(sites.oldfort.x + 30, sites.oldfort.h + 1, sites.oldfort.z) },
	{ id = "minecamp", name = "Deepdelve Mine (mountains)", modes = { air = true }, pos = Vector3.new(sites.minecamp.x + 20, sites.minecamp.h + 1, sites.minecamp.z + 20) },
	{ id = "observatory", name = "Pell's Observatory (mountains)", modes = { air = true }, pos = Vector3.new(sites.observatory.x + 20, sites.observatory.h + 1, sites.observatory.z + 20) },
	{ id = "hermitage", name = "Oswin's Hermitage (mountains)", modes = { air = true }, pos = Vector3.new(sites.hermitage.x + 20, sites.hermitage.h + 1, sites.hermitage.z + 20) },
	{ id = "cape", name = "Lighthouse Cape", modes = { air = true, sea = true }, pos = Vector3.new(sites.cape.x - 10, sites.cape.h + 1, sites.cape.z) },
	{ id = "harbour", name = "City Harbour", modes = { sea = true, air = true }, pos = Vector3.new(sites.harbour.x - 20, sites.harbour.h + 1, sites.harbour.z) },
	{ id = "docks", name = "Fishing Docks", modes = { sea = true }, pos = Vector3.new(sites.docks.x - 20, sites.docks.h + 1, sites.docks.z) },
	{ id = "pier", name = "Garden Island Pier", modes = { sea = true }, pos = Vector3.new(262, 2, 20) },
} :: { Destination }

function Travel.get(id: string): Destination?
	for _, d in Travel.Destinations do
		if d.id == id then
			return d
		end
	end
	return nil
end

return Travel
