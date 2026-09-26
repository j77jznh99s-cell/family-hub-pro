-- Week 5 live-ops "Codes" system: a player opens the client Codes box, types a code and hits
-- Redeem; this validates it server-side and grants a one-time, per-player, free-tier-only reward
-- (Dew, common/rare seeds, or a short Luck Boost -- see Codes.luau for the reward table and why).
-- Bad, already-redeemed and spammed attempts all get a clear toast via State.notify, matching the
-- pattern used by ShopService/PondService/SnatchService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Species = require(Shared.Species)
local Format = require(Shared.Format)

local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local Analytics = require(script.Parent.Analytics)
local Codes = require(script.Parent.Codes)

local CodesService = {}

local MAX_CODE_LENGTH = 24
local REDEEM_COOLDOWN = 1 -- seconds; a spammed client just gets ignored, not a toast

local function describeReward(reward: Codes.Reward): string
	local parts = {}
	if reward.dew and reward.dew > 0 then
		table.insert(parts, Format.number(reward.dew) .. " Dew")
	end
	if reward.seeds then
		for speciesId, count in reward.seeds do
			if count > 0 then
				local species = Species.get(speciesId)
				table.insert(parts, count .. "x " .. (species and species.name or speciesId) .. " seed")
			end
		end
	end
	if reward.luckSeconds and reward.luckSeconds > 0 then
		table.insert(parts, Format.time(reward.luckSeconds) .. " Luck Boost")
	end
	if #parts == 0 then
		return "nothing (this code has no reward set -- tell roblox-engineer)"
	end
	return table.concat(parts, ", ")
end

local function grant(session: State.Session, reward: Codes.Reward, reason: string)
	if reward.dew and reward.dew > 0 then
		State.addDew(session, reward.dew, reason)
	end
	if reward.seeds then
		for speciesId, count in reward.seeds do
			if count > 0 and Species.get(speciesId) then
				State.addSeeds(session, speciesId, count)
			end
		end
	end
	if reward.luckSeconds and reward.luckSeconds > 0 then
		-- M5 pattern (MonetizationService.LuckBoost): both the in-memory session field and the saved
		-- data field must be set, or the boost silently doesn't survive a rejoin/server hop.
		session.luckUntil = math.max(session.luckUntil, os.time()) + reward.luckSeconds
		session.data.luckUntil = session.luckUntil
		session.player:SetAttribute("LuckUntil", session.luckUntil)
	end
end

local function redeem(player: Player, rawCode: string)
	local session = State.get(player)
	if not session then
		return
	end
	local now = os.clock()
	if (session.codeReadyAt or 0) > now then
		return -- silent: a spammed/scripted client, not a real user mistake worth a toast
	end
	session.codeReadyAt = now + REDEEM_COOLDOWN
	if type(rawCode) ~= "string" then
		return
	end
	-- Case-insensitive, whitespace-trimmed: a reasonable UX default the spec doesn't dictate.
	local code = rawCode:gsub("%s+", ""):upper()
	if code == "" then
		return
	end
	if #code > MAX_CODE_LENGTH then
		State.notify(session, "That code doesn't look right.", "#ff8080")
		return
	end
	local reward = Codes.list[code]
	if not reward then
		State.notify(session, '"' .. code .. '" isn\'t a valid code.', "#ff8080")
		return
	end
	session.data.codes = session.data.codes or {}
	if session.data.codes[code] then
		State.notify(session, 'You already redeemed "' .. code .. '".', "#ffb070")
		return
	end
	session.data.codes[code] = true
	grant(session, reward, "Code:" .. code)
	State.notify(session, "Code redeemed! +" .. describeReward(reward), "#a0ffa0")
	Analytics.custom(player, "CodeRedeemed", nil, { code })
end

function CodesService.init()
	Net.RedeemCode.OnServerEvent:Connect(redeem)
end

return CodesService
