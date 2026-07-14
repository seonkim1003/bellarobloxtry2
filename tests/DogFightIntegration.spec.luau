--!nocheck

local fs = require("@lune/fs")

local bootstrap = fs.readFile("src/server/Bootstrap.server.luau")
local service = fs.readFile("src/server/NPC/DogFightService.luau")
local story = fs.readFile("src/server/Services/StoryService.luau")
local main = fs.readFile("src/client/Main.client.luau")

assert(
	string.find(bootstrap, 'require(NPC:WaitForChild("DogFightService"))', 1, true)
		and string.find(bootstrap, "DogFightService.new(remotes)", 1, true)
		and string.find(bootstrap, "dogFight:Start()", 1, true),
	"Bootstrap must construct and start DogFightService"
)
assert(
	string.find(bootstrap, "dogFight:OnStoryStateChanged", 1, true)
		and string.find(service, "self:Cancel()", 1, true),
	"story replacement and replay reset must cancel the active fight"
)
assert(
	string.find(bootstrap, "player == roles:GetProtagonist()", 1, true)
		and string.find(bootstrap, "dogFight:Cancel()", 1, true),
	"protagonist departure must cancel the fight immediately"
)
assert(
	string.find(bootstrap, "RuntimeRules.isDogFightCompletionValid", 1, true)
		and string.find(bootstrap, "dogFight:IsCompletedGeneration", 1, true)
		and string.find(
			bootstrap,
			"ConsumeOnce(`DogFight:{storyRevision}:{fightGeneration}`)",
			1,
			true
		)
		and string.find(bootstrap, "story:CompleteDogFight", 1, true),
	"DogFight completion must match revision and server generation exactly once"
)
assert(
	string.find(story, "function StoryService.CompleteDogFight", 1, true)
		and string.find(
			story,
			"self.state == Contract.States.DogFight and nextState == Contract.States.Epilogue",
			1,
			true
		),
	"the state machine must reject generic DogFight to Epilogue transitions"
)
assert(
	string.find(service, "self.completed:Fire(storyRevision, fightGeneration)", 1, true),
	"only the server timeline may emit fight completion"
)
assert(
	string.find(main, 'remotes:on("FightBeat"', 1, true)
		and string.find(main, "dogFight:applyFightBeat(payload)", 1, true),
	"FightBeat must route to DogFightPresenter"
)

print("dog fight integration test passed")
