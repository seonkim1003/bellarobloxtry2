--!strict

local Players = game:GetService("Players")

local SharedAccess = require(script.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local Shared = SharedAccess.getSharedFolder(10)
local BuildInfoModule = Shared:FindFirstChild("BuildInfo")
local BuildInfo = if BuildInfoModule and BuildInfoModule:IsA("ModuleScript")
	then (require :: any)(BuildInfoModule)
	else { name = "bella_game", version = "dev" }
local ContentConfig = SharedAccess.requireContentConfig()

local clientRoot = script.Parent

local RemoteBoundary = require(clientRoot:WaitForChild("Net"):WaitForChild("RemoteBoundary"))
local GuiShell = require(clientRoot:WaitForChild("UI"):WaitForChild("GuiShell"))
local TagDiscovery = require(clientRoot:WaitForChild("Scenes"):WaitForChild("TagDiscovery"))
local LightingController =
	require(clientRoot:WaitForChild("Scenes"):WaitForChild("LightingController"))
local ContentPackage = require(clientRoot:WaitForChild("Content"))

local SprintControls = require(clientRoot:WaitForChild("Controls"):WaitForChild("SprintControls"))
local SessionPreferences =
	require(clientRoot:WaitForChild("Controls"):WaitForChild("SessionPreferences"))
local ContentAudio = require(clientRoot:WaitForChild("Audio"):WaitForChild("ContentAudio"))
local ASMRStepListener = require(clientRoot:WaitForChild("Audio"):WaitForChild("ASMRStepListener"))
local StageTeleporterListener =
	require(clientRoot:WaitForChild("Audio"):WaitForChild("StageTeleporterListener"))
local CinematicPlayer =
	require(clientRoot:WaitForChild("Cinematics"):WaitForChild("CinematicPlayer"))
local RobberPresentation =
	require(clientRoot:WaitForChild("NPCs"):WaitForChild("RobberPresentation"))
local KidnapStage = require(clientRoot:WaitForChild("NPCs"):WaitForChild("KidnapStage"))
local EpilogueProps = require(clientRoot:WaitForChild("NPCs"):WaitForChild("EpilogueProps"))
local DogFightPresenter =
	require(clientRoot:WaitForChild("Presentation"):WaitForChild("DogFightPresenter"))
local FragmentFeedback =
	require(clientRoot:WaitForChild("Feedback"):WaitForChild("FragmentFeedback"))
local DetectionFeedback =
	require(clientRoot:WaitForChild("Feedback"):WaitForChild("DetectionFeedback"))
local CombatFeedback = require(clientRoot:WaitForChild("Feedback"):WaitForChild("CombatFeedback"))
local LetterPanel = require(clientRoot:WaitForChild("Feedback"):WaitForChild("LetterPanel"))
local FragmentPrompts =
	require(clientRoot:WaitForChild("Presentation"):WaitForChild("FragmentPrompts"))
local FirstPerson = require(clientRoot:WaitForChild("Presentation"):WaitForChild("FirstPerson"))
local StoryPresenter =
	require(clientRoot:WaitForChild("Presentation"):WaitForChild("StoryPresenter"))
local NpcProximityAudio =
	require(clientRoot:WaitForChild("Audio"):WaitForChild("NpcProximityAudio"))

local MazePolish = require(clientRoot:WaitForChild("Scenes"):WaitForChild("MazePolish"))
local FieldPolish = require(clientRoot:WaitForChild("Scenes"):WaitForChild("FieldPolish"))

print(`[{BuildInfo.name}] client content ready ({ContentConfig.version})`)

local gui = GuiShell.mount()
local remotes = RemoteBoundary.new()
local sprint =
	SprintControls.new(ContentConfig.controls.walkSpeed, ContentConfig.controls.sprintSpeed)
sprint:enable()
local asmr = ASMRStepListener.new(ContentConfig.controls.asmrDebounceSeconds)
local cinematics = CinematicPlayer.new()
cinematics:bindSubtitles(gui.setSubtitle, gui.clearSubtitle)
cinematics:bindAudio(ContentAudio)
local kidnapStage = KidnapStage.new()
local dogFight = DogFightPresenter.new(cinematics, ContentAudio)
dogFight:bindSubtitles(gui.setSubtitle, gui.clearSubtitle)

local presenter = StoryPresenter.new({
	gui = gui,
	remotes = remotes,
	lighting = LightingController,
	audio = ContentAudio,
	cinematics = cinematics,
	sprint = sprint,
	asmr = asmr,
	robber = RobberPresentation,
	dogFight = dogFight,
	kidnapStage = kidnapStage,
	epilogueProps = EpilogueProps,
	fragmentFeedback = FragmentFeedback,
	detection = DetectionFeedback,
	letterPanel = LetterPanel,
	firstPerson = FirstPerson,
	fragmentPrompts = FragmentPrompts,
	towerBuilder = ContentPackage.TowerBuilder,
	npcAudio = NpcProximityAudio,
})

FirstPerson.bindCursorToggle(gui.setCursorEnabled)
gui.setCursorHandler(function()
	FirstPerson.toggleCursor()
end)

asmr:setProgressHandler(function(step: number, total: number)
	gui.setTowerProgress(step, total)
	if step == 1 then
		gui.setObjective(ContentConfig.ui.towerGoalStart)
	elseif step >= total - 3 then
		gui.setObjective(ContentConfig.ui.towerGoalNearTop)
	end
end)

-- Honor session preference default from ContentConfig.
SessionPreferences.setReducedMotion(ContentConfig.accessibility.reducedMotionDefault == true)

gui.setRoleChoiceHandler(function(roleChoice: string)
	ContentAudio.playUiConfirm()
	remotes:request("RoleReady", {
		role = roleChoice,
	})
end)

gui.setReviveHandler(function(accepted: boolean)
	ContentAudio.playUiClick()
	remotes:request("ReviveConfirmed", accepted)
	if not accepted then
		gui.showRevive(true)
	else
		gui.showRevive(false)
	end
end)

gui.setReplayHandler(function()
	ContentAudio.playUiClick()
	presenter:resetForReplay()
	remotes:request("ReplayRequested")
end)

gui.setLeaveHandler(function()
	local player = Players.LocalPlayer
	player:Kick("Left the experience")
end)

remotes:on("StoryCue", function(payload: any)
	presenter:handleStoryCue(payload)
end)

remotes:on("ObjectiveUpdate", function(payload: any)
	local text = if typeof(payload) == "table" then payload.objective else payload
	if typeof(text) == "string" then
		gui.setObjective(text)
	end
end)

remotes:on("FragmentUpdate", function(payload: any)
	presenter:handleFragment(payload)
	if typeof(payload) == "table" then
		if payload.detected == true then
			gui.setThreatState("detected")
		elseif payload.caught == true then
			gui.setThreatState("chase")
		elseif typeof(payload.count) == "number" then
			gui.setThreatState("safe")
		end
	end
end)

remotes:on("RoleUpdate", function(payload: any)
	local roleName = if typeof(payload) == "table" then payload.role else payload
	if typeof(roleName) == "string" then
		gui.setRoleLabel(roleName)
		if roleName == "Protagonist" or roleName == "Admin" then
			gui.showTitle(false)
		end
	end
end)

remotes:on("AdminDiagnostics", function(payload: any)
	local text = if typeof(payload) == "table" then payload.message else tostring(payload)
	gui.showAdminDiagnostics(true, text)
end)

-- FightBeat sync is accepted by DogFightPresenter; coordinator may also route it.
-- Wire it here because client remotes are Codex-owned.
remotes:on("FightBeat", function(payload: any)
	dogFight:applyFightBeat(payload)
end)

-- Establish lobby presentation before remote events can transition into a stage.
-- Marketplace loading below can take several seconds, so applying these defaults
-- afterward would overwrite a stage cue chosen by a fast player.
LightingController.applyScene("Lobby")
ContentAudio.ambienceForScene("Lobby")
StageTeleporterListener.start()
CombatFeedback.start()
FirstPerson.start()
-- Title menu needs a free cursor; stay locked in first person.
FirstPerson.release()
gui.showTitle(true)

local remotesReady = remotes:start(12)
if not remotesReady then
	gui.setObjective("Waiting for systems remotes...")
end

local created = ContentPackage.PlaceholderMount.mountMissingMarkers()
print(`[Content] PlaceholderMount filled {created} missing markers`)

local marketplaceReady = ContentPackage.MarketplaceIntegration.waitUntilReady(12)
local mountedScenes = ContentPackage.MarketplaceIntegration.listMountedScenes()
print(`[Content] Marketplace ready={marketplaceReady} scenes={table.concat(mountedScenes, ",")}`)

-- Rebuild the deterministic tower flights and their ASMR sensors.
ContentPackage.TowerBuilder.rebuildFlights()
if ContentPackage.MarketplaceIntegration.hasSceneMap("Tower") then
	print("[Content] Tower marketplace map present; ASMR sensors only (no duplicate mesh)")
end

local hiddenStandIns = ContentPackage.MarketplaceIntegration.hideAllStandIns()
print(`[Content] Soft-hid {hiddenStandIns} marketplace stand-in parts`)

if not ContentPackage.MarketplaceIntegration.hasSceneMap("Maze") then
	MazePolish.ensureReadableShell()
else
	MazePolish.ensureExitReadable()
end
-- Landmark + fragment cue polish is useful whether or not a marketplace
-- field map is present; the function is idempotent either way.
FieldPolish.ensureLandmarks()

local report = TagDiscovery.scan()
TagDiscovery.printReport(report)
