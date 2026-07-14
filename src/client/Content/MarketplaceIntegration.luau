--!strict
--[[
	Client helper: wait for server marketplace mount, then soft-disable Part stand-ins
	when MarketplaceMap models are present.
]]

local CollectionService = game:GetService("CollectionService")
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

local function softHidePart(part: BasePart)
	if part:GetAttribute("ContentStandInHidden") == true then
		return
	end
	-- Keep collision/tags for gameplay markers; hide neon stand-in look.
	if part.Material == Enum.Material.Neon or part.Transparency < 0.9 then
		part:SetAttribute("ContentStandInHidden", true)
		part.Transparency = 1
		part.CanQuery = false
		-- Preserve CanCollide for trigger volumes; disable only decorative neon cubes.
		if part.Size.Magnitude < 6 and part.Material == Enum.Material.Neon then
			part.CanCollide = false
		end
	end
end

--[[
	Hide neon placeholder parts in a scene once MarketplaceMap is present.
	Does not destroy tagged markers (tags/attributes remain for systems).
]]
function MarketplaceIntegration.hideStandInsForScene(sceneId: string): number
	if not MarketplaceIntegration.hasSceneMap(sceneId) then
		return 0
	end
	local scenes = Workspace:FindFirstChild("Scenes")
	if scenes == nil then
		return 0
	end
	local scene = scenes:FindFirstChild(sceneId)
	if scene == nil then
		return 0
	end

	local hidden = 0
	for _, descendant in scene:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "MarketplaceMap" then
			local parentModel = descendant:FindFirstAncestor("MarketplaceMap")
			if parentModel == nil then
				-- Only hide neon stand-ins / placeholder-sized cubes, not whole geography.
				if
					descendant.Material == Enum.Material.Neon
					or descendant:GetAttribute("ContentPlaceholder") == true
				then
					softHidePart(descendant)
					hidden += 1
				end
			end
		end
	end
	return hidden
end

function MarketplaceIntegration.hideAllStandIns(): number
	local total = 0
	for _, sceneId in MarketplaceIntegration.listMountedScenes() do
		total += MarketplaceIntegration.hideStandInsForScene(sceneId)
	end
	return total
end

-- Keep CollectionService references warm for tools that audit stand-ins.
function MarketplaceIntegration.countTaggedNeonStandIns(): number
	local count = 0
	for _, tag in
		{
			"SceneSpawn",
			"NPCSpawn",
			"StoryTrigger",
			"LetterFragment",
			"CinematicMarker",
			"PatrolPoint",
			"MazeExit",
		}
	do
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsA("BasePart") and inst.Material == Enum.Material.Neon then
				count += 1
			end
		end
	end
	return count
end

return MarketplaceIntegration
