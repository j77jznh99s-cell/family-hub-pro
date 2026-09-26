-- Prints each species' payback time (price / dewPerSecond), grouped by rarity, so a human or
-- agent can eyeball the earn-rate curve at a glance instead of hand-computing it -- exactly the
-- check that caught a real balance bug in the Week 5 Codes review (2026-09-26: a proposed free
-- code's Rare seed turned out to be priced above the paid Starter Pack's own Rare seed).
--
-- Usage (from roblox/sproutling-isles): lune run tools/audit-economy
--
-- Second step (see vault/Projects/Sproutling Isles - Economy Auditor.md): also checks
-- src/server/Codes.luau's seed rewards against src/shared/Products.luau's paid catalogue, so the
-- exact GROWINGSTRONG-style mistake (a free code outpaying a paid item) gets caught automatically.
-- Event/gift tables beyond Codes.luau are still future work.

local roblox = require("@lune/roblox")
Color3 = roblox.Color3 :: any -- Species.luau evaluates Color3.fromRGB(...) at module load time;
-- Lune's require shares one global environment across scripts, so setting this global before
-- requiring Species is enough (confirmed by testing) -- no engine and no Studio needed.

local Species = require("../src/shared/Species")
local Codes = require("../src/server/Codes")
local Products = require("../src/shared/Products")

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

-- ---------------------------------------------------------------------------------------------
-- Free-tier code rewards vs. the paid catalogue's Rare-seed floor
-- ---------------------------------------------------------------------------------------------
-- The GROWINGSTRONG bug: a free evergreen code's seed reward (lilypadger, 180s payback) was
-- priced *above* the paid Starter Pack's own Rare seed (mushroomph, 120s payback) -- i.e. the free
-- code was a bigger giveaway than a paid dev product. That should never happen. This section
-- automates the check a human did by hand: find the cheapest (lowest-payback) Rare-or-above seed
-- granted by any paid dev product, then flag any Codes.list seed reward that pays back slower
-- (i.e. is worth more) than that floor.

local rarityRank: { [string]: number } = {}
for index, rarity in Species.RarityOrder do
	rarityRank[rarity] = index
end
local RARE_RANK = rarityRank["Rare"]

local function paybackOf(species: Species.Species): number
	return species.price / species.dewPerSecond
end

-- Products.luau doesn't have a structured "grants this species" field -- dev products only carry
-- a free-text `description` (e.g. "One-time: 2 Mushroomph seeds + 5,000 Dew."). Rather than
-- hardcode a separate reference table that could silently drift out of sync with Products.luau,
-- we parse each Rare-or-above species' name out of every dev product's description (case-
-- insensitive substring match). This is honest about being a text-matching heuristic, not a real
-- data link: it would miss a species mentioned under a different word, and it would false-match
-- a species name that happened to appear in unrelated copy. Spot-checked against the current
-- Products.luau contents (2026-09-26) and it only matches "Mushroomph" in the Starter Pack's
-- description, which is correct.
local paidRareOrAbove: { { productKey: string, species: Species.Species, payback: number } } = {}
for _, product in Products.DevProducts do
	local descriptionLower = string.lower(product.description)
	for _, species in Species.List do
		if (rarityRank[species.rarity] or 0) >= RARE_RANK and not species.limited then
			if string.find(descriptionLower, string.lower(species.name), 1, true) then
				table.insert(paidRareOrAbove, {
					productKey = product.key,
					species = species,
					payback = paybackOf(species),
				})
			end
		end
	end
end

