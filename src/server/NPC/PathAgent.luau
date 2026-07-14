--!strict

local PathfindingService = game:GetService("PathfindingService")

local NpcLocomotion = require(script.Parent:WaitForChild("NpcLocomotion"))

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
		lastDestination: Vector3?,
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
	local humanoidCount = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Humanoid") then
			humanoidCount += 1
			if descendant ~= humanoid then
				warn(`[PathAgent] Removing non-authoritative Humanoid from {model:GetFullName()}`)
				descendant:Destroy()
			end
		end
	end
	if humanoidCount ~= 1 then
		warn(
			`[PathAgent] {model:GetFullName()} had {humanoidCount} Humanoids; expected exactly one`
		)
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.Anchored then
			pcall(function()
				descendant:SetNetworkOwner(nil)
			end)
		end
	end
	NpcLocomotion.attach(model, root)

	return setmetatable({
		model = model,
		humanoid = humanoid,
		root = root,
		parameters = parameters or {},
		generation = 0,
		initialPivot = model:GetPivot(),
		moving = false,
		lastMoveStartedAt = 0,
		lastDestination = nil,
	}, PathAgent)
end

function PathAgent.Cancel(self: PathAgent)
	self.generation += 1
	self.moving = false
	self.lastDestination = nil
	self.humanoid:MoveTo(self.root.Position)
end

function PathAgent.MoveTo(self: PathAgent, destination: Vector3)
	local now = os.clock()
	if self.moving and self.lastDestination then
		local destinationShift = (destination - self.lastDestination).Magnitude
		local elapsed = now - self.lastMoveStartedAt
		if destinationShift < 4 and elapsed < 2 then
			return
		end
	end
	self.generation += 1
	local generation = self.generation
	self.moving = true
	self.lastMoveStartedAt = now
	self.lastDestination = destination
	local path = PathfindingService:CreatePath(self.parameters)
	local success = pcall(function()
		path:ComputeAsync(self.root.Position, destination)
	end)
	if generation ~= self.generation or not self.model:IsDescendantOf(game) then
		return
	end
	if not success or path.Status ~= Enum.PathStatus.Success then
		self.humanoid:MoveTo(destination)
		task.spawn(function()
			self.humanoid.MoveToFinished:Wait()
			if generation == self.generation then
				self.moving = false
			end
		end)
		return
	end

	local waypoints = path:GetWaypoints()
	if #waypoints < 2 then
		self.humanoid:MoveTo(destination)
		self.moving = false
		return
	end
	task.spawn(function()
		local blocked = false
		local currentWaypointIndex = 2
		local blockedConnection = path.Blocked:Connect(function(blockedIndex)
			if blockedIndex >= currentWaypointIndex then
				blocked = true
				-- Interrupt MoveToFinished:Wait so this route can recover immediately.
				self.humanoid:MoveTo(self.root.Position)
			end
		end)
		for index = 2, #waypoints do
			currentWaypointIndex = index
			if generation ~= self.generation or not self.model:IsDescendantOf(game) or blocked then
				blockedConnection:Disconnect()
				if generation == self.generation then
					self.moving = false
					if blocked then
						task.defer(function()
							if
								generation == self.generation and self.model:IsDescendantOf(game)
							then
								self:MoveTo(destination)
							end
						end)
					end
				end
				return
			end
			local waypoint = waypoints[index]
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				self.humanoid.Jump = true
			end
			self.humanoid:MoveTo(waypoint.Position)
			local reached = self.humanoid.MoveToFinished:Wait()
			if blocked or not reached then
				blockedConnection:Disconnect()
				if generation == self.generation then
					self.moving = false
					task.defer(function()
						if generation == self.generation and self.model:IsDescendantOf(game) then
							self:MoveTo(destination)
						end
					end)
				end
				return
			end
		end
		blockedConnection:Disconnect()
		if generation == self.generation then
			self.moving = false
		end
	end)
end

function PathAgent.Reset(self: PathAgent)
	self:Cancel()
	self.model:PivotTo(self.initialPivot)
	self.humanoid.Health = self.humanoid.MaxHealth
	NpcLocomotion.detach(self.model)
	NpcLocomotion.attach(self.model, self.root)
end

return PathAgent
