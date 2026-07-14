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

local function isUnsafeVisualRuntime(instance: Instance): boolean
	return instance:IsA("Humanoid")
		or instance:IsA("AnimationController")
		or instance:IsA("Animator")
		or instance:IsA("Sound")
		or instance:IsA("ClickDetector")
		or instance:IsA("DragDetector")
		or instance:IsA("ProximityPrompt")
		or instance:IsA("BodyMover")
		or instance:IsA("AlignPosition")
		or instance:IsA("AlignOrientation")
		or instance:IsA("AngularVelocity")
		or instance:IsA("LinearVelocity")
		or instance:IsA("VectorForce")
end

local function sanitizeCharacterVisual(model: Model)
	-- Marketplace characters are presentation only. Their controllers, sounds,
	-- interactions, and movers must never compete with the authoritative NPC actor.
	removeExecutableDescendants(model)
	for _, descendant in model:GetDescendants() do
		if isUnsafeVisualRuntime(descendant) then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
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

local function extractModel(container: Instance): Model?
	if container:IsA("Model") then
		-- InsertService:LoadAsset normally returns the asset wrapper itself as a
		-- Model. It must not be destroyed after this point.
		return container
	end

	local children = container:GetChildren()
	if #children == 0 then
		return nil
	end

	-- Preserve every top-level object from multi-model packs such as the farm.
	local model = Instance.new("Model")
	model.Name = container.Name
	for _, child in children do
		child.Parent = model
	end
	container:Destroy()
	return model
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

local function prepareSceneModel(
	model: Model,
	target: Vector3,
	extentLimit: number?,
	heightLimit: number?,
	collisionEnabled: boolean
)
	-- Free models frequently contain loose, unanchored assemblies. They collapse
	-- into a pile as soon as physics starts unless scene geometry is made static.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			if not collisionEnabled then
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end
	end

	local _, initialSize = model:GetBoundingBox()
	local horizontalExtent = math.max(initialSize.X, initialSize.Z)
	local maxExtent = extentLimit or ContentConfig.worldLayout.MaxMarketplaceExtent
	local scaleFactor = 1
	if horizontalExtent > maxExtent and horizontalExtent > 0 then
		scaleFactor = math.min(scaleFactor, maxExtent / horizontalExtent)
	end
	if heightLimit ~= nil and initialSize.Y > heightLimit and initialSize.Y > 0 then
		scaleFactor = math.min(scaleFactor, heightLimit / initialSize.Y)
	end
	if scaleFactor < 1 then
		model:ScaleTo(model:GetScale() * scaleFactor)
	end

	-- Align the bounding-box center to the stage origin and put its lowest point
	-- on the shared ground plane. Asset pivots are often arbitrary or far away.
	local bounds, size = model:GetBoundingBox()
	local bottomCenter =
		Vector3.new(bounds.Position.X, bounds.Position.Y - size.Y / 2, bounds.Position.Z)
	model:PivotTo(model:GetPivot() + (target - bottomCenter))
end

function ContentAssetMount.loadAssetModel(
	assetId: number,
	label: string,
	preserveExecutable: boolean?
): Model?
	local ok, containerOrErr = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok then
		warn(`[ContentAssets] LoadAsset failed for {label} ({assetId}): {containerOrErr}`)
		return nil
	end

	local container = containerOrErr :: Instance
	local model = extractModel(container)
	if model == nil then
		warn(`[ContentAssets] No Model inside asset {label} ({assetId})`)
		container:Destroy()
		return nil
	end

	model.Name = label
	if preserveExecutable ~= true then
		removeExecutableDescendants(model)
	end
	if ensurePrimary(model) == nil then
		warn(`[ContentAssets] No BasePart inside asset {label} ({assetId})`)
		model:Destroy()
		return nil
	end
	return model
end

local function storeFunctionalTemplate(templates: Folder, key: string, assetId: number): Model?
	local existing = templates:FindFirstChild(key)
	if existing then
		existing:Destroy()
	end
	-- Creator-selected obby props intentionally keep their original scripts,
	-- sounds, click detectors, and other interactions.
	local loaded = ContentAssetMount.loadAssetModel(assetId, key, true)
	if loaded == nil then
		return nil
	end
	loaded.Parent = templates
	return loaded
end

