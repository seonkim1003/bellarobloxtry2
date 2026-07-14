--!strict
--[[
	First-person cinematic runner with fade + camera restore.
	Uses a generation token so reset/replay/overlapping cues cannot complete stale work.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()
local SessionPreferences =
	require(script.Parent.Parent:WaitForChild("Controls"):WaitForChild("SessionPreferences"))

type DialogueLine = {
	id: string,
	speaker: string,
	text: string,
	durationSeconds: number,
}

export type SubtitleSink = (speaker: string?, text: string) -> ()
export type ClearSubtitle = () -> ()

type CinematicInternal = {
	_playing: boolean,
	_generation: number,
	_fadeGui: ScreenGui?,
	_fadeFrame: Frame?,
	_savedCameraType: Enum.CameraType?,
	_savedCameraCFrame: CFrame?,
	_subtitle: SubtitleSink?,
	_clearSubtitle: ClearSubtitle?,
	_shakeConnection: RBXScriptConnection?,
}

local CinematicPlayer = {}
CinematicPlayer.__index = CinematicPlayer

export type CinematicPlayer = typeof(setmetatable({} :: CinematicInternal, CinematicPlayer))

local function findDialogue(subtitleId: string?): (string?, string?)
	if subtitleId == nil then
		return nil, nil
	end

	local packs: { { DialogueLine } } = {
		ContentConfig.dialogue.lobby,
		ContentConfig.dialogue.mazeIntro,
		ContentConfig.dialogue.bellaChase,
		ContentConfig.dialogue.robberGuide,
		ContentConfig.dialogue.revive,
		ContentConfig.dialogue.corruption,
		ContentConfig.dialogue.fieldHunt,
		ContentConfig.dialogue.letterTheft,
		ContentConfig.dialogue.dogFight,
		ContentConfig.dialogue.epilogue,
		ContentConfig.dialogue.letterReveal,
	}

	for _, pack in packs do
		for _, entry in pack do
			if entry.id == subtitleId then
				return entry.speaker, entry.text
			end
		end
	end
	return nil, nil
end

local function findMarker(markerId: string): BasePart?
	for _, tagged in CollectionService:GetTagged("CinematicMarker") do
		if tagged:IsA("BasePart") and tagged:GetAttribute("MarkerId") == markerId then
			return tagged
		end
	end
	for _, tagged in CollectionService:GetTagged("MazeExit") do
		if tagged:IsA("BasePart") and markerId == "KidnapStart" then
			return tagged
		end
	end
	return nil
end

function CinematicPlayer.new(): CinematicPlayer
	return setmetatable({
		_playing = false,
		_generation = 0,
		_fadeGui = nil :: ScreenGui?,
		_fadeFrame = nil :: Frame?,
		_savedCameraType = nil :: Enum.CameraType?,
		_savedCameraCFrame = nil :: CFrame?,
		_subtitle = nil :: SubtitleSink?,
		_clearSubtitle = nil :: ClearSubtitle?,
		_shakeConnection = nil :: RBXScriptConnection?,
	}, CinematicPlayer)
end

function CinematicPlayer.bindSubtitles(
	self: CinematicPlayer,
	setSubtitle: SubtitleSink,
	clearSubtitle: ClearSubtitle
)
	self._subtitle = setSubtitle
	self._clearSubtitle = clearSubtitle
end

function CinematicPlayer._ensureFade(self: CinematicPlayer)
	if self._fadeGui then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "ContentCinematicFade"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Fade"
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	self._fadeGui = gui
	self._fadeFrame = frame
end

function CinematicPlayer._stopShake(self: CinematicPlayer)
	local conn = self._shakeConnection
	self._shakeConnection = nil
	if conn ~= nil then
		pcall(function()
			conn:Disconnect()
		end)
	end
end

function CinematicPlayer._stillCurrent(self: CinematicPlayer, selfGeneration: number): boolean
	return self._generation == selfGeneration
end

function CinematicPlayer._tweenFade(
	self: CinematicPlayer,
	transparency: number,
	duration: number,
	selfGeneration: number
)
	if not self:_stillCurrent(selfGeneration) then
		return
	end
	if SessionPreferences.shouldSkipMotionEffects() then
		self:_ensureFade()
		local frame = self._fadeFrame
		if frame then
			frame.BackgroundTransparency = transparency
		end
		return
	end
	self:_ensureFade()
	local frame = self._fadeFrame
	if frame == nil then
		return
	end
	local tween = TweenService:Create(
		frame,
		TweenInfo.new(math.max(duration, 0.01), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = transparency }
	)
	tween:Play()
	tween.Completed:Wait()
end

function CinematicPlayer._lockCamera(self: CinematicPlayer, target: CFrame)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	if self._savedCameraType == nil then
		self._savedCameraType = camera.CameraType
		self._savedCameraCFrame = camera.CFrame
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = target
end

function CinematicPlayer._restoreCamera(self: CinematicPlayer)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	if self._savedCameraType then
		camera.CameraType = self._savedCameraType
	else
		camera.CameraType = Enum.CameraType.Custom
	end
	if self._savedCameraCFrame then
		camera.CFrame = self._savedCameraCFrame
	end
	self._savedCameraType = nil
	self._savedCameraCFrame = nil
end

function CinematicPlayer.isPlaying(self: CinematicPlayer): boolean
	return self._playing
end

function CinematicPlayer._beginPlayback(self: CinematicPlayer): number
	self:_stopShake()
	local nextGeneration = self._generation + 1
	self._generation = nextGeneration
	self._playing = true
	return nextGeneration
end

function CinematicPlayer.playSequence(
	self: CinematicPlayer,
	sequenceName: string,
	onComplete: (() -> ())?
)
	local steps = ContentConfig.cinematics[sequenceName]
	if steps == nil then
		warn(`[Cinematic] Unknown sequence {sequenceName}`)
		if onComplete then
			onComplete()
		end
		return
	end

	local generation = self:_beginPlayback()
	task.spawn(function()
		for _, step in steps do
			if not self:_stillCurrent(generation) then
				return
			end
			self:_tweenFade(0, step.fadeInSeconds, generation)
			if not self:_stillCurrent(generation) then
				return
			end

			local marker = findMarker(step.markerId)
			if marker then
				local look = marker.CFrame * CFrame.new(0, 1.5, 4)
				self:_lockCamera(
					CFrame.lookAt(look.Position, marker.Position + Vector3.new(0, 1.5, 0))
				)
			end

			local speaker, text = findDialogue(step.subtitleId)
			if text and self._subtitle then
				self._subtitle(speaker, text)
			end

			self:_tweenFade(1, math.min(step.fadeOutSeconds, 0.35), generation)
			if not self:_stillCurrent(generation) then
				return
			end
			task.wait(
				math.max(step.durationSeconds - step.fadeInSeconds - step.fadeOutSeconds, 0.2)
			)
			if not self:_stillCurrent(generation) then
				return
			end

			if self._clearSubtitle then
				self._clearSubtitle()
			end
			self:_tweenFade(0, 0, generation)
			self:_tweenFade(1, step.fadeOutSeconds, generation)
		end

		if not self:_stillCurrent(generation) then
			return
		end
		self:_restoreCamera()
		self:_tweenFade(1, 0.2, generation)
		if not self:_stillCurrent(generation) then
			return
		end
		self._playing = false
		if onComplete then
			onComplete()
		end
	end)
end

function CinematicPlayer.playDogFightSilhouette(self: CinematicPlayer, onComplete: (() -> ())?)
	self:playSequence("dogFight", function()
		if SessionPreferences.shouldSkipMotionEffects() then
			if onComplete then
				onComplete()
			end
			return
		end

		local generation = self._generation
		local t0 = os.clock()
		self:_stopShake()
		self._shakeConnection = RunService.RenderStepped:Connect(function()
			if not self:_stillCurrent(generation) or os.clock() - t0 > 0.8 then
				self:_stopShake()
				return
			end
			local cam = workspace.CurrentCamera
			if cam and cam.CameraType == Enum.CameraType.Custom then
				local shake = math.sin(os.clock() * 40) * 0.05
				cam.CFrame = cam.CFrame * CFrame.new(shake, 0, 0)
			end
		end)

		task.delay(0.8, function()
			self:_stopShake()
			if self:_stillCurrent(generation) and onComplete then
				onComplete()
			end
		end)
	end)
end

function CinematicPlayer.reset(self: CinematicPlayer)
	self:_stopShake()
	self._generation = self._generation + 1
	self._playing = false
	self:_restoreCamera()
	if self._fadeFrame then
		self._fadeFrame.BackgroundTransparency = 1
	end
	if self._clearSubtitle then
		self._clearSubtitle()
	end
end

return CinematicPlayer
