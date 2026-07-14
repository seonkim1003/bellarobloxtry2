--!strict
--[[
	Builds / refreshes a no-fail ASMR tower: 28 steps across 7 right-angle flights.
	Uses CollectionService ASMRStep tags and ContentConfig sound IDs.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()
local Tagging = require(script.Parent:WaitForChild("Tagging"))

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
		then
			child:Destroy()
		end
	end
end

function TowerBuilder.rebuildFlights()
	local tower = ensureTowerModel()
	clearGeneratedSteps(tower)

	local stepCount = ContentConfig.towerStepCount
	local flights = ContentConfig.towerFlights
	local stepsPerFlight = math.ceil(stepCount / flights)

	local origin = Vector3.new(140, 0, 0)
	local facing = 0
	local cursor = origin

	for flight = 0, flights - 1 do
		local flightPart = Instance.new("Part")
		flightPart.Name = `TowerFlight_{flight + 1}`
		flightPart.Anchored = true
		flightPart.CanCollide = true
		flightPart.Size = Vector3.new(stepsPerFlight * 3 + 2, 1, 6)
		flightPart.Color = Color3.fromRGB(55, 50, 65)
		flightPart.Material = Enum.Material.Brick
		local mid = cursor
			+ Vector3.new(
				math.cos(facing) * (flightPart.Size.X / 2),
				1 + flight * 4,
				math.sin(facing) * (flightPart.Size.X / 2)
			)
		flightPart.CFrame = CFrame.new(mid) * CFrame.Angles(0, -facing, 0)
		flightPart.Parent = tower

		for stepInFlight = 1, stepsPerFlight do
			local index = flight * stepsPerFlight + stepInFlight
			if index > stepCount then
				break
			end

			local step = Instance.new("Part")
			step.Name = `ASMRStep_{index}`
			step.Anchored = true
			step.CanCollide = true
			step.Size = Vector3.new(2.6, 0.35, 4.5)
			step.Color = Color3.fromRGB(170, 150, 100)
			step.Material = Enum.Material.WoodPlanks
			local along = (stepInFlight - 0.5) * 3
			local position = cursor
				+ Vector3.new(
					math.cos(facing) * along,
					1.4 + flight * 4 + stepInFlight * 0.15,
					math.sin(facing) * along
				)
			step.CFrame = CFrame.new(position) * CFrame.Angles(0, -facing, 0)
			step.Parent = tower

			local soundId = ContentConfig.sounds.asmrSteps[index] or "rbxassetid://0"
			Tagging.applyMarker(step, "ASMRStep", {
				SceneId = "Tower",
				MarkerId = `ASMRStep_{index}`,
				SoundId = soundId,
				SequenceIndex = index,
			})
		end

		-- Right-angle turn for next flight.
		facing += math.rad(90)
		cursor = cursor
			+ Vector3.new(
				math.cos(facing - math.rad(90)) * (stepsPerFlight * 3),
				0,
				math.sin(facing - math.rad(90)) * (stepsPerFlight * 3)
			)
	end

	-- Soft rail for readability (collision on for no-fail guidance feel).
	local rail = Instance.new("Part")
	rail.Name = "TowerRail"
	rail.Anchored = true
	rail.CanCollide = true
	rail.Size = Vector3.new(1, 12, 1)
	rail.Color = Color3.fromRGB(90, 90, 100)
	rail.Material = Enum.Material.Metal
	rail.CFrame = CFrame.new(origin + Vector3.new(-2, 8, -2))
	rail.Parent = tower

	-- Ensure spawn / robber / cinematic markers still tagged if present.
	for _, tagged in CollectionService:GetTagged("ASMRStep") do
		if tagged:IsDescendantOf(tower) and tagged:IsA("BasePart") then
			tagged.CanCollide = true
		end
	end
end

return TowerBuilder
