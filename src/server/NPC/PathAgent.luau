--!strict

local PathfindingService = game:GetService("PathfindingService")

local PathAgent = {}
PathAgent.__index = PathAgent

export type PathAgent = typeof(setmetatable(
	{} :: {
		model: Model,
		humanoid: Humanoid,
		root: BasePart,
		parameters: { [string]: any },
		generation: number,
		initialPivot: CFrame,
		moving: boolean,
		lastMoveStartedAt: number,
	},
	PathAgent
))

function PathAgent.new(model: Model, parameters: { [string]: any }?): PathAgent?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		warn(`NPC {model:GetFullName()} needs a Humanoid and HumanoidRootPart`)
		return nil
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.Anchored then
			pcall(function()
				descendant:SetNetworkOwner(nil)
			end)
		end
	end
	return setmetatable({
		model = model,
		humanoid = humanoid,
		root = root,
		parameters = parameters or {},
		generation = 0,
		initialPivot = model:GetPivot(),
		moving = false,
		lastMoveStartedAt = 0,
	}, PathAgent)
end

function PathAgent.Cancel(self: PathAgent)
	self.generation += 1
	self.moving = false
	self.humanoid:MoveTo(self.root.Position)
end

function PathAgent.MoveTo(self: PathAgent, destination: Vector3)
	local now = os.clock()
	if self.moving and now - self.lastMoveStartedAt < 1.25 then
		return
	end
	self.generation += 1
	local generation = self.generation
	self.moving = true
	self.lastMoveStartedAt = now
	local path = PathfindingService:CreatePath(self.parameters)
	local success = pcall(function()
		path:ComputeAsync(self.root.Position, destination)
	end)
	if not success or path.Status ~= Enum.PathStatus.Success then
		self.humanoid:MoveTo(destination)
		self.moving = false
		return
	end

	local waypoints = path:GetWaypoints()
	task.spawn(function()
		for index = 2, #waypoints do
			if generation ~= self.generation or self.model.Parent == nil then
				return
			end
			local waypoint = waypoints[index]
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				self.humanoid.Jump = true
			end
			self.humanoid:MoveTo(waypoint.Position)
			local reached = self.humanoid.MoveToFinished:Wait()
			if not reached then
				if generation == self.generation then
					self.moving = false
				end
				return
			end
		end
		if generation == self.generation then
			self.moving = false
		end
	end)
end

function PathAgent.Reset(self: PathAgent)
	self:Cancel()
	self.model:PivotTo(self.initialPivot)
	self.humanoid.Health = self.humanoid.MaxHealth
end

return PathAgent
