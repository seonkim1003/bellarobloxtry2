--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()
local ContentAudio =
	require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("ContentAudio"))
local SessionPreferences =
	require(script.Parent.Parent:WaitForChild("Controls"):WaitForChild("SessionPreferences"))

local FragmentFeedback = {}

local activeTween: Tween? = nil

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

local function cancelActiveTween()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
end

function FragmentFeedback.pulse(collected: number, total: number)
	ContentAudio.playFragmentPickup()
	local label = getFragmentLabel()
	if label == nil then
		return
	end

	cancelActiveTween()

	local remaining = math.max(total - collected, 0)
	label.Text = `{ContentConfig.ui.fragmentLabel}: {collected} / {total}  ({remaining} left) ★`
	label.Visible = true
	label.TextColor3 = Color3.fromRGB(255, 230, 120)

	if SessionPreferences.shouldSkipMotionEffects() then
		label.TextColor3 = Color3.fromRGB(245, 245, 245)
		label.Text = `{ContentConfig.ui.fragmentLabel}: {collected} / {total}  ({remaining} left)`
		return
	end

	local duration = SessionPreferences.tweenSeconds(0.45, 0.05)
	local tween = TweenService:Create(
		label,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextColor3 = Color3.fromRGB(245, 245, 245) }
	)
	activeTween = tween
	tween.Completed:Connect(function()
		if activeTween == tween then
			activeTween = nil
			label.Text =
				`{ContentConfig.ui.fragmentLabel}: {collected} / {total}  ({remaining} left)`
		end
	end)
	tween:Play()
end

function FragmentFeedback.reset()
	cancelActiveTween()
end

return FragmentFeedback
