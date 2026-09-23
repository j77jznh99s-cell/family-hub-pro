-- ProximityPrompt factory. The server never toggles prompt.Enabled (that would fight the
-- client); instead it sets attributes the client uses to show/hide prompts per player:
--   Active    (bool)   - server-side state, e.g. soil has something to hatch
--   OnlyUser  (number) - only this UserId sees it (0 = nobody yet)
--   ExceptUser(number) - everyone except this UserId sees it
-- The server re-validates every trigger regardless.

local CollectionService = game:GetService("CollectionService")

local Prompts = {}

Prompts.Tag = "SIPrompt"

function Prompts.create(parent: Instance, action: string, object: string?, hold: number?, key: Enum.KeyCode?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object or ""
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	if key then
		prompt.KeyboardKeyCode = key
	end
	prompt:SetAttribute("Active", true)
	CollectionService:AddTag(prompt, Prompts.Tag)
	prompt.Parent = parent
	return prompt
end

return Prompts
