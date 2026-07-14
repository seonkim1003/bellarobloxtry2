--!strict
--[[
	Phase 1–2 UI shells: title, objectives, subtitles, fragments, revive,
	admin diagnostics, credits, Replay/Leave (with confirm), reduced motion,
	tower progress, threat state, and controller focus.
]]

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()
local SessionPreferences =
	require(script.Parent.Parent:WaitForChild("Controls"):WaitForChild("SessionPreferences"))
local ActionBindings =
	require(script.Parent.Parent:WaitForChild("Controls"):WaitForChild("ActionBindings"))
local ContentAudio =
	require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("ContentAudio"))

export type GuiShellApi = {
	setObjective: (text: string) -> (),
	setSubtitle: (speaker: string?, text: string) -> (),
	clearSubtitle: () -> (),
	setFragmentCount: (collected: number, total: number) -> (),
	setRoleLabel: (roleText: string) -> (),
	setReadyAccepted: (accepted: boolean) -> (),
	setTowerProgress: (step: number, totalSteps: number) -> (),
	setThreatState: (state: string) -> (),
	clearThreatState: () -> (),
	showTitle: (visible: boolean) -> (),
	showRevive: (visible: boolean) -> (),
	showCredits: (visible: boolean) -> (),
	showLeaveConfirm: (visible: boolean) -> (),
	showAdminDiagnostics: (visible: boolean, text: string?) -> (),
	setCursorEnabled: (enabled: boolean) -> (),
	setReducedMotionEnabled: (enabled: boolean) -> (),
	setRoleChoiceHandler: (handler: ((roleChoice: string) -> ())?) -> (),
	setCursorHandler: (handler: (() -> ())?) -> (),
	setReducedMotionHandler: (handler: (() -> ())?) -> (),
	setReviveHandler: (handler: ((accepted: boolean) -> ())?) -> (),
	setReplayHandler: (handler: (() -> ())?) -> (),
	setLeaveHandler: (handler: (() -> ())?) -> (),
	setLeaveConfirmHandler: (handler: ((confirmed: boolean) -> ())?) -> (),
}

local GuiShell = {}

local TOUCH_MIN = ContentConfig.ui.touchMinButtonPx or 72

local function mountModelViewport(
	parent: Instance,
	name: string,
	templateName: string,
	position: UDim2,
	viewportSize: UDim2
): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = name
	viewport.BackgroundTransparency = 1
	viewport.Position = position
	viewport.Size = viewportSize
	viewport.Ambient = Color3.fromRGB(190, 190, 205)
	viewport.LightColor = Color3.fromRGB(255, 238, 220)
	viewport.LightDirection = Vector3.new(-1, -0.6, -1)
	viewport.Parent = parent

	task.spawn(function()
		local templates = ReplicatedStorage:WaitForChild("ContentModels", 12)
		if templates == nil then
			return
		end
		local template = templates:WaitForChild(templateName, 12)
		if template == nil or not template:IsA("Model") or viewport.Parent == nil then
			return
		end

		local world = Instance.new("WorldModel")
		world.Parent = viewport
		local character = template:Clone()
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		character.Parent = world

		local bounds, size = character:GetBoundingBox()
		character:PivotTo(character:GetPivot() - bounds.Position)
		local camera = Instance.new("Camera")
		camera.FieldOfView = 32
		camera.CFrame = CFrame.lookAt(
			Vector3.new(0, size.Y * 0.05, math.max(size.X, size.Y, size.Z) * 2.15),
			Vector3.new(0, size.Y * 0.05, 0)
		)
		camera.Parent = viewport
		viewport.CurrentCamera = camera
	end)
	return viewport
end

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
	button.Active = true
	button.Selectable = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(TOUCH_MIN, math.floor(TOUCH_MIN * 0.55))
	constraint.Parent = button

	return button
end

local function softTween(instance: Instance, info: TweenInfo, goals: { [string]: any })
	if SessionPreferences.shouldSkipMotionEffects() then
		for key, value in goals do
			(instance :: any)[key] = value
		end
		return nil
	end
	local tween = TweenService:Create(instance, info, goals)
	tween:Play()
	return tween
