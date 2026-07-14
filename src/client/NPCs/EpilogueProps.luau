--!strict
--[[
	Epilogue table presentation: collar/tag focus, no blood/remains/meat.
	Actors and props persist through Credits until lobby/replay clears them.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EpilogueProps = {}

local FOLDER_NAME = "ContentEpilogue"
local ACTOR_FOLDER = "EpilogueActors"

local function findSceneSpawn(): BasePart?
	for _, tagged in CollectionService:GetTagged("SceneSpawn") do
		if tagged:IsA("BasePart") then
			local sceneId = tagged:GetAttribute("SceneId")
			if sceneId == "Epilogue" or sceneId == "EpilogueSeat" then
				return tagged
			end
		end
	end
	return nil
end

local function findNpcSpawn(npcType: string): BasePart?
	for _, tagged in CollectionService:GetTagged("NPCSpawn") do
		if tagged:IsA("BasePart") and tagged:GetAttribute("NPCType") == npcType then
			return tagged
		end
	end
	return nil
end

local function ensureFolder(): Folder
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = Workspace
	return created
end

local function cloneActor(templateName: string, actorName: string, at: CFrame): Model?
	local templates = ReplicatedStorage:FindFirstChild("ContentModels")
	local template = if templates then templates:FindFirstChild(templateName) else nil
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	else
		model = Instance.new("Model")
		local part = Instance.new("Part")
		part.Name = "FallbackVisual"
		part.Size = Vector3.new(2.5, 4, 2)
		part.Color = Color3.fromRGB(150, 130, 110)
		part.Anchored = true
		part.CanCollide = false
		part.Parent = model
		model.PrimaryPart = part
	end
	model.Name = actorName
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
	if model.PrimaryPart == nil then
		local part = model:FindFirstChildWhichIsA("BasePart", true)
		if part then
			model.PrimaryPart = part
		end
	end
	model:PivotTo(at)
	return model
end

function EpilogueProps.mount(): Model?
	local spawn = findSceneSpawn()
	if spawn == nil then
		return nil
	end

	local folder = ensureFolder()
	local existing = folder:FindFirstChild("CollarReveal")
	if existing and existing:IsA("Model") then
		return existing
	end

	local model = Instance.new("Model")
	model.Name = "CollarReveal"

	local tableTop = Instance.new("Part")
	tableTop.Name = "Table"
	tableTop.Size = Vector3.new(6, 0.4, 3)
	tableTop.Color = Color3.fromRGB(110, 85, 60)
	tableTop.Material = Enum.Material.Wood
	tableTop.Anchored = true
	tableTop.CFrame = spawn.CFrame * CFrame.new(0, 1.5, -4)
	tableTop.Parent = model

	local collar = Instance.new("Part")
	collar.Name = "Collar"
	collar.Size = Vector3.new(1.2, 0.15, 1.2)
	collar.Color = Color3.fromRGB(40, 40, 45)
	collar.Material = Enum.Material.Leather
	collar.Anchored = true
	collar.CanCollide = false
	collar.CFrame = tableTop.CFrame * CFrame.new(-1.2, 0.4, 0)
	collar.Parent = model

	local tag = Instance.new("Part")
	tag.Name = "NameTag"
	tag.Size = Vector3.new(0.5, 0.05, 0.7)
	tag.Color = Color3.fromRGB(200, 180, 90)
	tag.Material = Enum.Material.Metal
	tag.Anchored = true
	tag.CanCollide = false
	tag.CFrame = collar.CFrame * CFrame.new(0.4, 0.12, 0)
	tag.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 40)
	billboard.StudsOffset = Vector3.new(0, 1.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = tag
	billboard.Parent = tag

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(245, 230, 180)
	label.Text = "RAMBO"
	label.Parent = billboard

	local letter = Instance.new("Part")
	letter.Name = "CompletedLetter"
	letter.Size = Vector3.new(1.6, 0.05, 1.1)
	letter.Color = Color3.fromRGB(235, 225, 200)
	letter.Material = Enum.Material.Cardboard
	letter.Anchored = true
	letter.CanCollide = false
	letter.CFrame = tableTop.CFrame * CFrame.new(1.3, 0.35, 0)
	letter.Parent = model

	model.PrimaryPart = tableTop
	model.Parent = folder

	local actorsFolder = folder:FindFirstChild(ACTOR_FOLDER)
	local actors: Folder
	if actorsFolder and actorsFolder:IsA("Folder") then
		actors = actorsFolder
	else
		actors = Instance.new("Folder")
		actors.Name = ACTOR_FOLDER
		actors.Parent = folder
	end

	local gigiSpawn = findNpcSpawn("Gigi")
	if gigiSpawn and actors:FindFirstChild("EpilogueGigi") == nil then
		local gigi = cloneActor("Gigi", "EpilogueGigi", gigiSpawn.CFrame)
		if gigi then
			gigi.Parent = actors
		end
	end

	return model
end

function EpilogueProps.clear()
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
end

return EpilogueProps
