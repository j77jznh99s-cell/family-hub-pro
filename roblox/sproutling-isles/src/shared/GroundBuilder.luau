--!strict
-- A low-poly ground of wedge triangles over the whole landmass (Shared.Landscape), so the place
-- is one connected world even before Roblox Terrain exists: Studio's edit view shows every area
-- standing on the same land, and at server start it is a floor to walk on while
-- TerrainBuilder fills in the real terrain. TerrainBuilder removes it (workspace.EditGround)
-- once the terrain is ready. Built offline by tools/bake-map (service-free, like MapBuilder).

local GroundBuilder = {}

local Instance = Instance
local Vector3 = Vector3
local CFrame = CFrame
local Color3 = Color3
local Enum = Enum

function GroundBuilder.useApi(api: any)
	Instance = api.Instance
	Vector3 = api.Vector3
	CFrame = api.CFrame
	Color3 = api.Color3
	Enum = api.Enum
end

local CELL = 40 -- studs per ground quad

-- the same colours TerrainBuilder gives each terrain material
local COLORS = {
	Grass = { 108, 190, 78 },
	LeafyGrass = { 82, 165, 62 },
	Rock = { 150, 140, 128 },
	Ground = { 135, 100, 68 },
	Sand = { 236, 214, 158 },
	Cobblestone = { 190, 180, 165 },
	Pavement = { 178, 170, 160 },
	Mud = { 115, 80, 55 },
}

local function wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: any)
	local w = Instance.new("WedgePart")
	w.Name = "Ground"
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
end

-- A solid triangle (a, b, c) from two WedgeParts.
local function triangle(parent: Instance, a: Vector3, b: Vector3, c: Vector3, color: Color3, material: any)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	if height < 0.05 then
		return
	end
	wedge(parent, Vector3.new(1, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), color, material)
	wedge(parent, Vector3.new(1, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, material)
end

-- Builds workspace.EditGround (and a see-through sea sheet). `L` is Shared.Landscape.
function GroundBuilder.Build(workspace: Instance, L: any): (Instance, number)
	local existing = workspace:FindFirstChild("EditGround")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "EditGround"
	local b = L.Bounds
	local count = 0
	local heights: { [number]: { [number]: number } } = {}
	local function h(i: number, j: number): number
		heights[i] = heights[i] or {}
		local row = heights[i]
		if row[j] == nil then
			local x, z = b.x0 + i * CELL, b.z0 + j * CELL
			row[j] = if L.inPlayArea(x, z) then L.WaterLevel - 4 else L.height(x, z)
		end
		return row[j]
	end
	local ni, nj = math.floor((b.x1 - b.x0) / CELL), math.floor((b.z1 - b.z0) / CELL)
	for j = 0, nj - 1 do
		for i = 0, ni - 1 do
			local x, z = b.x0 + (i + 0.5) * CELL, b.z0 + (j + 0.5) * CELL
			local h00, h10, h01, h11 = h(i, j), h(i + 1, j), h(i, j + 1), h(i + 1, j + 1)
			local wet = L.WaterLevel + 0.4
			if not L.inPlayArea(x, z) and math.max(h00, h10, h01, h11) > wet then
				local x0, z0 = b.x0 + i * CELL, b.z0 + j * CELL
				local hc = (h00 + h10 + h01 + h11) / 4
				local mat = L.material(x, z, hc)
				local c = COLORS[mat] or COLORS.Grass
				local color = Color3.fromRGB(c[1], c[2], c[3])
				local material = Enum.Material[mat] or Enum.Material.Grass
				local p00 = Vector3.new(x0, h00, z0)
				local p10 = Vector3.new(x0 + CELL, h10, z0)
				local p01 = Vector3.new(x0, h01, z0 + CELL)
				local p11 = Vector3.new(x0 + CELL, h11, z0 + CELL)
				-- the triangles sit half a stud low so buildings never float above them
				local down = Vector3.new(0, -0.5, 0)
				triangle(folder, p00 + down, p10 + down, p11 + down, color, material)
				triangle(folder, p00 + down, p11 + down, p01 + down, color, material)
				count += 4
			end
		end
	end
	-- the roads: flat strips laid along every curve, following the low-poly ground
	local function groundAt(x: number, z: number): number
		local i, j = math.floor((x - b.x0) / CELL), math.floor((z - b.z0) / CELL)
		local fx, fz = (x - b.x0) / CELL - i, (z - b.z0) / CELL - j
		local h00, h10, h01, h11 = h(i, j), h(i + 1, j), h(i, j + 1), h(i + 1, j + 1)
		-- the same two triangles per quad as above (split along the 00-11 diagonal)
		if fx >= fz then
			return h00 + (h10 - h00) * fx + (h11 - h10) * fz - 0.5
		end
		return h00 + (h11 - h01) * fx + (h01 - h00) * fz - 0.5
	end
	for r, samples in L.RoadSamples do
		local mat = L.RoadMaterial[r]
		local c = COLORS[mat] or COLORS.Ground
		local color = Color3.fromRGB(c[1], c[2], c[3])
		local material = Enum.Material[mat] or Enum.Material.Ground
		for k = 1, #samples - 3, 3 do
			local s0, s1 = samples[k], samples[k + 3]
			local a = Vector3.new(s0.x, math.max(groundAt(s0.x, s0.z), L.WaterLevel) + 0.25, s0.z)
			local e = Vector3.new(s1.x, math.max(groundAt(s1.x, s1.z), L.WaterLevel) + 0.25, s1.z)
			if not L.inPlayArea(s0.x, s0.z) and (e - a).Magnitude > 0.5 then
				local strip = Instance.new("Part")
				strip.Name = "Road"
				strip.Anchored = true
				strip.CanCollide = false
				strip.Size = Vector3.new(s0.hw * 2, 0.4, (e - a).Magnitude + 1.5)
				strip.CFrame = CFrame.lookAt((a + e) / 2, e)
				strip.Color = color
				strip.Material = material
				strip.Parent = folder
				count += 1
			end
		end
	end
	-- the sea: one see-through sheet at the waterline (no collision)
	local sea = Instance.new("Part")
	sea.Name = "SeaSheet"
	sea.Anchored = true
	sea.CanCollide = false
	sea.CanQuery = false
	sea.Size = Vector3.new(b.x1 - b.x0 + 900, 1, b.z1 - b.z0 + 900)
	sea.CFrame = CFrame.new((b.x0 + b.x1) / 2, L.WaterLevel - 0.5, (b.z0 + b.z1) / 2)
	sea.Color = Color3.fromRGB(35, 150, 205)
	sea.Material = Enum.Material.Glass
	sea.Transparency = 0.35
	sea.Parent = folder
	folder.Parent = workspace
	return folder, count + 1
end

return GroundBuilder
