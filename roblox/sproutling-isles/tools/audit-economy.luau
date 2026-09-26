-- Prints each species' payback time (price / dewPerSecond), grouped by rarity, so a human or
-- agent can eyeball the earn-rate curve at a glance instead of hand-computing it -- exactly the
-- check that caught a real balance bug in the Week 5 Codes review (2026-09-26: a proposed free
-- code's Rare seed turned out to be priced above the paid Starter Pack's own Rare seed).
--
-- Usage (from roblox/sproutling-isles): lune run tools/audit-economy
--
-- First step only (see vault/Projects/Sproutling Isles - Economy Auditor.md): reports the base
-- roster's payback curve. Does not yet check event/code/gift tables against it -- that is future
-- work, deliberately left small for the owner to review before extending it.

local roblox = require("@lune/roblox")
Color3 = roblox.Color3 :: any -- Species.luau evaluates Color3.fromRGB(...) at module load time;
-- Lune's require shares one global environment across scripts, so setting this global before
-- requiring Species is enough (confirmed by testing) -- no engine and no Studio needed.

local Species = require("../src/shared/Species")

local byRarity: { [string]: { Species.Species } } = {}
for _, rarity in Species.RarityOrder do
	byRarity[rarity] = {}
end
for _, species in Species.List do
	local bucket = byRarity[species.rarity]
	if bucket then
		table.insert(bucket, species)
	end
end

print(string.format("%-14s %-12s %8s %8s %8s  %s", "Species", "Rarity", "Price", "Dew/s", "Payback", "Notes"))
print(string.rep("-", 70))

for _, rarity in Species.RarityOrder do
	local bucket = byRarity[rarity]
	table.sort(bucket, function(a, b)
		return (a.price / a.dewPerSecond) < (b.price / b.dewPerSecond)
	end)
	for _, species in bucket do
		local payback = species.price / species.dewPerSecond
		local note = species.limited and ("limited: " .. species.limited) or ""
		print(string.format(
			"%-14s %-12s %8d %8d %7.0fs  %s",
			species.name,
			species.rarity,
			species.price,
			species.dewPerSecond,
			payback,
			note
		))
	end
end
