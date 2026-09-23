-- Dumps every map part (position, size, colour) to build/parts.json for tools/render_map_preview.py.
-- Usage: lune run tools/dump-parts   (after building + baking build/SproutlingIsles.rbxlx)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local game = roblox.deserializePlace(fs.readFile("build/SproutlingIsles.rbxlx"))
local out = {}
for _, d in game:GetService("Workspace").Map:GetDescendants() do
	if d:IsA("BasePart") then
		local cf = d.CFrame
		local c = d.Color
		table.insert(out, { n = d.Name, x = cf.Position.X, y = cf.Position.Y, z = cf.Position.Z, sx = d.Size.X, sy = d.Size.Y, sz = d.Size.Z,
			shape = d:IsA("Part") and tostring(d.Shape) or "Block", r = c.R, g = c.G, b = c.B, t = d.Transparency,
			rx = cf.RightVector.X, rz = cf.RightVector.Z, ux = cf.UpVector.X, uy = cf.UpVector.Y })
	end
end
fs.writeFile("build/parts.json", serde.encode("json", out))
print(#out)
