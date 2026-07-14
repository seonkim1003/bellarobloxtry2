--!strict
--[[
	DogFight presentation director: hard camera cuts, puppet beats, reduced motion.
	Replaces SilhouetteStage. Combines client timeline playback with FightBeat sync.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local SessionPreferences =
	require(script.Parent.Parent:WaitForChild("Controls"):WaitForChild("SessionPreferences"))
local DogPuppet = require(script.Parent.Parent:WaitForChild("NPCs"):WaitForChild("DogPuppet"))

local ContentConfig = SharedAccess.requireContentConfig()
local DogFightTimeline = (require :: any)(
	SharedAccess.getSharedFolder(5):WaitForChild("DogFightTimeline")
)

local DogFightPresenter = {}
DogFightPresenter.__index = DogFightPresenter

export type DogFightPresenter = typeof(setmetatable(
	{} :: DogFightPresenterInternal,
	DogFightPresenter
))

type DogFightPresenterInternal = {
	_puppet: DogPuppet.DogPuppet,
	_cinematics: any,
	_audio: any,
	_subtitle: ((string?, string) -> ())?,
	_clearSubtitle: (() -> ())?,
	_generation: number,
	_fightGeneration: number,
	_storyRevision: number,
	_playing: boolean,
	_completedBeats: { [number]: boolean },
	_cameraConnection: RBXScriptConnection?,
	_activeCleanup: (() -> ())?,
	_onComplete: (() -> ())?,
	_restoredOnce: boolean,
}

local function findMarker(markerId: string): BasePart?
	for _, tagged in CollectionService:GetTagged("CinematicMarker") do
		if tagged:IsA("BasePart") and tagged:GetAttribute("MarkerId") == markerId then
			return tagged
		end
	end
	return nil
end

local function findDialogue(subtitleId: string?): (string?, string?)
	if subtitleId == nil then
		return nil, nil
	end
	for _, entry in ContentConfig.dialogue.dogFight do
		if entry.id == subtitleId then
			return entry.speaker, entry.text
		end
	end
	return nil, nil
end

function DogFightPresenter.new(cinematics: any, audio: any): DogFightPresenter
	return setmetatable({
		_puppet = DogPuppet.new(),
		_cinematics = cinematics,
		_audio = audio,
		_subtitle = nil,
		_clearSubtitle = nil,
		_generation = 0,
		_fightGeneration = 0,
		_storyRevision = 0,
		_playing = false,
		_completedBeats = {},
		_cameraConnection = nil,
		_activeCleanup = nil,
		_onComplete = nil,
		_restoredOnce = false,
	}, DogFightPresenter)
end

function DogFightPresenter.bindSubtitles(
	self: DogFightPresenter,
	setSubtitle: (string?, string) -> (),
	clearSubtitle: () -> ()
)
	self._subtitle = setSubtitle
	self._clearSubtitle = clearSubtitle
end

function DogFightPresenter._stopCamera(self: DogFightPresenter)
	local conn = self._cameraConnection
	self._cameraConnection = nil
	if conn then
		conn:Disconnect()
	end
end

function DogFightPresenter._stillCurrent(self: DogFightPresenter, generation: number): boolean
	return self._generation == generation
end

function DogFightPresenter._hardCut(self: DogFightPresenter, markerId: string, beatId: string)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local marker = findMarker(markerId)
	local focus = if marker then marker.CFrame else self._puppet:getFocusCFrame(beatId)
	if focus == nil then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	-- Authored markers store the full look CFrame; fall back to lookAt when needed.
	if marker then
		camera.CFrame = marker.CFrame
	else
		camera.CFrame = focus
	end
end

function DogFightPresenter._finishOnce(self: DogFightPresenter, generation: number)
	if not self:_stillCurrent(generation) or self._restoredOnce then
		return
	end
	self._restoredOnce = true
	self._playing = false
	self:_stopCamera()
	self._puppet:clear()
	if self._audio and self._audio.endCinematic then
		self._audio.endCinematic()
	end
	if self._clearSubtitle then
		self._clearSubtitle()
	end
	local onComplete = self._onComplete
	self._onComplete = nil
	self._activeCleanup = nil
	if onComplete then
		onComplete()
	end
end

function DogFightPresenter._playBeat(
	self: DogFightPresenter,
	beat: any,
	generation: number,
	reducedMotion: boolean
)
	if not self:_stillCurrent(generation) then
		return
	end
	if self._completedBeats[beat.beatIndex] then
		return
	end
	self._completedBeats[beat.beatIndex] = true

	self:_hardCut(beat.cameraMarkerId, beat.beatId)
	self._puppet:beginBeat(beat.beatId, beat.durationSeconds, reducedMotion)
	if self._audio and self._audio.playDogFightBeat then
		self._audio.playDogFightBeat(beat.beatId)
	end

	local speaker, text = findDialogue(beat.subtitleId)
	if text and self._subtitle then
		self._subtitle(speaker, text)
	elseif self._clearSubtitle then
		self._clearSubtitle()
	end
end

function DogFightPresenter.play(
	self: DogFightPresenter,
	storyRevision: number?,
	onComplete: (() -> ())?
)
	self:cancel()
	self._generation += 1
	local generation = self._generation
	self._storyRevision = if typeof(storyRevision) == "number" then storyRevision else 0
	self._fightGeneration += 1
	self._playing = true
	self._completedBeats = {}
	self._restoredOnce = false
	self._onComplete = onComplete

	self._activeCleanup = function()
		self:_stopCamera()
		self._puppet:clear()
		if self._audio and self._audio.endCinematic then
			self._audio.endCinematic()
		end
		if self._clearSubtitle then
			self._clearSubtitle()
		end
	end

	if self._audio and self._audio.beginCinematic then
		self._audio.beginCinematic()
	end
	if self._audio and self._audio.playDogFightImpact then
		self._audio.playDogFightImpact()
	end

	local prepared = self._puppet:prepare()
	if not self:_stillCurrent(generation) then
		return
	end
	if not prepared then
		warn("[DogFightPresenter] Puppet prepare failed; finishing early")
		self:_finishOnce(generation)
		return
	end

	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local reducedMotion = SessionPreferences.shouldSkipMotionEffects()
	task.spawn(function()
		local ok = pcall(function()
			for _, fightBeat in DogFightTimeline.Beats do
				if not self:_stillCurrent(generation) then
					return
				end
				self:_playBeat(fightBeat, generation, reducedMotion)
				local dwell = DogFightTimeline.durationForBeat(fightBeat, reducedMotion)
				task.wait(dwell)
				if not self:_stillCurrent(generation) then
					return
				end
			end
		end)

		if not ok then
			warn("[DogFightPresenter] Timeline failed")
		end
		if self:_stillCurrent(generation) then
			if not reducedMotion then
				-- Brief camera settle without owning a second restore path.
				task.wait(0.15)
			end
			self:_finishOnce(generation)
		end
	end)
end

function DogFightPresenter.applyFightBeat(self: DogFightPresenter, payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	if not self._playing then
		return
	end
	local beatIndex = payload.beatIndex
	local beatId = payload.beatId
	if typeof(beatIndex) ~= "number" or typeof(beatId) ~= "string" then
		return
	end
	if
		typeof(payload.fightGeneration) == "number"
		and payload.fightGeneration < self._fightGeneration
	then
		return
	end
	if
		typeof(payload.storyRevision) == "number"
		and payload.storyRevision ~= self._storyRevision
	then
		return
	end
	local beat = DogFightTimeline.getBeat(beatIndex)
	if beat == nil or beat.beatId ~= beatId then
		return
	end
	local reducedMotion = SessionPreferences.shouldSkipMotionEffects()
	self:_playBeat(beat, self._generation, reducedMotion)
end

function DogFightPresenter.cancel(self: DogFightPresenter)
	self._generation += 1
	self._playing = false
	self._onComplete = nil
	local cleanup = self._activeCleanup
	self._activeCleanup = nil
	self:_stopCamera()
	if cleanup then
		pcall(cleanup)
	else
		self._puppet:clear()
	end
	self._restoredOnce = true
	self._completedBeats = {}
end

function DogFightPresenter.clear(self: DogFightPresenter)
	self:cancel()
end

-- Compatibility shim for StoryPresenter paths that previously called SilhouetteStage.mount()
function DogFightPresenter.mount(self: DogFightPresenter): Folder?
	if not self._puppet:isReady() then
		self._puppet:prepare()
	end
	return Workspace:FindFirstChild("ContentDogFight") :: Folder?
end

return DogFightPresenter
