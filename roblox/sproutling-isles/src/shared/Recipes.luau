--!strict
-- Cooking: monster drops + herbs make meals with buffs (and a couple of hearty heals). Cook at
-- any kitchen: the Cook & Larder, the tavern, the airship-port inn, or a hamlet cooking pot.
--
-- Buffs last `duration` seconds; a new meal of the same buff refreshes it.
--   damage  - multiplies the damage you deal   (1.2 = +20%)
--   defense - fraction of damage blocked, added to armour
--   speed   - extra walk speed
--   stamina - multiplies stamina regeneration
--   regen   - health restored per second

local Recipes = {}

export type Recipe = {
	id: string,
	name: string,
	blurb: string,
	needs: { [string]: number }, -- material id -> count
	heal: number?,
	stamina: number?,
	buff: { [string]: number }?,
	duration: number?,
}

Recipes.List = {
	{ id = "jelly_tart", name = "Slime Jelly Tart", blurb = "Wobbly, sweet, surprisingly filling.", needs = { jelly = 2, sunleaf = 1 }, heal = 60 },
	{ id = "tusk_broth", name = "Fiery Tusk Broth", blurb = "+20% damage for 2 minutes.", needs = { tusk = 2, emberroot = 1 }, buff = { damage = 1.2 }, duration = 120 },
	{ id = "marrow_soup", name = "Bone Marrow Soup", blurb = "Stamina regenerates 60% faster for 3 minutes.", needs = { bone = 3, moonmint = 1 }, buff = { stamina = 1.6 }, duration = 180 },
	{ id = "wing_skewers", name = "Gloom Wing Skewers", blurb = "+6 walk speed for 2 minutes.", needs = { wing = 2, emberroot = 1 }, buff = { speed = 6 }, duration = 120 },
	{ id = "herb_bread", name = "Smoked Herb Bread", blurb = "Blocks 10% more damage for 3 minutes.", needs = { pelt = 1, sunleaf = 2 }, buff = { defense = 0.1 }, duration = 180 },
	{ id = "forest_salad", name = "Forest Forager's Salad", blurb = "Heals 3 health a second for 1 minute.", needs = { sunleaf = 1, moonmint = 1, dewcap = 1 }, buff = { regen = 3 }, duration = 60 },
	{ id = "warden_feast", name = "Warden's Feast", blurb = "+35% damage and 15% defense for 5 minutes.", needs = { skull = 1, dewcap = 2, moonmint = 1 }, buff = { damage = 1.35, defense = 0.15 }, duration = 300 },
	{ id = "heartwood_elixir", name = "Heartwood Elixir", blurb = "Full heal and stamina, then 5 health a second for 1 minute.", needs = { heartwood = 1, dewcap = 1 }, heal = 1000, stamina = 100, buff = { regen = 5 }, duration = 60 },
} :: { Recipe }

local byId: { [string]: Recipe } = {}
for _, r in Recipes.List do
	byId[r.id] = r
end

function Recipes.get(id: string): Recipe?
	return byId[id]
end

-- Herb patches: which herb grows where (forage nodes, see ForageService) and the garden bonus
-- chances per hatch (first matching roll wins).
Recipes.GardenHerbs = { { id = "dewcap", chance = 0.08 }, { id = "emberroot", chance = 0.25 }, { id = "moonmint", chance = 0.45 }, { id = "sunleaf", chance = 1 } }

return Recipes