end

local function roleDisplay(roleText: string): (string, string)
	local lower = string.lower(roleText)
	if string.find(lower, "protagonist", 1, true) then
		return "Protagonist", ContentConfig.ui.lobbyProtagonistHint
	elseif string.find(lower, "observer", 1, true) then
		return "Observer", ContentConfig.ui.lobbyObserverHint
	elseif string.find(lower, "wait", 1, true) then
		return "Waiting", ContentConfig.ui.lobbyWaitingHint
	elseif roleText == "" or roleText == "Unassigned" then
		return "Unassigned", ContentConfig.ui.lobbyWaitingHint
	end
	return roleText, ContentConfig.ui.lobbyCapacityHint
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
	screenGui.DisplayOrder = 20
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
	titleFrame.Active = true
	titleFrame.ZIndex = 10
	titleFrame.Visible = true
	titleFrame.Parent = screenGui
	local roleLabel = createTextLabel(titleFrame, "Role", {
		Text = "Role: Unassigned",
		Position = UDim2.fromScale(0.15, 0.4),
		Size = UDim2.fromScale(0.7, 0.06),
		Visible = false,
	})
	local lobbyHint = createTextLabel(titleFrame, "LobbyHint", {
		Text = ContentConfig.ui.lobbyCapacityHint,
		Position = UDim2.fromScale(0.12, 0.34),
		Size = UDim2.fromScale(0.76, 0.05),
		TextColor3 = Color3.fromRGB(190, 195, 210),
		Visible = false,
	})
	local roleChoicePrompt = createTextLabel(titleFrame, "RoleChoicePrompt", {
		Text = "Select your role",
		Position = UDim2.fromScale(0.25, 0.3),
		Size = UDim2.fromScale(0.5, 0.09),
		Font = Enum.Font.GothamBold,
	})
	local bellaButton = createButton(
		titleFrame,
		"ChooseBella",
		"Bella",
		UDim2.fromScale(0.3, 0.43),
		UDim2.fromScale(0.18, 0.09)
	)
	local adminButton = createButton(
		titleFrame,
		"ChooseAdmin",
		"Admin",
		UDim2.fromScale(0.52, 0.43),
		UDim2.fromScale(0.18, 0.09)
	)
	local roleChoiceHint = createTextLabel(titleFrame, "RoleChoiceHint", {
		Text = "After choosing Bella, walk onto one of the three teleporters in the lobby.",
		Position = UDim2.fromScale(0.2, 0.57),
		Size = UDim2.fromScale(0.6, 0.08),
		TextColor3 = Color3.fromRGB(200, 205, 220),
	})

	local reducedMotionButton = createButton(
		titleFrame,
		"ReducedMotion",
		ContentConfig.ui.reducedMotionOff,
		UDim2.fromScale(0.25, 0.72),
		UDim2.fromScale(0.5, 0.07)
	)
	reducedMotionButton.TextScaled = false
	reducedMotionButton.TextSize = 16

	local lobbyButtons: { TextButton } = {
		bellaButton,
		adminButton,
		reducedMotionButton,
	}
	for _, button in lobbyButtons do
		button.Active = true
		button.Modal = true
		button.ZIndex = 12
	end
	roleChoicePrompt.ZIndex = 11
	roleChoiceHint.ZIndex = 11

	-- In-game mouse unlock. Keyboard/mouse players can use Tab, controller players
	-- can use Y, and touch/controller users can activate this selectable button.
	local cursorButton = createButton(
		screenGui,
		"CursorToggle",
		"Unlock Cursor  [Tab / Y]",
		UDim2.fromScale(0.72, 0.91),
		UDim2.fromScale(0.26, 0.055)
	)
	cursorButton.TextScaled = false
	cursorButton.TextSize = 16
	cursorButton.Visible = false

	local settingsButton = createButton(
		screenGui,
		"SettingsMotion",
		"Motion: Full  [M]",
		UDim2.fromScale(0.02, 0.91),
		UDim2.fromScale(0.28, 0.055)
	)
	settingsButton.TextScaled = false
	settingsButton.TextSize = 15
	settingsButton.Visible = false

	-- Objective
	local objectiveLabel = createTextLabel(screenGui, "Objective", {
		Text = ContentConfig.ui.objectiveFallback,
		Position = UDim2.fromScale(0.05, 0.04),
		Size = UDim2.fromScale(0.58, 0.06),
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
	})

	-- Fragment count
	local fragmentLabel = createTextLabel(screenGui, "Fragments", {
		Text = `{ContentConfig.ui.fragmentLabel}: 0 / 3`,
		Position = UDim2.fromScale(0.64, 0.04),
		Size = UDim2.fromScale(0.31, 0.06),
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
	})
	local fragmentIcon = mountModelViewport(
		screenGui,
		"FragmentIcon",
		"LetterFragmentTemplate",
		UDim2.fromScale(0.6, 0.035),
		UDim2.fromScale(0.055, 0.075)
	)
	fragmentIcon.Visible = false

	-- Tower progress (step / flight)
	local towerProgressLabel = createTextLabel(screenGui, "TowerProgress", {
		Text = "",
		Position = UDim2.fromScale(0.25, 0.12),
		Size = UDim2.fromScale(0.5, 0.05),
		Visible = false,
		BackgroundTransparency = 0.45,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	})

	-- Threat state (text + icon glyph; not color-only)
	local threatLabel = createTextLabel(screenGui, "ThreatState", {
		Text = "",
		Position = UDim2.fromScale(0.3, 0.18),
		Size = UDim2.fromScale(0.4, 0.05),
		Visible = false,
		BackgroundTransparency = 0.4,
		BackgroundColor3 = Color3.fromRGB(20, 10, 10),
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
		Position = UDim2.fromScale(0.1, 0.12),
		Size = UDim2.fromScale(0.8, 0.28),
	})
	local acceptButton = createButton(
		reviveFrame,
		"Accept",
		`{ContentConfig.ui.reviveAccept}  [Enter / A]`,
		UDim2.fromScale(0.08, 0.5),
		UDim2.fromScale(0.38, 0.32)
	)
	local refuseButton = createButton(
		reviveFrame,
		"Refuse",
		`{ContentConfig.ui.reviveRefuse}  [Bksp / B]`,
		UDim2.fromScale(0.54, 0.5),
		UDim2.fromScale(0.38, 0.32)
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

	createTextLabel(creditsFrame, "Body", {
		Text = table.concat(ContentConfig.ui.creditsLines, "\n"),
		Position = UDim2.fromScale(0.12, 0.16),
		Size = UDim2.fromScale(0.76, 0.38),
	})

	local replayButton = createButton(
		creditsFrame,
		"Replay",
		`{ContentConfig.ui.replayLabel}  [R / X]`,
		UDim2.fromScale(0.2, 0.62),
		UDim2.fromScale(0.26, 0.1)
	)
	local leaveButton = createButton(
		creditsFrame,
		"Leave",
		`{ContentConfig.ui.leaveLabel}  [L / B]`,
		UDim2.fromScale(0.54, 0.62),
		UDim2.fromScale(0.26, 0.1)
	)

	-- Leave confirmation overlay
	local leaveConfirmFrame = Instance.new("Frame")
	leaveConfirmFrame.Name = "LeaveConfirm"
	leaveConfirmFrame.BackgroundColor3 = Color3.fromRGB(14, 12, 20)
	leaveConfirmFrame.BackgroundTransparency = 0.1
	leaveConfirmFrame.Size = UDim2.fromScale(0.52, 0.3)
	leaveConfirmFrame.Position = UDim2.fromScale(0.24, 0.35)
	leaveConfirmFrame.Visible = false
	leaveConfirmFrame.ZIndex = 5
	leaveConfirmFrame.Parent = screenGui
	local leaveConfirmCorner = Instance.new("UICorner")
	leaveConfirmCorner.CornerRadius = UDim.new(0, 12)
	leaveConfirmCorner.Parent = leaveConfirmFrame

	createTextLabel(leaveConfirmFrame, "Prompt", {
		Text = ContentConfig.ui.leaveConfirmPrompt,
		Position = UDim2.fromScale(0.08, 0.12),
		Size = UDim2.fromScale(0.84, 0.32),
		ZIndex = 6,
	})
	local leaveYesButton = createButton(
		leaveConfirmFrame,
		"LeaveYes",
		`{ContentConfig.ui.leaveConfirmYes}  [Enter / A]`,
		UDim2.fromScale(0.08, 0.52),
		UDim2.fromScale(0.38, 0.32)
	)
	leaveYesButton.ZIndex = 6
	local leaveNoButton = createButton(
		leaveConfirmFrame,
		"LeaveNo",
		`{ContentConfig.ui.leaveConfirmNo}  [Esc / B]`,
		UDim2.fromScale(0.54, 0.52),
		UDim2.fromScale(0.38, 0.32)
	)
	leaveNoButton.ZIndex = 6

	-- Selection graph (controller)
	bellaButton.NextSelectionDown = reducedMotionButton
	adminButton.NextSelectionDown = reducedMotionButton
	reducedMotionButton.NextSelectionUp = bellaButton
	acceptButton.NextSelectionRight = refuseButton
	refuseButton.NextSelectionLeft = acceptButton
	replayButton.NextSelectionRight = leaveButton
	leaveButton.NextSelectionLeft = replayButton
	leaveYesButton.NextSelectionRight = leaveNoButton
	leaveNoButton.NextSelectionLeft = leaveYesButton
	cursorButton.NextSelectionLeft = settingsButton
	settingsButton.NextSelectionRight = cursorButton

	local roleChoiceHandler: ((string) -> ())? = nil
	local cursorHandler: (() -> ())? = nil
	local reducedMotionHandler: (() -> ())? = nil
	local reviveHandler: ((boolean) -> ())? = nil
	local replayHandler: (() -> ())? = nil
	local leaveHandler: (() -> ())? = nil
	local leaveConfirmHandler: ((boolean) -> ())? = nil

	local titleVisible = true
	local reviveVisible = false
	local creditsVisible = false
	local leaveConfirmVisible = false
	local selectedRole = ""

	local function showRoleSelection()
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		selectedRole = ""
		roleChoicePrompt.Visible = true
		roleChoiceHint.Visible = true
		bellaButton.Visible = true
		adminButton.Visible = true
		reducedMotionButton.Visible = true
		ActionBindings.focus(bellaButton)
	end

	local function updateLobbyChoices()
		bellaButton.BackgroundColor3 = if selectedRole == "Bella"
			then Color3.fromRGB(65, 105, 75)
			else Color3.fromRGB(35, 35, 48)
		adminButton.BackgroundColor3 = if selectedRole == "Admin"
			then Color3.fromRGB(105, 75, 65)
			else Color3.fromRGB(35, 35, 48)
	end

	local function updateMotionButtonLabels()
		local reduced = SessionPreferences.isReducedMotion()
		local text = if reduced
			then ContentConfig.ui.reducedMotionOn
			else ContentConfig.ui.reducedMotionOff
		reducedMotionButton.Text = text
		settingsButton.Text = if reduced then "Motion: Reduced  [M]" else "Motion: Full  [M]"
	end

	local function syncBindings()
		ActionBindings.setPanelVisibility({
			title = titleVisible,
			revive = reviveVisible,
			credits = creditsVisible and not leaveConfirmVisible,
			leaveConfirm = leaveConfirmVisible,
		})
	end

	local function showLeaveConfirm(visible: boolean)
		leaveConfirmVisible = visible
		leaveConfirmFrame.Visible = visible
		if visible then
			ActionBindings.focus(leaveNoButton)
		elseif creditsVisible then
			ActionBindings.focus(replayButton)
		else
			ActionBindings.clearFocus()
		end
		syncBindings()
	end

	local function toggleReducedMotion()
		if reducedMotionHandler then
			reducedMotionHandler()
		else
			SessionPreferences.toggleReducedMotion()
			updateMotionButtonLabels()
		end
	end

	local function invokeRoleChoice()
		if selectedRole ~= "" and roleChoiceHandler then
			roleChoiceHandler(selectedRole)
		end
	end

	bellaButton.Activated:Connect(function()
		ContentAudio.playUiClick()
		selectedRole = "Bella"
		updateLobbyChoices()
		invokeRoleChoice()
	end)
	adminButton.Activated:Connect(function()
		ContentAudio.playUiClick()
		selectedRole = "Admin"
		updateLobbyChoices()
		invokeRoleChoice()
	end)
	cursorButton.Activated:Connect(function()
		ContentAudio.playUiClick()
		if cursorHandler then
			cursorHandler()
		end
	end)
	acceptButton.Activated:Connect(function()
		if reviveHandler then
			reviveHandler(true)
		end
	end)
	refuseButton.Activated:Connect(function()
		if reviveHandler then
			reviveHandler(false)
		end
	end)
	replayButton.Activated:Connect(function()
		if replayHandler then
			replayHandler()
		end
	end)
	leaveButton.Activated:Connect(function()
		ContentAudio.playUiClick()
		showLeaveConfirm(true)
	end)
	leaveYesButton.Activated:Connect(function()
		ContentAudio.playUiConfirm()
		showLeaveConfirm(false)
		if leaveConfirmHandler then
			leaveConfirmHandler(true)
		elseif leaveHandler then
			leaveHandler()
		end
	end)
	leaveNoButton.Activated:Connect(function()
		ContentAudio.playUiClick()
		showLeaveConfirm(false)
		if leaveConfirmHandler then
			leaveConfirmHandler(false)
		end
	end)
	reducedMotionButton.Activated:Connect(function()
		ContentAudio.playUiClick()
		toggleReducedMotion()
	end)
	settingsButton.Activated:Connect(function()
		ContentAudio.playUiClick()
		toggleReducedMotion()
	end)

	ActionBindings.setHandlers({
		ready = function()
			if titleVisible then
				invokeRoleChoice()
			end
		end,
		reviveAccept = function()
			if reviveVisible and reviveHandler then
				reviveHandler(true)
			end
		end,
		reviveRefuse = function()
			if reviveVisible and reviveHandler then
				reviveHandler(false)
			end
		end,
		replay = function()
			if creditsVisible and not leaveConfirmVisible and replayHandler then
				replayHandler()
			end
		end,
		leave = function()
			if creditsVisible and not leaveConfirmVisible then
				showLeaveConfirm(true)
			end
		end,
		leaveConfirm = function()
			if leaveConfirmVisible then
				showLeaveConfirm(false)
				if leaveHandler then
					leaveHandler()
				end
			end
		end,
		leaveCancel = function()
			if leaveConfirmVisible then
				showLeaveConfirm(false)
			end
		end,
		reducedMotionToggle = toggleReducedMotion,
	})
	ActionBindings.start()
	showRoleSelection()
	updateLobbyChoices()
	updateMotionButtonLabels()
	syncBindings()
	ActionBindings.focus(bellaButton)

	SessionPreferences.onChanged(function()
		updateMotionButtonLabels()
	end)

	-- Keep touch padding honest if device capabilities change after startup.
	UserInputService.LastInputTypeChanged:Connect(function()
		local guiInset = GuiService:GetGuiInset()
		pad.PaddingTop = UDim.new(inset, guiInset.Y > 0 and 0 or 8)
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
			fragmentIcon.Visible = true
			local remaining = math.max(total - collected, 0)
			fragmentLabel.Text =
				`{ContentConfig.ui.fragmentLabel}: {collected} / {total}  ({remaining} left)`
		end,
		setRoleLabel = function(roleText: string)
			local display, hint = roleDisplay(roleText)
			roleLabel.Text = `Role: {display}`
			lobbyHint.Text = `{hint}\n{ContentConfig.ui.lobbyCapacityHint}`
		end,
		setReadyAccepted = function(accepted: boolean)
			-- Compatibility API retained for callers that reset the lobby presentation.
			if not accepted then
				selectedRole = ""
				updateLobbyChoices()
			end
		end,
		setTowerProgress = function(step: number, totalSteps: number)
			local flights = ContentConfig.towerFlights
			local perFlight = math.max(1, math.ceil(totalSteps / flights))
			local flight = math.clamp(math.ceil(step / perFlight), 1, flights)
			towerProgressLabel.Visible = step > 0
			towerProgressLabel.Text =
				`{ContentConfig.ui.towerProgressLabel}: {step}/{totalSteps}  ·  Flight {flight}/{flights}`
		end,
		setThreatState = function(state: string)
			threatLabel.Visible = true
			if state == "detected" then
				threatLabel.Text = ContentConfig.ui.threatDetected
				threatLabel.TextColor3 = Color3.fromRGB(255, 200, 90)
			elseif state == "chase" then
				threatLabel.Text = ContentConfig.ui.threatChase
				threatLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
			elseif state == "safe" then
				threatLabel.Text = ContentConfig.ui.threatSafe
				threatLabel.TextColor3 = Color3.fromRGB(160, 220, 160)
			else
				threatLabel.Text = state
			end
		end,
		clearThreatState = function()
			threatLabel.Visible = false
			threatLabel.Text = ""
		end,
		showTitle = function(visible: boolean)
			titleVisible = visible
			titleFrame.Visible = visible
			cursorButton.Visible = not visible
			settingsButton.Visible = not visible
			objectiveLabel.Visible = not visible
				and objectiveLabel.Text ~= ContentConfig.ui.objectiveFallback
			if not visible then
				towerProgressLabel.Visible = false
			end
			if visible then
				showRoleSelection()
			else
				ActionBindings.clearFocus()
			end
			syncBindings()
		end,
		showRevive = function(visible: boolean)
			reviveVisible = visible
			reviveFrame.Visible = visible
			if visible then
				softTween(
					reviveFrame,
					TweenInfo.new(SessionPreferences.tweenSeconds(0.25, 0), Enum.EasingStyle.Quad),
					{ BackgroundTransparency = 0.2 }
				)
				ActionBindings.focus(acceptButton)
			else
				ActionBindings.clearFocus()
			end
			syncBindings()
		end,
		showCredits = function(visible: boolean)
			creditsVisible = visible
			creditsFrame.Visible = visible
			if not visible then
				showLeaveConfirm(false)
			end
			if visible then
				ActionBindings.focus(replayButton)
			else
				ActionBindings.clearFocus()
			end
			syncBindings()
		end,
		showLeaveConfirm = function(visible: boolean)
			showLeaveConfirm(visible)
		end,
		showAdminDiagnostics = function(visible: boolean, text: string?)
			adminFrame.Visible = visible
			if text then
				adminLabel.Text = text
			end
		end,
		setCursorEnabled = function(enabled: boolean)
			cursorButton.Text = if enabled
				then "Lock Cursor  [Tab / Y]"
				else "Unlock Cursor  [Tab / Y]"
			cursorButton.Modal = enabled
		end,
		setReducedMotionEnabled = function(enabled: boolean)
			SessionPreferences.setReducedMotion(enabled)
			updateMotionButtonLabels()
		end,
		setRoleChoiceHandler = function(handler: ((string) -> ())?)
			roleChoiceHandler = handler
		end,
		setCursorHandler = function(handler: (() -> ())?)
			cursorHandler = handler
		end,
		setReducedMotionHandler = function(handler: (() -> ())?)
			reducedMotionHandler = handler
		end,
		setReviveHandler = function(handler: ((accepted: boolean) -> ())?)
			reviveHandler = handler
		end,
		setReplayHandler = function(handler: (() -> ())?)
			replayHandler = handler
		end,
		setLeaveHandler = function(handler: (() -> ())?)
			leaveHandler = handler
		end,
		setLeaveConfirmHandler = function(handler: ((confirmed: boolean) -> ())?)
			leaveConfirmHandler = handler
		end,
	}

	return api
end

return GuiShell
