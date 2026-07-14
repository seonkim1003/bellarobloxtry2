--!strict
--[[
	Content marketplace asset bootstrap (InsertService must run on the server).
	Loads maps/characters/props from ContentConfig.assets.marketplace.
	Compatible with Agent 1 GameShared and scaffold Shared folder names.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
ContentAssetMount.mountAll()
