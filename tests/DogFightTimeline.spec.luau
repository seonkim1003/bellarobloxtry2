--!nocheck

local AnimationIds = require("../src/shared/AnimationIds")
local DogFightTimeline = require("../src/shared/DogFightTimeline")

assert(DogFightTimeline.BeatCount == 8, "expected eight dog fight beats")

local expected = {
	"Establish",
	"RamboStalk",
	"AttackTelegraph",
	"FirstClash",
	"RamboAdvantage",
	"GigiCounter",
	"RamboBackDown",
	"GigiVictory",
}

for index, beatId in expected do
	local beat = DogFightTimeline.getBeat(index)
	assert(beat ~= nil, `missing beat {index}`)
	assert(beat.beatId == beatId, `beat {index} id mismatch`)
	assert(beat.beatIndex == index, `beat {index} index mismatch`)
	assert(type(beat.cameraMarkerId) == "string", `beat {beatId} camera marker`)
	assert(beat.durationSeconds > 0, `beat {beatId} duration`)
	assert(beat.reducedMotionSeconds > 0, `beat {beatId} reduced duration`)
	assert(beat.reducedMotionSeconds <= beat.durationSeconds, `beat {beatId} reduced <= normal`)
	assert(DogFightTimeline.isValidBeatId(beatId), `beatId {beatId} invalid`)
	assert(AnimationIds.DogFight[beatId] ~= nil, `AnimationIds missing {beatId}`)
	assert(
		AnimationIds.isPlaceholder(AnimationIds.DogFight[beatId]),
		`must not invent {beatId} asset id`
	)
end

local normalTotal = DogFightTimeline.totalDuration(false)
local reducedTotal = DogFightTimeline.totalDuration(true)
assert(normalTotal >= 5.5, "timeline must cover server DogFight minimum seconds")
assert(reducedTotal >= 4.5, "reduced-motion timeline must still tell the fight")
assert(reducedTotal < normalTotal, "reduced motion must shorten the fight")

assert(AnimationIds.isPlaceholder(AnimationIds.KidnapHold), "kidnap hold stays placeholder")
assert(AnimationIds.isPlaceholder("rbxassetid://0"), "zero id is placeholder")
assert(not AnimationIds.isPlaceholder("rbxassetid://123"), "non-zero id is real")

print("dog fight timeline test passed")
