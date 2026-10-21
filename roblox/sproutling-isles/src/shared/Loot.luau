--!strict
-- Loot: rarities, weapon drops, monster materials and who drops what.
--
-- A weapon drop is a stronger (or weaker) copy of one of the three base weapons; its rarity sets
-- a power multiplier on that weapon's damage. Picking up a better one than you have upgrades
-- that weapon; a worse one is salvaged for Dew. Materials are kept for cooking (step 5).

local Loot = {}

export type Rarity = { name: string, color: Color3, power: number, weight: number, salvage: number }

Loot.Rarities = {
	{ name = "Common", color = Color3.fromRGB(235, 235, 235), power = 1.0, weight = 55, salvage = 5 },
	{ name = "Uncommon", color = Color3.fromRGB(110, 220, 110), power = 1.18, weight = 27, salvage = 12 },
	{ name = "Rare", color = Color3.fromRGB(90, 160, 255), power = 1.4, weight = 12, salvage = 30 },
	{ name = "Epic", color = Color3.fromRGB(190, 110, 255), power = 1.7, weight = 5, salvage = 75 },
	{ name = "Legendary", color = Color3.fromRGB(255, 165, 40), power = 2.1, weight = 1, salvage = 200 },
} :: { Rarity }

-- Name prefixes per rarity, per weapon (all original).
local PREFIX = { "Worn", "Fine", "Runed", "Royal", "Sunforged" }
local BASE_NAME = { sword = "Knight's Sword", bow = "Hunter's Bow", staff = "Arcane Staff" }
Loot.WeaponIds = { "sword", "bow", "staff" }

function Loot.weaponName(base: string, rarity: number): string
	return PREFIX[rarity] .. " " .. (BASE_NAME[base] or base)
end

export type Material = { id: string, name: string, color: Color3, value: number } -- value = Dew a shop pays

Loot.Materials = {
	jelly = { id = "jelly", name = "Slime Jelly", color = Color3.fromRGB(120, 220, 100), value = 3 },
	tusk = { id = "tusk", name = "Goblin Tusk", color = Color3.fromRGB(235, 225, 190), value = 6 },
	pelt = { id = "pelt", name = "Ashen Pelt", color = Color3.fromRGB(140, 140, 150), value = 5 },
	bone = { id = "bone", name = "Old Bone", color = Color3.fromRGB(230, 225, 210), value = 5 },
	wing = { id = "wing", name = "Gloom Wing", color = Color3.fromRGB(90, 70, 110), value = 4 },
	skull = { id = "skull", name = "Warden's Skull", color = Color3.fromRGB(250, 245, 230), value = 120 },
	heartwood = { id = "heartwood", name = "Ironbark Heartwood", color = Color3.fromRGB(150, 100, 60), value = 150 },
} :: { [string]: Material }

-- What each enemy can drop: a material (with a chance), and a chance at a weapon with a minimum
-- rarity. Bosses always drop a weapon.
export type DropTable = { material: string?, materialChance: number, weaponChance: number, minRarity: number }

Loot.Drops = {
	slime = { material = "jelly", materialChance = 0.6, weaponChance = 0.08, minRarity = 1 },
	goblin = { material = "tusk", materialChance = 0.55, weaponChance = 0.14, minRarity = 1 },
	wolf = { material = "pelt", materialChance = 0.6, weaponChance = 0.1, minRarity = 1 },
	skeleton = { material = "bone", materialChance = 0.6, weaponChance = 0.16, minRarity = 1 },
	bat = { material = "wing", materialChance = 0.5, weaponChance = 0.06, minRarity = 1 },
	warden = { material = "skull", materialChance = 1, weaponChance = 1, minRarity = 3 },
	treant = { material = "heartwood", materialChance = 1, weaponChance = 1, minRarity = 3 },
} :: { [string]: DropTable }

-- Chests in the crypt: how many weapons and their minimum rarity.
Loot.Chests = {
	vault = { weapons = 2, minRarity = 2, dew = 60 },
	boss = { weapons = 1, minRarity = 4, dew = 250 },
}

-- Picks a rarity index at or above minRarity, weighted by Loot.Rarities[].weight.
function Loot.rollRarity(rng: Random, minRarity: number): number
	local total = 0
	for i, r in Loot.Rarities do
		if i >= minRarity then
			total += r.weight
		end
	end
	local roll = rng:NextNumber() * total
	for i, r in Loot.Rarities do
		if i >= minRarity then
			roll -= r.weight
			if roll <= 0 then
				return i
			end
		end
	end
	return minRarity
end

export type WeaponDrop = { base: string, rarity: number }

function Loot.rollWeapon(rng: Random, minRarity: number): WeaponDrop
	return { base = Loot.WeaponIds[rng:NextInteger(1, #Loot.WeaponIds)], rarity = Loot.rollRarity(rng, minRarity) }
end

return Loot
