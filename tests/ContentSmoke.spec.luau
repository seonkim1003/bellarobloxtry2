--!nocheck
-- Lune's @lune modules are not part of the strict Roblox type definitions;
-- see IntegrationContract.spec.luau for the same convention.
--[[
	Agent 2 content smoke tests (pure Luau / Lune).
	Loads ContentConfig for structural + identifier uniqueness checks.
]]

local ContentConfig = require("../src/shared/ContentConfig")

local sceneOrder = { "Lobby", "Maze", "Tower", "Field", "Epilogue" }
for index, sceneId in sceneOrder do
	local layout = ContentConfig.sceneLayouts[sceneId]
	assert(layout ~= nil, `missing scene layout for {sceneId}`)
	if index > 1 then
		local previous = ContentConfig.sceneLayouts[sceneOrder[index - 1]]
		local gap = layout.position.x - previous.position.x
		assert(
			gap >= ContentConfig.worldLayout.SceneSpacing,
			`scene {sceneId} is only {gap} studs from its predecessor`
		)
	end
end

assert(
	ContentConfig.worldLayout.MaxMarketplaceExtent < ContentConfig.worldLayout.SceneSpacing,
	"marketplace maps must fit inside isolated scene cells"
)

local storyStates = ContentConfig.storyStates
local requiredTags = ContentConfig.requiredTags
local requiredAttributes = ContentConfig.requiredAttributes
local serverSignals = ContentConfig.serverSignals
local clientRequests = ContentConfig.clientRequests
local sceneIds = ContentConfig.sceneIds

local uiShells = {
	"Title",
	"Objective",
	"Subtitle",
	"Fragments",
	"RevivePrompt",
	"AdminDiagnostics",
	"Credits",
	"Replay",
	"Leave",
	"LeaveConfirm",
	"ReducedMotion",
	"TowerProgress",
	"ThreatState",
}

assert(#storyStates == 14, "expected 14 story states")
assert(#requiredTags == 8, "expected 8 required tags")
assert(#requiredAttributes == 6, "expected 6 required attributes")
assert(#serverSignals == 5, "expected 5 server signals")
assert(#clientRequests == 4, "expected 4 client requests")
assert(#sceneIds == 5, "expected 5 scenes")
assert(#uiShells == 13, "expected 13 UI shells")

local seen: { [string]: boolean } = {}
for _, state in storyStates do
	assert(seen[state] == nil, `duplicate story state {state}`)
	seen[state] = true
end

assert(ContentConfig.towerStepCount >= 24 and ContentConfig.towerStepCount <= 32, "ASMR steps")
assert(ContentConfig.towerFlights >= 6 and ContentConfig.towerFlights <= 8, "ASMR flights")
assert(
	ContentConfig.towerStepCount // ContentConfig.towerFlights >= 3,
	"steps should cover right-angle flights"
)

local finalTwist = ContentConfig.finalLetterText.twist
assert(#finalTwist > 20, "final letter twist must be drafted")

assert(ContentConfig.ui.touchMinButtonPx >= 64, "touch min size")
assert(ContentConfig.accessibility.reducedMotionDefault == false, "motion default")

local placeholderIds: { [string]: boolean } = {}
for _, entry in ContentConfig.placeholderObjects do
	local key = `{entry.sceneId}/{entry.name}`
	assert(placeholderIds[key] == nil, `duplicate content id {key}`)
	placeholderIds[key] = true
end

-- manifest consistency
for key, id in pairs(ContentConfig.assets.marketplace.scenes) do
	assert(ContentConfig.assets.models[key] == `rbxassetid://{id}`, `manifest mismatch {key}`)
end
for key, id in pairs(ContentConfig.assets.marketplace.characters) do
	local modelKey = key == "ramboFriendly" and "rambo" or key
	assert(ContentConfig.assets.models[modelKey] == `rbxassetid://{id}`, `manifest mismatch {key}`)
end

print("content smoke test passed")
