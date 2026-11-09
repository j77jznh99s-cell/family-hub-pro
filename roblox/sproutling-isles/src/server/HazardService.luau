-- Floor hazards: parts with a Hazard attribute (lava in the Emberdeep Caldera, whirlpools in the
-- Tidewrack Grotto). Touching one hurts a little and applies its element (Combat.Elements), at
-- most twice a second.

local Players = game:GetService("Players")

local CombatService = require(script.Parent.CombatService)

local HazardService = {}

local last: { [Player]: number } = {}

function HazardService.init(map: Instance)
	for _, d in map:GetDescendants() do
		local element = d:GetAttribute("Hazard")
		if d:IsA("BasePart") and typeof(element) == "string" then
			d.CanTouch = true
			d.Touched:Connect(function(hit)
				local character = hit:FindFirstAncestorOfClass("Model")
				local player = character and Players:GetPlayerFromCharacter(character)
				if not player or os.clock() < (last[player] or 0) then
					return
				end
				last[player] = os.clock() + 0.5
				CombatService.hurtPlayer(player, 4, d.Position, element)
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
end

return HazardService
