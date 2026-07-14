--!strict
--[[
	Content marketplace asset bootstrap (InsertService must run on the server).
	Loads maps/characters/props from ContentConfig.assets.marketplace.
	Compatible with Agent 1 GameShared and scaffold Shared folder names.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMarkerService =
	require(script.Parent:WaitForChild("Services"):WaitForChild("WorldMarkerService"))

local registeredMarkers = WorldMarkerService.RegisterAuthoredMarkers()
print(`[ContentAssets] Registered {registeredMarkers} authored world markers`)

local templates = ReplicatedStorage:FindFirstChild("ContentModels")
if not templates then
	templates = Instance.new("Folder")
	templates.Name = "ContentModels"
	templates.Parent = ReplicatedStorage
end
templates:SetAttribute("Ready", false)
templates:SetAttribute("MountFailed", false)

local function getSharedFolder(): Folder
	local gameShared = ReplicatedStorage:FindFirstChild("GameShared")
	if gameShared and gameShared:IsA("Folder") then
		return gameShared
	end
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if shared and shared:IsA("Folder") then
		return shared
	end
	return ReplicatedStorage:WaitForChild("GameShared") :: Folder
end

local Shared = getSharedFolder()
local BuildInfoModule = Shared:FindFirstChild("BuildInfo")
local label = if BuildInfoModule and BuildInfoModule:IsA("ModuleScript")
	then ((require :: any)(BuildInfoModule) :: any).name
	else "bella_game"
local contentMountModule = Shared:WaitForChild("ContentAssetMount")
assert(contentMountModule:IsA("ModuleScript"))
local ContentAssetMount = (require :: any)(contentMountModule)

print(`[{label}] mounting content marketplace assets…`)
local ok, mountError = pcall(function()
	ContentAssetMount.mountAll()
end)
if not ok then
	templates:SetAttribute("MountFailed", true)
	warn(`[{label}] content mount failed: {mountError}`)
elseif (templates:GetAttribute("AssetFailureCount") :: number?) ~= 0 then
	templates:SetAttribute("MountFailed", true)
	warn(
		`[{label}] one or more marketplace assets failed; inspect ContentModels Asset_* attributes`
	)
end
-- Always release Bootstrap. Runtime fallbacks remain available after a failed mount.
templates:SetAttribute("Ready", true)
