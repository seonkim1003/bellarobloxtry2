--!nocheck

local fs = require("@lune/fs")

local guiSource = fs.readFile("src/client/UI/GuiShell.luau")
local mainSource = fs.readFile("src/client/Main.client.luau")
local bootstrapSource = fs.readFile("src/server/Bootstrap.server.luau")
local presenterSource = fs.readFile("src/client/Presentation/StoryPresenter.luau")
local ContentConfig = require("../src/shared/ContentConfig")

local buttons = {}
for variableName in string.gmatch(guiSource, "local%s+(%w+Button)%s*=%s*createButton") do
	table.insert(buttons, variableName)
end

assert(#buttons == 15, `expected 15 interactive buttons, found {#buttons}`)
for _, variableName in buttons do
	assert(
		string.find(guiSource, `{variableName}.Activated:Connect`, 1, true),
		`{variableName} has no mouse/touch Activated handler`
	)
end

assert(
	string.find(guiSource, "button.Active = true", 1, true)
		and string.find(guiSource, "button.Selectable = true", 1, true),
	"Every created button must support pointer/touch and controller focus"
)
assert(
	string.find(guiSource, "screenGui.DisplayOrder = 20", 1, true)
		and string.find(guiSource, "button.ZIndex = 12", 1, true)
		and string.find(guiSource, "button.Modal = true", 1, true),
	"Lobby buttons must remain above competing UI and retain the mouse"
)
assert(
	string.find(guiSource, "showRoleSelection", 1, true)
		and string.find(guiSource, "showStageSelection", 1, true)
		and string.find(guiSource, "UserInputService.MouseIconEnabled = true", 1, true)
		and string.find(
			guiSource,
			"UserInputService.MouseBehavior = Enum.MouseBehavior.Default",
			1,
			true
		),
	"Role and stage screens must unlock the pointer"
)

for _, choice in { "Maze", "Obby", "Scavenger Hunt" } do
	assert(string.find(guiSource, `selectedStage = "{choice}"`, 1, true), `missing {choice} click`)
	assert(
		string.find(bootstrapSource, `stageChoice == "{choice}"`, 1, true) or choice == "Maze",
		`missing {choice} server route`
	)
end
assert(
	string.find(mainSource, 'remotes:request("RoleReady", {', 1, true)
		and string.find(mainSource, "role = roleChoice", 1, true)
		and string.find(mainSource, "stage = stageChoice", 1, true),
	"Start must submit both selections"
)

for _, state in ContentConfig.storyStates do
	assert(
		string.find(presenterSource, `state == "{state}"`, 1, true) or state == "RoleLobby",
		`StoryPresenter has no screen path for {state}`
	)
end

assert(
	string.find(presenterSource, 'if state ~= "RoleLobby" and state ~= "Credits" then', 1, true)
		and string.find(presenterSource, "d.gui.showTitle(false)", 1, true),
	"Every direct stage start must close the lobby screen"
)

for _, screenApi in { "showTitle", "showRevive", "showCredits", "showLeaveConfirm" } do
	assert(
		string.find(guiSource, `{screenApi} = function`, 1, true),
		`missing {screenApi} screen API`
	)
end

print(`ui interaction audit passed: {#buttons} buttons, all story states, all stage routes`)
