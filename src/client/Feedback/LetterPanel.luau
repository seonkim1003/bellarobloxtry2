--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()

local LetterPanel = {}

local guiRef: ScreenGui? = nil

local function ensure(): (ScreenGui, TextLabel, TextLabel)
	if guiRef then
		local title = guiRef:FindFirstChild("Title") :: TextLabel
		local body = guiRef:FindFirstChild("Body") :: TextLabel
		return guiRef, title, body
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "ContentLetter"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.7, 0.62)
	panel.BackgroundColor3 = Color3.fromRGB(235, 225, 200)
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.08, 0.06)
	title.Size = UDim2.fromScale(0.84, 0.12)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(40, 30, 20)
	title.Text = ContentConfig.finalLetterText.title
	title.Parent = panel

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromScale(0.08, 0.2)
	body.Size = UDim2.fromScale(0.84, 0.7)
	body.Font = Enum.Font.Gotham
	body.TextScaled = true
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.fromRGB(45, 35, 25)
	body.Text = table.concat(ContentConfig.finalLetterText.body, "\n")
	body.Parent = panel

	gui.Enabled = false
	guiRef = gui
	return gui, title, body
end

function LetterPanel.show(includeTwist: boolean)
	local gui, _title, body = ensure()
	local text = table.concat(ContentConfig.finalLetterText.body, "\n")
	if includeTwist then
		text ..= "\n\n" .. ContentConfig.finalLetterText.twist
	end
	body.Text = text
	gui.Enabled = true
	local panel = gui:FindFirstChild("Panel")
	if panel and panel:IsA("Frame") then
		panel.BackgroundTransparency = 1
		TweenService:Create(panel, TweenInfo.new(0.35), { BackgroundTransparency = 0 }):Play()
	end
end

function LetterPanel.hide()
	if guiRef then
		guiRef.Enabled = false
	end
end

function LetterPanel.reset()
	LetterPanel.hide()
end

return LetterPanel
