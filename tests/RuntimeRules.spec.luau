--!strict
--[[
	Pure Lune behavioral tests for RuntimeRules.
]]

local RuntimeRules = require("../src/shared/RuntimeRules")

assert(RuntimeRules.canAdmitPlayer(0, 2) == true, "empty server admits")
assert(RuntimeRules.canAdmitPlayer(1, 2) == true, "one player admits")
assert(RuntimeRules.canAdmitPlayer(2, 2) == false, "full server rejects")
assert(RuntimeRules.canAdmitPlayer(0, 0) == false, "zero max rejects")
assert(RuntimeRules.canStartStory("Protagonist", true, "RoleLobby") == true, "ready starts")
assert(RuntimeRules.canStartStory("Protagonist", false, "RoleLobby") == false, "ready gates")
assert(RuntimeRules.canStartStory("Admin", true, "RoleLobby") == false, "admin cannot start")

assert(RuntimeRules.canTransition("RoleLobby", "MazeIntro") == true, "lobby->maze")
assert(RuntimeRules.canTransition("RoleLobby", "Credits") == false, "lobby cannot skip to credits")
assert(RuntimeRules.cinematicNextState("DogFight") == nil, "dogfight requires server generation")
assert(RuntimeRules.cinematicNextState("BellaChase") == nil, "chase is not cinematic-ack")

local now = 100
assert(
	RuntimeRules.isCinematicAckValid("DogFight", 3, 90, "DogFight", 3, now, 5.5) == false,
	"dogfight cannot advance through a cinematic acknowledgement"
)
assert(
	RuntimeRules.isCinematicAckValid("RamboTaken", 3, 96, "RamboTaken", 3, now, 5.5) == false,
	"reject early cinematic ack"
)
assert(
	RuntimeRules.isCinematicAckValid("RamboTaken", 3, 90, "RamboTaken", 4, now, 5.5) == false,
	"reject stale revision"
)
assert(
	RuntimeRules.isCinematicAckValid("RamboTaken", 3, 90, "LetterTheft", 3, now, 5.5) == false,
	"reject mismatched cue"
)

assert(
	RuntimeRules.shouldRecoverCinematic("RamboTaken", 7, 100, "RamboTaken", 7, 130, 30) == true,
	"recover a cinematic exactly at its server deadline"
)
assert(
	RuntimeRules.shouldRecoverCinematic("RamboTaken", 7, 100, "RamboTaken", 7, 129.99, 30) == false,
	"do not recover a cinematic before its deadline"
)
assert(
	RuntimeRules.shouldRecoverCinematic("GuideEncounter", 8, 100, "RamboTaken", 7, 140, 30) == false,
	"an old watchdog cannot advance a newer state and revision"
)
assert(
	RuntimeRules.shouldRecoverCinematic("RamboTaken", 8, 100, "RamboTaken", 7, 140, 30) == false,
	"an old watchdog cannot advance a newer revision of the same state"
)
assert(
	RuntimeRules.shouldRecoverCinematic("BellaChase", 7, 100, "BellaChase", 7, 140, 30) == false,
	"non-cinematic states never recover through the cinematic watchdog"
)
assert(
	RuntimeRules.shouldRecoverCinematic("RamboTaken", 7, 100, "RamboTaken", 7, 140, 0) == false,
	"disabled recovery deadlines fail closed"
)
local acknowledgedNextState = RuntimeRules.cinematicNextState("RamboTaken")
assert(acknowledgedNextState == "GuideEncounter", "valid ack chooses one canonical next state")
assert(
	RuntimeRules.isCinematicAckValid(acknowledgedNextState, 8, 130, "RamboTaken", 7, 131, 18)
		== false,
	"the same acknowledgement cannot advance twice after its first transition"
)

assert(RuntimeRules.shouldEmitDetection(false, true, 0, 10, 2) == true, "emit first detect")
assert(
	RuntimeRules.shouldEmitDetection(false, true, 9, 10, 2) == false,
	"cooldown blocks detect spam"
)
assert(
	RuntimeRules.shouldEmitDetection(true, true, 0, 10, 2) == false,
	"already chasing does not re-emit"
)

local allowed, startedAt, count = RuntimeRules.evaluateRateLimit(nil, nil, 10, 2, 3)
assert(allowed and startedAt == 10 and count == 1, "first request opens bucket")
allowed, startedAt, count = RuntimeRules.evaluateRateLimit(startedAt, count, 11, 2, 3)
assert(allowed and count == 2, "request inside burst is allowed")
allowed, startedAt, count = RuntimeRules.evaluateRateLimit(startedAt, count, 12, 2, 3)
assert(not allowed and count == 2, "request over burst is rejected")
allowed, startedAt, count = RuntimeRules.evaluateRateLimit(startedAt, count, 13, 2, 3)
assert(allowed and startedAt == 13 and count == 1, "window boundary resets bucket")

print("runtime rules test passed")
