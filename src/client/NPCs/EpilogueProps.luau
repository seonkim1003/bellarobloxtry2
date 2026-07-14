--!strict
--[[
	Epilogue table presentation: collar/tag focus, no blood/remains/meat.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local EpilogueProps = {}

function EpilogueProps.mount(): Model?
	local spawn: BasePart? = nil
	for _, tagged in CollectionService:GetTagged("SceneSpawn") do
		if tagged:IsA("BasePart") and tagged:GetAttribute("SceneId") == "Epilogue" then
			spawn = tagged
			break
		end
	end
	if spawn == nil then
		return nil
	end

	local folder = Workspace:FindFirstChild("ContentEpilogue")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "ContentEpilogue"
		folder.Parent = Workspace
	end

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
	return model
end

function EpilogueProps.clear()
	local folder = Workspace:FindFirstChild("ContentEpilogue")
	if folder then
		folder:Destroy()
	end
end

return EpilogueProps
