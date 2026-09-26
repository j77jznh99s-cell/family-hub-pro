--!strict
-- Week 5 live-ops "Codes" system (vault/Projects/Sproutling Isles - Launch & Live Ops.md, Week 5,
-- 7 Nov): a server-side table of redeemable codes and their rewards. See CodesService.luau for
-- redemption, validation and one-time-per-player tracking.
--
-- Per the spec, rewards must stay FREE-TIER ONLY: Dew, common/rare seeds, or a short Luck Boost.
-- Never add a reward here that only paying players could otherwise get (skins, game passes,
-- dev-product-gated perks) -- codes must not create a paid-only shortcut.
--
-- Reward shape: { dew: number?, seeds: { [speciesId]: count }?, luckSeconds: number? }.
-- A single code may combine more than one field; at least one should be set or redeeming does
-- nothing. `seeds` keys must be Species ids of Common/Uncommon/Rare rarity only (CodesService
-- doesn't enforce this at runtime since this table is dev-authored, not player input).

export type Reward = {
	dew: number?,
	seeds: { [string]: number }?,
	luckSeconds: number?,
}

local Codes = {}

Codes.list = {
	-- Real Week 5 code list (live-ops-manager proposal, 2026-09-26; GROWINGSTRONG's seed reward
	-- reviewed/swapped by game-designer same day -- see the vault note's "Week 5 code list" section
	-- for the full table, rationale and retention window per code). Goes live 7 Nov.

	-- The announcement copy already promises this exact code -- evergreen "thank you for finding
	-- the Codes button" grant.
	SPROUT1K = { dew = 1000 } :: Reward,

	-- Catch-up code for players who joined during Weeks 2-4 and missed the Week 1 Founding
	-- Gardener window.
	MISSEDBLOOM = { dew = 500, seeds = { mossbun = 1 } } :: Reward,

	-- Matches the shortest ad-tier Luck reward (5 min) so a code never beats the free ad path.
	LUCKYGARDEN = { luckSeconds = 300 } :: Reward,

	-- Community milestone/thank-you code. Reward uses mushroomph (not lilypadger -- swapped
	-- 2026-09-26 after a balance review found lilypadger priced above the paid Starter Pack's own
	-- Rare seed; mushroomph matches the Starter Pack's grant instead).
	GROWINGSTRONG = { dew = 250, seeds = { mushroomph = 1 } } :: Reward,

	-- Dew-free code: pure seed variety for new or alt accounts still Dew-poor.
	SEEDSTASH = { seeds = { mossbun = 2 } } :: Reward,
} :: { [string]: Reward }

return Codes
