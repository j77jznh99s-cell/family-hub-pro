--!strict
-- Reward crates: earned by levelling up, in the arena and from quests, or bought at the Royal
-- Treasury's crate vault. Opening one rolls a reward from its table (weights add up per tier).

local Crates = {}

export type Reward = { kind: string, amount: number?, id: string?, rarity: number?, weight: number, label: string }

Crates.Tiers = {
	wood = {
		name = "Wooden Crate",
		color = { 170, 120, 70 },
		price = 150,
		rewards = {
			{ kind = "dew", amount = 120, weight = 30, label = "120 Dew" },
			{ kind = "dew", amount = 300, weight = 12, label = "300 Dew" },
			{ kind = "xp", amount = 150, weight = 20, label = "150 XP" },
			{ kind = "potion", amount = 2, weight = 18, label = "2 Healing Draughts" },
			{ kind = "material", id = "dewcap", amount = 2, weight = 10, label = "2 Dewcap Mushrooms" },
			{ kind = "weapon", rarity = 2, weight = 9, label = "Uncommon+ weapon" },
			{ kind = "weapon", rarity = 3, weight = 1, label = "Rare+ weapon" },
		},
	},
	silver = {
		name = "Silver Crate",
		color = { 200, 205, 220 },
		price = 900,
		rewards = {
			{ kind = "dew", amount = 600, weight = 25, label = "600 Dew" },
			{ kind = "xp", amount = 600, weight = 22, label = "600 XP" },
			{ kind = "potion", amount = 5, weight = 15, label = "5 Healing Draughts" },
			{ kind = "material", id = "heartwood", amount = 1, weight = 8, label = "Ironbark Heartwood" },
			{ kind = "weapon", rarity = 3, weight = 22, label = "Rare+ weapon" },
			{ kind = "weapon", rarity = 4, weight = 8, label = "Epic+ weapon" },
		},
	},
	gold = {
		name = "Golden Crate",
		color = { 240, 195, 70 },
		price = 4000,
		rewards = {
			{ kind = "dew", amount = 3000, weight = 25, label = "3,000 Dew" },
			{ kind = "xp", amount = 2500, weight = 25, label = "2,500 XP" },
			{ kind = "material", id = "galecore", amount = 1, weight = 10, label = "Gale Core" },
			{ kind = "weapon", rarity = 4, weight = 30, label = "Epic+ weapon" },
			{ kind = "weapon", rarity = 5, weight = 10, label = "Legendary weapon" },
		},
	},
} :: { [string]: { name: string, color: { number }, price: number, rewards: { Reward } } }

Crates.Order = { "wood", "silver", "gold" }

-- Picks a reward index from a tier's table.
function Crates.roll(tier: string, r: number): number
	local list = Crates.Tiers[tier].rewards
	local total = 0
	for _, reward in list do
		total += reward.weight
	end
	local pick = r * total
	for i, reward in list do
		pick -= reward.weight
		if pick <= 0 then
			return i
		end
	end
	return #list
end

return Crates
