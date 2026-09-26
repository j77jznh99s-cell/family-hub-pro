-- Thin wrapper around Roblox AnalyticsService. Every real call is wrapped in pcall so a
-- rate limit, a wrong argument or a service outage never breaks gameplay: we warn and move on.
--
-- NOTE (unverified): the AnalyticsService method signatures below are written from the spec in
-- vault/Projects/Sproutling Isles - Launch & Live Ops.md section 3, which itself says they are
-- "from memory, must be checked against Creator Docs". This sandbox has no internet access, so
-- they have NOT been checked against the live Creator Docs. If Roblox's real signatures differ,
-- the pcall below stops it from crashing gameplay, but the events may simply fail to log until
-- someone verifies and fixes the argument order/names against the current docs.

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

-- 3a. Onboarding funnel, once per player, ever. Order matches the spec's table exactly; Roblox
-- uses the step number to draw the funnel and the drop-off between steps.
local ONBOARDING_STEP_NUMBER: { [string]: number } = {
	Joined = 1,
	PlotClaimed = 2,
	FirstPlant = 3,
	FirstHatch = 4,
	FirstSeedBought = 5,
	FirstSell = 6,
	FirstWeatherHatch = 7,
	FirstGateLock = 8,
	FirstPondCast = 9,
	FirstDailyClaim = 10,
	FirstPurchase = 11,
}

-- 3c. Economy events: derive a default transactionType from the reason's prefix (the part before
-- the first ":"), matching the spec's table. Callers can still override it explicitly.
local TRANSACTION_TYPE_BY_REASON_PREFIX: { [string]: string } = {
	Income = "Gameplay",
	Sell = "Gameplay",
	SellStorage = "Gameplay",
	Daily = "TimedReward",
	Pond = "Gameplay",
	IAP = "IAP",
	AdReward = "Gameplay",
	Event = "Gameplay",
	Seed = "Shop",
	Rebirth = "Gameplay",
	EventShop = "Shop",
	Code = "Gameplay", -- Week 5 Codes system (CodesService.luau); not in the section 3 spec table, chosen to match the closest existing free-grant precedent (Daily uses TimedReward, but a one-off redeemable code reads closer to a plain Gameplay grant)
}

local CUSTOM_FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01,
	Enum.AnalyticsCustomFieldKeys.CustomField02,
	Enum.AnalyticsCustomFieldKeys.CustomField03,
}

-- Custom fields: up to 3 short, low-cardinality values (rarity names, not UIDs). Accepts a plain
-- array so call sites don't need to know the Enum; nils are skipped.
local function toCustomFields(fields: { string? }?): { [any]: string }?
	if not fields then
		return nil
	end
	local out = {}
	local any = false
	for i = 1, 3 do
		local value = fields[i]
		if value ~= nil then
			out[CUSTOM_FIELD_KEYS[i]] = tostring(value)
			any = true
		end
	end
	if not any then
		return nil
	end
	return out
end

local function reasonPrefix(reason: string): string
	return reason:match("^([^:]+)") or reason
end

local function transactionTypeFor(reason: string): string
	return TRANSACTION_TYPE_BY_REASON_PREFIX[reasonPrefix(reason)] or "Gameplay"
end

-- Fires an onboarding funnel step exactly once (callers guard with `session.data.onb[stepName]`).
function Analytics.onboarding(player: Player, stepName: string)
	local step = ONBOARDING_STEP_NUMBER[stepName]
	if not step then
		warn("[Analytics] unknown onboarding step:", stepName)
		return
	end
	local ok, err = pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
	if not ok then
		warn("[Analytics] LogOnboardingFunnelStepEvent failed:", err)
	end
end

-- 3b recurring funnels (Store/Snatch/Rebirth/EventShop/Ad) are not wired yet; this wrapper exists
-- so a follow-up task can call it without touching Analytics.luau again.
function Analytics.funnel(
	player: Player,
	funnelName: string,
	funnelSessionId: string?,
	step: number,
	stepName: string,
	customFields: { string? }?
)
	local ok, err = pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, funnelName, funnelSessionId, step, stepName, toCustomFields(customFields))
	end)
	if not ok then
		warn("[Analytics] LogFunnelStepEvent failed:", err)
	end
end

local function economy(
	flowType: any,
	player: Player,
	reason: string,
	amount: number,
	endingBalance: number,
	currencyType: string?,
	transactionType: string?
)
	local ok, err = pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flowType,
			currencyType or "Dew",
			amount,
			endingBalance,
			transactionType or transactionTypeFor(reason),
			reason
		)
	end)
	if not ok then
		warn("[Analytics] LogEconomyEvent failed:", err)
	end
end

-- 3c economy source (income, sells, daily gifts, pond, IAP...). `reason` doubles as the itemSku.
function Analytics.source(
	player: Player,
	reason: string,
	amount: number,
	endingBalance: number,
	currencyType: string?,
	transactionType: string?
)
	economy(Enum.AnalyticsEconomyFlowType.Source, player, reason, amount, endingBalance, currencyType, transactionType)
end

-- 3c economy sink (seed purchases, rebirth's Dew reset...). Same shape as Analytics.source.
function Analytics.sink(
	player: Player,
	reason: string,
	amount: number,
	endingBalance: number,
	currencyType: string?,
	transactionType: string?
)
	economy(Enum.AnalyticsEconomyFlowType.Sink, player, reason, amount, endingBalance, currencyType, transactionType)
end

-- 3d custom events. Not wired yet (a follow-up task); exists so call sites can start using it
-- without another change to this file.
function Analytics.custom(player: Player, eventName: string, value: number?, customFields: { string? }?)
	local ok, err = pcall(function()
		AnalyticsService:LogCustomEvent(player, eventName, value, toCustomFields(customFields))
	end)
	if not ok then
		warn("[Analytics] LogCustomEvent failed:", err)
	end
end

return Analytics
