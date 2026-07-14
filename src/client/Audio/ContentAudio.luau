--!strict
--[[
	Content audio helpers with graceful fallback when asset IDs fail to load.
	Music + SFX groups, ambience crossfade, ducking, and scene helpers.
]]

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()
local AssetFallback =
	require(script.Parent.Parent:WaitForChild("Content"):WaitForChild("AssetFallback"))

local ContentAudio = {}

export type SoundEntry = {
	soundId: string,
	volume: number,
	looped: boolean,
}

local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "ContentMusic"
musicGroup.Volume = 1
musicGroup.Parent = SoundService

local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "ContentSfx"
sfxGroup.Volume = 1
sfxGroup.Parent = SoundService

local ambienceFolder = Instance.new("Folder")
ambienceFolder.Name = "ContentAmbience"
ambienceFolder.Parent = SoundService

local musicFolder = Instance.new("Folder")
musicFolder.Name = "ContentMusicBeds"
musicFolder.Parent = SoundService

local activeAmbience: Sound? = nil
local activeMusic: Sound? = nil
local activeTension: Sound? = nil
local ambienceFadeGeneration = 0
local musicDuckGeneration = 0
local musicBaseVolume = 1
local CROSSFADE_SECONDS = 0.85

local function isPlaceholderId(soundId: string): boolean
	return AssetFallback.isMissing(soundId)
end

local function tweenVolume(sound: Sound, targetVolume: number, seconds: number, onDone: (() -> ())?)
	if seconds <= 0 then
		sound.Volume = targetVolume
		if onDone then
			onDone()
		end
		return
	end
	local tween = TweenService:Create(
		sound,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = targetVolume }
	)
	if onDone then
		tween.Completed:Once(function()
			onDone()
		end)
	end
	tween:Play()
end

local function destroySound(sound: Sound?)
	if sound == nil then
		return
	end
	pcall(function()
		sound:Stop()
	end)
	sound:Destroy()
end

function ContentAudio.safePlay(
	soundId: string,
	volume: number?,
	parent: Instance?,
	asMusic: boolean?
): Sound?
	local normalized = AssetFallback.normalizeSoundId(soundId)
	if isPlaceholderId(normalized) then
		local silent = Instance.new("Sound")
		silent.Name = "ContentSilentPlaceholder"
		silent.SoundId = ""
		silent.Volume = 0
		silent.Parent = parent or SoundService
		Debris:AddItem(silent, 2)
		return silent
	end

	local sound = Instance.new("Sound")
	sound.Name = if asMusic then "ContentMusicOneShot" else "ContentOneShot"
	AssetFallback.applySound(sound, normalized)
	sound.Volume = volume or 0.5
	sound.SoundGroup = if asMusic then musicGroup else sfxGroup
	sound.Parent = parent or SoundService

	local played = false
	local ok, err = pcall(function()
		sound:Play()
		played = true
	end)
	if not ok then
		warn(`[ContentAudio] Failed to play {soundId}: {err}`)
		sound:Destroy()
		return nil
	end

	if played then
		Debris:AddItem(sound, math.max(sound.TimeLength + 0.5, 2))
	end
	return sound
end

function ContentAudio.playEntry(entry: SoundEntry, parent: Instance?, asMusic: boolean?): Sound?
	return ContentAudio.safePlay(entry.soundId, entry.volume, parent, asMusic)
end

function ContentAudio.setAmbience(entry: SoundEntry)
	ambienceFadeGeneration += 1
	local previous = activeAmbience
	activeAmbience = nil

	if previous then
		tweenVolume(previous, 0, CROSSFADE_SECONDS, function()
			if previous.Parent then
				destroySound(previous)
			end
		end)
	end

	local normalized = AssetFallback.normalizeSoundId(entry.soundId)
	if isPlaceholderId(normalized) then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "Ambience"
	AssetFallback.applySound(sound, normalized)
	sound.Volume = 0
	sound.Looped = entry.looped
	sound.SoundGroup = musicGroup
	sound.Parent = ambienceFolder

	local ok, err = pcall(function()
		sound:Play()
	end)
	if not ok then
		warn(`[ContentAudio] Ambience failed: {err}`)
		sound:Destroy()
		return
	end

	activeAmbience = sound
	tweenVolume(sound, entry.volume, CROSSFADE_SECONDS)
end

function ContentAudio.setMusicBed(entry: SoundEntry?)
	destroySound(activeMusic)
	activeMusic = nil
	if entry == nil then
		return
	end

	local normalized = AssetFallback.normalizeSoundId(entry.soundId)
	if isPlaceholderId(normalized) then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "MusicBed"
	AssetFallback.applySound(sound, normalized)
	sound.Volume = 0
	sound.Looped = entry.looped
	sound.SoundGroup = musicGroup
	sound.Parent = musicFolder

	local ok, err = pcall(function()
		sound:Play()
	end)
	if not ok then
		warn(`[ContentAudio] Music bed failed: {err}`)
		sound:Destroy()
		return
	end

	activeMusic = sound
	tweenVolume(sound, entry.volume, CROSSFADE_SECONDS)
end

