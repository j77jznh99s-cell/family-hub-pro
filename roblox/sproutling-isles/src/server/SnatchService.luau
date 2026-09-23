-- Snatching: carry a rival's Sproutling home before time runs out or the owner bonks you.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local SproutModel = require(Shared.SproutModel)

local Net = require(script.Parent.Net)
local State = require(script.Parent.State)
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
}

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

	local victimSession = State.get(carry.victim)
	if success then
		if PlotService.placeSprout(thiefSession, carry.sprout) then
			Net.announce(thief.DisplayName .. " snatched " .. carry.victim.DisplayName .. "'s " .. SproutModel.displayName(carry.sprout) .. "!", "#ff9a5a")
			Net.Effect:FireClient(thief, "SnatchSuccess", { name = SproutModel.displayName(carry.sprout) })
			return
		end
		State.notify(thiefSession, "Your garden is full, so the Sproutling ran home!", "#ff8080")
	end

	if victimSession then
		local key = tostring(carry.pad)
		if not victimSession.data.pads[key] then
			victimSession.data.pads[key] = carry.sprout
			PlotService.renderPads(victimSession)
		else
			PlotService.placeSprout(victimSession, carry.sprout)
		end
		State.notify(victimSession, "Your " .. SproutModel.displayName(carry.sprout) .. " came back" .. (reason and (" (" .. reason .. ")") or "") .. "!", "#80ff80")
	end
	State.notify(thiefSession, "Snatch failed" .. (reason and (": " .. reason) or ""), "#ff8080")
end

local function onSnatch(plot: Model, pad: number, thief: Player)
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
	local key = tostring(pad)
	local sprout = victimSession.data.pads[key]
	if not sprout then
		return
	end

	victimSession.data.pads[key] = nil
	PlotService.renderPads(victimSession)

	local model = SproutModel.build(sprout, true)
	SproutModel.weldTo(model, root, CFrame.new(0, 4.5, 0))
	model.Parent = character

	local bonk = Prompts.create(root, "Bonk thief!", thief.DisplayName, 0, Enum.KeyCode.E)
	bonk.MaxActivationDistance = 12
	bonk:SetAttribute("OnlyUser", victim.UserId)
	bonk.Triggered:Connect(function(player)
		if player == victim then
			finish(thief, false, "bonked by " .. victim.DisplayName)
		end
	end)

	thiefSession.carrying = {
		sprout = sprout,
		victim = victim,
		pad = pad,
		expiresAt = os.clock() + Config.SnatchCarrySeconds,
		model = model,
		bonkPrompt = bonk,
	} :: Carry
	thiefSession.snatchReadyAt = now + Config.SnatchCooldownSeconds
	thiefSession.shieldUntil = 0 -- snatching gives up your own new-player shield
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

function SnatchService.init()
	for _, info in PlotService.allPlots() do
		for pad, prompt in info.snatchPrompts do
			prompt.Triggered:Connect(function(player)
				onSnatch(info.model, pad, player)
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
