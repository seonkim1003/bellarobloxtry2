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

for _, sceneId in { "Lobby", "Tower", "Field" } do
	assert(
		type(ContentConfig.sceneLayouts[sceneId].marketplaceKey) == "string",
		`marketplace scene {sceneId} must be active`
	)
end

assert(ContentConfig.sceneLayouts.Maze.marketplaceKey == nil, "Backrooms maze must stay disabled")
assert(
	ContentConfig.sceneLayouts.Tower.marketplaceCollision == false,
	"catalog tower must not block the deterministic gameplay route"
)
assert(
	ContentConfig.sceneLayouts.Tower.maxMarketplaceExtent == 44
		and ContentConfig.sceneLayouts.Tower.maxMarketplaceHeight == 24,
	"tower shell must fit the authored inner-wall ASMR route"
)

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
assert(#requiredTags == 9, "expected 9 required tags")
assert(#requiredAttributes == 7, "expected 7 required attributes")
assert(#serverSignals == 6, "expected 6 server signals")
assert(
	table.find(serverSignals, "FightBeat") ~= nil,
	"FightBeat must be a recognized server signal"
)
assert(#clientRequests == 4, "expected 4 client requests")
assert(#sceneIds == 5, "expected 5 scenes")
assert(#uiShells == 13, "expected 13 UI shells")

local seen: { [string]: boolean } = {}
for _, state in storyStates do
	assert(seen[state] == nil, `duplicate story state {state}`)
	seen[state] = true
end

local foundRobertSpawn = false
for _, entry in ContentConfig.placeholderObjects do
	if entry.attributes.NPCType == "RobertPattinson" then
		foundRobertSpawn = entry.sceneId == "Tower" and entry.attributes.MarkerId == "RobertSpawn"
	end
end
assert(foundRobertSpawn, "Robert Pattinson must have a canonical tower spawn")
assert(
	ContentConfig.assets.marketplace.characters.robertPattinson == 11851270,
	"Robert Pattinson asset must be wired"
)

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
for key, id in pairs(ContentConfig.assets.marketplace.props) do
	assert(ContentConfig.assets.models[key] == `rbxassetid://{id}`, `manifest mismatch {key}`)
end
assert(
	ContentConfig.assets.marketplace.props.letterFragments == 17475591057,
	"Clickable Note must supply letter fragments"
)
assert(
	ContentConfig.assets.marketplace.props.fatBart == 102058945923521,
	"Fat Bart must supply the title-side character"
)

local function assertAudible(entry: any, key: string)
	assert(type(entry) == "table", `missing sound entry {key}`)
	assert(type(entry.soundId) == "string" and entry.soundId ~= "", `missing soundId {key}`)
	assert(entry.soundId ~= "rbxassetid://0", `sound {key} must not be a silent placeholder`)
end

local requiredSounds = {
	"ambienceLobby",
	"ambienceMaze",
	"ambienceTower",
	"ambienceField",
	"ambienceEpilogue",
	"musicCredits",
	"chaseTension",
	"chaseSting",
	"corruptionSting",
	"stateTransition",
	"fragmentPickup",
	"uiClick",
	"uiConfirm",
	"kidnapGrab",
	"kidnapDrag",
	"cinematicWhoosh",
	"dogFightImpact",
	"dogFightClash",
	"dogFightVictory",
	"letterOpen",
	"respawnSoft",
	"teleporterActivate",
	"sprintStart",
	"sprintStop",
	"playerHit",
	"playerDeath",
	"healthLow",
	"hostileApproach",
	"friendlyApproach",
	"evilApproach",
	"mazeExit",
	"towerSummit",
	"revivePanelOpen",
	"threatClear",
	"promptShown",
	"promptHold",
	"subtitleTick",
	"objectiveTick",
	"uiError",
	"cursorToggle",
	"cameraLock",
	"cinematicCut",
	"letterClose",
	"creditsOpen",
}
for _, key in requiredSounds do
	assertAudible(ContentConfig.sounds[key], key)
end
assert(#ContentConfig.sounds.asmrSteps == ContentConfig.towerStepCount, "ASMR catalog length")
assert(
	ContentConfig.sounds.obbyMaterials[2].soundId == "rbxassetid://9125563505",
	"Butter ASMR should use licensed floor creak"
)

print("content smoke test passed")
