--!strict
--[[
	Final letter panel. Twist text is intentionally NOT duplicated here —
	StoryPresenter shows the twist via subtitle. includeTwist is kept for API
	compat but does not append twist body (dedupe handoff).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()
local SessionPreferences =
	require(script.Parent.Parent:WaitForChild("Controls"):WaitForChild("SessionPreferences"))

local LetterPanel = {}

local guiRef: ScreenGui? = nil
local activeTween: Tween? = nil

local function cancelTween()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
end

local function ensure(): (ScreenGui, TextLabel, TextLabel, Frame)
	if guiRef then
		local panel = guiRef:FindFirstChild("Panel") :: Frame
		local title = panel:FindFirstChild("Title") :: TextLabel
		local body = panel:FindFirstChild("Body") :: TextLabel
		return guiRef, title, body, panel
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "ContentLetter"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.IgnoreGuiInset = false
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.82, 0.72)
	panel.BackgroundColor3 = Color3.fromRGB(235, 225, 200)
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(280, 320)
	sizeConstraint.MaxSize = Vector2.new(900, 720)
	sizeConstraint.Parent = panel

	local pad = Instance.new("UIPadding")
	local inset = ContentConfig.ui.touchSafeInsetScale
	pad.PaddingTop = UDim.new(inset * 0.5, 8)
	pad.PaddingBottom = UDim.new(inset * 0.5, 8)
	pad.PaddingLeft = UDim.new(inset * 0.5, 8)
	pad.PaddingRight = UDim.new(inset * 0.5, 8)
	pad.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.06, 0.04)
	title.Size = UDim2.fromScale(0.88, 0.1)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(40, 30, 20)
	title.Text = ContentConfig.finalLetterText.title
	title.Parent = panel

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromScale(0.06, 0.16)
	body.Size = UDim2.fromScale(0.88, 0.78)
	body.Font = Enum.Font.Gotham
	body.TextSize = 22
	body.TextScaled = false
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.fromRGB(45, 35, 25)
	body.Text = table.concat(ContentConfig.finalLetterText.body, "\n")
	body.Parent = panel

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = 14
	textConstraint.MaxTextSize = 28
	textConstraint.Parent = body
	body.TextScaled = true

	gui.Enabled = false
	guiRef = gui
	return gui, title, body, panel
end

function LetterPanel.show(includeTwist: boolean)
	local gui, _title, body, panel = ensure()
	-- Dedupe: StoryPresenter also pushes twist via subtitle. Letter body stays
	-- readable without repeating the twist paragraph.
	local _ = includeTwist
	body.Text = table.concat(ContentConfig.finalLetterText.body, "\n")
	gui.Enabled = true

	cancelTween()
	local guiInset = GuiService:GetGuiInset()
	panel.Size = UDim2.fromScale(0.82, 0.72)
	panel.Position = UDim2.new(0.5, 0, 0.5, -guiInset.Y * 0.1)

	if SessionPreferences.shouldSkipMotionEffects() then
		panel.BackgroundTransparency = 0
		return
	end

	panel.BackgroundTransparency = 1
	local tween = TweenService:Create(
		panel,
		TweenInfo.new(SessionPreferences.tweenSeconds(0.35, 0.05)),
		{ BackgroundTransparency = 0 }
	)
	activeTween = tween
	tween:Play()
end

function LetterPanel.hide()
	cancelTween()
	if guiRef then
		guiRef.Enabled = false
	end
end

function LetterPanel.reset()
	LetterPanel.hide()
end

return LetterPanel
