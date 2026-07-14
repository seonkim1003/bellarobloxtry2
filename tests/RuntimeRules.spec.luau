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
assert(RuntimeRules.cinematicNextState("DogFight") == "Epilogue", "dogfight advances")
assert(RuntimeRules.cinematicNextState("BellaChase") == nil, "chase is not cinematic-ack")

local now = 100
assert(
	RuntimeRules.isCinematicAckValid("DogFight", 3, 90, "DogFight", 3, now, 5.5) == true,
	"valid dogfight ack after dwell"
)
assert(
	RuntimeRules.isCinematicAckValid("DogFight", 3, 96, "DogFight", 3, now, 5.5) == false,
	"reject early cinematic ack"
)
assert(
	RuntimeRules.isCinematicAckValid("DogFight", 3, 90, "DogFight", 4, now, 5.5) == false,
	"reject stale revision"
)
assert(
	RuntimeRules.isCinematicAckValid("DogFight", 3, 90, "LetterTheft", 3, now, 5.5) == false,
	"reject mismatched cue"
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
