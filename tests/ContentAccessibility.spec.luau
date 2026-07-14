--!nocheck
--[[
	Agent 2 content / accessibility / binding structure tests (Lune).
]]

local fs = require("@lune/fs")

local ContentConfig = require("../src/shared/ContentConfig")
local SessionPreferences = require("../src/client/Controls/SessionPreferences")

-- ContentConfig structure
assert(type(ContentConfig.projectTitle) == "string", "projectTitle required")
assert(#ContentConfig.storyStates == 14, "expected 14 story states")
assert(ContentConfig.towerStepCount == 28, "towerStepCount")
assert(ContentConfig.towerFlights == 7, "towerFlights")

-- Animations must not reuse the sound placeholder constant path as the only semantics:
-- they live under assets.animations with independent placeholder animation IDs.
local anims = ContentConfig.assets.animations
assert(type(anims.kidnapHold) == "string", "kidnapHold animation id")
assert(type(anims.reviveKneel) == "string", "reviveKneel animation id")
assert(type(anims.corruptionPulse) == "string", "corruptionPulse animation id")

local configSource = fs.readFile("src/shared/ContentConfig.luau")
assert(
	string.find(configSource, "PLACEHOLDER_ANIMATION", 1, true),
	"animations must use PLACEHOLDER_ANIMATION"
)
assert(
	string.find(configSource, "kidnapHold = PLACEHOLDER_ANIMATION", 1, true),
	"kidnapHold must not use PLACEHOLDER_SOUND"
)

-- Accessibility defaults
assert(ContentConfig.accessibility.reducedMotionDefault == false, "reduced motion default off")
assert(SessionPreferences.isReducedMotion() == false, "session default")
SessionPreferences.setReducedMotion(true)
assert(SessionPreferences.isReducedMotion() == true, "session toggle on")
assert(SessionPreferences.tweenSeconds(1, 0.1) == 0.1, "reduced tween helper")
SessionPreferences.resetToDefaults()
assert(SessionPreferences.isReducedMotion() == false, "session reset")

-- UI resolution-safe constants
assert(ContentConfig.ui.touchMinButtonPx >= 64, "touch targets must be comfortably sized")
assert(ContentConfig.ui.touchSafeInsetScale > 0, "safe inset required")
assert(ContentConfig.ui.minReadableTextPx >= 12, "readable text floor")
assert(type(ContentConfig.ui.leaveConfirmPrompt) == "string", "leave confirm required")
assert(type(ContentConfig.ui.lobbyCapacityHint) == "string", "lobby capacity hint required")

-- No duplicate placeholder object names
local seenNames: { [string]: boolean } = {}
for _, entry in ContentConfig.placeholderObjects do
	assert(seenNames[entry.name] == nil, `duplicate placeholder {entry.name}`)
	seenNames[entry.name] = true
end
for _, entry in ContentConfig.asmrStepPlaceholders do
	assert(seenNames[entry.name] == nil, `duplicate ASMR placeholder {entry.name}`)
	seenNames[entry.name] = true
end
assert(#ContentConfig.asmrStepPlaceholders == ContentConfig.towerStepCount, "ASMR count")

-- Marketplace IDs listed in ContentConfig match export manifest references
local exportManifest = fs.readFile("art/export/MANIFEST.md")
for key, assetId in ContentConfig.assets.marketplace.scenes do
	assert(
		string.find(exportManifest, tostring(assetId), 1, true),
		`scene {key} id missing from export manifest`
	)
end
for key, assetId in ContentConfig.assets.marketplace.characters do
	assert(
		string.find(exportManifest, tostring(assetId), 1, true),
		`character {key} id missing from export manifest`
	)
end

-- Required UI actions + binding configuration (source contracts)
local guiSource = fs.readFile("src/client/UI/GuiShell.luau")
local bindingsSource = fs.readFile("src/client/Controls/ActionBindings.luau")
local mainSource = fs.readFile("src/client/Main.client.luau")

assert(
	not string.find(guiSource, '"Brand"', 1, true)
		and string.find(guiSource, "showRoleSelection", 1, true)
		and string.find(guiSource, "showStageSelection", 1, true),
	"Lobby must show role selection first without the title screen overlapping it"
)
assert(
	string.find(guiSource, "button.Active = true", 1, true)
		and string.find(guiSource, "button.Modal = true", 1, true)
		and string.find(
			guiSource,
			"UserInputService.MouseBehavior = Enum.MouseBehavior.Default",
			1,
			true
		),
	"Lobby role, stage, and Start buttons must support direct mouse/touch activation"
)

for _, needle in
	{
		"LeaveConfirm",
		"ReducedMotion",
		"Selectable = true",
		"Activated:Connect",
		"setTowerProgress",
		"setThreatState",
		"CursorToggle",
		"ChooseBella",
		"ChooseAdmin",
		"ChooseMaze",
		"ChooseObby",
		"ChooseScavengerHunt",
	}
do
	assert(string.find(guiSource, needle, 1, true), `GuiShell missing {needle}`)
end

for _, action in
	{
		"ready",
		"reviveAccept",
		"reviveRefuse",
		"replay",
		"leave",
		"leaveConfirm",
		"reducedMotion",
		"cursorToggle",
	}
do
	assert(string.find(bindingsSource, action, 1, true), `ActionBindings missing {action}`)
end

assert(string.find(mainSource, "SessionPreferences", 1, true), "Main must wire SessionPreferences")
assert(string.find(mainSource, "setTowerProgress", 1, true), "Main must wire tower progress")
assert(string.find(mainSource, "bindCursorToggle", 1, true), "cursor unlock must remain wired")
assert(string.find(mainSource, "hideAllStandIns", 1, true), "stand-in hide required")

local letterSource = fs.readFile("src/client/Feedback/LetterPanel.luau")
assert(
	string.find(letterSource, "Dedupe", 1, true) or string.find(letterSource, "dedupe", 1, true),
	"LetterPanel must document twist dedupe"
)

local fragmentSource = fs.readFile("src/client/Feedback/FragmentFeedback.luau")
assert(
	string.find(fragmentSource, "Cancel", 1, true) or string.find(fragmentSource, "cancel", 1, true),
	"fragment tween cancel"
)

local sprintSource = fs.readFile("src/client/Controls/SprintControls.luau")
assert(string.find(sprintSource, "TouchEnabled", 1, true), "sprint must watch touch availability")

print("content accessibility test passed")
