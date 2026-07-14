--!strict
--[[
	Server-side InsertService mount for marketplace assets listed in ContentConfig.
	Falls back silently when an asset cannot be loaded (not owned / filtered).
]]

local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ContentConfig = require(script.Parent:WaitForChild("ContentConfig"))

local ContentAssetMount = {}

local function removeExecutableDescendants(instance: Instance)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
end

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function firstModel(container: Instance): Model?
	if container:IsA("Model") then
		return container
	end
	for _, child in container:GetChildren() do
		if child:IsA("Model") then
			return child
		end
	end
	for _, child in container:GetChildren() do
		if child:IsA("BasePart") then
			local model = Instance.new("Model")
			model.Name = container.Name
			child.Parent = model
			for _, other in container:GetChildren() do
				other.Parent = model
			end
			model.PrimaryPart = child
			return model
		end
	end
	return nil
end

local function ensurePrimary(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	if part then
		model.PrimaryPart = part
	end
	return part
end

local function pivotTo(model: Model, target: CFrame)
	if ensurePrimary(model) then
		model:PivotTo(target)
	end
end

function ContentAssetMount.loadAssetModel(assetId: number, label: string): Model?
	local ok, containerOrErr = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok then
		warn(`[ContentAssets] LoadAsset failed for {label} ({assetId}): {containerOrErr}`)
		return nil
	end

	local container = containerOrErr :: Instance
	local model = firstModel(container)
	if model == nil then
		warn(`[ContentAssets] No Model inside asset {label} ({assetId})`)
		container:Destroy()
		return nil
	end

	model.Name = label
	-- Detach from LoadAsset wrapper.
	model.Parent = nil
	container:Destroy()
	removeExecutableDescendants(model)
	ensurePrimary(model)
	return model
end

local function hideNeonDecor(instance: Instance)
	if instance:IsA("BasePart") then
		local name = instance.Name
		if name:find("Floor") or name:find("FogWall") or name:find("Landmark") then
			instance.Transparency = 1
			instance.CanCollide = false
		elseif
			CollectionService:HasTag(instance, "SceneSpawn")
			or CollectionService:HasTag(instance, "NPCSpawn")
			or CollectionService:HasTag(instance, "PatrolPoint")
			or CollectionService:HasTag(instance, "LetterFragment")
			or CollectionService:HasTag(instance, "MazeExit")
			or CollectionService:HasTag(instance, "StoryTrigger")
			or CollectionService:HasTag(instance, "CinematicMarker")
			or CollectionService:HasTag(instance, "ASMRStep")
		then
			-- Keep collision on ASMR steps / floors if needed; markers become invisible anchors.
			if CollectionService:HasTag(instance, "ASMRStep") then
				instance.Transparency = 0.85
			else
				instance.Transparency = 1
				instance.CanCollide = false
			end
		end
	end
end

local function placeSceneAsset(sceneId: string, assetId: number)
	local layout = ContentConfig.sceneLayouts[sceneId]
	if layout == nil then
		return
	end

	local scenes = ensureFolder(Workspace, "Scenes")
	local sceneFolder: Instance? = scenes:FindFirstChild(sceneId)
	if sceneFolder == nil then
		local model = Instance.new("Model")
		model.Name = sceneId
		model.Parent = scenes
		sceneFolder = model
	end

	local folder = sceneFolder :: Instance
	local existing = folder:FindFirstChild("MarketplaceMap")
	if existing then
		existing:Destroy()
	end

	local loaded = ContentAssetMount.loadAssetModel(assetId, `{sceneId}_Map`)
	if loaded == nil then
		return
	end

	loaded.Name = "MarketplaceMap"
	local pos = layout.position
	pivotTo(loaded, CFrame.new(pos.x, pos.y, pos.z))
	loaded.Parent = folder

	for _, descendant in folder:GetDescendants() do
		hideNeonDecor(descendant)
	end

	print(`[ContentAssets] Mounted scene {sceneId} from asset {assetId}`)
end

local function storeCharacterTemplate(templates: Folder, key: string, assetId: number)
	local existing = templates:FindFirstChild(key)
	if existing then
		existing:Destroy()
	end
	local loaded = ContentAssetMount.loadAssetModel(assetId, key)
	if loaded == nil then
		return
	end
	loaded.Parent = templates
	print(`[ContentAssets] Stored character template {key} ({assetId})`)
end

local function createNpcActor(
	template: Model,
	cloneName: string,
	target: CFrame,
	npcType: string
): Model
	local actor = Instance.new("Model")
	actor.Name = cloneName
	actor:SetAttribute("NPCType", npcType)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = false
	root.CanCollide = true
	root.Transparency = 1
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = target
	root.Parent = actor
	actor.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = actor

	local visual = template:Clone()
	visual.Name = "Visual"
	removeExecutableDescendants(visual)
	pivotTo(visual, target)
	visual.Parent = actor

	local visualPartCount = 0
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			visualPartCount += 1
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end

	if visualPartCount == 0 then
		local fallback = Instance.new("Part")
		fallback.Name = "FallbackVisual"
		fallback.Shape = Enum.PartType.Ball
		fallback.Size = Vector3.new(2.5, 2.5, 2.5)
		fallback.Color = Color3.fromRGB(110, 90, 75)
		fallback.Material = Enum.Material.SmoothPlastic
		fallback.CanCollide = false
		fallback.Massless = true
		fallback.CFrame = target
		fallback.Parent = actor
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = fallback
		weld.Parent = fallback
	end

	return actor
end

local function createFallbackTemplate(templates: Folder, templateName: string): Model
	local model = Instance.new("Model")
	model.Name = templateName
	local visual = Instance.new("Part")
	visual.Name = "FallbackVisual"
	visual.Anchored = true
	visual.CanCollide = false
	visual.Size = if templateName == "Bella" then Vector3.new(4, 6, 3) else Vector3.new(3, 2.5, 4)
	visual.Color = if templateName == "Bella"
		then Color3.fromRGB(120, 50, 55)
		elseif templateName == "RamboEvil" then Color3.fromRGB(55, 30, 30)
		elseif templateName == "RamboFriendly" then Color3.fromRGB(145, 105, 70)
		else Color3.fromRGB(105, 90, 80)
	visual.Material = Enum.Material.SmoothPlastic
	visual.Parent = model
	model.PrimaryPart = visual
	model.Parent = templates
	warn(`[ContentAssets] Using fallback visual for {templateName}`)
	return model
end

local function spawnAtNpcTags(templates: Folder, npcType: string, templateName: string)
	local foundTemplate = templates:FindFirstChild(templateName)
	local template: Model
	if foundTemplate and foundTemplate:IsA("Model") then
		template = foundTemplate
	else
		template = createFallbackTemplate(templates, templateName)
	end

	local folder = ensureFolder(Workspace, "ContentNPCs")
	for _, tagged in CollectionService:GetTagged("NPCSpawn") do
		if tagged:IsA("BasePart") and tagged:GetAttribute("NPCType") == npcType then
			local cloneName = `{templateName}_{tagged.Name}`
			local old = folder:FindFirstChild(cloneName)
			if old then
				old:Destroy()
			end
			local actor = createNpcActor(template, cloneName, tagged.CFrame, npcType)
			actor.Parent = folder
			CollectionService:AddTag(actor, "NPCSpawn")
		end
	end
end

local function placeLetterFragments(templates: Folder)
	local template = templates:FindFirstChild("LetterFragmentTemplate")
	if template == nil then
		local propId = ContentConfig.assets.marketplace.props.letterFragments
		local loaded = ContentAssetMount.loadAssetModel(propId, "LetterFragmentTemplate")
		if loaded == nil then
			return
		end
		loaded.Parent = templates
		template = loaded
	end
	if template == nil or not template:IsA("Model") then
		return
	end

	local folder = ensureFolder(Workspace, "ContentProps")
	for _, tagged in CollectionService:GetTagged("LetterFragment") do
		if tagged:IsA("BasePart") then
			local fragmentId = tagged:GetAttribute("FragmentId")
			local name = `LetterFragment_{fragmentId or tagged.Name}`
			local old = folder:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			local clone = template:Clone()
			clone.Name = name
			pivotTo(clone, tagged.CFrame)
			clone:SetAttribute("FragmentId", fragmentId)
			-- Prefer prompting on the visual prop; keep invisible marker.
			tagged.Transparency = 1
			tagged.CanCollide = false
			clone.Parent = folder
		end
	end
	print("[ContentAssets] Placed letter fragment visuals")
end

function ContentAssetMount.mountAll()
	local marketplace = ContentConfig.assets.marketplace
	local templates = ensureFolder(ReplicatedStorage, "ContentModels")
	templates:SetAttribute("MountedAt", os.time())

	-- Scenes
	local sceneOrder = { "Lobby", "Maze", "Tower", "Field", "Epilogue" }
	for _, sceneId in sceneOrder do
		local layout = ContentConfig.sceneLayouts[sceneId]
		if layout then
			local key = layout.marketplaceKey
			local assetId: number? = nil
			if key == "lobby" then
				assetId = marketplace.scenes.lobby
			elseif key == "maze" then
				assetId = marketplace.scenes.maze
			elseif key == "tower" then
				assetId = marketplace.scenes.tower
			elseif key == "field" then
				assetId = marketplace.scenes.field
			end
			if assetId ~= nil then
				placeSceneAsset(sceneId, assetId)
			end
		end
	end

	-- Characters
	storeCharacterTemplate(templates, "Bella", marketplace.characters.bella)
	storeCharacterTemplate(templates, "RamboFriendly", marketplace.characters.ramboFriendly)
	storeCharacterTemplate(templates, "RamboEvil", marketplace.characters.ramboEvil)
	storeCharacterTemplate(templates, "RobberPatterinson", marketplace.characters.robberPatterinson)
	storeCharacterTemplate(templates, "Gigi", marketplace.characters.gigi)

	spawnAtNpcTags(templates, "Bella", "Bella")
	spawnAtNpcTags(templates, "FriendlyRambo", "RamboFriendly")
	spawnAtNpcTags(templates, "EvilRambo", "RamboEvil")
	spawnAtNpcTags(templates, "RobberPatterinson", "RobberPatterinson")
	spawnAtNpcTags(templates, "Gigi", "Gigi")

	placeLetterFragments(templates)
	for _, step in CollectionService:GetTagged("ASMRStep") do
		if step:IsA("BasePart") then
			step.CanCollide = true
		end
	end

	templates:SetAttribute("Ready", true)
	print("[ContentAssets] Mount complete")
end

function ContentAssetMount.getTemplate(name: string): Model?
	local templates = ReplicatedStorage:FindFirstChild("ContentModels")
	if templates == nil then
		return nil
	end
	local template = templates:FindFirstChild(name)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

return ContentAssetMount
