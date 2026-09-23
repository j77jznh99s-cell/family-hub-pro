-- Bakes the procedural map into a Rojo-built place so it is visible in Studio edit mode.
-- Usage (from roblox/sproutling-isles):
--   rojo build -o build/SproutlingIsles.rbxlx && lune run tools/bake-map build/SproutlingIsles.rbxlx
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local MapBuilder = require("../src/shared/MapBuilder")

local path = process.args[1] or "build/SproutlingIsles.rbxlx"
local game = roblox.deserializePlace(fs.readFile(path))
local workspace = game:GetService("Workspace")

MapBuilder.useApi(roblox)
local map = MapBuilder.Build(workspace)

local count = 0
for _, descendant in map:GetDescendants() do
	if descendant:IsA("BasePart") then
		count += 1
	end
end

fs.writeFile(path, roblox.serializePlace(game, true))
print(string.format("Baked map into %s (%d parts)", path, count))
