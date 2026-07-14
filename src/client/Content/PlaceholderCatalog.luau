--!strict
--[[
	Content-side catalog mirror for Agent 2.
	Requires Shared.ContentConfig when mapped under ReplicatedStorage.Content.
]]

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()

local PlaceholderCatalog = {}

function PlaceholderCatalog.getAllObjects()
	local combined = {}
	for _, entry in ContentConfig.placeholderObjects do
		table.insert(combined, entry)
	end
	for _, entry in ContentConfig.asmrStepPlaceholders do
		table.insert(combined, entry)
	end
	return combined
end

function PlaceholderCatalog.getObjectsForScene(sceneId: string)
	local matched = {}
	for _, entry in PlaceholderCatalog.getAllObjects() do
		if entry.sceneId == sceneId then
			table.insert(matched, entry)
		end
	end
	return matched
end

function PlaceholderCatalog.getRequiredTags(): { string }
	return ContentConfig.requiredTags
end

function PlaceholderCatalog.getRequiredAttributes(): { string }
	return ContentConfig.requiredAttributes
end

return PlaceholderCatalog
