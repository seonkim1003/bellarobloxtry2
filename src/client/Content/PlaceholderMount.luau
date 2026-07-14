--!strict
--[[
	Runtime mount helpers for placeholder markers.
	Prefer Rojo Workspace.Scenes; this fills gaps if a marker is missing.
]]

local Workspace = game:GetService("Workspace")

local Tagging = require(script.Parent:WaitForChild("Tagging"))
local PlaceholderCatalog = require(script.Parent:WaitForChild("PlaceholderCatalog"))

local PlaceholderMount = {}

local function ensureScenesRoot(): Folder
	local existing = Workspace:FindFirstChild("Scenes")
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = "Scenes"
	folder.Parent = Workspace
	return folder
end

local function ensureSceneFolder(scenesRoot: Folder, sceneId: string): Model
	local existing = scenesRoot:FindFirstChild(sceneId)
	if existing and existing:IsA("Model") then
		return existing
	end

	local model = Instance.new("Model")
	model.Name = sceneId
	model.Parent = scenesRoot
	return model
end

local function makeMarkerPart(name: string, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(2, 2, 2)
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Transparency = 0.35
	return part
end

local SCENE_COLORS: { [string]: Color3 } = {
	Lobby = Color3.fromRGB(120, 160, 220),
	Maze = Color3.fromRGB(90, 60, 140),
	Tower = Color3.fromRGB(180, 140, 80),
	Field = Color3.fromRGB(80, 140, 90),
	Epilogue = Color3.fromRGB(200, 180, 160),
}

function PlaceholderMount.mountMissingMarkers()
	local scenesRoot = ensureScenesRoot()
	local created = 0

	for _, entry in PlaceholderCatalog.getAllObjects() do
		local sceneModel = ensureSceneFolder(scenesRoot, entry.sceneId)
		local existing = sceneModel:FindFirstChild(entry.name)
		if existing == nil then
			local part = makeMarkerPart(
				entry.name,
				SCENE_COLORS[entry.sceneId] or Color3.fromRGB(180, 180, 180)
			)
			part:SetAttribute("ContentPlaceholder", true)
			part.Parent = sceneModel
			Tagging.applyMarker(part, entry.tag, entry.attributes)
			created += 1
		else
			Tagging.applyMarker(existing, entry.tag, entry.attributes)
		end
	end

	return created
end

return PlaceholderMount
