--!strict
--[[
	Resolves Agent 1 (GameShared/GameRemotes) or scaffold (Shared/Remotes) folder names.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedAccess = {}

function SharedAccess.getSharedFolder(timeoutSeconds: number?): Folder
	local timeout = timeoutSeconds or 10
	local existing = ReplicatedStorage:FindFirstChild("GameShared")
	if existing and existing:IsA("Folder") then
		return existing
	end
	existing = ReplicatedStorage:FindFirstChild("Shared")
	if existing and existing:IsA("Folder") then
		return existing
	end

	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local gameShared = ReplicatedStorage:FindFirstChild("GameShared")
		if gameShared and gameShared:IsA("Folder") then
			return gameShared
		end
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		if shared and shared:IsA("Folder") then
			return shared
		end
		task.wait(0.1)
	end

	return ReplicatedStorage:WaitForChild("GameShared") :: Folder
end

function SharedAccess.requireContentConfig(): any
	local shared = SharedAccess.getSharedFolder(10)
	local moduleScript = shared:WaitForChild("ContentConfig")
	assert(moduleScript:IsA("ModuleScript"), "ContentConfig must be a ModuleScript")
	return (require :: any)(moduleScript)
end

function SharedAccess.getRemotesFolder(timeoutSeconds: number?): Folder?
	local timeout = timeoutSeconds or 10
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local gameRemotes = ReplicatedStorage:FindFirstChild("GameRemotes")
		if gameRemotes and gameRemotes:IsA("Folder") then
			return gameRemotes
		end
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes and remotes:IsA("Folder") then
			return remotes
		end
		task.wait(0.1)
	end
	return nil
end

return SharedAccess
