-- Fills Roblox Terrain with the hills, lagoon and sea described by Shared.Landscape.
--
-- Runs once at server start (Terrain can't be written offline by the Lune bake), in the
-- background so it never delays players joining. Takes a few seconds; the hills appear as it goes.

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

function TerrainBuilder.build(map: Instance?)
	local terrain = workspace.Terrain
	style(terrain)
	terrain:Clear()

	local extent = Landscape.Extent
	local span = extent * 2 + 900
	local centreZ = -30
	-- open sea: sand floor, then water up to the waterline
	terrain:FillBlock(CFrame.new(0, Landscape.SeaFloor - 4, centreZ), Vector3.new(span, 8, span), Enum.Material.Sand)
	local waterDepth = Landscape.WaterLevel - Landscape.SeaFloor
	terrain:FillBlock(CFrame.new(0, Landscape.SeaFloor + waterDepth / 2, centreZ), Vector3.new(span, waterDepth, span), Enum.Material.Water)
	-- a sand base under the play island so its edge doesn't float over deep water
	local p = Landscape.Play
	local baseTop = -3
	terrain:FillBlock(
		CFrame.new((p.x0 + p.x1) / 2, (Landscape.SeaFloor + baseTop) / 2, (p.z0 + p.z1) / 2),
		Vector3.new(p.x1 - p.x0 - 4, baseTop - Landscape.SeaFloor, p.z1 - p.z0 - 4),
		Enum.Material.Sand
	)

	-- hills, one column at a time
	local count = 0
	for z = -extent + centreZ, extent + centreZ, STEP do
		for x = -extent, extent, STEP do
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

	-- cobblestone paths
	for _, path in Landscape.Paths do
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local length = math.sqrt(dx * dx + dz * dz)
			local turn = math.atan2(dx, dz)
			for s = 0, length, 3 do
				local f = s / length
				paint(terrain, a[1] + dx * f, a[2] + dz * f, Vector3.new(7, 3, 4), Enum.Material.Cobblestone, turn)
			end
		end
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

return TerrainBuilder
