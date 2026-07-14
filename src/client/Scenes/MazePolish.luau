--!strict
--[[
	Lightweight maze presentation polish: fog-readable walls near tagged markers.
	Does not alter supplied layout corridors if already present — only fills gaps.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local MazePolish = {}

function MazePolish.ensureReadableShell()
	local scenes = Workspace:FindFirstChild("Scenes")
	if scenes == nil then
		return
	end
	local maze = scenes:FindFirstChild("Maze")
	if maze == nil or not maze:IsA("Model") then
		return
	end

	if maze:FindFirstChild("ContentFogWalls") then
		return
	end
	if maze:FindFirstChild("MazeWall1") then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "ContentFogWalls"
	folder.Parent = maze

	local exitPart: BasePart? = nil
	for _, tagged in CollectionService:GetTagged("MazeExit") do
		if tagged:IsA("BasePart") and tagged:IsDescendantOf(maze) then
			exitPart = tagged
			break
		end
	end

	local spawnPart: BasePart? = nil
	for _, tagged in CollectionService:GetTagged("SceneSpawn") do
		if tagged:IsA("BasePart") and tagged:GetAttribute("SceneId") == "MazeCheckpoint" then
			spawnPart = tagged
			break
		end
	end

	if spawnPart and exitPart then
		local mid = (spawnPart.Position + exitPart.Position) / 2
		for i = -2, 2 do
			local wall = Instance.new("Part")
			wall.Name = `FogWall_{i}`
			wall.Anchored = true
			wall.CanCollide = true
			wall.Size = Vector3.new(2, 10, 28)
			wall.Color = Color3.fromRGB(25, 20, 35)
			wall.Material = Enum.Material.Slate
			wall.Transparency = 0.15
			wall.CFrame = CFrame.new(mid + Vector3.new(i * 8, 5, 0))
			wall.Parent = folder
		end
	end

	-- Navigation clearance pad under spawn for pathfinding friendliness.
	if spawnPart and maze:FindFirstChild("NavClearance") == nil then
		local pad = Instance.new("Part")
		pad.Name = "NavClearance"
		pad.Anchored = true
		pad.CanCollide = false
		pad.Transparency = 1
		pad.Size = Vector3.new(12, 1, 12)
		pad.CFrame = spawnPart.CFrame * CFrame.new(0, -1, 0)
		pad.Parent = maze
	end
end

return MazePolish
