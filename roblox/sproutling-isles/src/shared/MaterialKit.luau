--!strict
-- The royal Renaissance material kit: tiled textures (made with Higgsfield, 2026-10-21) applied
-- across every structure by role, so the whole world shares one look.
--
-- How it works
--   * Each kit entry becomes a MaterialVariant in MaterialService (a texture tied to a base
--     material). Parts opt in by name through part.MaterialVariant.
--   * paint() walks a model and gives each part a role from its name, material and colour:
--     castle stone, street cobbles, slate or terracotta roofs, timber-frame plaster, oak, marble,
--     crimson or navy cloth, carved friezes, flagstones. Stained glass gets a decal instead.
--   * Entries with an empty `asset` are skipped, so nothing changes until the images are
--     uploaded to Roblox and their IDs pasted below.
--
-- Uploading (one-off, needs the owner's Roblox account): download the 12 images from the
-- Higgsfield gallery (job ids below), then in Studio use Asset Manager > Bulk Import, or upload
-- them as Decals on the Creator Hub. Paste each image's asset id into `asset` (numbers only).
--
-- Service-free like MapBuilder: runs at bake time under Lune (tools/bake-map.luau) and at
-- server start.

local MaterialKit = {}

local Instance = Instance
local Enum = Enum

function MaterialKit.useApi(api: any)
	Instance = api.Instance
	Enum = api.Enum
end

export type Entry = {
	name: string, -- MaterialVariant name
	base: string, -- Enum.Material the variant applies to
	file: string, -- image file name (assets/textures/)
	job: string, -- Higgsfield job id, for re-downloading
	studs: number, -- studs per tile
	asset: string, -- Roblox asset id once uploaded ("" = not yet)
}

MaterialKit.Kit = {
	{ name = "RoyalAshlar", base = "Cobblestone", file = "royal_ashlar.png", job = "e23c5480-470d-411e-9971-5ed15ff7fa5c", studs = 14, asset = "" },
	{ name = "RoyalCobbles", base = "Cobblestone", file = "royal_cobbles.png", job = "5347a499-2292-4768-b898-fe9e560fcb0d", studs = 12, asset = "" },
	{ name = "RoyalSlate", base = "Slate", file = "royal_slate.png", job = "1c4eff2e-7da6-47f4-827e-6abf4794fccf", studs = 8, asset = "" },
	{ name = "RoyalTerracotta", base = "Brick", file = "royal_terracotta.png", job = "5cfc5982-2e32-4c03-a974-de916e633478", studs = 8, asset = "" },
	{ name = "RoyalTimberframe", base = "Plaster", file = "royal_timberframe.png", job = "27f385b8-a951-4bb6-ae45-4849c3ccde88", studs = 12, asset = "" },
	{ name = "RoyalOak", base = "WoodPlanks", file = "royal_oak.png", job = "721f3fca-d5c1-4ffb-9c7d-5080e0685ef7", studs = 6, asset = "" },
	{ name = "RoyalMarble", base = "Marble", file = "royal_marble.png", job = "9cc932e6-8067-48a3-9872-fc039c56c8dc", studs = 10, asset = "" },
	{ name = "RoyalStainedGlass", base = "Neon", file = "royal_stainedglass.png", job = "1135d8ec-c9a4-4bb5-923b-9cee7f9f3462", studs = 6, asset = "" },
	{ name = "RoyalCrimson", base = "Fabric", file = "royal_crimson.png", job = "3c1f49e4-cd5b-413b-8d84-1bd3c706aba3", studs = 4, asset = "" },
	{ name = "RoyalDamask", base = "Leather", file = "royal_damask.png", job = "b43d6b7e-41eb-45cd-9645-d7e1f3d0492a", studs = 4, asset = "" },
	{ name = "RoyalFrieze", base = "Limestone", file = "royal_frieze.png", job = "ab6f9511-9758-4f6c-ac3f-ee5eec7d3bc9", studs = 4, asset = "" },
	{ name = "RoyalFlagstone", base = "Pavement", file = "royal_flagstone.png", job = "d5c50fa8-de43-43c9-b533-b835c1579ea8", studs = 16, asset = "" },
} :: { Entry }

local byName: { [string]: Entry } = {}
for _, e in MaterialKit.Kit do
	byName[e.name] = e
end

local function ready(name: string): Entry?
	local e = byName[name]
	if e and e.asset ~= "" then
		return e
	end
	return nil
end

local function contentId(e: Entry): string
	return "rbxassetid://" .. e.asset
end

-- Part names that are carved trim (cornices, arches, bands) rather than plain wall.
local FRIEZE = {
	Cornice = true, Entablature = true, Band = true, DoorArch = true, WindowArch = true, Portal = true,
	Belfry = true, TowerRim = true, ClockBand = true, Setback = true, GateArch = true, Ledge = true,
}
-- Part names that are street paving rather than building stone.
local STREET = { Cobbles = true, Road = true, Deck = true, Quay = true, Gutter = true }
local PAVING = { Flagstones = true, Square = true, Plaza = true, Promenade = true, Boardwalk = false }
local STAINED = { StainedGlass = true, RoseWindow = true, RoseInner = true }

-- The kit entry a part should use, or nil to leave it alone.
function MaterialKit.role(p: BasePart): string?
	local name = p.Name
	local material = p.Material
	local c = p.Color
	if STAINED[name] then
		return "RoyalStainedGlass"
	elseif FRIEZE[name] then
		return "RoyalFrieze"
	elseif PAVING[name] then
		return "RoyalFlagstone"
	elseif material == Enum.Material.Cobblestone then
		return if STREET[name] then "RoyalCobbles" else "RoyalAshlar"
	elseif material == Enum.Material.Slate then
		if name == "Flagstones" then
			return "RoyalFlagstone"
		end
		-- warm roofs become terracotta, cool ones slate
		return if c.R > c.B + 0.12 then "RoyalTerracotta" else "RoyalSlate"
	elseif material == Enum.Material.Plaster then
		return "RoyalTimberframe"
	elseif material == Enum.Material.WoodPlanks then
		return "RoyalOak"
	elseif material == Enum.Material.Marble then
		return "RoyalMarble"
	elseif material == Enum.Material.Fabric and (name == "Banner" or name == "Flag" or name == "Blanket" or name == "Pennant" or name == "SailEmblem") then
		return if c.R > c.B then "RoyalCrimson" else "RoyalDamask"
	end
	return nil
end

-- Creates (or refreshes) a MaterialVariant for every uploaded kit entry. Returns how many.
function MaterialKit.ensureVariants(materialService: Instance): number
	local count = 0
	for _, e in MaterialKit.Kit do
		if e.asset ~= "" and e.base ~= "Neon" then
			local variant = materialService:FindFirstChild(e.name)
			if not variant then
				variant = Instance.new("MaterialVariant")
				variant.Name = e.name
				variant.Parent = materialService
			end
			local v = variant :: any
			v.BaseMaterial = (Enum.Material :: any)[e.base]
			v.ColorMap = contentId(e)
			v.StudsPerTile = e.studs
			count += 1
		end
	end
	-- anything cobblestone that paint() didn't claim, including the terrain's cobbled paths,
	-- falls back to the street cobbles
	local cobbles = ready("RoyalCobbles")
	if cobbles then
		pcall(function()
			(materialService :: any):SetBaseMaterialOverride(Enum.Material.Cobblestone, cobbles.name)
		end)
	end
	return count
end

local FACES = { "Front", "Back" }

-- Applies the kit to every part under root. Returns how many parts changed.
function MaterialKit.paint(root: Instance): number
	local changed = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local roleName = MaterialKit.role(d)
			local e = roleName and ready(roleName)
			if e then
				if e.base == "Neon" then
					if d:FindFirstChild("KitGlass") then
						continue -- already painted (baked place)
					end
					-- stained glass: a decal on both faces keeps the neon glow behind it
					for _, face in FACES do
						local decal = Instance.new("Decal")
						decal.Name = "KitGlass"
						decal.Texture = contentId(e)
						decal.Face = (Enum.NormalId :: any)[face]
						decal.Transparency = 0.15
						decal.Parent = d
					end
				else
					d.Material = (Enum.Material :: any)[e.base]
					d.MaterialVariant = e.name
				end
				changed += 1
			end
		end
	end
	return changed
end

return MaterialKit
