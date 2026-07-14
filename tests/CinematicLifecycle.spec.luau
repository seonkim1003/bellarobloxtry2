--!nocheck

local fs = require("@lune/fs")

local presenterSource = fs.readFile("src/client/Presentation/StoryPresenter.luau")
local dogFightSource = fs.readFile("src/client/Presentation/DogFightPresenter.luau")
local dogPuppetSource = fs.readFile("src/client/NPCs/DogPuppet.luau")
local kidnapSource = fs.readFile("src/client/NPCs/KidnapStage.luau")
local mainSource = fs.readFile("src/client/Main.client.luau")
local serviceSource = fs.readFile("src/server/NPC/DogFightService.luau")
local mountSource = fs.readFile("src/shared/ContentAssetMount.luau")
local epilogueSource = fs.readFile("src/client/NPCs/EpilogueProps.luau")

assert(
	string.find(presenterSource, "d.dogFight:play(", 1, true)
		and string.find(presenterSource, "self:_restorePlayerMovement()", 1, true)
		and string.find(presenterSource, "self:_finishCinematic(", 1, true),
	"DogFight must restore movement once then finish cinematic/first-person"
)
assert(
	string.find(presenterSource, 'state == "Credits"', 1, true)
		and string.find(
			presenterSource,
			"-- Epilogue props intentionally remain until lobby/reset",
			1,
			true
		),
	"Credits must keep epilogue props mounted"
)
assert(
	string.find(presenterSource, "d.dogFight:clear()", 1, true)
		and string.find(presenterSource, "function StoryPresenter.resetForReplay", 1, true),
	"Replay must cancel the dog fight presenter"
)

assert(
	string.find(dogFightSource, "self._generation", 1, true)
		and string.find(dogFightSource, "function DogFightPresenter.cancel", 1, true)
		and string.find(dogFightSource, "_restoredOnce", 1, true)
		and string.find(dogFightSource, "shouldSkipMotionEffects", 1, true)
		and string.find(dogFightSource, "_hardCut", 1, true),
	"DogFightPresenter must cancel stale work, hard-cut cameras, and honor reduced motion"
)
assert(
	string.find(dogFightSource, "function DogFightPresenter.applyFightBeat", 1, true),
	"DogFightPresenter must accept FightBeat payloads"
)

assert(
	string.find(dogPuppetSource, "beginBeat", 1, true)
		and string.find(dogPuppetSource, "Motor6D", 1, true)
		and string.find(dogPuppetSource, "_generation", 1, true),
	"DogPuppet must proceduralize beats with Motor6D-safe clones and generation cancel"
)

assert(
	string.find(kidnapSource, "ANIMATION_PHASES", 1, true)
		and string.find(kidnapSource, "ApproachWindup", 1, true)
		and string.find(kidnapSource, "HoldGrasp", 1, true)
		and string.find(kidnapSource, "NpcAnimationController", 1, true),
	"KidnapStage must use named animation phases"
)

assert(
	string.find(mainSource, 'remotes:on("FightBeat"', 1, true)
		and string.find(mainSource, "DogFightPresenter", 1, true)
		and string.find(mainSource, "applyFightBeat", 1, true),
	"Client must route FightBeat into DogFightPresenter"
)

assert(
	string.find(serviceSource, "FightBeat", 1, true)
		and string.find(serviceSource, "fightGeneration", 1, true)
		and string.find(serviceSource, "function DogFightService.Cancel", 1, true)
		and string.find(serviceSource, "DogFightTimeline", 1, true),
	"DogFightService must broadcast FightBeat with generation and cancel support"
)

assert(
	string.find(mountSource, "Motor6D", 1, true)
		and string.find(mountSource, "VisualRootWeld", 1, true)
		and string.find(mountSource, "motorParts", 1, true),
	"NPC mounting must preserve Motor6D joints instead of welding every part"
)

assert(
	string.find(epilogueSource, 'sceneId == "EpilogueSeat"', 1, true)
		and string.find(epilogueSource, "EpilogueActors", 1, true),
	"Epilogue props must resolve the seat spawn and keep staged actors"
)

local fieldSource = fs.readFile("src/workspace/Scenes/Field.model.json")
for _, markerId in
	{
		"FightEstablish",
		"FightRamboStalk",
		"FightAttackTelegraph",
		"FightFirstClash",
		"FightRamboAdvantage",
		"FightGigiCounter",
		"FightRamboBackDown",
		"FightGigiVictory",
	}
do
	assert(string.find(fieldSource, markerId, 1, true), `Field missing authored marker {markerId}`)
end

print("cinematic lifecycle test passed")
