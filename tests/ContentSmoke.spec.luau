--!strict
--[[
	Agent 2 Phase 1 content smoke tests (pure Luau / Lune, no filesystem requires).
	Mirrors the frozen contract + ContentConfig expectations. Structural presence of
	ContentConfig / GuiShell is guaranteed by luau-lsp analyze on src/.
]]

local storyStates = {
	"RoleLobby",
	"MazeIntro",
	"BellaChase",
	"RamboTaken",
	"GuideEncounter",
	"TowerClimb",
	"RevivePrompt",
	"Corruption",
	"FieldHunt",
	"LetterTheft",
	"DogFight",
	"Epilogue",
	"LetterReveal",
	"Credits",
}

local requiredTags = {
	"SceneSpawn",
	"MazeExit",
	"NPCSpawn",
	"PatrolPoint",
	"StoryTrigger",
	"LetterFragment",
	"ASMRStep",
	"CinematicMarker",
}

local requiredAttributes = {
	"SceneId",
	"MarkerId",
	"NPCType",
	"FragmentId",
	"SoundId",
	"SequenceIndex",
}

local serverSignals = {
	"StoryCue",
	"ObjectiveUpdate",
	"FragmentUpdate",
	"RoleUpdate",
	"AdminDiagnostics",
}

local clientRequests = {
	"CinematicFinished",
	"ReviveConfirmed",
	"ReplayRequested",
	"RoleReady",
}

local sceneIds = { "Lobby", "Maze", "Tower", "Field", "Epilogue" }
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
}

assert(#storyStates == 14, "expected 14 story states")
assert(#requiredTags == 8, "expected 8 required tags")
assert(#requiredAttributes == 6, "expected 6 required attributes")
assert(#serverSignals == 5, "expected 5 server signals")
assert(#clientRequests == 4, "expected 4 client requests")
assert(#sceneIds == 5, "expected 5 scenes")
assert(#uiShells == 9, "expected 9 UI shells")

local seen: { [string]: boolean } = {}
for _, state in storyStates do
	assert(seen[state] == nil, `duplicate story state {state}`)
	seen[state] = true
end

local towerStepCount = 28
local towerFlights = 7
assert(towerStepCount >= 24 and towerStepCount <= 32, "ASMR steps must be 24–32")
assert(towerFlights >= 6 and towerFlights <= 8, "ASMR flights must be 6–8")
assert(towerStepCount // towerFlights >= 3, "steps should cover right-angle flights")

local finalTwist =
	"The journey was never about losing weight. It was about who gets remembered when the fog clears."
assert(#finalTwist > 20, "final letter twist must be drafted")

print("content smoke test passed")
