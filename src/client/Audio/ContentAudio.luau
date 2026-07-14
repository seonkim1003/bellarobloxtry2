--!strict
--[[
	Content audio helpers with graceful fallback when asset IDs fail to load.
]]

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()

local ContentAudio = {}

local group = Instance.new("SoundGroup")
group.Name = "ContentAudio"
group.Volume = 1
group.Parent = SoundService

local ambienceFolder = Instance.new("Folder")
ambienceFolder.Name = "ContentAmbience"
ambienceFolder.Parent = SoundService

local activeAmbience: Sound? = nil

local function isPlaceholderId(soundId: string): boolean
	return soundId == "" or soundId == "rbxassetid://0" or soundId == "0"
end

function ContentAudio.safePlay(soundId: string, volume: number?, parent: Instance?): Sound?
	if isPlaceholderId(soundId) then
		-- Placeholder: no audible asset yet; still return a silent Sound for timing APIs.
		local silent = Instance.new("Sound")
		silent.Name = "ContentSilentPlaceholder"
		silent.SoundId = ""
		silent.Volume = 0
		silent.Parent = parent or SoundService
		Debris:AddItem(silent, 2)
		return silent
	end

	local sound = Instance.new("Sound")
	sound.Name = "ContentOneShot"
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.SoundGroup = group
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

function ContentAudio.playEntry(
	entry: { soundId: string, volume: number, looped: boolean },
	parent: Instance?
): Sound?
	return ContentAudio.safePlay(entry.soundId, entry.volume, parent)
end

function ContentAudio.setAmbience(entry: { soundId: string, volume: number, looped: boolean })
	if activeAmbience then
		activeAmbience:Stop()
		activeAmbience:Destroy()
		activeAmbience = nil
	end

	if isPlaceholderId(entry.soundId) then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "Ambience"
	sound.SoundId = entry.soundId
	sound.Volume = entry.volume
	sound.Looped = entry.looped
	sound.SoundGroup = group
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

function ContentAudio.ambienceForScene(sceneId: string)
	if sceneId == "Lobby" or sceneId == "Epilogue" then
		ContentAudio.setAmbience(ContentConfig.sounds.ambienceLobby)
	elseif sceneId == "Maze" then
		ContentAudio.setAmbience(ContentConfig.sounds.ambienceMaze)
	elseif sceneId == "Tower" then
		ContentAudio.setAmbience(ContentConfig.sounds.ambienceTower)
	elseif sceneId == "Field" then
		ContentAudio.setAmbience(ContentConfig.sounds.ambienceField)
	end
end

function ContentAudio.reset()
	if activeAmbience then
		activeAmbience:Stop()
		activeAmbience:Destroy()
		activeAmbience = nil
	end
end

return ContentAudio
