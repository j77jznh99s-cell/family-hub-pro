-- Bakes the procedural map into a Rojo-built place so it is visible in Studio edit mode.
-- Usage (from roblox/sproutling-isles):
--   rojo build -o build/SproutlingIsles.rbxlx && lune run tools/bake-map build/SproutlingIsles.rbxlx
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local MapBuilder = require("../src/shared/MapBuilder")
local Ambience = require("../src/shared/Ambience")

local path = process.args[1] or "build/SproutlingIsles.rbxlx"
local game = roblox.deserializePlace(fs.readFile(path))
local workspace = game:GetService("Workspace")

MapBuilder.useApi(roblox)
MapBuilder.useLandscape(require("../src/shared/Landscape"))
local CityBuilder = require("../src/shared/CityBuilder")
CityBuilder.useApi(roblox)
MapBuilder.useCity(CityBuilder)
local DungeonBuilder = require("../src/shared/DungeonBuilder")
DungeonBuilder.useApi(roblox)
MapBuilder.useDungeon(DungeonBuilder)
local WildsBuilder = require("../src/shared/WildsBuilder")
WildsBuilder.useApi(roblox)
MapBuilder.useWilds(WildsBuilder, require("../src/shared/Quests"), require("../src/shared/Waystones"))
local map = MapBuilder.Build(workspace)

-- Bake the lighting look too, so edit mode in Studio matches play mode.
Ambience.useApi(roblox)
Ambience.Apply(game:GetService("Lighting"))

-- Royal material kit: variants for uploaded textures, then paint the map by role.
local MaterialKit = require("../src/shared/MaterialKit")
MaterialKit.useApi(roblox)
local variants = MaterialKit.ensureVariants(game:GetService("MaterialService"))
local painted = MaterialKit.paint(map)
print(string.format("Material kit: %d variants, %d parts painted", variants, painted))

local count = 0
for _, descendant in map:GetDescendants() do
	if descendant:IsA("BasePart") then
		count += 1
	end
end

fs.writeFile(path, roblox.serializePlace(game, true))
print(string.format("Baked map into %s (%d parts)", path, count))
