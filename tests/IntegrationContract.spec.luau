--!nocheck
-- Lune's @lune modules are runtime-tested below but are not part of Roblox type definitions.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local ContentConfig = require("../src/shared/ContentConfig")
local StoryContract = require("../src/shared/StoryContract")

local function arraySet(values: { string }): { [string]: boolean }
	local result = {}
	for _, value in values do
		result[value] = true
	end
	return result
end

local configuredStates = arraySet(ContentConfig.storyStates)
for _, state in StoryContract.States do
	assert(configuredStates[state], `ContentConfig is missing story state {state}`)
end

for name, remoteName in StoryContract.ServerEvents do
	assert(
		table.find(ContentConfig.serverSignals, remoteName) ~= nil,
		`ContentConfig.serverSignals missing {name}={remoteName}`
	)
end
for name, remoteName in StoryContract.ClientEvents do
	assert(
		table.find(ContentConfig.clientRequests, remoteName) ~= nil,
		`ContentConfig.clientRequests missing {name}={remoteName}`
	)
end
for name, tag in StoryContract.Tags do
	assert(
		table.find(ContentConfig.requiredTags, tag) ~= nil,
		`ContentConfig.requiredTags missing {name}={tag}`
	)
end
for name, attribute in StoryContract.Attributes do
	assert(
		table.find(ContentConfig.requiredAttributes, attribute) ~= nil,
		`ContentConfig.requiredAttributes missing {name}={attribute}`
	)
end

local expectedAcks = {
	"MazeIntro",
	"RamboTaken",
	"GuideEncounter",
	"Corruption",
	"LetterTheft",
	"DogFight",
	"Epilogue",
	"LetterReveal",
}
for _, state in expectedAcks do
	assert(ContentConfig.cinematicAckStates[state] == true, `Missing cinematic ack {state}`)
end

type Marker = {
	name: string?,
	className: string?,
	tags: { string }?,
	attributes: { [string]: any }?,
	properties: { [string]: any }?,
	children: { Marker }?,
}

local markers: { Marker } = {}
local function collect(node: Marker)
	table.insert(markers, node)
	for _, child in node.children or {} do
		collect(child)
	end
end

for _, sceneName in { "Maze", "Tower", "Field", "Epilogue" } do
	local text = fs.readFile(`src/workspace/Scenes/{sceneName}.model.json`)
	collect(serde.decode("json", text) :: Marker)
end

local function hasTag(marker: Marker, wanted: string): boolean
	for _, tag in marker.tags or {} do
		if tag == wanted then
			return true
		end
	end
	return false
end

local function findTagged(tag: string, attribute: string?, value: any?): { Marker }
	local found = {}
	for _, marker in markers do
		if hasTag(marker, tag) then
			local attributes = marker.attributes or {}
			if attribute == nil or attributes[attribute] == value then
				table.insert(found, marker)
			end
		end
	end
	return found
end

assert(#findTagged("StoryTrigger", "MarkerId", "TowerTop") == 1, "TowerTop trigger missing")
assert(#findTagged("CinematicMarker", "MarkerId", "RamboGuideTarget") >= 3, "Rambo route missing")
assert(#findTagged("NPCSpawn", "NPCType", "FriendlyRambo") == 1, "FriendlyRambo spawn missing")
assert(#findTagged("NPCSpawn", "NPCType", "EvilRambo") == 1, "EvilRambo spawn missing")
assert(#findTagged("LetterFragment") == 3, "Expected exactly three server-authored fragments")

for _, point in findTagged("PatrolPoint") do
	assert((point.attributes or {}).NPCType == "EvilRambo", "Patrol point NPCType mismatch")
end

local sceneSpawns = {}
for _, marker in findTagged("SceneSpawn") do
	local sceneId = (marker.attributes or {}).SceneId
	if typeof(sceneId) == "string" then
		sceneSpawns[sceneId] = true
	end
end
for _, sceneId in { "MazeCheckpoint", "TowerBase", "FieldEntrance", "EpilogueSeat" } do
	assert(sceneSpawns[sceneId], `Missing checkpoint SceneSpawn {sceneId}`)
end

local mainSource = fs.readFile("src/client/Main.client.luau")
assert(
	string.find(mainSource, 'request("ReviveConfirmed", accepted)', 1, true),
	"ReviveConfirmed must send a direct boolean"
)
local presenterSource = fs.readFile("src/client/Presentation/StoryPresenter.luau")
assert(
	string.find(presenterSource, 'request("CinematicFinished"', 1, true)
		and string.find(presenterSource, "cue = state", 1, true)
		and string.find(presenterSource, "revision =", 1, true),
	"CinematicFinished must send { cue, revision } for server-validated cinematic acks"
)
assert(
	string.find(presenterSource, "d.gui.showRevive(false)", 1, true)
		and string.find(presenterSource, "d.gui.showRevive(true)", 1, true),
	"Revive choice must stay hidden until its cinematic completes"
)
local adminSource = fs.readFile("src/server/Services/AdminService.luau")
assert(
	string.find(adminSource, 'Secrets.AdminPassword ~= "CHANGE-ME-BEFORE-PUBLISHING"', 1, true),
	"Placeholder admin credentials must fail closed"
)
local gameplaySource = fs.readFile("src/server/Services/GameplayService.luau")
assert(
	string.find(gameplaySource, "detected = true", 1, true)
		and string.find(gameplaySource, "caught = true", 1, true),
	"Evil Rambo must emit detected and caught feedback"
)
local assetMountSource = fs.readFile("src/shared/ContentAssetMount.luau")
assert(
	string.find(assetMountSource, 'descendant:IsA("LuaSourceContainer")', 1, true),
	"Marketplace assets must remove executable descendants"
)
assert(
	string.find(assetMountSource, 'CollectionService:AddTag(actor, "NPCSpawn")', 1, true),
	"Runtime NPC actors must be tagged for server AI"
)

print("integration contract test passed")
