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

local function spawnAtNpcTags(templates: Folder, npcType: string, templateName: string)
	local template = templates:FindFirstChild(templateName)
	if template == nil or not template:IsA("Model") then
		return
	end

	local folder = ensureFolder(Workspace, "ContentNPCs")
	for _, tagged in CollectionService:GetTagged("NPCSpawn") do
		if tagged:IsA("BasePart") and tagged:GetAttribute("NPCType") == npcType then
			local cloneName = `{templateName}_{tagged.Name}`
			local old = folder:FindFirstChild(cloneName)
			if old then
				old:Destroy()
			end
			local clone = template:Clone()
			clone.Name = cloneName
			pivotTo(clone, tagged.CFrame)
			clone.Parent = folder
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
			CollectionService:AddTag(clone, "LetterFragment")
			local promptPart = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
			if promptPart then
				promptPart:SetAttribute("FragmentId", fragmentId)
				CollectionService:AddTag(promptPart, "LetterFragment")
			end
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
	spawnAtNpcTags(templates, "RamboGuide", "RamboFriendly")
	spawnAtNpcTags(templates, "RamboEvil", "RamboEvil")
	spawnAtNpcTags(templates, "RobberPatterinson", "RobberPatterinson")
	spawnAtNpcTags(templates, "Gigi", "Gigi")

	placeLetterFragments(templates)

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
