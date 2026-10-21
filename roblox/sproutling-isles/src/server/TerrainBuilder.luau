-- Fills Roblox Terrain with the land, lagoon, sea and roads described by Shared.Landscape.
--
-- Runs at server start (Terrain can't be written offline by the Lune bake), in the background so
-- it never delays players joining; the land appears as it goes. To see the terrain while editing,
-- and skip the build at start-up, bake it into the place once from Studio's command bar:
--   require(game.ServerScriptService.Server.TerrainBuilder).build(workspace.Map, true)
-- then save. A baked terrain is kept until Landscape.Version changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Landscape = require(ReplicatedStorage:WaitForChild("Shared").Landscape)

local TerrainBuilder = {}

local STEP = 8 -- column width in studs
local SURFACE_DEPTH = 4

local function style(terrain: Terrain)
	local colors = {
		[Enum.Material.Grass] = Color3.fromRGB(108, 190, 78),
		[Enum.Material.LeafyGrass] = Color3.fromRGB(82, 165, 62),
		[Enum.Material.Rock] = Color3.fromRGB(150, 140, 128),
		[Enum.Material.Ground] = Color3.fromRGB(135, 100, 68),
		[Enum.Material.Sand] = Color3.fromRGB(236, 214, 158),
		[Enum.Material.Cobblestone] = Color3.fromRGB(190, 180, 165),
		[Enum.Material.Mud] = Color3.fromRGB(115, 80, 55),
		[Enum.Material.Pavement] = Color3.fromRGB(178, 170, 160),
	}
	for material, color in colors do
		terrain:SetMaterialColor(material, color)
	end
	terrain.WaterColor = Color3.fromRGB(35, 150, 205)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.35
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	-- animated grass blades; not settable from scripts on every engine version, so best effort
	pcall(function()
		(terrain :: any).Decoration = true
	end)
end

local function paint(terrain: Terrain, x: number, z: number, size: Vector3, material: Enum.Material, turn: number?)
	local h = Landscape.height(x, z)
	local cf = CFrame.new(x, h - size.Y / 2, z) * CFrame.Angles(0, turn or 0, 0)
	terrain:FillBlock(cf, size, material)
end

local function hideSeaParts(map: Instance?)
	-- the terrain sea replaces the old glass sea parts
	local island = map and map:FindFirstChild("Island")
	if island then
		for _, name in { "Sea", "Seabed" } do
			local seaPart = island:FindFirstChild(name)
			if seaPart and seaPart:IsA("BasePart") then
				seaPart.Transparency = 1
				seaPart.CanCollide = false
			end
		end
	end
end

-- bake = true when run from Studio's command bar: marks the terrain as baked into the place.
function TerrainBuilder.build(map: Instance?, bake: boolean?)
	local terrain = workspace.Terrain
	if not bake and workspace:GetAttribute("TerrainBakedVersion") == Landscape.Version then
		hideSeaParts(map)
		workspace:SetAttribute("TerrainReady", true)
		return
	end
	workspace:SetAttribute("TerrainReady", false)
	style(terrain)
	terrain:Clear()

	local b = Landscape.Bounds
	local margin = 450
	local centre = Vector3.new((b.x0 + b.x1) / 2, 0, (b.z0 + b.z1) / 2)
	local span = Vector3.new(b.x1 - b.x0 + margin * 2, 0, b.z1 - b.z0 + margin * 2)
	-- open sea: sand floor, then water up to the waterline
	terrain:FillBlock(CFrame.new(centre.X, Landscape.SeaFloor - 4, centre.Z), Vector3.new(span.X, 8, span.Z), Enum.Material.Sand)
	local waterDepth = Landscape.WaterLevel - Landscape.SeaFloor
	terrain:FillBlock(CFrame.new(centre.X, Landscape.SeaFloor + waterDepth / 2, centre.Z), Vector3.new(span.X, waterDepth, span.Z), Enum.Material.Water)
	-- a sand base under each flat area so its edge doesn't float over deep water
	local baseTop = -3
	for _, p in Landscape.Areas do
		terrain:FillBlock(
			CFrame.new((p.x0 + p.x1) / 2, (Landscape.SeaFloor + baseTop) / 2, (p.z0 + p.z1) / 2),
			Vector3.new(p.x1 - p.x0 - 4, baseTop - Landscape.SeaFloor, p.z1 - p.z0 - 4),
			Enum.Material.Sand
		)
	end

	-- hills, one column at a time
	local count = 0
	for z = b.z0, b.z1, STEP do
		for x = b.x0, b.x1, STEP do
			if not Landscape.inPlayArea(x, z) then
				local h = Landscape.height(x, z)
				if h > Landscape.SeaFloor + 0.5 then
					local surface = Enum.Material[Landscape.material(x, z, h)]
					local bottom = Landscape.SeaFloor - 2
					local coreTop = h - SURFACE_DEPTH
					if coreTop > bottom then
						local core = if h < 1.5 then Enum.Material.Sand else Enum.Material.Rock
						terrain:FillBlock(CFrame.new(x, (bottom + coreTop) / 2, z), Vector3.new(STEP, coreTop - bottom, STEP), core)
					end
					local top = math.max(bottom, coreTop)
					terrain:FillBlock(CFrame.new(x, (top + h) / 2, z), Vector3.new(STEP, h - top, STEP), surface)
				end
				count += 1
				if count % 400 == 0 then
					task.wait()
				end
			end
		end
	end

	-- roads: overlapping slabs along every curve, at the road's own (rolling) height
	for i, samples in Landscape.RoadSamples do
		local material = Enum.Material[Landscape.RoadMaterial[i]]
		for k, sample in samples do
			if k % 2 == 1 or k == #samples then
				local cf = CFrame.lookAt(Vector3.new(sample.x, sample.y - 2, sample.z), Vector3.new(sample.x + sample.tx, sample.y - 2, sample.z + sample.tz))
				terrain:FillBlock(cf, Vector3.new(sample.hw * 2, 4, 9), material)
				-- clear anything poking above the road surface
				terrain:FillBlock(cf + Vector3.new(0, 6, 0), Vector3.new(sample.hw * 2, 8, 9), Enum.Material.Air)
			end
		end
		task.wait()
	end
	-- cobbled squares in the castle courtyard and the hamlets, ploughed farm fields
	local sites = Landscape.Sites
	for _, name in { "castle", "hamletWest", "hamletEast" } do
		local s = sites[name]
		local radius = if name == "castle" then 24 else 14
		terrain:FillCylinder(CFrame.new(s.x, s.h - 1.5, s.z), 3, radius, Enum.Material.Cobblestone)
	end
	for _, field in Landscape.Fields do
		paint(terrain, field.x, field.z, Vector3.new(field.w, 3, field.d), Enum.Material.Mud)
	end

	if bake then
		workspace:SetAttribute("TerrainBakedVersion", Landscape.Version)
	end
	workspace:SetAttribute("TerrainReady", true) -- EnemyService waits for this before spawning camps
	hideSeaParts(map)
end

return TerrainBuilder