function ContentAudio.setChaseTension(active: boolean)
	if not active then
		local tension = activeTension
		activeTension = nil
		if tension then
			tweenVolume(tension, 0, 0.45, function()
				destroySound(tension)
			end)
		end
		ContentAudio.restoreMusic(0.45)
		return
	end

	if activeTension and activeTension.Parent then
		ContentAudio.duckMusic(0.45, 0.35)
		return
	end

	local entry = ContentConfig.sounds.chaseTension
	local normalized = AssetFallback.normalizeSoundId(entry.soundId)
	if isPlaceholderId(normalized) then
		ContentAudio.duckMusic(0.45, 0.35)
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "ChaseTension"
	AssetFallback.applySound(sound, normalized)
	sound.Volume = 0
	sound.Looped = entry.looped
	sound.SoundGroup = musicGroup
	sound.Parent = musicFolder

	local ok = pcall(function()
		sound:Play()
	end)
	if not ok then
		sound:Destroy()
		ContentAudio.duckMusic(0.45, 0.35)
		return
	end

	activeTension = sound
	ContentAudio.duckMusic(0.45, 0.35)
	tweenVolume(sound, entry.volume, 0.5)
end

function ContentAudio.duckMusic(factor: number, seconds: number?)
	musicDuckGeneration += 1
	local generation = musicDuckGeneration
	local target = math.clamp(factor, 0, 1)
	local duration = seconds or 0.35
	TweenService:Create(
		musicGroup,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = musicBaseVolume * target }
	):Play()
	task.delay(duration + 0.05, function()
		if musicDuckGeneration ~= generation then
			return
		end
		musicGroup.Volume = musicBaseVolume * target
	end)
end

function ContentAudio.restoreMusic(seconds: number?)
	musicDuckGeneration += 1
	local generation = musicDuckGeneration
	local duration = seconds or 0.45
	TweenService:Create(
		musicGroup,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = musicBaseVolume }
	):Play()
	task.delay(duration + 0.05, function()
		if musicDuckGeneration ~= generation then
			return
		end
		musicGroup.Volume = musicBaseVolume
	end)
end

function ContentAudio.playChaseSting()
	ContentAudio.playEntry(ContentConfig.sounds.chaseSting)
end

function ContentAudio.playFragmentPickup()
	ContentAudio.playEntry(ContentConfig.sounds.fragmentPickup)
end

function ContentAudio.playDogFightImpact()
	ContentAudio.playEntry(ContentConfig.sounds.dogFightImpact)
end

function ContentAudio.playUiClick()
	ContentAudio.playEntry(ContentConfig.sounds.uiClick)
end

function ContentAudio.playUiConfirm()
	ContentAudio.playEntry(ContentConfig.sounds.uiConfirm)
end

function ContentAudio.playStinger()
	ContentAudio.playEntry(ContentConfig.sounds.stateTransition)
end

function ContentAudio.playCorruptionSting()
	ContentAudio.playEntry(ContentConfig.sounds.corruptionSting)
end

function ContentAudio.playCinematicCue(kind: string)
	if kind == "grab" then
		ContentAudio.playEntry(ContentConfig.sounds.kidnapGrab)
	elseif kind == "drag" then
		ContentAudio.playEntry(ContentConfig.sounds.kidnapDrag)
	elseif kind == "corruption" then
		ContentAudio.playCorruptionSting()
	else
		ContentAudio.playEntry(ContentConfig.sounds.cinematicWhoosh)
	end
end

function ContentAudio.playDogFightBeat(beatId: string)
	if beatId == "Establish" or beatId == "RamboStalk" or beatId == "AttackTelegraph" then
		ContentAudio.playEntry(ContentConfig.sounds.cinematicWhoosh)
	elseif beatId == "FirstClash" or beatId == "RamboAdvantage" then
		ContentAudio.playEntry(ContentConfig.sounds.dogFightClash)
	elseif beatId == "GigiVictory" then
		ContentAudio.playEntry(ContentConfig.sounds.dogFightVictory)
	else
		ContentAudio.playEntry(ContentConfig.sounds.dogFightImpact)
	end
end

function ContentAudio.playLetterOpen()
	ContentAudio.playEntry(ContentConfig.sounds.letterOpen)
end

function ContentAudio.playRespawn()
	ContentAudio.playEntry(ContentConfig.sounds.respawnSoft)
end

function ContentAudio.ambienceForScene(sceneId: string)
	ContentAudio.setMusicBed(nil)
	if sceneId == "Lobby" then
		ContentAudio.setAmbience(ContentConfig.sounds.ambienceLobby)
	elseif sceneId == "Epilogue" then
		ContentAudio.setAmbience(ContentConfig.sounds.ambienceEpilogue)
	elseif sceneId == "Maze" then
		ContentAudio.setAmbience(ContentConfig.sounds.ambienceMaze)
	elseif sceneId == "Tower" then
		ContentAudio.setAmbience(ContentConfig.sounds.ambienceTower)
	elseif sceneId == "Field" then
		ContentAudio.setAmbience(ContentConfig.sounds.ambienceField)
	elseif sceneId == "Credits" then
		ContentAudio.setAmbience(ContentConfig.sounds.ambienceEpilogue)
		ContentAudio.setMusicBed(ContentConfig.sounds.musicCredits)
	end
end

function ContentAudio.beginCinematic()
	ContentAudio.setChaseTension(false)
	ContentAudio.duckMusic(0.28, 0.3)
end

function ContentAudio.endCinematic()
	ContentAudio.restoreMusic(0.5)
end

function ContentAudio.reset()
	ambienceFadeGeneration += 1
	musicDuckGeneration += 1
	ContentAudio.setChaseTension(false)
	destroySound(activeAmbience)
	activeAmbience = nil
	destroySound(activeMusic)
	activeMusic = nil
	musicGroup.Volume = musicBaseVolume
	sfxGroup.Volume = 1
end

return ContentAudio
