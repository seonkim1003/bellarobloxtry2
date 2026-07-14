--!strict
--[[
	Uses server-mounted marketplace character clones when available.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RobberPresentation = {}

local function waitForTemplates(timeoutSeconds: number): Folder?
	local deadline = os.clock() + timeoutSeconds
	while os.clock() < deadline do
		local folder = ReplicatedStorage:FindFirstChild("ContentModels")
		if folder and folder:IsA("Folder") and folder:GetAttribute("Ready") == true then
			return folder
		end
		task.wait(0.1)
	end
	return ReplicatedStorage:FindFirstChild("ContentModels") :: Folder?
end

local function attachBillboard(adornee: BasePart, title: string, subtitle: string)
	local existing = adornee:FindFirstChild("RobberBillboard")
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RobberBillboard"
	billboard.Size = UDim2.fromOffset(220, 70)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = adornee
	billboard.Parent = adornee

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 0.55)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(240, 230, 210)
	nameLabel.Text = title
	nameLabel.Parent = billboard

	local subLabel = Instance.new("TextLabel")
	subLabel.BackgroundTransparency = 1
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.Size = UDim2.fromScale(1, 0.45)
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextScaled = true
	subLabel.TextColor3 = Color3.fromRGB(190, 180, 160)
	subLabel.Text = subtitle
	subLabel.Parent = billboard
end

function RobberPresentation.ensureAtSpawn(): Model?
	waitForTemplates(8)

	local folder = Workspace:FindFirstChild("ContentNPCs")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and child.Name:find("RobertPattinson") then
				local head = child:FindFirstChildWhichIsA("BasePart", true)
				if head then
					attachBillboard(head, "Robert Pattinson", "Tower guide")
				end
				return child
			end
		end
	end

	-- Fallback: clone template locally if server mount missed this NPC.
	local templates = ReplicatedStorage:FindFirstChild("ContentModels")
	local template = if templates then templates:FindFirstChild("RobertPattinson") else nil
	local spawnPart: BasePart? = nil
	for _, tagged in CollectionService:GetTagged("NPCSpawn") do
		if tagged:IsA("BasePart") and tagged:GetAttribute("NPCType") == "RobertPattinson" then
			spawnPart = tagged
			break
		end
	end
	if template == nil or not template:IsA("Model") or spawnPart == nil then
		return nil
	end

	local npcs = folder
	if npcs == nil then
		npcs = Instance.new("Folder")
		npcs.Name = "ContentNPCs"
		npcs.Parent = Workspace
	end

	local clone = template:Clone()
	clone.Name = "RobertPattinson_Client"
	if clone.PrimaryPart then
		clone:PivotTo(spawnPart.CFrame)
	end
	clone.Parent = npcs
	local adornee = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
	if adornee then
		attachBillboard(adornee, "Robert Pattinson", "Tower guide")
	end
	return clone
end

function RobberPresentation.clear()
	local folder = Workspace:FindFirstChild("ContentNPCs")
	if folder == nil then
		return
	end
	for _, child in folder:GetChildren() do
		-- Only destroy local fallbacks — never the server-mounted marketplace NPC.
		if child.Name == "RobertPattinson_Client" then
			child:Destroy()
		end
	end
end

return RobberPresentation
