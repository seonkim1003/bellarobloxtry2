--!strict
--[[
	Lightweight maze presentation polish: fog-readable walls near tagged markers
	and a readable exit beacon that does not reveal the whole route.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local MazePolish = {}

local function ensureExitBeacon(maze: Model, exitPart: BasePart)
	if maze:FindFirstChild("ContentExitBeacon") then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "ContentExitBeacon"
	folder.Parent = maze

	local glow = Instance.new("Part")
	glow.Name = "ExitGlow"
	glow.Anchored = true
	glow.CanCollide = false
	glow.Size = Vector3.new(3, 8, 3)
	glow.Color = Color3.fromRGB(200, 210, 230)
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.45
	glow.CFrame = exitPart.CFrame * CFrame.new(0, 4, 0)
	glow.Parent = folder

	local light = Instance.new("PointLight")
	light.Brightness = 1.4
	light.Range = 22
	light.Color = Color3.fromRGB(210, 220, 255)
	light.Parent = glow

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ExitLabel"
	billboard.Size = UDim2.fromOffset(120, 36)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 48
	billboard.Parent = glow

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(230, 235, 255)
	label.Text = "EXIT"
	label.Parent = billboard
end

function MazePolish.ensureReadableShell()
	local scenes = Workspace:FindFirstChild("Scenes")
	if scenes == nil then
		return
	end
	local maze = scenes:FindFirstChild("Maze")
	if maze == nil or not maze:IsA("Model") then
		return
	end

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

	if exitPart then
		ensureExitBeacon(maze, exitPart)
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

--[[
	Always safe to call: ensures exit readability even when marketplace maze exists.
]]
function MazePolish.ensureExitReadable()
	local scenes = Workspace:FindFirstChild("Scenes")
	if scenes == nil then
		return
	end
	local maze = scenes:FindFirstChild("Maze")
	if maze == nil or not maze:IsA("Model") then
		return
	end
	for _, tagged in CollectionService:GetTagged("MazeExit") do
		if tagged:IsA("BasePart") and tagged:IsDescendantOf(maze) then
			ensureExitBeacon(maze, tagged)
			return
		end
	end
end

return MazePolish
