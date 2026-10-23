-- The world map's points of interest: villages and sites, quest givers, shops and halls,
-- wind shrines, ports, the arena and the crypt. Collected once from the map at start-up and
-- handed to each client on request (MapPOIs).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Landscape = require(Shared.Landscape)
local Shops = require(Shared.Shops)
local Quests = require(Shared.Quests)

local MapService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local POIRemote = Instance.new("RemoteFunction")
POIRemote.Name = "MapPOIs"
POIRemote.Parent = remotes

type POI = { name: string, kind: string, x: number, z: number }
local pois: { POI } = {}

local SITE_NAMES = {
	castle = "Hilltop Castle",
	hamletWest = "West Hamlet",
	hamletEast = "East Hamlet",
	farm = "The Farm",
	falls = "Skyfall Falls",
	cape = "Lighthouse Cape",
	watch = "Watchtower",
	ruins = "Old Ruins",
	grove = "Ironbark's Grove",
	airport = "Airship Port",
	southvale = "Southvale",
	eastmere = "Eastmere",
	pinecrest = "Pinecrest",
	oldfort = "The Old Fort",
}

-- shops worth a pin, with the map category they show under
local SHOP_KINDS = {
	carriages = "vehicles", boats = "vehicles", aircraft = "vehicles",
	coachpaint = "custom", sailmaker = "custom", aeriepaint = "custom",
	bank = "crates", library = "hall", trainer = "hall", guild = "hall", maps = "hall",
	airships = "travel", shipwright = "travel", stable = "vehicles", tamer = "hall",
	blacksmith = "shop", armorer = "shop", alchemist = "shop", fletcher = "shop", enchanter = "shop", tailor = "shop",
}

function MapService.init(map: Instance)
	table.insert(pois, { name = "Garden Island", kind = "town", x = 0, z = 0 })
	table.insert(pois, { name = "Sproutling City", kind = "town", x = Landscape.CityCentre.x, z = Landscape.CityCentre.z })
	for id, name in SITE_NAMES do
		local s = Landscape.Sites[id]
		if s then
			table.insert(pois, { name = name, kind = "village", x = s.x, z = s.z })
		end
	end
	local seenShop: { [string]: boolean } = {}
	for _, d in map:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local p = d.Position
		local npc = d:GetAttribute("QuestNpc")
		local shop = d:GetAttribute("Shop")
		if typeof(npc) == "string" and Quests.Npcs[npc] then
			local who = Quests.Npcs[npc]
			table.insert(pois, { name = who.name .. " (" .. who.title .. ")", kind = "quest", x = p.X, z = p.Z })
		elseif d.Name == "ShopAnchor" and typeof(shop) == "string" then
			local catalog, key = Shops.get(shop)
			local kind = SHOP_KINDS[key]
			if catalog and kind and not seenShop[shop] then
				seenShop[shop] = true
				table.insert(pois, { name = catalog.name, kind = kind, x = p.X, z = p.Z })
			end
		elseif d:GetAttribute("WindShrine") then
			table.insert(pois, { name = "Wind Shrine to " .. tostring(d:GetAttribute("WindShrine")), kind = "shrine", x = p.X, z = p.Z })
		elseif d:GetAttribute("SkyLanding") then
			table.insert(pois, { name = tostring(d:GetAttribute("SkyLanding")) .. " (sky isle)", kind = "sky", x = p.X, z = p.Z })
		elseif d:GetAttribute("ArenaGate") then
			table.insert(pois, { name = "The Arena", kind = "arena", x = p.X, z = p.Z })
		elseif d.Name == "CryptPortal" then
			table.insert(pois, { name = "The Hollow Crypt (dungeon)", kind = "dungeon", x = p.X, z = p.Z })
		elseif d.Name == "MinePortal" then
			table.insert(pois, { name = "The Deepdelve Mines (dungeon, level 12+)", kind = "dungeon", x = p.X, z = p.Z })
		end
	end
	POIRemote.OnServerInvoke = function()
		return pois
	end
end

return MapService
