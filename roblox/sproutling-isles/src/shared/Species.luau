--!strict
-- Sproutling species. A seed of a species always hatches into that species;
-- mutation and size are rolled at hatch time.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type Species = {
	id: string,
	name: string,
	rarity: Rarity,
	price: number, -- seed price in Dew
	growSeconds: number,
	dewPerSecond: number,
	stockChance: number, -- chance the seed shop stocks it on a restock (0 = never sold in shop)
	stockRange: { number },
	body: Color3,
	leaf: Color3,
	topper: "Leaf" | "Petals" | "Cap" | "Spikes" | "Pad" | "Flame" | "Crystal",
	limited: string?, -- event id (e.g. "halloween2026") for limited species; nil for the base roster.
	-- Limited species always have stockChance = 0 (Species.ShopList excludes them automatically) and
	-- are earned only through the matching event's own systems (EventService, PondService).
}

local Species = {}

Species.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Species.RarityColors = {
	Common = Color3.fromRGB(190, 190, 190),
	Uncommon = Color3.fromRGB(110, 210, 110),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(180, 100, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 80, 140),
	Secret = Color3.fromRGB(40, 255, 230),
}

local list: { Species } = {
	{ id = "mossbun", name = "Mossbun", rarity = "Common", price = 10, growSeconds = 30, dewPerSecond = 1, stockChance = 1, stockRange = { 8, 20 }, body = Color3.fromRGB(120, 170, 90), leaf = Color3.fromRGB(70, 130, 60), topper = "Leaf" },
	{ id = "pebblepup", name = "Pebblepup", rarity = "Common", price = 40, growSeconds = 45, dewPerSecond = 2, stockChance = 1, stockRange = { 6, 15 }, body = Color3.fromRGB(150, 150, 160), leaf = Color3.fromRGB(90, 160, 80), topper = "Leaf" },
	{ id = "clovercub", name = "Clovercub", rarity = "Common", price = 120, growSeconds = 60, dewPerSecond = 4, stockChance = 0.9, stockRange = { 4, 10 }, body = Color3.fromRGB(90, 200, 110), leaf = Color3.fromRGB(40, 150, 60), topper = "Petals" },
	{ id = "tulipaca", name = "Tulipaca", rarity = "Uncommon", price = 500, growSeconds = 90, dewPerSecond = 10, stockChance = 0.7, stockRange = { 3, 8 }, body = Color3.fromRGB(250, 235, 215), leaf = Color3.fromRGB(240, 90, 120), topper = "Petals" },
	{ id = "cactoad", name = "Cactoad", rarity = "Uncommon", price = 1_500, growSeconds = 120, dewPerSecond = 20, stockChance = 0.55, stockRange = { 2, 6 }, body = Color3.fromRGB(80, 160, 90), leaf = Color3.fromRGB(250, 200, 80), topper = "Spikes" },
	{ id = "mushroomph", name = "Mushroomph", rarity = "Rare", price = 6_000, growSeconds = 180, dewPerSecond = 50, stockChance = 0.4, stockRange = { 1, 4 }, body = Color3.fromRGB(240, 225, 200), leaf = Color3.fromRGB(210, 60, 60), topper = "Cap" },
	{ id = "lilypadger", name = "Lilypadger", rarity = "Rare", price = 18_000, growSeconds = 240, dewPerSecond = 100, stockChance = 0.3, stockRange = { 1, 3 }, body = Color3.fromRGB(70, 110, 90), leaf = Color3.fromRGB(110, 200, 120), topper = "Pad" },
	{ id = "thornix", name = "Thornix", rarity = "Epic", price = 60_000, growSeconds = 360, dewPerSecond = 220, stockChance = 0.18, stockRange = { 1, 2 }, body = Color3.fromRGB(90, 40, 70), leaf = Color3.fromRGB(200, 40, 90), topper = "Spikes" },
	{ id = "bloomingo", name = "Bloomingo", rarity = "Epic", price = 180_000, growSeconds = 480, dewPerSecond = 450, stockChance = 0.12, stockRange = { 1, 2 }, body = Color3.fromRGB(255, 150, 190), leaf = Color3.fromRGB(255, 240, 120), topper = "Petals" },
	{ id = "sunfloof", name = "Sunfloof", rarity = "Legendary", price = 600_000, growSeconds = 600, dewPerSecond = 1_000, stockChance = 0.06, stockRange = { 1, 1 }, body = Color3.fromRGB(255, 210, 90), leaf = Color3.fromRGB(255, 140, 30), topper = "Flame" },
	{ id = "orchidragon", name = "Orchidragon", rarity = "Legendary", price = 2_000_000, growSeconds = 900, dewPerSecond = 2_200, stockChance = 0.03, stockRange = { 1, 1 }, body = Color3.fromRGB(170, 120, 220), leaf = Color3.fromRGB(250, 250, 255), topper = "Petals" },
	{ id = "moonpetal", name = "Moonpetal Wisp", rarity = "Mythic", price = 7_500_000, growSeconds = 1_500, dewPerSecond = 5_000, stockChance = 0, stockRange = { 0, 0 }, body = Color3.fromRGB(200, 220, 255), leaf = Color3.fromRGB(120, 140, 255), topper = "Crystal" },
	{ id = "starseed", name = "Starseed Sprite", rarity = "Secret", price = 25_000_000, growSeconds = 1_800, dewPerSecond = 12_000, stockChance = 0, stockRange = { 0, 0 }, body = Color3.fromRGB(30, 30, 60), leaf = Color3.fromRGB(80, 255, 230), topper = "Crystal" },
	-- Halloween "Hollow Harvest" limited species (appended after the base 13 so their `order` never
	-- shifts an existing species' analytics order). stockChance = 0 keeps them out of Species.ShopList;
	-- they're earned only via the Lantern Stall (pumpkit, gourdgeist) or the Wishing Pond during Spooky
	-- Fog from Part 2 (hollowisp). See EventService.luau and PondService.luau.
	{ id = "pumpkit", name = "Pumpkit", rarity = "Epic", price = 150_000, growSeconds = 420, dewPerSecond = 380, stockChance = 0, stockRange = { 0, 0 }, body = Color3.fromRGB(235, 140, 40), leaf = Color3.fromRGB(40, 110, 50), topper = "Cap", limited = "halloween2026" },
	{ id = "gourdgeist", name = "Gourdgeist", rarity = "Legendary", price = 1_200_000, growSeconds = 780, dewPerSecond = 1_500, stockChance = 0, stockRange = { 0, 0 }, body = Color3.fromRGB(225, 235, 215), leaf = Color3.fromRGB(150, 90, 255), topper = "Flame", limited = "halloween2026" },
	{ id = "hollowisp", name = "Hollowisp", rarity = "Mythic", price = 10_000_000, growSeconds = 1_500, dewPerSecond = 6_000, stockChance = 0, stockRange = { 0, 0 }, body = Color3.fromRGB(30, 30, 40), leaf = Color3.fromRGB(170, 90, 255), topper = "Crystal", limited = "halloween2026" },
}

Species.List = list
Species.ById = {} :: { [string]: Species }
for index, species in list do
	Species.ById[species.id] = species
	;(species :: any).order = index
end

function Species.get(id: string): Species?
	return Species.ById[id]
end

-- Limited species (Halloween etc.) are excluded here on purpose: Species.rollByRarity backs the
-- Pollen Parade and the Wishing Pond/Sky Well, and a limited species must only ever come from its
-- own event system (the Lantern Stall, or the Pond during Spooky Fog for hollowisp) -- never leak
-- out through an unrelated random-rarity roll just because it shares a rarity tier.
local countByRarity: { [string]: number } = {}
for _, species in list do
	if not species.limited then
		countByRarity[species.rarity] = (countByRarity[species.rarity] or 0) + 1
	end
end

-- Weighted random species pick. `weights` maps rarity -> total weight for that rarity,
-- shared evenly between the (non-limited) species of that rarity.
function Species.rollByRarity(weights: { [string]: number }, rng: Random): Species
	local total = 0
	for rarity, weight in weights do
		if countByRarity[rarity] then
			total += weight
		end
	end
	local roll = rng:NextNumber() * total
	for _, species in list do
		if not species.limited then
			roll -= (weights[species.rarity] or 0) / countByRarity[species.rarity]
			if roll <= 0 then
				return species
			end
		end
	end
	return list[1]
end

-- Species sold in the seed shop, in kiosk order.
Species.ShopList = {} :: { Species }
for _, species in list do
	if species.stockChance > 0 then
		table.insert(Species.ShopList, species)
	end
end

return Species
