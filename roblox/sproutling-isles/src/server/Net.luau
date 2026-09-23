-- Creates the RemoteEvents the client talks through. Everything else is ProximityPrompts,
-- which the server validates itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

Net.Notify = remote("Notify") -- server -> client: (text, colorHex?)
Net.SelectSeed = remote("SelectSeed") -- client -> server: (speciesId)
Net.Effect = remote("Effect") -- server -> client: (kind, data) for hatch/snatch fanfare

folder.Parent = ReplicatedStorage

function Net.notify(player: Player, text: string, color: string?)
	Net.Notify:FireClient(player, text, color)
end

function Net.announce(text: string, color: string?)
	Net.Notify:FireAllClients(text, color)
end

return Net
