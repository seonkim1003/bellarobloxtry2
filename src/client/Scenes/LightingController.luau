--!strict
--[[
	Applies ContentConfig lighting presets (RGB tables to Color3).
]]

local Lighting = game:GetService("Lighting")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()

local LightingController = {}

local function toColor3(rgb: { r: number, g: number, b: number }): Color3
	return Color3.fromRGB(rgb.r, rgb.g, rgb.b)
end

function LightingController.applyScene(sceneId: string)
	local preset = ContentConfig.lighting[sceneId]
	if preset == nil then
		warn(`[Content] No lighting preset for scene {sceneId}`)
		return
	end

	Lighting.Ambient = toColor3(preset.ambient)
	Lighting.OutdoorAmbient = toColor3(preset.outdoorAmbient)
	Lighting.Brightness = preset.brightness
	Lighting.ClockTime = preset.clockTime
	Lighting.FogColor = toColor3(preset.fogColor)
	Lighting.FogStart = preset.fogStart
	Lighting.FogEnd = preset.fogEnd
end

return LightingController
