--!strict
--[[
	Graceful fallbacks when ContentConfig asset IDs are missing or fail to load.
	Use from Audio / UI presentation paths — never throw on missing creator media.
]]

local ContentAssetFallback = {}

local PLACEHOLDER = "rbxassetid://0"

function ContentAssetFallback.placeholderId(): string
	return PLACEHOLDER
end

function ContentAssetFallback.normalizeSoundId(soundId: string?): string
	if soundId == nil or soundId == "" or soundId == "0" or soundId == PLACEHOLDER then
		return PLACEHOLDER
	end
	if not string.find(soundId, "rbxassetid://", 1, true) and tonumber(soundId) then
		return `rbxassetid://{soundId}`
	end
	return soundId
end

function ContentAssetFallback.normalizeImageId(imageId: string?): string
	if imageId == nil or imageId == "" or imageId == "0" or imageId == PLACEHOLDER then
		return PLACEHOLDER
	end
	if not string.find(imageId, "rbxassetid://", 1, true) and tonumber(imageId) then
		return `rbxassetid://{imageId}`
	end
	return imageId
end

function ContentAssetFallback.normalizeAnimationId(animationId: string?): string
	return ContentAssetFallback.normalizeSoundId(animationId)
end

function ContentAssetFallback.isMissing(assetId: string?): boolean
	local id = ContentAssetFallback.normalizeSoundId(assetId)
	return id == PLACEHOLDER
end

function ContentAssetFallback.applyImage(
	imageLabel: ImageLabel,
	imageId: string?,
	fallbackVisible: boolean?
): boolean
	local id = ContentAssetFallback.normalizeImageId(imageId)
	if ContentAssetFallback.isMissing(id) then
		imageLabel.Image = ""
		imageLabel.Visible = fallbackVisible ~= false
		return false
	end

	local ok = pcall(function()
		imageLabel.Image = id
	end)
	if not ok then
		imageLabel.Image = ""
		return false
	end
	return true
end

function ContentAssetFallback.applySound(sound: Sound, soundId: string?): boolean
	local id = ContentAssetFallback.normalizeSoundId(soundId)
	if ContentAssetFallback.isMissing(id) then
		sound.SoundId = ""
		sound.Volume = 0
		return false
	end
	local ok = pcall(function()
		sound.SoundId = id
	end)
	return ok
end

return ContentAssetFallback
