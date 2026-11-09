-- Samples the Landscape heightfield to JSON for offline previews.
-- Usage (from roblox/sproutling-isles): lune run tools/sample-landscape build/landscape.json [step]
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Landscape = require("../src/shared/Landscape")

local step = tonumber(process.args[2]) or 8
local b = Landscape.Bounds
local out = { step = step, x0 = b.x0, z0 = b.z0, rows = {} }
for z = b.z0, b.z1, step do
	local row = {}
	for x = b.x0, b.x1, step do
		local h = Landscape.height(x, z)
		local material = if Landscape.inPlayArea(x, z) then "None" else Landscape.material(x, z, h)
		table.insert(row, { h, material })
	end
	table.insert(out.rows, row)
end
fs.writeFile(process.args[1] or "build/landscape.json", serde.encode("json", out))
print(string.format("%d rows", #out.rows))
