--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameShared = ReplicatedStorage:WaitForChild("GameShared")
local Contract = require(GameShared:WaitForChild("StoryContract"))

local RemoteRegistry = {}

local function getOrCreateEvent(folder: Folder, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing then
		assert(existing:IsA("RemoteEvent"), (`Remote {name} must be a RemoteEvent`))
		return existing
	end

	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

function RemoteRegistry.Create(): {[string]: RemoteEvent}
	local folder = ReplicatedStorage:FindFirstChild("GameRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GameRemotes"
		folder.Parent = ReplicatedStorage
	end
	assert(folder:IsA("Folder"), "ReplicatedStorage.GameRemotes must be a Folder")

	local remotes: {[string]: RemoteEvent} = {}
	for _, name in Contract.ServerEvents do
		remotes[name] = getOrCreateEvent(folder, name)
	end
	for _, name in Contract.ClientEvents do
		remotes[name] = getOrCreateEvent(folder, name)
	end

	return table.freeze(remotes)
end

return RemoteRegistry
