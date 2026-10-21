--!strict
-- What each trade shop in the city sells (prices in Dew). Shop ids come from the Shop attribute
-- on the city's shop models; the second shop of a trade has a "2" suffix ("blacksmith2"), which
-- Shops.get() strips. Every open shop also buys monster materials (Loot.Materials[].value).

local Shops = {}

export type Item = {
	id: string,
	kind: string, -- "weapon" | "armor" | "consumable"
	name: string,
	price: number,
	base: string?, -- weapon: sword | bow | staff
	rarity: number?, -- weapon rarity index
	tier: number?, -- armor tier
	reduce: number?, -- armor: fraction of damage blocked
	heal: number?, -- consumable
	stamina: number?, -- consumable
}

export type Shop = { name: string, greeting: string, items: { Item }, cooking: boolean? } -- cooking: has a kitchen (Shared/Recipes)

local function weapons(base: string, label: string): { Item }
	return {
		{ id = base .. "_2", kind = "weapon", base = base, rarity = 2, name = "Fine " .. label, price = 350 },
		{ id = base .. "_3", kind = "weapon", base = base, rarity = 3, name = "Runed " .. label, price = 1400 },
		{ id = base .. "_4", kind = "weapon", base = base, rarity = 4, name = "Royal " .. label, price = 5000 },
	}
end

-- Armour tiers (index = tier). Tier 0 = none.
Shops.Armor = {
	{ id = "armor_1", kind = "armor", tier = 1, name = "Padded Jerkin", reduce = 0.08, price = 300 },
	{ id = "armor_2", kind = "armor", tier = 2, name = "Chain Hauberk", reduce = 0.16, price = 1200 },
	{ id = "armor_3", kind = "armor", tier = 3, name = "Knight's Plate", reduce = 0.25, price = 4500 },
} :: { Item }

Shops.Consumables = {
	potion_health = { id = "potion_health", kind = "consumable", name = "Healing Draught", heal = 60, price = 60 },
	potion_stamina = { id = "potion_stamina", kind = "consumable", name = "Stamina Tonic", stamina = 100, price = 40 },
	meal_stew = { id = "meal_stew", kind = "consumable", name = "Hearty Stew", heal = 35, price = 25 },
	meal_pie = { id = "meal_pie", kind = "consumable", name = "Berry Pie", heal = 20, stamina = 50, price = 30 },
} :: { [string]: Item }

local C = Shops.Consumables

Shops.Catalog = {
	blacksmith = { name = "Blacksmith", greeting = "Steel for the road ahead.", items = weapons("sword", "Knight's Sword") },
	fletcher = { name = "Fletcher", greeting = "Straight shafts, true aim.", items = weapons("bow", "Hunter's Bow") },
	enchanter = { name = "Enchanter", greeting = "Staves humming with power.", items = weapons("staff", "Arcane Staff") },
	armorer = { name = "Armorer", greeting = "Better to wear it than need it.", items = Shops.Armor },
	alchemist = { name = "Alchemist", greeting = "Mind the fumes.", items = { C.potion_health, C.potion_stamina } },
	tavern = { name = "The Gilded Tankard", greeting = "Sit, eat, rest your feet. Use the kitchen if you like.", items = { C.meal_stew, C.meal_pie }, cooking = true },
	cook = { name = "Cook & Larder", greeting = "Bring me monster bits and herbs and we'll make a feast.", items = { C.meal_stew, C.meal_pie }, cooking = true },
	inn = { name = "The Cloud's Rest Inn", greeting = "Welcome, sky-traveller. The stove's yours.", items = { C.meal_stew, C.potion_stamina }, cooking = true },
	kitchen = { name = "Cooking Pot", greeting = "A bubbling pot over the fire.", items = {}, cooking = true },
	herbalist = { name = "Herbalist", greeting = "Every herb has its use.", items = {}, cooking = true },
} :: { [string]: Shop }

-- The catalogue for a Shop attribute value, or nil if that trade isn't open yet.
function Shops.get(id: string): (Shop?, string)
	local base = string.gsub(id, "%d+$", "")
	return Shops.Catalog[base], base
end

-- Find an item by id in any catalogue.
function Shops.item(id: string): Item?
	for _, shop in Shops.Catalog do
		for _, item in shop.items do
			if item.id == id then
				return item
			end
		end
	end
	return nil
end

Shops.BagSize = 30

return Shops
