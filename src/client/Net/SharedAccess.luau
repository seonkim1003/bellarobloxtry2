--!strict
--[[
	Resolves Agent 1 (GameShared/GameRemotes) or scaffold (Shared/Remotes) folder names.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedAccess = {}

local function asFolder(instance: Instance?): Folder?
	if instance and instance:IsA("Folder") then
		return instance
	end
	return nil
end

function SharedAccess.getSharedFolder(timeoutSeconds: number?): Folder
	local timeout = timeoutSeconds or 10
	local existing = asFolder(ReplicatedStorage:FindFirstChild("GameShared"))
		or asFolder(ReplicatedStorage:FindFirstChild("Shared"))
	if existing then
		return existing
	end

	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local found = asFolder(ReplicatedStorage:FindFirstChild("GameShared"))
			or asFolder(ReplicatedStorage:FindFirstChild("Shared"))
		if found then
			return found
		end
		task.wait(0.1)
	end

	-- Prefer GameShared, but accept Shared rather than yielding forever on a scaffold-only tree.
	local late = asFolder(ReplicatedStorage:FindFirstChild("GameShared"))
		or asFolder(ReplicatedStorage:FindFirstChild("Shared"))
	if late then
		return late
	end

	local waited = ReplicatedStorage:WaitForChild("GameShared", 1)
	local waitedFolder = asFolder(waited)
	if waitedFolder then
		return waitedFolder
	end
	local sharedWaited = ReplicatedStorage:WaitForChild("Shared", 1)
	local sharedFolder = asFolder(sharedWaited)
	if sharedFolder then
		return sharedFolder
	end
	error("Neither ReplicatedStorage.GameShared nor ReplicatedStorage.Shared is available")
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
