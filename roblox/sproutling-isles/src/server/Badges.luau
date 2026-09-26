-- Thin wrapper around Roblox BadgeService, same pcall-facade pattern as Analytics.luau: a
-- throttle, a bad ID or a service outage must never break gameplay.

local BadgeService = game:GetService("BadgeService")

local Badges = {}

-- Awards `badgeId` to `player`. No-ops (silently, no warning) while badgeId is 0 -- see
-- Products.luau's "IDs are 0 until you create the passes/products... paste the real IDs here"
-- convention: the badge hasn't been created on the Creator Dashboard yet. Once a real ID is
-- pasted into Config, this actually calls BadgeService, pcall-wrapped like every other
-- external-service call in this codebase (BadgeService:AwardBadge can throttle or fail).
function Badges.award(player: Player, badgeId: number)
	if badgeId == 0 then
		return
	end
	local ok, err = pcall(function()
		BadgeService:AwardBadge(player.UserId, badgeId)
	end)
	if not ok then
		warn("[Badges] AwardBadge failed:", err)
	end
end

return Badges
