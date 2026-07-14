--!strict
--[[
	Field landmarks for chase-readable routes (visual only).
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
end

return FieldPolish
