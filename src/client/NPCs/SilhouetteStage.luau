--!strict
--[[
	Silhouette-only prop helpers for the dog fight (no gore, no injury mesh).
]]

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local SilhouetteStage = {}

function SilhouetteStage.mount(): Folder
	local existing = Workspace:FindFirstChild("ContentSilhouettes")
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = "ContentSilhouettes"
	folder.Parent = Workspace

	local stageCFrame = CFrame.new(3600, 2, 10)
	for _, marker in CollectionService:GetTagged("CinematicMarker") do
		if marker:IsA("BasePart") and marker:GetAttribute("MarkerId") == "FightSilhouette" then
			stageCFrame = marker.CFrame
			break
		end
	end

	for index = 1, 2 do
		local figure = Instance.new("Part")
		figure.Name = `Silhouette_{index}`
		figure.Size = Vector3.new(1.4, 2.6, 1.4)
		figure.Color = Color3.new(0, 0, 0)
		figure.Material = Enum.Material.SmoothPlastic
		figure.Transparency = 0.15
		figure.Anchored = true
		figure.CanCollide = false
		figure.CFrame = stageCFrame
			* CFrame.new((index - 1.5) * 3, 0, 0)
			* CFrame.Angles(0, math.rad(index * 35), 0)
		figure.Parent = folder

		local cast = Instance.new("PointLight")
		cast.Brightness = 0.4
		cast.Range = 10
		cast.Color = Color3.fromRGB(80, 100, 90)
		cast.Parent = figure
	end

	return folder
end

function SilhouetteStage.clear()
	local folder = Workspace:FindFirstChild("ContentSilhouettes")
	if folder then
		folder:Destroy()
	end
end

return SilhouetteStage
