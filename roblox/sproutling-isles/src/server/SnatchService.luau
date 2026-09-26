-- Snatching: carry a rival's Sproutling home before time runs out or the owner bonks you.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Species = require(Shared.Species)
local SproutModel = require(Shared.SproutModel)

local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
local Analytics = require(script.Parent.Analytics)
local Prompts = require(script.Parent.Prompts)
local PlotService = require(script.Parent.PlotService)

local SnatchService = {}

type Carry = {
	sprout: any,
	victim: Player,
	pad: number,
	expiresAt: number,
	model: Model,
	bonkPrompt: ProximityPrompt,
	-- anti-cheat (see Config.CarryMaxSpeedFactor)
	lastPos: Vector3,
	lastClock: number,
	budget: number, -- studs of horizontal movement the thief may still make
	-- M3: set when the victim rebirths mid-carry. The victim's garden was wiped, so a failed carry
	-- does NOT return the Sproutling to them (it would survive the rebirth); it is simply lost.
	-- A successful carry still pays the thief. Either way exactly one copy exists: no dupe.
	forfeited: boolean,
	id: string, -- 3b Snatch funnel session id, one GUID per carry
	startedAt: number, -- os.clock() the carry began (3d SnatchResult's "seconds carried")
}

local function maxCarrySpeed(): number
	return Config.CarryWalkSpeed * Config.CarryMaxSpeedFactor
end

local function horizontal(v: Vector3): number
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- Saves both players right after a Sproutling changes hands, so a crash can't leave it in both
-- profiles (m17). DataService serialises saves per player, so this can't clobber a newer write.
local function saveBoth(a: State.Session?, b: State.Session?)
	for _, session in { a, b } do
		if session and session.persist and not session.leaving then
			task.spawn(DataService.save, session.player, session.data, false)
		end
	end
end

local function restoreWalkSpeed(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed
	end
end

-- Ends a carry. `success` hands the Sproutling to the thief, otherwise it goes back to the victim.
local function finish(thief: Player, success: boolean, reason: string?)
	local thiefSession = State.get(thief)
	local carry: Carry? = thiefSession and thiefSession.carrying
	if not thiefSession or not carry then
		return
	end
	thiefSession.carrying = nil
	thief:SetAttribute("Carrying", nil)
	carry.model:Destroy()
	carry.bonkPrompt:Destroy()
	restoreWalkSpeed(thief)

	-- 3d SnatchResult: fires exactly once per carry (guarded by `reported`) with a low-cardinality
	-- result bucket. The spec's fixed list is success/bonked/fell/timeout/full; "other" covers edge
	-- cases it doesn't name (moved too fast, the thief vanished, either player left).
	local secondsCarried = os.clock() - carry.startedAt
	local carrySpecies = Species.get(carry.sprout.s)
	local carryRarity = carrySpecies and carrySpecies.rarity or "unknown"
	local reported = false
	local function reportResult(result: string)
		if not reported then
			reported = true
			Analytics.custom(thief, "SnatchResult", secondsCarried, { result, carryRarity })
		end
	end

	local victimSession = State.get(carry.victim)
	if success then
		if PlotService.placeSprout(thiefSession, carry.sprout) then
			Net.announce(thief.DisplayName .. " snatched " .. carry.victim.DisplayName .. "'s " .. SproutModel.displayName(carry.sprout) .. "!", "#ff9a5a")
			Net.Effect:FireClient(thief, "SnatchSuccess", { name = SproutModel.displayName(carry.sprout) })
			if victimSession and not carry.forfeited then
				PlotService.refillPads(victimSession) -- m4: fill the emptied pad from storage
			end
			saveBoth(thiefSession, victimSession)
			Analytics.funnel(thief, "Snatch", carry.id, 2, "ReachedHome")
			reportResult("success")
			return
		end
		State.notify(thiefSession, "Your garden is full, so the Sproutling ran home!", "#ff8080")
		reportResult("full")
	end

	if carry.forfeited then
		-- the victim rebirthed mid-carry (see Carry.forfeited)
		State.notify(thiefSession, "Snatch failed" .. (reason and (": " .. reason) or "") .. ". The Sproutling faded away.", "#ff8080")
		reportResult("other")
		return
	end

	if victimSession then
		local key = tostring(carry.pad)
		if not victimSession.data.pads[key] then
			victimSession.data.pads[key] = carry.sprout
			PlotService.renderPads(victimSession)
		else
			PlotService.placeSprout(victimSession, carry.sprout, true) -- force: never delete a returned Sproutling
		end
		State.notify(victimSession, "Your " .. SproutModel.displayName(carry.sprout) .. " came back" .. (reason and (" (" .. reason .. ")") or "") .. "!", "#80ff80")
	end
	State.notify(thiefSession, "Snatch failed" .. (reason and (": " .. reason) or ""), "#ff8080")
	reportResult(
		if reason and reason:match("^bonked") then "bonked"
		elseif reason == "the thief fell" or reason == "the thief vanished" then "fell"
		elseif reason == "too slow" then "timeout"
		else "other"
	)
end

local function onSnatch(plot: Model, pad: number, thief: Player, prompt: ProximityPrompt)
	local thiefSession = State.get(thief)
	local ownerId = plot:GetAttribute("OwnerUserId")
	local victim = ownerId and Players:GetPlayerByUserId(ownerId)
	local victimSession = victim and State.get(victim)
	if not thiefSession or not victimSession or victim == thief or not thiefSession.plot then
		return
	end
	local now = os.time()
	if thiefSession.carrying then
		State.notify(thiefSession, "You're already carrying one!")
		return
	elseif now < thiefSession.snatchReadyAt then
		State.notify(thiefSession, "Catch your breath! Snatch again in " .. (thiefSession.snatchReadyAt - now) .. "s")
		return
	elseif PlotService.isLocked(victimSession) then
		State.notify(thiefSession, "That gate is locked!")
		return
	elseif victimSession.shieldUntil > now then
		State.notify(thiefSession, victim.DisplayName .. " is new here and shielded for a bit.")
		return
	end
	local character = thief.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	-- M1: the thief must really be at the pad (don't trust the client or engine-side prompt range checks)
	local pads = plot:FindFirstChild("Pads")
	local padPart = pads and pads:FindFirstChild("Pad" .. pad) :: BasePart?
	if not padPart or (root.Position - padPart.Position).Magnitude > prompt.MaxActivationDistance + Config.SnatchReachSlack then
		return
	end
	local key = tostring(pad)
	local sprout = victimSession.data.pads[key]
	if not sprout then
		return
	end
	local species = Species.get(sprout.s)
	local rarity = species and species.rarity or "unknown"

	victimSession.data.pads[key] = nil
	PlotService.renderPads(victimSession)
	-- 3d SnatchVictimLeft: checked in init.server.luau's onPlayerRemoving within 120s of this
	victimSession.lastStolenAt = os.time()
	victimSession.lastStolenRarity = rarity

	local model = SproutModel.build(sprout, true)
	SproutModel.weldTo(model, root, CFrame.new(0, 4.5, 0))
	model.Parent = character

	-- M2: own key (R / gamepad Y) and AlwaysShow, so the victim's E soil prompts never hide it
	local bonk = Prompts.create(root, "Bonk thief!", thief.DisplayName, 0, Enum.KeyCode.R)
	bonk.GamepadKeyCode = Enum.KeyCode.ButtonY
	bonk.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	bonk.MaxActivationDistance = 14
	bonk:SetAttribute("OnlyUser", victim.UserId)
	bonk.Triggered:Connect(function(player)
		if player == victim then
			finish(thief, false, "bonked by " .. victim.DisplayName)
		end
	end)

	local carryId = HttpService:GenerateGUID(false)
	thiefSession.carrying = {
		sprout = sprout,
		victim = victim,
		pad = pad,
		expiresAt = os.clock() + Config.SnatchCarrySeconds,
		model = model,
		bonkPrompt = bonk,
		lastPos = root.Position,
		lastClock = os.clock(),
		budget = maxCarrySpeed() * Config.CarryBurstSeconds,
		forfeited = false,
		id = carryId,
		startedAt = os.clock(),
	} :: Carry
	Analytics.funnel(thief, "Snatch", carryId, 1, "Grabbed")
	Analytics.custom(thief, "SnatchStart", 1, { rarity, if victimSession.passes.SturdyGate then "y" else "n" })
	thiefSession.snatchReadyAt = now + Config.SnatchCooldownSeconds
	thiefSession.shieldUntil = 0 -- snatching gives up your own new-player shield
	thiefSession.data.shieldForfeited = true -- m7: for good, not just until you rejoin
	thief:SetAttribute("ShieldUntil", 0)
	thief:SetAttribute("Carrying", SproutModel.displayName(sprout))
	thief:SetAttribute("CarryEndsAt", workspace:GetServerTimeNow() + Config.SnatchCarrySeconds)
	humanoid.WalkSpeed = Config.CarryWalkSpeed

	State.notify(thiefSession, "Run home! " .. Config.SnatchCarrySeconds .. "s to reach your garden.", "#ffd060")
	State.notify(victimSession, thief.DisplayName .. " is stealing your " .. SproutModel.displayName(sprout) .. "! Catch them and BONK!", "#ff5050")
	Net.Effect:FireClient(victim, "Stolen", { thief = thief.DisplayName })

	humanoid.Died:Once(function()
		finish(thief, false, "the thief fell")
	end)
end

function SnatchService.onLeaving(player: Player)
	local session = State.get(player)
	if session and session.carrying then
		finish(player, false, "the thief left")
	end
	-- anything stolen FROM this player is still mid-carry: send it back to them first so it is saved
	for _, other in State.sessions do
		local carry = other.carrying
		if carry and carry.victim == player then
			finish(other.player, false, "owner left")
		end
	end
end

-- M3: called by the Rebirth Shrine before it wipes `victim`'s garden. Carries of their Sproutlings
-- keep going (the thief can still win them), but a failed carry no longer returns the Sproutling
-- to the reborn garden. We void rather than refuse the rebirth so a thief can't block it.
function SnatchService.forfeitCarriesFrom(victim: Player)
	for _, other in State.sessions do
		local carry = other.carrying
		if carry and carry.victim == victim then
			carry.forfeited = true
		end
	end
end

-- M1: token-bucket speed check. Returns false if the thief moved faster than allowed.
local function movedLegally(session: State.Session, carry: Carry, position: Vector3): boolean
	local now = os.clock()
	local dt = now - carry.lastClock
	carry.lastClock = now
	local moved = horizontal(position - carry.lastPos)
	-- A server teleport (e.g. pushed out of a locked garden) is free. For ~1 s after it, measure from
	-- whichever is closer, the old position or the teleport target, since the client may briefly
	-- report either while it catches up. Jumping somewhere else in that window is still charged.
	local movedTo = session.serverMovedTo
	if movedTo and session.serverMovedAt and now - session.serverMovedAt < 1 then
		moved = math.min(moved, horizontal(position - movedTo))
	end
	carry.lastPos = position
	local speed = maxCarrySpeed()
	carry.budget = math.min(carry.budget + speed * dt, speed * Config.CarryBurstSeconds) - moved
	return carry.budget >= 0
end

function SnatchService.init()
	for _, info in PlotService.allPlots() do
		for pad, prompt in info.snatchPrompts do
			prompt.Triggered:Connect(function(player)
				onSnatch(info.model, pad, player, prompt)
			end)
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, session in State.sessions do
				local carry = session.carrying
				if carry then
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if not root then
						finish(player, false, "the thief vanished")
					elseif not movedLegally(session, carry, root.Position) then
						warn("[Sproutling] carry speed check failed for", player.Name)
						finish(player, false, "moved too fast")
					elseif session.plot and PlotService.isInside(session.plot, root.Position) then
						finish(player, true)
					elseif os.clock() > carry.expiresAt then
						finish(player, false, "too slow")
					end
				end
			end
		end
	end)
end

return SnatchService
