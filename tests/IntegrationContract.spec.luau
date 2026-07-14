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

for _, sceneName in { "Lobby", "Maze", "Tower", "Field", "Epilogue" } do
	local text = fs.readFile(`src/workspace/Scenes/{sceneName}.model.json`)
	collect(serde.decode("json", text) :: Marker)
end

local function approximately(actual: number, expected: number): boolean
	return math.abs(actual - expected) < 0.001
end

local cframeCount = 0
for _, marker in markers do
	local properties = marker.properties or {}
	local cframe = properties.CFrame
	if type(cframe) == "table" then
		assert(#cframe == 12, `{marker.name or "instance"} CFrame must have 12 components`)
		-- Rojo's implicit order is position first, followed by a 3x3 rotation
		-- matrix. Orthonormal rows catch the former rotation-first serialization.
		local r00, r01, r02 = cframe[4], cframe[5], cframe[6]
		local r10, r11, r12 = cframe[7], cframe[8], cframe[9]
		local r20, r21, r22 = cframe[10], cframe[11], cframe[12]
		assert(approximately(r00 * r00 + r01 * r01 + r02 * r02, 1), "invalid CFrame row 1")
		assert(approximately(r10 * r10 + r11 * r11 + r12 * r12, 1), "invalid CFrame row 2")
		assert(approximately(r20 * r20 + r21 * r21 + r22 * r22, 1), "invalid CFrame row 3")
		assert(approximately(r00 * r10 + r01 * r11 + r02 * r12, 0), "CFrame rows 1/2")
		assert(approximately(r00 * r20 + r01 * r21 + r02 * r22, 0), "CFrame rows 1/3")
		assert(approximately(r10 * r20 + r11 * r21 + r12 * r22, 0), "CFrame rows 2/3")
		cframeCount += 1
	end
end
assert(cframeCount >= 70, "expected authored scene CFrames")

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
assert(#findTagged("NPCSpawn", "NPCType", "Bella") >= 1, "Bella spawn marker missing")
assert(#findTagged("NPCSpawn", "NPCType", "EvilRambo") == 1, "EvilRambo spawn missing")
assert(#findTagged("MazeExit") >= 1, "MazeExit marker missing")
assert(#findTagged("CinematicMarker", "MarkerId", "KidnapHold") >= 1, "KidnapHold marker missing")
assert(#findTagged("LetterFragment") == 3, "Expected exactly three server-authored fragments")
assert(#findTagged("StageTeleporter") == 3, "Expected exactly three lobby stage teleporters")

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
for _, sceneId in { "Lobby", "MazeCheckpoint", "TowerBase", "FieldEntrance", "EpilogueSeat" } do
	assert(sceneSpawns[sceneId], `Missing checkpoint SceneSpawn {sceneId}`)
end

local mainSource = fs.readFile("src/client/Main.client.luau")
assert(
	string.find(mainSource, 'request("ReviveConfirmed", accepted)', 1, true),
	"ReviveConfirmed must send a direct boolean"
)
assert(
	string.find(mainSource, "role = roleChoice", 1, true)
		and not string.find(mainSource, "stage = stageChoice", 1, true),
	"Lobby UI must submit only the selected Bella/Admin role"
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
assert(
	string.find(presenterSource, "function StoryPresenter:_finishCinematic", 1, true)
		and string.find(presenterSource, "self._deps.firstPerson.apply()", 1, true),
	"Completed cinematics must return the player to first person"
)
assert(
	string.find(presenterSource, "d.sprint:enable()", 1, true)
		and string.find(presenterSource, "d.sprint:disable()", 1, true)
		and string.find(presenterSource, "d.asmr:start()", 1, true)
		and string.find(presenterSource, "d.asmr:stop()", 1, true),
	"Object-backed sprint and ASMR dependencies must be invoked with self"
)
assert(
	not string.find(presenterSource, "d.sprint.enable()", 1, true)
		and not string.find(presenterSource, "d.sprint.disable()", 1, true)
		and not string.find(presenterSource, "d.asmr.start()", 1, true)
		and not string.find(presenterSource, "d.asmr.stop()", 1, true),
	"Object-backed sprint and ASMR dependencies must never use self-less dot calls"
)
local adminSource = fs.readFile("src/server/Services/AdminService.luau")
assert(
	string.find(adminSource, 'Secrets.AdminPassword ~= "CHANGE-ME-BEFORE-PUBLISHING"', 1, true),
	"Placeholder admin credentials must fail closed"
)
local gameplaySource = fs.readFile("src/server/Services/GameplayService.luau")
assert(
	string.find(gameplaySource, "humanoid:TakeDamage(Config.NPC.Bella.ContactDamage)", 1, true),
	"Bella must deal server-authoritative contact damage during the maze chase"
)
assert(
	string.find(gameplaySource, "detected = true", 1, true)
		and string.find(gameplaySource, "caught = true", 1, true),
	"Evil Rambo must emit detected and caught feedback"
)
assert(
	string.find(
		gameplaySource,
		"self.evilRambo:SetActive(state == Contract.States.FieldHunt)",
		1,
		true
	),
	"Evil Rambo must roam and hunt during the letter-fragment state"
)
assert(
	string.find(gameplaySource, "function GameplayService._tryCompleteMazeExit", 1, true)
		and string.find(gameplaySource, "instance.Touched:Connect", 1, true)
		and string.find(gameplaySource, "function GameplayService._pollMazeExit", 1, true)
		and string.find(gameplaySource, "RunService.Heartbeat:Connect", 1, true)
		and string.find(gameplaySource, "self.validator.IsStoryState", 1, true),
	"Maze exit must have server-validated touch and distance fallbacks"
)
assert(
	string.find(gameplaySource, "MazeExitInteractionDistance", 1, true),
	"Maze exit must use a generous closest-point interaction radius"
)
assert(
	string.find(gameplaySource, "function GameplayService._armCinematicRecovery", 1, true)
		and string.find(gameplaySource, "RuntimeRules.shouldRecoverCinematic", 1, true)
		and string.find(gameplaySource, "CinematicRecovery:", 1, true),
	"Every cinematic state must have server-owned recovery from a missing client acknowledgement"
)
local cinematicSource = fs.readFile("src/client/Cinematics/CinematicPlayer.luau")
assert(
	string.find(cinematicSource, "kidnapStage:prepare()", 1, true)
		and string.find(cinematicSource, "kidnapStage:getFocusCFrame", 1, true)
		and string.find(cinematicSource, "kidnapStage:beginPhase", 1, true),
	"Kidnap cutscene must call KidnapStage methods with self"
)
local hostileSource = fs.readFile("src/server/NPC/HostileNpcService.luau")
assert(
	string.find(hostileSource, 'if self.npcType == "Bella" then', 1, true),
	"Bella must have dedicated chase fallback behavior"
)
assert(
	string.find(hostileSource, "self:_patrol()", 1, true)
		and string.find(hostileSource, "self.agent:MoveTo(targetRoot.Position)", 1, true),
	"Evil Rambo must patrol the Field and chase the detected protagonist"
)
local assetMountSource = fs.readFile("src/shared/ContentAssetMount.luau")
assert(
	string.find(assetMountSource, "arrangeFieldHuntMarkers", 1, true)
		and string.find(assetMountSource, 'field:FindFirstChild("FieldFloor", true)', 1, true)
		and string.find(assetMountSource, "spawn.CFrame = huntOrigin", 1, true)
		and string.find(assetMountSource, "FragmentA = Vector3.new(8, 0, 8)", 1, true),
	"The Field hunt and Evil Rambo patrol must be inset from the map edge"
)
assert(
	string.find(assetMountSource, "preserveExecutable", 1, true)
		and string.find(assetMountSource, "loadAssetModel(assetId, key, true)", 1, true),
	"Creator-selected obby assets must preserve their original functionality"
)
assert(
	string.find(assetMountSource, 'descendant:IsA("LuaSourceContainer")', 1, true),
	"Marketplace assets must remove executable descendants"
)
assert(
	string.find(assetMountSource, 'instance:IsA("Humanoid")', 1, true)
		and string.find(assetMountSource, "sanitizeCharacterVisual", 1, true)
		and string.find(assetMountSource, 'instance:IsA("Sound")', 1, true)
		and string.find(assetMountSource, 'instance:IsA("ClickDetector")', 1, true)
		and string.find(assetMountSource, 'instance:IsA("ProximityPrompt")', 1, true)
		and string.find(assetMountSource, "descendant.CanCollide = false", 1, true)
		and string.find(assetMountSource, "descendant.CanTouch = false", 1, true)
		and string.find(assetMountSource, "descendant.Massless = true", 1, true),
	"Marketplace NPC visuals must remove competing controllers and disable body physics"
)
local pathAgentSource = fs.readFile("src/server/NPC/PathAgent.luau")
assert(
	string.find(pathAgentSource, "local currentWaypointIndex", 1, true)
		and string.find(pathAgentSource, "blockedIndex >= currentWaypointIndex", 1, true),
	"Path blockage recovery must ignore waypoints the NPC already passed"
)
assert(
	string.find(assetMountSource, 'CollectionService:AddTag(actor, "NPCSpawn")', 1, true),
	"Runtime NPC actors must be tagged for server AI"
)
assert(
	string.find(assetMountSource, 'if npcType == "EvilRambo" then', 1, true)
		and string.find(assetMountSource, "visual:ScaleTo(visual:GetScale() * 10)", 1, true),
	"Evil Rambo must be presented as a ten-times-larger giant dog"
)
assert(
	string.find(assetMountSource, 'highlight.Name = "EvilRamboAlwaysVisible"', 1, true)
		and string.find(assetMountSource, "Enum.HighlightDepthMode.AlwaysOnTop", 1, true),
	"Evil Rambo must be highlighted through walls"
)
local mazePolishSource = fs.readFile("src/client/Scenes/MazePolish.luau")
assert(
	not string.find(mazePolishSource, 'glow.Name = "ExitGlow"', 1, true)
		and string.find(mazePolishSource, "removeExitBeacon", 1, true),
	"The vertical marketplace door must be the sole maze-exit visual"
)
assert(
	string.find(assetMountSource, 'spawnAtNpcTags(templates, "RobertPattinson"', 1, true)
		and string.find(assetMountSource, 'templateName == "RobertPattinson"', 1, true),
	"Robert Pattinson must mount with a visible fallback"
)

local towerBuilderSource = fs.readFile("src/client/Content/TowerBuilder.luau")
assert(
	string.find(towerBuilderSource, "preserveAuthoritativeSteps", 1, true),
	"client tower builder must preserve server-authored ASMR progression steps"
)

local worldMarkerSource = fs.readFile("src/server/Services/WorldMarkerService.luau")
assert(
	string.find(worldMarkerSource, "ContentConfig.placeholderObjects", 1, true)
		and string.find(worldMarkerSource, "ContentConfig.asmrStepPlaceholders", 1, true)
		and string.find(worldMarkerSource, "CollectionService:AddTag", 1, true),
	"Server must restore authored CollectionService tags from the canonical marker catalog"
)
local bootstrapSource = fs.readFile("src/server/Bootstrap.server.luau")
assert(
	string.find(bootstrapSource, "ProgressionRules.parseRoleSelection(payload)", 1, true)
		and string.find(gameplaySource, "ProgressionRules.startStateForStage(stage)", 1, true)
		and string.find(gameplaySource, "self.storyService:StartFor(player, startState)", 1, true),
	"Lobby teleporters must map to their authoritative starting states"
)
local roleServiceSource = fs.readFile("src/server/Services/RoleService.luau")
assert(
	not string.find(roleServiceSource, "task.delay", 1, true)
		and not string.find(roleServiceSource, "_promoteNextCandidate", 1, true)
		and string.find(roleServiceSource, "ClaimProtagonist", 1, true),
	"Protagonist assignment must happen only after an explicit Bella selection"
)
local markerRegistration =
	string.find(bootstrapSource, "WorldMarkerService.RegisterAuthoredMarkers()", 1, true)
local checkpointStart = string.find(bootstrapSource, "checkpoints:Start()", 1, true)
assert(
	markerRegistration ~= nil and checkpointStart ~= nil and markerRegistration < checkpointStart,
	"World markers must be registered before checkpoint discovery starts"
)
local checkpointSource = fs.readFile("src/server/Services/CheckpointService.luau")
assert(
	string.find(checkpointSource, "player.CharacterAdded:Connect", 1, true)
		and string.find(checkpointSource, "self:Respawn(player)", 1, true)
		and string.find(checkpointSource, 'SetAttribute("CheckpointSceneId"', 1, true),
	"Checkpoints must restore characters after Roblox respawns them"
)

print("integration contract test passed")
