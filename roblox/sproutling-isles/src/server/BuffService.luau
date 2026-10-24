-- Timed buffs from meals (Shared/Recipes): damage, defense, speed, stamina regen, health regen.
--
-- A new buff of a kind replaces the old one of that kind. Each active buff is mirrored to the
-- client as a player attribute Buff_<kind> = server time it ends, plus BuffName_<kind>, so the
-- HUD can show what's running. Buffs end on death.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local BuffService = {}

type Buff = { value: number, ends: number, name: string }
local buffs: { [Player]: { [string]: Buff } } = {}

local DEFAULTS = { damage = 1, defense = 0, speed = 0, stamina = 1, regen = 0, fireres = 0 }

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- The current value of a buff kind (its neutral default when none is active).
function BuffService.get(player: Player, kind: string): number
	local b = buffs[player] and buffs[player][kind]
	if b and now() < b.ends then
		return b.value
	end
	return DEFAULTS[kind] or 0
end

local function applySpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local mounted = player:GetAttribute("MountSpeed") or 0
		humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed + BuffService.get(player, "speed") + mounted
	end
end
BuffService.refreshSpeed = applySpeed

function BuffService.apply(player: Player, effects: { [string]: number }, duration: number, name: string)
	buffs[player] = buffs[player] or {}
	local ends = now() + duration
	for kind, value in effects do
		buffs[player][kind] = { value = value, ends = ends, name = name }
		player:SetAttribute("Buff_" .. kind, ends)
		player:SetAttribute("BuffName_" .. kind, name)
	end
	if effects.speed then
		applySpeed(player)
	end
end

local function clear(player: Player)
	local mine = buffs[player]
	if mine then
		for kind in mine do
			player:SetAttribute("Buff_" .. kind, nil)
			player:SetAttribute("BuffName_" .. kind, nil)
		end
	end
	buffs[player] = {}
end

function BuffService.init()
	Players.PlayerAdded:Connect(function(player)
		buffs[player] = {}
		player.CharacterAdded:Connect(function()
			clear(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		buffs[player] = nil
	end)
	-- expiry and health regen, once a second
	task.spawn(function()
		while true do
			task.wait(1)
			local t = now()
			for player, mine in buffs do
				local speedEnded = false
				for kind, b in mine do
					if t >= b.ends then
						mine[kind] = nil
						player:SetAttribute("Buff_" .. kind, nil)
						player:SetAttribute("BuffName_" .. kind, nil)
						if kind == "speed" then
							speedEnded = true
						end
					end
				end
				if speedEnded then
					applySpeed(player)
				end
				local regen = BuffService.get(player, "regen")
				if regen > 0 then
					local character = player.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.Health > 0 then
						humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + regen)
					end
				end
			end
		end
	end)
end

return BuffService
