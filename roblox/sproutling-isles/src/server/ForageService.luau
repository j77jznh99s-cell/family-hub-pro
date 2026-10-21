-- Wild herb patches for cooking: sunleaf in the lowlands, moonmint on the slopes, emberroot on
-- the high hills, and rare dewcap mushrooms under the trees. Walk up and gather (hold E);
-- a patch regrows two minutes later. Patches are placed once at server start from the
-- Landscape heightfield (plus a few on the garden island's beaches).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Landscape = require(Shared.Landscape)
local Loot = require(Shared.Loot)

local Prompts = require(script.Parent.Prompts)
local InventoryService = require(script.Parent.InventoryService)

local ForageService = {}

local REGROW = 120

local function hash(n: number): number
	local s = math.sin(n * 12.9898) * 43758.5453
	return s - math.floor(s)
end

local function patch(folder: Instance, herb: string, pos: Vector3)
	local m = Instance.new("Model")
	m.Name = "HerbPatch"
	m:SetAttribute("Herb", herb)
	local color = Loot.Materials[herb].color
	local function piece(name: string, size: Vector3, offset: Vector3, c: Color3, material: Enum.Material): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Ball
		p.Size = size
		p.CFrame = CFrame.new(pos + offset)
		p.Color = c
		p.Material = material
		p.Anchored = true
		p.CanCollide = false
		p.Parent = m
		return p
	end
	local bush = piece("Bush", Vector3.new(3, 2, 3), Vector3.new(0, 0.8, 0), Color3.fromRGB(70, 140, 60), Enum.Material.Grass)
	m.PrimaryPart = bush
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		piece("Bud", Vector3.new(0.9, 0.9, 0.9), Vector3.new(math.cos(a) * 1.1, 1.8, math.sin(a) * 1.1), color, Enum.Material.Neon)
	end
	m.Parent = folder
	local prompt = Prompts.create(bush, "Gather", Loot.Materials[herb].name, 0.8)
	prompt.MaxActivationDistance = 9
	local ready = true
	prompt.Triggered:Connect(function(player)
		if not ready then
			return
		end
		ready = false
		InventoryService.addMaterial(player, herb, if herb == "dewcap" then 1 else math.random(1, 2))
		prompt:SetAttribute("Active", false)
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = if p.Name == "Bud" then 1 else 0.6
			end
		end
		task.delay(REGROW, function()
			ready = true
			prompt:SetAttribute("Active", true)
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") then
					p.Transparency = 0
				end
			end
		end)
	end)
end

function ForageService.init()
	local folder = Instance.new("Folder")
	folder.Name = "HerbPatches"
	folder.Parent = Workspace
	local b = Landscape.Bounds
	local placed = 0
	local i = 0
	-- hills: sample a coarse grid, keep gentle grassy spots off sites and paths
	for z = b.z0, b.z1, 60 do
		for x = b.x0, b.x1, 60 do
			i += 1
			local px, pz = x + (hash(i) - 0.5) * 40, z + (hash(i + 7) - 0.5) * 40
			if not Landscape.inPlayArea(px, pz) and not Landscape.onSite(px, pz, 8) and hash(i + 3) < 0.35 then
				local h = Landscape.height(px, pz)
				if h > 3 and Landscape.slope(px, pz) < 0.5 then
					local herb = if hash(i + 11) < 0.12 then "dewcap" elseif h > 36 then "emberroot" elseif h > 18 then "moonmint" else "sunleaf"
					patch(folder, herb, Vector3.new(px, h, pz))
					placed += 1
				end
			end
		end
	end
	-- garden island beaches: sunleaf and moonmint for new players
	for k = 0, 7 do
		local side = if k % 2 == 0 then -1 else 1
		patch(folder, if k % 3 == 0 then "moonmint" else "sunleaf", Vector3.new(side * 238, 0, -320 + k * 85))
	end
	folder:SetAttribute("Count", placed + 8)
end

return ForageService
