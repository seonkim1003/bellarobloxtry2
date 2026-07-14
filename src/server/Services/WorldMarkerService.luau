--!strict

-- Rojo model JSON preserves the authored marker attributes, but CollectionService
-- tags are not present in the built place. Reapply the canonical marker catalog on
-- the server before any content, checkpoint, NPC, or gameplay discovery runs.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ContentConfig =
	require(ReplicatedStorage:WaitForChild("GameShared"):WaitForChild("ContentConfig"))

local WorldMarkerService = {}

local function registerEntry(scenes: Instance, entry: any): boolean
	local scene = scenes:FindFirstChild(entry.sceneId)
	if not scene then
		warn(`[WorldMarkers] Missing scene {entry.sceneId} for {entry.name}`)
		return false
	end

	local marker = scene:FindFirstChild(entry.name, true)
	if not marker then
		warn(`[WorldMarkers] Missing marker {entry.sceneId}/{entry.name}`)
		return false
	end

	for key, value in entry.attributes do
		marker:SetAttribute(key, value)
	end
	if not CollectionService:HasTag(marker, entry.tag) then
		CollectionService:AddTag(marker, entry.tag)
	end
	return true
end

function WorldMarkerService.RegisterAuthoredMarkers(): number
	local scenes = Workspace:WaitForChild("Scenes")
	local registered = 0

	for _, entry in ContentConfig.placeholderObjects do
		if registerEntry(scenes, entry) then
			registered += 1
		end
	end
	for _, entry in ContentConfig.asmrStepPlaceholders do
		if registerEntry(scenes, entry) then
			registered += 1
		end
	end

	return registered
end

return WorldMarkerService
