--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameShared = ReplicatedStorage:WaitForChild("GameShared")
local Contract = require(GameShared:WaitForChild("StoryContract"))
local Config = require(GameShared:WaitForChild("SystemsConfig"))
local RuntimeRules = require(GameShared:WaitForChild("RuntimeRules"))
local PathAgent = require(script.Parent:WaitForChild("PathAgent"))

local HostileNpcService = {}
HostileNpcService.__index = HostileNpcService

function HostileNpcService.new(
	roleService: any,
	npcType: string,
	settings: any,
	onCaught: (Player, string) -> boolean,
	onDetected: ((Player, string) -> ())?
)
	return setmetatable({
		roleService = roleService,
		npcType = npcType,
		settings = settings,
		onCaught = onCaught,
		onDetected = onDetected,
		agent = nil,
		active = false,
		chasing = npcType == "Bella",
		patrolPoints = {},
		patrolIndex = 1,
		elapsed = 0,
		catchDebounce = false,
		lastDetectedAt = -math.huge,
		connection = nil,
	}, HostileNpcService)
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

function HostileNpcService._tryAttach(self: any, candidate: Instance)
	if self.agent and self.agent.model.Parent == nil then
		self.agent:Cancel()
		self.agent = nil
	end
	if self.agent or not candidate:IsA("Model") then
		return
	end
	if candidate:GetAttribute(Contract.Attributes.NPCType) ~= self.npcType then
		return
	end
	self.agent = PathAgent.new(candidate)
	if self.agent then
		self.agent.humanoid.WalkSpeed = self.settings.WalkSpeed
	end
end

function HostileNpcService._discover(self: any)
	for _, candidate in CollectionService:GetTagged(Contract.Tags.NPCSpawn) do
		self:_tryAttach(candidate)
	end
	local points = {}
	for _, point in CollectionService:GetTagged(Contract.Tags.PatrolPoint) do
		if point:GetAttribute(Contract.Attributes.NPCType) == self.npcType then
			table.insert(points, point)
		end
	end
	table.sort(points, function(a, b)
		return (a:GetAttribute(Contract.Attributes.SequenceIndex) or 0)
			< (b:GetAttribute(Contract.Attributes.SequenceIndex) or 0)
	end)
	self.patrolPoints = points
end

function HostileNpcService._canSee(self: any, character: Model, targetRoot: BasePart): boolean
	if not self.agent then
		return false
	end
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { self.agent.model }
	local result = workspace:Raycast(
		self.agent.root.Position,
		targetRoot.Position - self.agent.root.Position,
		parameters
	)
	return result == nil or result.Instance:IsDescendantOf(character)
end

function HostileNpcService._patrol(self: any)
	if not self.agent or #self.patrolPoints == 0 then
		return
	end
	local point = self.patrolPoints[self.patrolIndex]
	local destination = positionOf(point)
	if not destination then
		return
	end
	self.agent:MoveTo(destination)
	if (self.agent.root.Position - destination).Magnitude < 6 then
		self.patrolIndex = (self.patrolIndex % #self.patrolPoints) + 1
	end
end

function HostileNpcService._step(self: any)
	if not self.active or not self.agent then
		return
	end
	local player = self.roleService:GetProtagonist()
	local character = player and player.Character
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not player or not character or not targetRoot or not targetRoot:IsA("BasePart") then
		self:_patrol()
		return
	end
	local distance = (self.agent.root.Position - targetRoot.Position).Magnitude
	if distance <= self.settings.CatchDistance and not self.catchDebounce then
		local accepted = self.onCaught(player, self.npcType)
		if accepted then
			self.catchDebounce = true
			task.delay(1.5, function()
				self.catchDebounce = false
			end)
		end
		return
	end

	local wasChasing = self.chasing
	if self.npcType == "Bella" then
		self.chasing = true
	elseif self.chasing then
		self.chasing = distance <= self.settings.DisengageDistance
	else
		self.chasing = distance <= self.settings.DetectionDistance
			and self:_canSee(character, targetRoot)
	end
	local now = os.clock()
	if
		self.onDetected
		and RuntimeRules.shouldEmitDetection(
			wasChasing,
			self.chasing,
			self.lastDetectedAt,
			now,
			Config.NPC.DetectionCooldownSeconds
		)
	then
		self.lastDetectedAt = now
		self.onDetected(player, self.npcType)
	end

	if self.chasing then
		self.agent:MoveTo(targetRoot.Position)
	else
		self:_patrol()
	end
end

function HostileNpcService.Start(self: any)
	self:_discover()
	CollectionService:GetInstanceAddedSignal(Contract.Tags.NPCSpawn):Connect(function(candidate)
		self:_tryAttach(candidate)
	end)
	self.connection = RunService.Heartbeat:Connect(function(dt)
		if not self.active then
			return
		end
		self.elapsed += dt
		if self.elapsed >= Config.NPC.RepathSeconds then
			self.elapsed = 0
			self:_step()
		end
	end)
end

function HostileNpcService.SetActive(self: any, active: boolean)
	self.active = active
	if active then
		self:_discover()
		self.elapsed = Config.NPC.RepathSeconds
	end
	if not active and self.agent then
		self.agent:Cancel()
	end
end

function HostileNpcService.Reset(self: any)
	self.active = false
	self.chasing = self.npcType == "Bella"
	self.patrolIndex = 1
	self.catchDebounce = false
	self.lastDetectedAt = -math.huge
	if self.agent then
		self.agent:Reset()
	end
end

return HostileNpcService
