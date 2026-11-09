--!strict
-- What each trade shop in the city sells (prices in Dew). Shop ids come from the Shop attribute
-- on the city's shop models; the second shop of a trade has a "2" suffix ("blacksmith2"), which
-- Shops.get() strips. Every open shop also buys monster materials (Loot.Materials[].value).

local Vehicles = require(script.Parent.Vehicles)
local Crates = require(script.Parent.Crates)

local Shops = {}

export type Item = {
	id: string,
	kind: string, -- "weapon" | "armor" | "consumable" | "unlock" | "vehicle" | "crate"
	unlock: string?, -- unlock: "companion" | "horse"
	vehicle: string?, -- vehicle id (Shared/Vehicles)
	crate: string?, -- crate tier (Shared/Crates)
	level: number?, -- player level needed to buy
	xp: number?, -- consumable: XP when used
	buff: { [string]: number }?, -- consumable: timed buff (BuffService kinds)
	duration: number?,
	name: string,
	price: number,
	base: string?, -- weapon: sword | bow | staff
	rarity: number?, -- weapon rarity index
	tier: number?, -- armor tier
	reduce: number?, -- armor: fraction of damage blocked
	heal: number?, -- consumable
	stamina: number?, -- consumable
}

-- cooking: has a kitchen (Shared/Recipes); travel: "air" | "sea" fast travel (Shared/Travel);
-- customize: paints vehicles of that class; map: opens the world map ("all" or "quests").
export type Shop = { name: string, greeting: string, items: { Item }, cooking: boolean?, travel: string?, customize: string?, map: string? }

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

C.tome_small = { id = "tome_small", kind = "consumable", name = "Traveller's Journal", xp = 250, price = 300 }
C.tome_large = { id = "tome_large", kind = "consumable", name = "Tome of Heroes", xp = 1500, price = 1600, level = 8 }
C.manual = { id = "manual", kind = "consumable", name = "Sparring Manual", xp = 500, price = 550 }
C.cloak = { id = "cloak", kind = "consumable", name = "Windrunner Cloak (+8 speed, 5 min)", buff = { speed = 8 }, duration = 300, price = 120 }
C.fireward = { id = "fireward", kind = "consumable", name = "Fireward Tonic (halves burning, 5 min)", buff = { fireres = 0.5 }, duration = 300, price = 150 }
C.tidebalm = { id = "tidebalm", kind = "consumable", name = "Tidebalm (halves soaking, 5 min)", buff = { waterres = 0.5 }, duration = 300, price = 180 }
C.warpaint = { id = "warpaint", kind = "consumable", name = "War Paint (+20% damage, 5 min)", buff = { damage = 1.2 }, duration = 300, price = 180 }

local function vehicles(shop: string): { Item }
	local out = {}
	for _, v in Vehicles.List do
		if v.shop == shop then
			table.insert(out, { id = "vehicle_" .. v.id, kind = "vehicle", vehicle = v.id, name = v.name .. " (" .. v.kind .. ")", price = v.price, level = v.level })
		end
	end
	return out
end

local function crates(): { Item }
	local out = {}
	for _, tier in Crates.Order do
		local c = Crates.Tiers[tier]
		table.insert(out, { id = "crate_" .. tier, kind = "crate", crate = tier, name = c.name, price = c.price })
	end
	return out
end

