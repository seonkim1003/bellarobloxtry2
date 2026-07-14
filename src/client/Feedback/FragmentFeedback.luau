--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()
local ContentAudio =
	require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("ContentAudio"))

local FragmentFeedback = {}

local function getFragmentLabel(): TextLabel?
	local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if gui == nil then
		return nil
	end
	local hud = gui:FindFirstChild("ContentHud")
	if hud == nil then
		return nil
	end
	local label = hud:FindFirstChild("Fragments")
	if label and label:IsA("TextLabel") then
		return label
	end
	return nil
end

function FragmentFeedback.pulse(collected: number, total: number)
	ContentAudio.playFragmentPickup()
	local label = getFragmentLabel()
	if label == nil then
		return
	end
	label.Text = `{ContentConfig.ui.fragmentLabel}: {collected} / {total}`
	label.Visible = true
	label.TextColor3 = Color3.fromRGB(255, 230, 120)
	local tween = TweenService:Create(
		label,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextColor3 = Color3.fromRGB(245, 245, 245), TextSize = label.TextSize }
	)
	tween:Play()
end

return FragmentFeedback
