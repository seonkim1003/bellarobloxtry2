--!strict
--[[
	Phase 1 UI shells: title, objectives, subtitles, fragments, revive,
	admin diagnostics, credits, Replay, and Leave.
]]

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()

export type GuiShellApi = {
	setObjective: (text: string) -> (),
	setSubtitle: (speaker: string?, text: string) -> (),
	clearSubtitle: () -> (),
	setFragmentCount: (collected: number, total: number) -> (),
	setRoleLabel: (roleText: string) -> (),
	showTitle: (visible: boolean) -> (),
	showRevive: (visible: boolean) -> (),
	showCredits: (visible: boolean) -> (),
	showAdminDiagnostics: (visible: boolean, text: string?) -> (),
	setReadyHandler: (handler: (() -> ())?) -> (),
	setReviveHandler: (handler: ((accepted: boolean) -> ())?) -> (),
	setReplayHandler: (handler: (() -> ())?) -> (),
	setLeaveHandler: (handler: (() -> ())?) -> (),
}

local GuiShell = {}

local function createTextLabel(parent: Instance, name: string, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.TextWrapped = true
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

local function createButton(
	parent: Instance,
	name: string,
	text: string,
	position: UDim2,
	size: UDim2
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.TextColor3 = Color3.fromRGB(250, 250, 250)
	button.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = size
	button.AutoButtonColor = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	return button
end

function GuiShell.mount(): GuiShellApi
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("ContentHud")
	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ContentHud"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	local inset = ContentConfig.ui.touchSafeInsetScale
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(inset, GuiService:GetGuiInset().Y > 0 and 0 or 8)
	pad.PaddingBottom = UDim.new(inset, 8)
	pad.PaddingLeft = UDim.new(inset, 8)
	pad.PaddingRight = UDim.new(inset, 8)
	pad.Parent = screenGui

	-- Title shell
	local titleFrame = Instance.new("Frame")
	titleFrame.Name = "Title"
	titleFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
	titleFrame.BackgroundTransparency = 0.15
	titleFrame.Size = UDim2.fromScale(1, 1)
	titleFrame.Visible = true
	titleFrame.Parent = screenGui

	createTextLabel(titleFrame, "Brand", {
		Text = ContentConfig.projectTitle,
		Position = UDim2.fromScale(0.1, 0.28),
		Size = UDim2.fromScale(0.8, 0.16),
		Font = Enum.Font.GothamBold,
	})
	createTextLabel(titleFrame, "Prompt", {
		Text = ContentConfig.ui.titlePrompt,
		Position = UDim2.fromScale(0.15, 0.48),
		Size = UDim2.fromScale(0.7, 0.08),
	})
	local roleLabel = createTextLabel(titleFrame, "Role", {
		Text = "Role: Unassigned",
		Position = UDim2.fromScale(0.2, 0.58),
		Size = UDim2.fromScale(0.6, 0.06),
	})
	local readyButton = createButton(
		titleFrame,
		"Ready",
		"Ready",
		UDim2.fromScale(0.35, 0.7),
		UDim2.fromScale(0.3, 0.08)
	)

	-- Objective
	local objectiveLabel = createTextLabel(screenGui, "Objective", {
		Text = ContentConfig.ui.objectiveFallback,
		Position = UDim2.fromScale(0.05, 0.04),
		Size = UDim2.fromScale(0.6, 0.06),
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
	})

	-- Fragment count
	local fragmentLabel = createTextLabel(screenGui, "Fragments", {
		Text = `{ContentConfig.ui.fragmentLabel}: 0 / 3`,
		Position = UDim2.fromScale(0.7, 0.04),
		Size = UDim2.fromScale(0.25, 0.06),
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
	})

	-- Subtitles
	local subtitleLabel = createTextLabel(screenGui, "Subtitle", {
		Text = "",
		Position = UDim2.fromScale((1 - ContentConfig.ui.subtitleMaxWidthScale) / 2, 0.78),
		Size = UDim2.fromScale(ContentConfig.ui.subtitleMaxWidthScale, 0.1),
		Visible = false,
		BackgroundTransparency = 0.35,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	})

	-- Revive prompt
	local reviveFrame = Instance.new("Frame")
	reviveFrame.Name = "RevivePrompt"
	reviveFrame.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
	reviveFrame.BackgroundTransparency = 0.2
	reviveFrame.Size = UDim2.fromScale(0.5, 0.28)
	reviveFrame.Position = UDim2.fromScale(0.25, 0.36)
	reviveFrame.Visible = false
	reviveFrame.Parent = screenGui
	local reviveCorner = Instance.new("UICorner")
	reviveCorner.CornerRadius = UDim.new(0, 12)
	reviveCorner.Parent = reviveFrame

	createTextLabel(reviveFrame, "Prompt", {
		Text = ContentConfig.dialogue.revive[1].text,
		Position = UDim2.fromScale(0.1, 0.15),
		Size = UDim2.fromScale(0.8, 0.3),
	})
	local acceptButton = createButton(
		reviveFrame,
		"Accept",
		ContentConfig.ui.reviveAccept,
		UDim2.fromScale(0.1, 0.55),
		UDim2.fromScale(0.35, 0.28)
	)
	local refuseButton = createButton(
		reviveFrame,
		"Refuse",
		ContentConfig.ui.reviveRefuse,
		UDim2.fromScale(0.55, 0.55),
		UDim2.fromScale(0.35, 0.28)
	)

	-- Admin diagnostics (read-only shell)
	local adminFrame = Instance.new("Frame")
	adminFrame.Name = "AdminDiagnostics"
	adminFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 20)
	adminFrame.BackgroundTransparency = 0.25
	adminFrame.Size = UDim2.fromScale(0.34, 0.28)
	adminFrame.Position = UDim2.fromScale(0.64, 0.12)
	adminFrame.Visible = false
	adminFrame.Parent = screenGui
	local adminLabel = createTextLabel(adminFrame, "Body", {
		Text = "Admin diagnostics",
		Position = UDim2.fromScale(0.05, 0.05),
		Size = UDim2.fromScale(0.9, 0.9),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	-- Credits + end actions
	local creditsFrame = Instance.new("Frame")
	creditsFrame.Name = "Credits"
	creditsFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
	creditsFrame.Size = UDim2.fromScale(1, 1)
	creditsFrame.Visible = false
	creditsFrame.Parent = screenGui

	local creditsBody = createTextLabel(creditsFrame, "Body", {
		Text = table.concat(ContentConfig.ui.creditsLines, "\n"),
		Position = UDim2.fromScale(0.15, 0.2),
		Size = UDim2.fromScale(0.7, 0.4),
	})
	local _ = creditsBody

	local replayButton = createButton(
		creditsFrame,
		"Replay",
		ContentConfig.ui.replayLabel,
		UDim2.fromScale(0.25, 0.7),
		UDim2.fromScale(0.2, 0.08)
	)
	local leaveButton = createButton(
		creditsFrame,
		"Leave",
		ContentConfig.ui.leaveLabel,
		UDim2.fromScale(0.55, 0.7),
		UDim2.fromScale(0.2, 0.08)
	)

	local readyHandler: (() -> ())? = nil
	local reviveHandler: ((boolean) -> ())? = nil
	local replayHandler: (() -> ())? = nil
	local leaveHandler: (() -> ())? = nil

	readyButton.MouseButton1Click:Connect(function()
		if readyHandler then
			readyHandler()
		end
	end)
	acceptButton.MouseButton1Click:Connect(function()
		if reviveHandler then
			reviveHandler(true)
		end
	end)
	refuseButton.MouseButton1Click:Connect(function()
		if reviveHandler then
			reviveHandler(false)
		end
	end)
	replayButton.MouseButton1Click:Connect(function()
		if replayHandler then
			replayHandler()
		end
	end)
	leaveButton.MouseButton1Click:Connect(function()
		if leaveHandler then
			leaveHandler()
		end
	end)

	local api: GuiShellApi = {
		setObjective = function(text: string)
			objectiveLabel.Visible = true
			objectiveLabel.Text = text
		end,
		setSubtitle = function(speaker: string?, text: string)
			subtitleLabel.Visible = true
			if speaker and speaker ~= "" then
				subtitleLabel.Text = `{speaker}: {text}`
			else
				subtitleLabel.Text = text
			end
		end,
		clearSubtitle = function()
			subtitleLabel.Visible = false
			subtitleLabel.Text = ""
		end,
		setFragmentCount = function(collected: number, total: number)
			fragmentLabel.Visible = true
			fragmentLabel.Text = `{ContentConfig.ui.fragmentLabel}: {collected} / {total}`
		end,
		setRoleLabel = function(roleText: string)
			roleLabel.Text = `Role: {roleText}`
		end,
		showTitle = function(visible: boolean)
			titleFrame.Visible = visible
			objectiveLabel.Visible = not visible
				and objectiveLabel.Text ~= ContentConfig.ui.objectiveFallback
		end,
		showRevive = function(visible: boolean)
			reviveFrame.Visible = visible
		end,
		showCredits = function(visible: boolean)
			creditsFrame.Visible = visible
		end,
		showAdminDiagnostics = function(visible: boolean, text: string?)
			adminFrame.Visible = visible
			if text then
				adminLabel.Text = text
			end
		end,
		setReadyHandler = function(handler: (() -> ())?)
			readyHandler = handler
		end,
		setReviveHandler = function(handler: ((boolean) -> ())?)
			reviveHandler = handler
		end,
		setReplayHandler = function(handler: (() -> ())?)
			replayHandler = handler
		end,
		setLeaveHandler = function(handler: (() -> ())?)
			leaveHandler = handler
		end,
	}

	return api
end

return GuiShell
