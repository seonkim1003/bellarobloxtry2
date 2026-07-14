--!strict
--[[
	Rambo detection / chase presentation: vignette + sting (no health mutation).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ContentAudio =
	require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("ContentAudio"))

local DetectionFeedback = {}

local vignette: Frame? = nil

local function ensureVignette(): Frame
	if vignette then
		return vignette
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "ContentDetection"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Vignette"
	frame.BackgroundColor3 = Color3.fromRGB(90, 10, 10)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	vignette = frame
	return frame
end

function DetectionFeedback.flashDetected()
	ContentAudio.playChaseSting()
	local frame = ensureVignette()
	frame.BackgroundTransparency = 0.55
	local tween = TweenService:Create(
		frame,
		TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	tween:Play()
end

function DetectionFeedback.showChase(active: boolean)
	local frame = ensureVignette()
	local target = if active then 0.72 else 1
	TweenService:Create(
		frame,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = target }
	):Play()
	if active then
		ContentAudio.playChaseSting()
	end
end

function DetectionFeedback.reset()
	if vignette then
		vignette.BackgroundTransparency = 1
	end
end

return DetectionFeedback
