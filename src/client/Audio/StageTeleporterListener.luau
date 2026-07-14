--!strict
--[[
	Local feedback when the player touches a lobby StageTeleporter pad.
	Does not alter progression — server GameplayService owns stage start.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()
local ContentAudio = require(script.Parent:WaitForChild("ContentAudio"))

local StoryContract = (require :: any)(
	SharedAccess.getSharedFolder(5):WaitForChild("StoryContract")
)

local StageTeleporterListener = {}

local debounceSeconds = 1.1
local lastPlayed: { [Instance]: number } = {}
local connections: { RBXScriptConnection } = {}
local started = false

local function playActivate(part: BasePart)
	local entry = ContentConfig.sounds.teleporterActivate
	if entry == nil then
		entry = ContentConfig.sounds.stateTransition
	end
	ContentAudio.playEntry(entry, part)
end

local function onTouched(part: BasePart, hit: BasePart)
	local character = Players.LocalPlayer.Character
	if character == nil or not hit:IsDescendantOf(character) then
		return
	end

	local now = os.clock()
	local last = lastPlayed[part]
	if last ~= nil and (now - last) < debounceSeconds then
		return
	end
	lastPlayed[part] = now
	playActivate(part)
end

local function bindPart(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	table.insert(
		connections,
		instance.Touched:Connect(function(hit)
			if hit:IsA("BasePart") then
				onTouched(instance, hit)
			end
		end)
	)
end

function StageTeleporterListener.start()
	if started then
		return
	end
	started = true

	local tag = StoryContract.Tags.StageTeleporter
	for _, instance in CollectionService:GetTagged(tag) do
		bindPart(instance)
	end
	table.insert(
		connections,
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			bindPart(instance)
		end)
	)
end

function StageTeleporterListener.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(lastPlayed)
	started = false
end

return StageTeleporterListener
