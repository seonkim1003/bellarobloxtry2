--!strict
--[[
	Graceful fallbacks when ContentConfig asset IDs are missing or fail to load.
]]

local ContentAssetFallback = {}

local PLACEHOLDER = "rbxassetid://0"

function ContentAssetFallback.normalizeSoundId(soundId: string?): string
	if soundId == nil or soundId == "" or soundId == "0" then
		return PLACEHOLDER
	end
	return soundId
end

function ContentAssetFallback.normalizeImageId(imageId: string?): string
	if imageId == nil or imageId == "" or imageId == "0" then
		return PLACEHOLDER
	end
	return imageId
end

function ContentAssetFallback.isMissing(assetId: string?): boolean
	local id = ContentAssetFallback.normalizeSoundId(assetId)
	return id == PLACEHOLDER
end

function ContentAssetFallback.applyImage(
	imageLabel: ImageLabel,
	imageId: string?,
	fallbackVisible: boolean?
)
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

return ContentAssetFallback
