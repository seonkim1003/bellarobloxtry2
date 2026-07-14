--!strict
--[[
	Field landmarks for chase-readable routes + fragment remaining markers (visual only).
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local FieldPolish = {}

function FieldPolish.ensureLandmarks()
	local scenes = Workspace:FindFirstChild("Scenes")
	if scenes == nil then
		return
	end
	local field = scenes:FindFirstChild("Field")
	if field == nil or not field:IsA("Model") then
		return
	end
	if field:FindFirstChild("ContentLandmarks") then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "ContentLandmarks"
	folder.Parent = field

	for _, tagged in CollectionService:GetTagged("PatrolPoint") do
		if tagged:IsA("BasePart") and tagged:IsDescendantOf(field) then
			local post = Instance.new("Part")
			post.Name = `Landmark_{tagged.Name}`
			post.Anchored = true
			post.CanCollide = false
			post.Size = Vector3.new(1, 8, 1)
			post.Color = Color3.fromRGB(90, 120, 70)
			post.Material = Enum.Material.Grass
			post.CFrame = tagged.CFrame * CFrame.new(0, 4, 0)
			post.Parent = folder

			local light = Instance.new("PointLight")
			light.Brightness = 0.6
			light.Range = 18
			light.Color = Color3.fromRGB(140, 180, 120)
			light.Parent = post
		end
	end

	for _, tagged in CollectionService:GetTagged("LetterFragment") do
		if tagged:IsA("BasePart") and tagged:IsDescendantOf(field) then
			local spark = Instance.new("Part")
			spark.Name = `FragmentCue_{tagged.Name}`
			spark.Anchored = true
			spark.CanCollide = false
			spark.Size = Vector3.new(1.2, 1.2, 1.2)
			spark.Shape = Enum.PartType.Ball
			spark.Color = Color3.fromRGB(240, 220, 120)
			spark.Material = Enum.Material.Neon
			spark.Transparency = 0.35
			spark.CFrame = tagged.CFrame * CFrame.new(0, 2.2, 0)
			spark.Parent = folder

			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.fromOffset(90, 28)
			billboard.StudsOffset = Vector3.new(0, 1.5, 0)
			billboard.MaxDistance = 40
			billboard.Parent = spark

			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(255, 240, 180)
			label.Text = "✉"
			label.Parent = billboard
		end
	end
end

return FieldPolish