local function fitFunctionalClone(
	template: Model,
	marker: BasePart,
	cloneName: string,
	maxSize: Vector3,
	rotation: CFrame?
): Model
	local clone = template:Clone()
	clone.Name = cloneName
	if rotation then
		clone:PivotTo(clone:GetPivot() * rotation)
	end
	local _, size = clone:GetBoundingBox()
	local scale = math.min(
		maxSize.X / math.max(size.X, 0.01),
		maxSize.Y / math.max(size.Y, 0.01),
		maxSize.Z / math.max(size.Z, 0.01)
	)
	clone:ScaleTo(clone:GetScale() * scale)
	local bounds, fittedSize = clone:GetBoundingBox()
	local desiredBounds = marker.CFrame * (rotation or CFrame.identity)
		+ Vector3.new(0, (fittedSize.Y - marker.Size.Y) / 2, 0)
	local transform = desiredBounds * bounds:Inverse()
	clone:PivotTo(transform * clone:GetPivot())
	return clone
end

local function placeFunctionalProps(templates: Folder): boolean
	local props = ContentConfig.assets.marketplace.props
	local door = storeFunctionalTemplate(templates, "MazeExitDoor", props.mazeExitDoor)
	local jelly = storeFunctionalTemplate(templates, "ObbyJelly", props.jelly)
	local butter = storeFunctionalTemplate(templates, "ObbyButter", props.butter)
	local popIt = storeFunctionalTemplate(templates, "ObbyPopIt", props.popIt)
	if door == nil or jelly == nil or butter == nil or popIt == nil then
		return false
	end

	local folder = ensureFolder(Workspace, "FunctionalMarketplaceProps")
	folder:ClearAllChildren()
	for _, tagged in CollectionService:GetTagged("MazeExit") do
		if tagged:IsA("BasePart") then
			local visual = fitFunctionalClone(
				door,
				tagged,
				"MazeExitDoor",
				Vector3.new(10, 9, 3),
				CFrame.Angles(math.rad(90), 0, 0)
			)
			-- The exit sensor is intentionally oversized for reliable touch/proximity.
			-- Raise the fitted door so its threshold sits on the maze floor.
			visual:PivotTo(visual:GetPivot() + Vector3.new(0, 2.5, 0))
			visual.Parent = folder
			tagged.Transparency = 1
		end
	end

	local obbyTemplates = { jelly, butter, popIt }
	local materialNames = { "Jelly", "Butter", "PopIt" }
	for _, tagged in CollectionService:GetTagged("ASMRStep") do
		if tagged:IsA("BasePart") then
			local sequenceIndex = tagged:GetAttribute("SequenceIndex")
			if typeof(sequenceIndex) == "number" then
				local materialIndex = ((sequenceIndex - 1) % #obbyTemplates) + 1
				local material = ContentConfig.sounds.obbyMaterials[materialIndex]
				tagged:SetAttribute("StepMaterial", materialNames[materialIndex])
				tagged:SetAttribute("SoundId", material.soundId)
				tagged:SetAttribute("PlaybackSpeed", material.playbackSpeed)
				local visual = fitFunctionalClone(
					obbyTemplates[materialIndex],
					tagged,
					`{materialNames[materialIndex]}Step_{sequenceIndex}`,
					tagged.Size
				)
				visual.Parent = folder
				tagged.Transparency = 1
				tagged.CanCollide = true
			end
		end
	end
	return true
end

local function arrangeFieldHuntMarkers()
	local scenes = Workspace:FindFirstChild("Scenes")
	local field = scenes and scenes:FindFirstChild("Field")
	local spawn = field and field:FindFirstChild("FieldSpawn", true)
	local floor = field and field:FindFirstChild("FieldFloor", true)
	if
		field == nil
		or spawn == nil
		or not spawn:IsA("BasePart")
		or floor == nil
		or not floor:IsA("BasePart")
	then
		return
	end

	-- The authored entrance sits near a corner of the large Field floor. Anchoring
	-- patrol offsets there put giant Evil Rambo against the map edge. Move the hunt
	-- inward first, then keep the fragments and patrol loop close to the player.
	local huntOrigin = floor.CFrame * CFrame.new(-45, floor.Size.Y * 0.5 + 0.5, 0)
	spawn.CFrame = huntOrigin
	local offsets: { [string]: Vector3 } = {
		FragmentA = Vector3.new(8, 0, 8),
		FragmentB = Vector3.new(18, 0, 0),
		FragmentC = Vector3.new(8, 0, -8),
		EvilRamboSpawn = Vector3.new(38, 0, 0),
		PatrolA = Vector3.new(30, 0, -18),
		PatrolB = Vector3.new(42, 0, 0),
		PatrolC = Vector3.new(30, 0, 18),
	}
	for markerName, offset in offsets do
		local marker = field:FindFirstChild(markerName, true)
		if marker and marker:IsA("BasePart") then
			marker.CFrame = spawn.CFrame * CFrame.new(offset)
		end
	end
end

local function hideAuthoredMarker(instance: Instance)
	if instance:IsA("BasePart") then
		if
			CollectionService:HasTag(instance, "SceneSpawn")
			or CollectionService:HasTag(instance, "NPCSpawn")
			or CollectionService:HasTag(instance, "PatrolPoint")
			or CollectionService:HasTag(instance, "LetterFragment")
			or CollectionService:HasTag(instance, "MazeExit")
			or CollectionService:HasTag(instance, "StoryTrigger")
			or CollectionService:HasTag(instance, "CinematicMarker")
			or CollectionService:HasTag(instance, "ASMRStep")
		then
			-- Keep collision on authored ASMR stairs; other markers are invisible anchors.
			if CollectionService:HasTag(instance, "ASMRStep") then
				instance.Transparency = 0
			else
				instance.Transparency = 1
				instance.CanCollide = false
			end
		end
	end
end

local function placeSceneAsset(sceneId: string, assetId: number): boolean
	local layout = ContentConfig.sceneLayouts[sceneId]
	if layout == nil then
		return false
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
		return false
	end

	loaded.Name = "MarketplaceMap"
	local pos = layout.position
	prepareSceneModel(
		loaded,
		Vector3.new(pos.x, pos.y, pos.z),
		layout.maxMarketplaceExtent,
		layout.maxMarketplaceHeight,
		layout.marketplaceCollision == true
	)
	loaded.Parent = folder

	for _, descendant in folder:GetDescendants() do
		if not descendant:IsDescendantOf(loaded) then
			hideAuthoredMarker(descendant)
		end
	end

	print(`[ContentAssets] Mounted scene {sceneId} from asset {assetId}`)
	return true
end

local function storeCharacterTemplate(templates: Folder, key: string, assetId: number): boolean
	local existing = templates:FindFirstChild(key)
	if existing then
		existing:Destroy()
	end
	local loaded = ContentAssetMount.loadAssetModel(assetId, key)
	if loaded == nil then
		return false
	end
	sanitizeCharacterVisual(loaded)
	local _, size = loaded:GetBoundingBox()
	local largestExtent = math.max(size.X, size.Y, size.Z)
	if largestExtent > 8 then
		loaded:ScaleTo(loaded:GetScale() * 8 / largestExtent)
	end
	loaded.Parent = templates
	print(`[ContentAssets] Stored character template {key} ({assetId})`)
	return true
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
	humanoid.HipHeight = 2
	humanoid.AutoRotate = true
	humanoid.WalkSpeed = 16
	humanoid.Parent = actor

	if npcType == "EvilRambo" then
		local highlight = Instance.new("Highlight")
		highlight.Name = "EvilRamboAlwaysVisible"
		highlight.Adornee = actor
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillColor = Color3.fromRGB(190, 25, 25)
		highlight.FillTransparency = 0.55
		highlight.OutlineColor = Color3.fromRGB(255, 235, 80)
		highlight.OutlineTransparency = 0
		highlight.Parent = actor
	end

	local visualAnchor = Instance.new("Part")
	visualAnchor.Name = "VisualAnchor"
	visualAnchor.Anchored = false
	visualAnchor.CanCollide = false
	visualAnchor.Massless = true
	visualAnchor.Transparency = 1
	visualAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
	visualAnchor.CFrame = target
	visualAnchor.Parent = actor

	local locomotionJoint = Instance.new("Motor6D")
	locomotionJoint.Name = "LocomotionJoint"
	locomotionJoint.Part0 = root
	locomotionJoint.Part1 = visualAnchor
	locomotionJoint.Parent = root

	local visual = template:Clone()
	visual.Name = "Visual"
	sanitizeCharacterVisual(visual)
	if npcType == "EvilRambo" then
		-- Keep the pathfinding rig compact and reliable while presenting corrupted
		-- Rambo as a giant dog towering over the Field hunt.
		visual:ScaleTo(visual:GetScale() * 10)
	end
	local visualBounds, visualSize = visual:GetBoundingBox()
	local visualBottom = visualBounds.Position.Y - visualSize.Y / 2
	local desiredBottom = target.Position.Y - root.Size.Y / 2
	visual:PivotTo(
		visual:GetPivot()
			+ Vector3.new(
				target.Position.X - visualBounds.Position.X,
				desiredBottom - visualBottom,
				target.Position.Z - visualBounds.Position.Z
			)
	)
	visual.Parent = actor

	local visualPartCount = 0
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			visualPartCount += 1
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = visualAnchor
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
		weld.Part0 = visualAnchor
		weld.Part1 = fallback
		weld.Parent = fallback
	end

	local humanoidCount = 0
	for _, descendant in actor:GetDescendants() do
		if descendant:IsA("Humanoid") then
			humanoidCount += 1
		end
	end
	assert(humanoidCount == 1, `{cloneName} must contain exactly one authoritative Humanoid`)

	return actor
end

local function createFallbackTemplate(templates: Folder, templateName: string): Model
	local model = Instance.new("Model")
	model.Name = templateName
	local visual = Instance.new("Part")
	visual.Name = "FallbackVisual"
	visual.Anchored = true
	visual.CanCollide = false
	visual.Size = if templateName == "Bella"
		then Vector3.new(4, 6, 3)
		elseif templateName == "RobertPattinson" then Vector3.new(3, 6, 2)
		else Vector3.new(3, 2.5, 4)
	visual.Color = if templateName == "Bella"
		then Color3.fromRGB(120, 50, 55)
		elseif templateName == "RamboEvil" then Color3.fromRGB(55, 30, 30)
		elseif templateName == "RamboFriendly" then Color3.fromRGB(145, 105, 70)
		elseif templateName == "RobertPattinson" then Color3.fromRGB(90, 80, 75)
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
			return false
		end
		local _, size = loaded:GetBoundingBox()
		local largestExtent = math.max(size.X, size.Y, size.Z)
		if largestExtent > 4 then
			loaded:ScaleTo(loaded:GetScale() * 4 / largestExtent)
		end
		for _, descendant in loaded:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
			end
		end
		loaded.Parent = templates
		template = loaded
	end
	if template == nil or not template:IsA("Model") then
		return false
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
	return true
end

local function setMountStatus(templates: Folder, key: string, assetId: number, mounted: boolean)
	templates:SetAttribute(`Asset_{key}_Id`, assetId)
	templates:SetAttribute(`Asset_{key}_Mounted`, mounted)
	local countKey = if mounted then "AssetMountedCount" else "AssetFailureCount"
	local count = templates:GetAttribute(countKey)
	templates:SetAttribute(countKey, (if typeof(count) == "number" then count else 0) + 1)
end

function ContentAssetMount.mountAll()
	local marketplace = ContentConfig.assets.marketplace
	local templates = ensureFolder(ReplicatedStorage, "ContentModels")
	templates:SetAttribute("MountedAt", os.time())
	templates:SetAttribute("AssetMountedCount", 0)
	templates:SetAttribute("AssetFailureCount", 0)

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
				setMountStatus(templates, key, assetId, placeSceneAsset(sceneId, assetId))
			end
		end
	end

	-- Characters
	setMountStatus(
		templates,
		"bella",
		marketplace.characters.bella,
		storeCharacterTemplate(templates, "Bella", marketplace.characters.bella)
	)
	setMountStatus(
		templates,
		"ramboFriendly",
		marketplace.characters.ramboFriendly,
		storeCharacterTemplate(templates, "RamboFriendly", marketplace.characters.ramboFriendly)
	)
	setMountStatus(
		templates,
		"ramboEvil",
		marketplace.characters.ramboEvil,
		storeCharacterTemplate(templates, "RamboEvil", marketplace.characters.ramboEvil)
	)
	setMountStatus(
		templates,
		"robertPattinson",
		marketplace.characters.robertPattinson,
		storeCharacterTemplate(templates, "RobertPattinson", marketplace.characters.robertPattinson)
	)
	setMountStatus(
		templates,
		"gigi",
		marketplace.characters.gigi,
		storeCharacterTemplate(templates, "Gigi", marketplace.characters.gigi)
	)

	arrangeFieldHuntMarkers()
	spawnAtNpcTags(templates, "Bella", "Bella")
	spawnAtNpcTags(templates, "FriendlyRambo", "RamboFriendly")
	spawnAtNpcTags(templates, "EvilRambo", "RamboEvil")
	spawnAtNpcTags(templates, "RobertPattinson", "RobertPattinson")
	spawnAtNpcTags(templates, "Gigi", "Gigi")

	setMountStatus(
		templates,
		"letterFragments",
		marketplace.props.letterFragments,
		placeLetterFragments(templates)
	)
	setMountStatus(
		templates,
		"fatBart",
		marketplace.props.fatBart,
		storeCharacterTemplate(templates, "TitleFatBart", marketplace.props.fatBart)
	)
	local functionalPropsMounted = placeFunctionalProps(templates)
	setMountStatus(
		templates,
		"mazeExitDoor",
		marketplace.props.mazeExitDoor,
		functionalPropsMounted
	)
	setMountStatus(templates, "jelly", marketplace.props.jelly, functionalPropsMounted)
	setMountStatus(templates, "butter", marketplace.props.butter, functionalPropsMounted)
	setMountStatus(templates, "popIt", marketplace.props.popIt, functionalPropsMounted)
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
