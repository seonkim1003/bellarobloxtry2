--!strict
--[[
	Client helper: wait for server marketplace mount, then soft-disable Part stand-ins
	when MarketplaceMap models are present.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MarketplaceIntegration = {}

function MarketplaceIntegration.waitUntilReady(timeoutSeconds: number?): boolean
	local timeout = timeoutSeconds or 10
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local folder = ReplicatedStorage:FindFirstChild("ContentModels")
		if folder and folder:GetAttribute("Ready") == true then
			return true
		end
		task.wait(0.1)
	end
	return false
end

function MarketplaceIntegration.hasSceneMap(sceneId: string): boolean
	local scenes = Workspace:FindFirstChild("Scenes")
	if scenes == nil then
		return false
	end
	local scene = scenes:FindFirstChild(sceneId)
	if scene == nil then
		return false
	end
	return scene:FindFirstChild("MarketplaceMap") ~= nil
end

function MarketplaceIntegration.listMountedScenes(): { string }
	local mounted = {}
	local scenes = Workspace:FindFirstChild("Scenes")
	if scenes == nil then
		return mounted
	end
	for _, scene in scenes:GetChildren() do
		if scene:FindFirstChild("MarketplaceMap") then
			table.insert(mounted, scene.Name)
		end
	end
	return mounted
end

return MarketplaceIntegration
