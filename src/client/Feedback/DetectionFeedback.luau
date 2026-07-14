--!strict
--[[
	Rambo detection / chase presentation: vignette + sting + text threat state.
	Respects SessionPreferences reduced motion (skips / softens vignette pulses).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ContentAudio =
	require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("ContentAudio"))
local SessionPreferences =
	require(script.Parent.Parent:WaitForChild("Controls"):WaitForChild("SessionPreferences"))

local DetectionFeedback = {}

local vignette: Frame? = nil
local statusLabel: TextLabel? = nil
local activeTween: Tween? = nil

local function cancelTween()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
end

local function setStatus(text: string, color: Color3)
	if statusLabel then
		statusLabel.Visible = text ~= ""
		statusLabel.Text = text
		statusLabel.TextColor3 = color
	end
	-- Also mirror into ContentHud ThreatState when present.
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui == nil then
		return
	end
	local hud = playerGui:FindFirstChild("ContentHud")
	if hud == nil then
		return
	end
	local threat = hud:FindFirstChild("ThreatState")
	if threat and threat:IsA("TextLabel") then
		threat.Visible = text ~= ""
		threat.Text = text
		threat.TextColor3 = color
	end
end

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

	local label = Instance.new("TextLabel")
	label.Name = "ThreatStatus"
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 8, 8)
	label.Size = UDim2.fromScale(0.42, 0.05)
	label.Position = UDim2.fromScale(0.29, 0.14)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 200)
	label.Visible = false
	label.Text = ""
	label.Parent = gui

	vignette = frame
	statusLabel = label
	return frame
end

local function playFade(
	frame: Frame,
	fromTransparency: number,
	toTransparency: number,
	seconds: number
)
	cancelTween()
	frame.BackgroundTransparency = fromTransparency
	if SessionPreferences.shouldSkipMotionEffects() then
		-- Instant soft flash only — no lingering pulse.
		frame.BackgroundTransparency = math.max(toTransparency, 0.92)
		task.defer(function()
			frame.BackgroundTransparency = 1
		end)
		return
	end
	local duration = SessionPreferences.tweenSeconds(seconds, 0.05)
	local tween = TweenService:Create(
		frame,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = toTransparency }
	)
	activeTween = tween
	tween:Play()
end

function DetectionFeedback.flashDetected()
	ContentAudio.playChaseSting()
	ContentAudio.setChaseTension(true)
	local frame = ensureVignette()
	setStatus("⚠ DETECTED — move", Color3.fromRGB(255, 200, 90))
	playFade(frame, 0.7, 1, 0.7)
end

function DetectionFeedback.showChase(active: boolean)
	local frame = ensureVignette()
	if active then
		setStatus("‼ CHASE — run", Color3.fromRGB(255, 120, 120))
		ContentAudio.playChaseSting()
		ContentAudio.setChaseTension(true)
		local target = if SessionPreferences.shouldSkipMotionEffects() then 0.9 else 0.78
		playFade(frame, frame.BackgroundTransparency, target, 0.35)
	else
		setStatus("● Clear", Color3.fromRGB(160, 220, 160))
		ContentAudio.setChaseTension(false)
		playFade(frame, frame.BackgroundTransparency, 1, 0.35)
		task.delay(1.2, function()
			setStatus("", Color3.fromRGB(255, 255, 255))
		end)
	end
end

function DetectionFeedback.reset()
	cancelTween()
	ContentAudio.setChaseTension(false)
	if vignette then
		vignette.BackgroundTransparency = 1
	end
	setStatus("", Color3.fromRGB(255, 255, 255))
end

return DetectionFeedback
