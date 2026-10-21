-- Fast travel: the Skyward Shipyard (airships) and the Shipwright (boats) open a shop window
-- that lists destinations (Shared/Travel). Picking one costs Dew and moves you there after a
-- short "boarding" pause. The server checks you're still at the right shop when you pay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shops = require(Shared.Shops)
local Travel = require(Shared.Travel)

local State = require(script.Parent.State)
local InventoryService = require(script.Parent.InventoryService)

local TravelService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local TravelRemote = Instance.new("RemoteEvent")
TravelRemote.Name = "Travel" -- client -> server: (destinationId)
TravelRemote.Parent = remotes

local busy: { [Player]: boolean } = {}

local function go(player: Player, id: any)
	local session = State.get(player)
	if not session or busy[player] or typeof(id) ~= "string" then
		return
	end
	local key = InventoryService.nearShop(player)
	local shop = key and Shops.get(key)
	local mode = shop and shop.travel
	local dest = Travel.get(id)
	if not mode or not dest or not dest.modes[mode] then
		return
	end
	if player:GetAttribute("InDungeon") then
		return
	end
	local price = Travel.Prices[mode] or 0
	if not State.spendDew(session, price, "Travel") then
		State.notify(session, string.format("You need %d Dew for passage.", price), "#ffb070")
		return
	end
	busy[player] = true
	State.notify(session, if mode == "air" then "All aboard! The airship lifts off..." else "Casting off! The boat heads out...", "#bfe3ff")
	task.delay(1.5, function()
		busy[player] = nil
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character and root then
			character:PivotTo(CFrame.new(dest.pos + Vector3.new(0, 4, 0)))
			root.AssemblyLinearVelocity = Vector3.zero
			State.notify(session, "You arrive at " .. dest.name .. ".", "#a0ffa0")
		end
	end)
end

function TravelService.init()
	TravelRemote.OnServerEvent:Connect(go)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return TravelService
