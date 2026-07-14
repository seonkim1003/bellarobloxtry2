--!strict
--[[
	Discovers Phase 1 placeholder tags/attributes in Workspace.Scenes.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()

local TagDiscovery = {}

export type DiscoveryReport = {
	scenesFound: { string },
	tagCounts: { [string]: number },
	missingTags: { string },
	markerCount: number,
}

function TagDiscovery.scan(): DiscoveryReport
	local tagCounts: { [string]: number } = {}
	for _, tag in ContentConfig.requiredTags do
		tagCounts[tag] = #CollectionService:GetTagged(tag)
	end

	local missingTags = {}
	for tag, count in tagCounts do
		if count == 0 then
			table.insert(missingTags, tag)
		end
	end

	local scenesFound = {}
	local markerCount = 0
	local scenesFolder = Workspace:FindFirstChild("Scenes")
	if scenesFolder then
		for _, child in scenesFolder:GetChildren() do
			table.insert(scenesFound, child.Name)
			markerCount += #child:GetDescendants()
		end
	end

	return {
		scenesFound = scenesFound,
		tagCounts = tagCounts,
		missingTags = missingTags,
		markerCount = markerCount,
	}
end

function TagDiscovery.printReport(report: DiscoveryReport)
	print(
		`[Content] Scenes={table.concat(report.scenesFound, ",")} markers~{report.markerCount} missingTags={#report.missingTags}`
	)
	for tag, count in report.tagCounts do
		print(`[Content] tag {tag} = {count}`)
	end
end

return TagDiscovery
