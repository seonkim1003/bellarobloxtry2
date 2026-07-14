--!nocheck

local fs = require("@lune/fs")

local bootstrap = fs.readFile("src/server/Bootstrap.server.luau")
local gameplay = fs.readFile("src/server/Services/GameplayService.luau")
local story = fs.readFile("src/server/Services/StoryService.luau")
local runtime = fs.readFile("src/shared/RuntimeRules.luau")

assert(
	string.find(bootstrap, "ProgressionRules.parseRoleSelection(payload)", 1, true),
	"role ingress must use strict pure validation"
)
assert(
	string.find(
		bootstrap,
		"validator:AllowAction(player, Contract.ClientEvents.RoleReady)",
		1,
		true
	)
		and string.find(
			gameplay,
			"validator:AllowAction(player, Contract.ClientEvents.ReviveConfirmed)",
			1,
			true
		)
		and string.find(
			gameplay,
			"validator:AllowAction(player, Contract.ClientEvents.ReplayRequested)",
			1,
			true
		),
	"role, revive, and replay ingress must be rate-limited"
)
assert(
	not string.find(bootstrap, 'payload.role else "Bella"', 1, true)
		and not string.find(bootstrap, 'payload.stage else "Maze"', 1, true),
	"malformed role/stage payloads must never default"
)
assert(
	string.find(story, "function StoryService.StartFor", 1, true)
		and not string.find(story, "StartForStage", 1, true),
	"normal and direct-stage starts share one authority path"
)
assert(
	string.find(gameplay, "ProgressionRules.canCollectTowerStep", 1, true)
		and string.find(gameplay, 'AllowRate(player, "TowerStep"', 1, true),
	"tower progression must be sequential and rate-limited"
)
assert(
	string.find(gameplay, "function GameplayService._bindStageTeleporter", 1, true)
		and string.find(gameplay, "Contract.Tags.StageTeleporter", 1, true)
		and string.find(gameplay, "AllowRate(", 1, true)
		and string.find(gameplay, "self.validator.IsNear", 1, true)
		and string.find(gameplay, "self.storyService:StartFor(player, startState)", 1, true),
	"stage teleporters must be server-bound, proximity-validated, rate-limited, and authoritative"
)
assert(
	string.find(gameplay, "serverAuthoredFragmentIds", 1, true)
		and string.find(gameplay, "ProgressionRules.canCollectFragment", 1, true)
		and string.find(gameplay, 'AllowRate(player, "FragmentCollect"', 1, true),
	"fragment progression must use server-authored IDs and rate limits"
)
assert(
	string.find(gameplay, "self:_isProtagonist(player)", 1, true),
	"progression ingress must require the current protagonist"
)
assert(
	string.find(gameplay, "ConsumeOnce(`Cinematic:{state}:{revision}`)", 1, true)
		and string.find(gameplay, "state == Contract.States.DogFight", 1, true),
	"cinematic acknowledgements must be consume-once and reject DogFight"
)
assert(
	not string.find(runtime, 'DogFight = "Epilogue"', 1, true),
	"DogFight cannot use generic cinematic completion or recovery"
)
assert(
	string.find(gameplay, "for _, lobbyPlayer in Players:GetPlayers()", 1, true)
		and string.find(gameplay, "self.checkpoints:Clear(player)", 1, true),
	"lobby resets must return every remaining player and replace checkpoints"
)
assert(
	string.find(bootstrap, "previousRole == Contract.Roles.Protagonist", 1, true)
		and string.find(bootstrap, 'story:ResetToLobby("ProtagonistLeft")', 1, true),
	"protagonist departure or demotion must reset the authoritative story"
)

print("ingress integrity test passed")