-- Hardcoded fallback (used only if the parse above ever finds nothing -- e.g. a future dev
-- product grants a Rare+ seed via a description that doesn't name it, such as "a random rare
-- seed"). Keep this in sync by hand if that happens; it exists purely so the audit can't go
-- silent just because free text stopped being parseable. As of 2026-09-26 the parse above always
-- finds mushroomph via the Starter Pack, so this fallback is not exercised.
local FALLBACK_FLOOR = { productKey = "StarterPack (hardcoded fallback)", speciesId = "mushroomph" }

local floorPayback: number
local floorSourceLabel: string
if #paidRareOrAbove > 0 then
	table.sort(paidRareOrAbove, function(a, b)
		return a.payback < b.payback
	end)
	local cheapest = paidRareOrAbove[1]
	floorPayback = cheapest.payback
	floorSourceLabel = string.format("%s (%s, %ds payback)", cheapest.productKey, cheapest.species.name, floorPayback)
else
	local fallbackSpecies = Species.ById[FALLBACK_FLOOR.speciesId]
	assert(fallbackSpecies, "audit-economy: hardcoded fallback species id not found in Species.luau")
	floorPayback = paybackOf(fallbackSpecies)
	floorSourceLabel = string.format(
		"%s (%s, %ds payback) [hardcoded fallback -- no Rare+ seed name matched any dev product description]",
		FALLBACK_FLOOR.productKey,
		fallbackSpecies.name,
		floorPayback
	)
end

print("")
print(string.format("Paid Rare-seed floor: %s", floorSourceLabel))
print(string.rep("-", 70))

local anyFlagged = false
local codeNames: { string } = {}
for codeName in Codes.list do
	table.insert(codeNames, codeName)
end
table.sort(codeNames)

for _, codeName in codeNames do
	local reward = Codes.list[codeName]
	if reward.seeds then
		local seedIds: { string } = {}
		for speciesId in reward.seeds do
			table.insert(seedIds, speciesId)
		end
		table.sort(seedIds)
		for _, speciesId in seedIds do
			local species = Species.ById[speciesId]
			if not species then
				anyFlagged = true
				print(string.format("WARNING: code %s grants unknown species id %q", codeName, speciesId))
			else
				local payback = paybackOf(species)
				if payback > floorPayback then
					anyFlagged = true
					print(string.format(
						"WARNING: code %s grants %s (%ds payback), which exceeds the paid Rare-seed floor of %ds (%s) -- this free code out-values a paid dev product.",
						codeName,
						species.name,
						payback,
						floorPayback,
						floorSourceLabel
					))
				end
			end
		end
	end
end

if not anyFlagged then
	print("No free-tier code rewards exceed the paid catalogue's Rare-seed floor.")
end

-- ---------------------------------------------------------------------------------------------
-- Dev product Dew-per-Robux rates
-- ---------------------------------------------------------------------------------------------
-- Robux dev products don't carry a structured "grants this much Dew" field either -- same
-- situation as the Codes/Products check above, so this is another free-text heuristic parse of
-- each product's `description`, not a real data link. Two shapes show up in the current copy:
--   * a flat one-time amount, e.g. "5,000 Dew" (Starter Pack)
--   * a time-based income multiplier with a stated floor, e.g. "15 minutes of your current
--     income (min 500 Dew)" (Dew Pouch/Dew Barrel) -- for these we use the stated minimum,
--     since that's the only fixed number the description gives us. This is NOT an estimate of
--     what the product actually pays out at redemption time (that depends on the buyer's real
--     income rate, which this offline script has no way to know) -- it's a floor, so the real
--     rate for these two is >= what's printed here.
-- Several products have no parseable Dew number at all: InstantGrow, RestockNow (Restock Shop),
-- LuckBoost, SummonStarfall and SummonAurora all grant an instant action, a re-roll, a temporary
-- multiplier or a server-wide event rather than a lump Dew amount, and every Products.Passes
-- entry (DoubleDew, BigGreenhouse, SturdyGate, LuckyRod, VIP) grants a permanent passive effect,
-- not Dew. Those are skipped from the rate table below rather than guessed at, and listed
-- separately with a reason so nothing is silently omitted.

local function parseDewAmount(description: string): (number?, string?)
	local minAmount = string.match(description, "%(min ([%d,]+) Dew%)")
	if minAmount then
		return tonumber((string.gsub(minAmount, ",", ""))),
			"stated minimum floor (time-based income -- not an estimate of actual payout)"
	end
	local flatAmount = string.match(description, "([%d][%d,]*) Dew")
	if flatAmount then
		return tonumber((string.gsub(flatAmount, ",", ""))), "flat one-time amount"
	end
	return nil, nil
end

local rated: { { key: string, price: number, dew: number, ratePerRobux: number, basis: string } } = {}
local unrated: { { key: string, reason: string } } = {}

for _, product in Products.DevProducts do
	local dew, basis = parseDewAmount(product.description)
	if dew then
		table.insert(rated, {
			key = product.key,
			price = product.price,
			dew = dew,
			ratePerRobux = dew / product.price,
			basis = basis :: string,
		})
	else
		table.insert(unrated, {
			key = product.key,
			reason = "no parseable Dew amount (instant action / re-roll / temporary multiplier / server-wide event)",
		})
	end
end

for _, pass in Products.Passes do
	table.insert(unrated, { key = pass.key, reason = "game pass: permanent passive effect, not a lump Dew amount" })
end

table.sort(rated, function(a, b)
	return a.ratePerRobux > b.ratePerRobux
end)

print("")
print("Dev product Dew-per-Robux rates (heuristic parse of description text; see comment above)")
print(string.rep("-", 70))
print(string.format("%-14s %8s %10s %12s  %s", "Product", "Price", "Dew", "Dew/Robux", "Basis"))
for _, entry in rated do
	print(string.format(
		"%-14s %8d %10d %12.1f  %s",
		entry.key,
		entry.price,
		entry.dew,
		entry.ratePerRobux,
		entry.basis
	))
end

print("")
print("No flat Dew amount to rate:")
for _, entry in unrated do
	print(string.format("  %-14s -- %s", entry.key, entry.reason))
end
