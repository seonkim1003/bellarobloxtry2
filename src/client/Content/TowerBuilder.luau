--!strict
--[[
	Builds / refreshes ASMR tower step triggers: 28 steps across 7 right-angle flights.
	When a reviewed MarketplaceMap tower is present, only lightweight invisible
	ASMRStep sensors are placed (no duplicate visible geometry).
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()
local Tagging = require(script.Parent:WaitForChild("Tagging"))
local MarketplaceIntegration = require(script.Parent:WaitForChild("MarketplaceIntegration"))

local TowerBuilder = {}

local function ensureTowerModel(): Model
	local scenes = Workspace:FindFirstChild("Scenes")
	if scenes == nil then
		scenes = Instance.new("Folder")
		scenes.Name = "Scenes"
		scenes.Parent = Workspace
	end

	local tower = scenes:FindFirstChild("Tower")
	if tower and tower:IsA("Model") then
		return tower
	end

	local model = Instance.new("Model")
	model.Name = "Tower"
	model.Parent = scenes
	return model
end

local function clearGeneratedSteps(tower: Model)
	for _, child in tower:GetChildren() do
		if
			child.Name:match("^ASMRStep_")
			or child.Name:match("^TowerFlight_")
			or child.Name == "TowerRail"
			or child.Name == "ContentASMRSensors"
		then
			child:Destroy()
		end
	end
end

local function placeStepPart(
	parent: Instance,
	index: number,
	position: Vector3,
	facing: number,
	visible: boolean
)
	local step = Instance.new("Part")
	step.Name = `ASMRStep_{index}`
	step.Anchored = true
	step.CanCollide = visible
	step.CanTouch = true
	step.Size = if visible then Vector3.new(3, 0.5, 5) else Vector3.new(3.2, 1.2, 5)
	step.Transparency = if visible then 0 else 1
	step.Color = Color3.fromRGB(170, 150, 100)
	step.Material = if visible then Enum.Material.WoodPlanks else Enum.Material.SmoothPlastic
	step.CFrame = CFrame.new(position) * CFrame.Angles(0, -facing, 0)
	step.Parent = parent

	local soundId = ContentConfig.sounds.asmrSteps[index] or "rbxassetid://0"
	Tagging.applyMarker(step, "ASMRStep", {
		SceneId = "Tower",
		MarkerId = `ASMRStep_{index}`,
		SoundId = soundId,
		SequenceIndex = index,
	})
end

function TowerBuilder.rebuildFlights()
	local tower = ensureTowerModel()
	clearGeneratedSteps(tower)

	local marketplaceTower = MarketplaceIntegration.hasSceneMap("Tower")
	local stepCount = ContentConfig.towerStepCount
	local flights = ContentConfig.towerFlights
	local stepsPerFlight = math.ceil(stepCount / flights)

	local towerLayout = ContentConfig.sceneLayouts.Tower.position
	local origin = Vector3.new(towerLayout.x - 10, towerLayout.y, towerLayout.z - 10)
	-- Prefer marketplace map pivot when available so sensors land near real stairs.
	local map = tower:FindFirstChild("MarketplaceMap")
	if map and map:IsA("Model") then
		local pivot = map:GetPivot().Position
		origin = Vector3.new(pivot.X, pivot.Y, pivot.Z)
	end

	local facing = 0
	local cursor = origin
	local parent: Instance = tower

	if marketplaceTower then
		local folder = Instance.new("Folder")
		folder.Name = "ContentASMRSensors"
		folder.Parent = tower
		parent = folder
	end

	for flight = 0, flights - 1 do
		for stepInFlight = 1, stepsPerFlight do
			local index = flight * stepsPerFlight + stepInFlight
			if index > stepCount then
				break
			end

			local along = (stepInFlight - 0.5) * 3
			local position = cursor
				+ Vector3.new(math.cos(facing) * along, 1 + index * 0.75, math.sin(facing) * along)
			placeStepPart(parent, index, position, facing, not marketplaceTower)
		end

		cursor = cursor
			+ Vector3.new(
				math.cos(facing) * (stepsPerFlight * 3),
				0,
				math.sin(facing) * (stepsPerFlight * 3)
			)
		facing += math.rad(90)
	end

	if not marketplaceTower then
		local rail = Instance.new("Part")
		rail.Name = "TowerRail"
		rail.Anchored = true
		rail.CanCollide = true
		rail.Size = Vector3.new(1, 12, 1)
		rail.Color = Color3.fromRGB(90, 90, 100)
		rail.Material = Enum.Material.Metal
		rail.CFrame = CFrame.new(origin + Vector3.new(-2, 8, -2))
		rail.Parent = tower
	end

	for _, tagged in CollectionService:GetTagged("ASMRStep") do
		if tagged:IsDescendantOf(tower) and tagged:IsA("BasePart") then
			if marketplaceTower then
				tagged.CanCollide = false
			else
				tagged.CanCollide = true
			end
		end
	end
end

return TowerBuilder
