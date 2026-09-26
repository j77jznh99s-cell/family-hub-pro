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
	-- Demo/placeholder code from the Week 5 announcement copy ("Redeem code SPROUT1K for free
	-- Dew"). This is NOT a real launch code -- swap in the actual Week 5 code list (live-ops-manager
	-- / owner) before 7 Nov.
	SPROUT1K = { dew = 1000 } :: Reward,
} :: { [string]: Reward }

return Codes