Shops.Catalog = {
	blacksmith = { name = "Blacksmith", greeting = "Steel for the road ahead.", items = weapons("sword", "Knight's Sword") },
	fletcher = { name = "Fletcher", greeting = "Straight shafts, true aim.", items = weapons("bow", "Hunter's Bow") },
	enchanter = { name = "Enchanter", greeting = "Staves humming with power.", items = weapons("staff", "Arcane Staff") },
	armorer = { name = "Armorer", greeting = "Better to wear it than need it.", items = Shops.Armor },
	alchemist = { name = "Alchemist", greeting = "Mind the fumes.", items = { C.potion_health, C.potion_stamina, C.fireward, C.tidebalm } },
	outfitter = { name = "Highcrag Outfitter", greeting = "Thick boots, warm cloaks, and tonics for the peak.", items = { C.potion_health, C.potion_stamina, C.fireward } },
	lodge = { name = "Climbers' Lodge", greeting = "Hot stew for cold climbers. The hearth's yours to cook on.", items = { C.meal_stew, C.meal_pie }, cooking = true },
	tidemarket = { name = "Tide Market", greeting = "Fresh from the sea! And Tidebalm for those who go under it.", items = { C.potion_health, C.potion_stamina, C.tidebalm } },
	gull = { name = "The Salty Gull", greeting = "Sit down, dry off. Fish pie's on, and the stove's free.", items = { C.meal_stew, C.meal_pie }, cooking = true },
	tavern = { name = "The Gilded Tankard", greeting = "Sit, eat, rest your feet. Use the kitchen if you like.", items = { C.meal_stew, C.meal_pie }, cooking = true },
	cook = { name = "Cook & Larder", greeting = "Bring me monster bits and herbs and we'll make a feast.", items = { C.meal_stew, C.meal_pie }, cooking = true },
	inn = { name = "The Cloud's Rest Inn", greeting = "Welcome, sky-traveller. The stove's yours.", items = { C.meal_stew, C.potion_stamina }, cooking = true },
	tamer = {
		name = "Beast Tamer",
		greeting = "Your Sproutlings could be more than garden friends.",
		items = { { id = "unlock_companion", kind = "unlock", unlock = "companion", name = "Sproutling Bond (companion)", price = 250 } },
	},
	stable = {
		name = "Stables",
		greeting = "A good horse is worth its oats.",
		items = { { id = "unlock_horse", kind = "unlock", unlock = "horse", name = "Riding Horse", price = 800 } },
	},
	airships = { name = "Skyward Shipyard", greeting = "Where to? The winds are fair.", items = {}, travel = "air" },
	shipwright = { name = "Shipwright", greeting = "Hop aboard, we sail with the tide.", items = {}, travel = "sea" },
	kitchen = { name = "Cooking Pot", greeting = "A bubbling pot over the fire.", items = {}, cooking = true },
	-- vehicles and their paint shops
	carriages = { name = "Carriage Works", greeting = "Wheels, horses, and the open road. What'll it be?", items = vehicles("carriages") },
	boats = { name = "Boatwright", greeting = "Every hull here floats. I checked twice.", items = vehicles("boats") },
	aircraft = { name = "Aerie Workshop", greeting = "Mind the propellers. And the wings. And the sky.", items = vehicles("aircraft") },
	coachpaint = { name = "Coachpaint Atelier", greeting = "Pick a colour, any colour. Then pick a better one.", items = {}, customize = "land" },
	sailmaker = { name = "Sailmaker", greeting = "Hulls, sails and trim, painted to order.", items = {}, customize = "water" },
	aeriepaint = { name = "Aerie Paint Loft", greeting = "Bright wings fly better. Probably.", items = {}, customize = "air" },
	-- the city's halls
	bank = { name = "Royal Treasury Crate Vault", greeting = "Crates of every kind, sealed by royal warrant.", items = crates() },
	library = { name = "Grand Library", greeting = "Knowledge is experience you didn't have to bleed for.", items = { C.tome_small, C.tome_large } },
	trainer = { name = "Barracks Quartermaster", greeting = "Train hard. Then train harder in the arena.", items = { C.manual, C.potion_health, C.warpaint } },
	tailor = { name = "Tailor", greeting = "A good cloak makes a quick traveller.", items = { C.cloak } },
	maps = { name = "Cartographer", greeting = "Every road, river and peak, inked by hand. Have a look.", items = {}, map = "all" },
	guild = { name = "Adventurers' Guild", greeting = "Folk across the land need help. The board shows who and where.", items = {}, map = "quests" },
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
