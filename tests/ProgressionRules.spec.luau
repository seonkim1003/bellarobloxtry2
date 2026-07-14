--!strict

local ProgressionRules = require("../src/shared/ProgressionRules")

local role, stage = ProgressionRules.parseLobbySelection({ role = "Bella", stage = "Maze" })
assert(role == "Bella" and stage == "Maze", "valid lobby selection")
local adminRole, adminStage =
	ProgressionRules.parseLobbySelection({ role = "Admin", stage = "Obby" })
assert(adminRole == "Admin" and adminStage == "Obby", "valid admin selection is recognized")

local function assertInvalid(payload: any)
	local invalidRole, invalidStage = ProgressionRules.parseLobbySelection(payload)
	assert(invalidRole == nil and invalidStage == nil, "malformed lobby payload fails closed")
end
assertInvalid(nil)
assertInvalid({})
assertInvalid({ role = "Bella" })
assertInvalid({ stage = "Maze" })
assertInvalid({ role = "Observer", stage = "Maze" })
assertInvalid({ role = "Bella", stage = "Credits" })
assertInvalid({ role = "Bella", stage = "Maze", extra = true })

assert(ProgressionRules.startStateForStage("Maze") == "MazeIntro", "maze start")
assert(ProgressionRules.startStateForStage("Obby") == "TowerClimb", "tower start")
assert(ProgressionRules.startStateForStage("Scavenger Hunt") == "FieldHunt", "field start")
assert(ProgressionRules.startStateForStage("Credits") == nil, "invalid direct start")

local towerSteps: { [number]: boolean } = {}
assert(ProgressionRules.canCollectTowerStep(towerSteps, 0, 1, 3), "first tower step")
towerSteps[1] = true
assert(not ProgressionRules.canCollectTowerStep(towerSteps, 1, 1, 3), "duplicate step")
assert(not ProgressionRules.canCollectTowerStep(towerSteps, 1, 3, 3), "skipped step")
assert(not ProgressionRules.canCollectTowerStep(towerSteps, 1, 2.5, 3), "fractional step")
assert(ProgressionRules.canCollectTowerStep(towerSteps, 1, 2, 3), "sequential step")
assert(not ProgressionRules.canCollectTowerStep(towerSteps, 3, 4, 3), "excess step")

local authored = { A = true, B = true, C = true }
local collected: { [string]: boolean } = {}
assert(ProgressionRules.canCollectFragment(authored, collected, 0, "A", 3), "known fragment")
collected.A = true
assert(not ProgressionRules.canCollectFragment(authored, collected, 1, "A", 3), "duplicate")
assert(not ProgressionRules.canCollectFragment(authored, collected, 1, "D", 3), "unknown")
assert(not ProgressionRules.canCollectFragment(authored, collected, 3, "B", 3), "excess")
assert(not ProgressionRules.canCollectFragment(authored, collected, 1, 7, 3), "typed id")

print("progression rules test passed")
