-- Rebirth Shrine, Daily Gift streak and the Sky Garden launch pad.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Species = require(Shared.Species)
local Format = require(Shared.Format)

local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local Analytics = require(script.Parent.Analytics)
local Prompts = require(script.Parent.Prompts)
local PlotService = require(script.Parent.PlotService)
local SnatchService = require(script.Parent.SnatchService)

local ProgressionService = {}

local DAILY_COOLDOWN = 20 * 3600

function ProgressionService.rebirthCost(session: State.Session): number
	return Config.RebirthBaseCost * Config.RebirthCostGrowth ^ session.data.rebirths
end

local function rebirth(player: Player)
	local session = State.get(player)
	if not session then
		return
	end
	if session.carrying then
		State.notify(session, "Finish your snatch first!")
		return
	end
	local cost = ProgressionService.rebirthCost(session)
	if session.data.dew < cost then
		State.notify(session, "Rebirth needs " .. Format.number(cost) .. " Dew. Keep growing!", "#ffb070")
		return
	end
	-- M3: Sproutlings being carried away from this player right now must not come back into the
	-- reborn garden. See SnatchService.forfeitCarriesFrom for why we void instead of refusing.
	SnatchService.forfeitCarriesFrom(player)
	local data = session.data
	-- 3b Rebirth funnel: same session id as step 1 "CanAfford" (fired in the income tick for this
	-- same tier), so Roblox can join the two steps into one funnel instance.
	local funnelSessionId = "rb" .. data.rebirths
	local dewBefore = data.dew
	data.rebirths += 1
	data.dew = Config.StartingDew
	if dewBefore > Config.StartingDew then
		-- 3c sink "Rebirth": the Dew reset isn't a plain State.spendDew (it's a hard reset to the
		-- starting amount, not a subtraction), so log it directly.
		Analytics.sink(player, "Rebirth", dewBefore - Config.StartingDew, data.dew)
	end
	-- 3d custom "Rebirth" (distinct from the sink above and the funnel step below)
	Analytics.custom(player, "Rebirth", data.rebirths)
	Analytics.funnel(player, "Rebirth", funnelSessionId, 2, "Rebirthed")
	data.seeds = table.clone(Config.StartingSeeds)
	data.soil = {}
	data.pads = {}
	data.storage = {}
	session.selectedSeed = nil
	State.syncAll(session)
	PlotService.renderPads(session)
	Net.announce(player.DisplayName .. " reached Rebirth " .. data.rebirths .. "! (+" .. math.floor(data.rebirths * Config.RebirthBonus * 100) .. "% Dew forever)", "#d0a0ff")
	Net.Effect:FireClient(player, "Rebirth", { rebirths = data.rebirths })
end

local function claimDaily(player: Player)
	local session = State.get(player)
	if not session then
		return
	end
	local data = session.data
	local now = os.time()
	local since = now - data.lastDaily
	if since < DAILY_COOLDOWN then
		State.notify(session, "Next gift in " .. Format.time(DAILY_COOLDOWN - since), "#ffb0d0")
		return
	end
	if since > Config.DailyResetHours * 3600 then
		data.streak = 0
	end
	data.streak += 1
	data.lastDaily = now
	local reward = Config.DailyRewards[(data.streak - 1) % #Config.DailyRewards + 1]
	local text
	if reward.seed then
		State.addSeeds(session, reward.seed, reward.count)
		local species = Species.get(reward.seed)
		text = reward.count .. "x " .. (species and species.name or reward.seed) .. " seed"
	else
		local amount = reward.dew * (1 + data.rebirths)
		State.addDew(session, amount, "Daily:" .. data.streak)
		text = Format.number(amount) .. " Dew"
	end
	if not data.onb.FirstDailyClaim then
		data.onb.FirstDailyClaim = true
		Analytics.onboarding(player, "FirstDailyClaim")
	end
	Analytics.custom(player, "DailyClaim", data.streak)
	player:SetAttribute("Streak", data.streak)
	player:SetAttribute("LastDaily", data.lastDaily)
	State.notify(session, "Day " .. data.streak .. " gift: " .. text .. "! Come back tomorrow to keep your streak.", "#ffb0d0")
end

function ProgressionService.init(map: Instance)
	local shrine = map.Plaza:FindFirstChild("Rebirth Shrine"):FindFirstChild("Anchor")
	local rebirthPrompt = Prompts.create(shrine, "Rebirth", "Rebirth Shrine", 1.5)
	rebirthPrompt.Triggered:Connect(rebirth)

	local gift = map.Plaza:FindFirstChild("Daily Gift"):FindFirstChild("Anchor")
	local giftPrompt = Prompts.create(gift, "Claim daily gift", "Daily Gift")
	giftPrompt.Triggered:Connect(claimDaily)

	-- Sky Garden: touching the launch pad flies you up if you have rebirthed at least once
	local sky = map.SkyGarden
	local landing = sky:FindFirstChild("Landing") :: BasePart
	local debounce: { [Player]: number } = {}
	local function touchPad(pad: BasePart, onTouch: (Player, Model) -> ())
		pad.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = character and game:GetService("Players"):GetPlayerFromCharacter(character)
			if player and (debounce[player] or 0) < os.clock() then
				debounce[player] = os.clock() + 2
				onTouch(player, character)
			end
		end)
	end
	touchPad(sky:FindFirstChild("LaunchPad") :: BasePart, function(player, character)
		local session = State.get(player)
		if session and session.carrying then
			State.notify(session, "You can't fly while carrying a Sproutling!", "#ffb070")
		elseif session and session.data.rebirths >= 1 then
			session.serverMovedAt = os.clock()
			session.serverMovedTo = landing.Position
			character:PivotTo(landing.CFrame + Vector3.new(0, 4, 0))
		elseif session then
			State.notify(session, "The Sky Garden opens after your first Rebirth.", "#d0a0ff")
		end
	end)
	touchPad(sky:FindFirstChild("ReturnPad") :: BasePart, function(player, character)
		local session = State.get(player)
		if session then
			session.serverMovedAt = os.clock()
			session.serverMovedTo = Vector3.new(0, 5, 220)
		end
		character:PivotTo(CFrame.new(0, 5, 220))
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		debounce[player] = nil
	end)
end

return ProgressionService
