--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Contract = require(ReplicatedStorage:WaitForChild("GameShared"):WaitForChild("StoryContract"))
local PathAgent = require(script.Parent:WaitForChild("PathAgent"))

local FriendlyRamboService = {}
FriendlyRamboService.__index = FriendlyRamboService

function FriendlyRamboService.new(roleService: any)
	return setmetatable({
		roleService = roleService,
		agent = nil,
		active = false,
		markers = {},
		markerIndex = 1,
		elapsed = 0,
		connection = nil,
	}, FriendlyRamboService)
end

function FriendlyRamboService._discover(self: any)
	if self.agent and self.agent.model.Parent == nil then
		self.agent:Cancel()
		self.agent = nil
	end
	if not self.agent then
		for _, candidate in CollectionService:GetTagged(Contract.Tags.NPCSpawn) do
			if
				candidate:GetAttribute(Contract.Attributes.NPCType) == "FriendlyRambo"
				and candidate:IsA("Model")
			then
				self.agent = PathAgent.new(candidate)
				break
			end
		end
	end
	local markers = {}
	for _, marker in CollectionService:GetTagged(Contract.Tags.CinematicMarker) do
		if marker:GetAttribute(Contract.Attributes.MarkerId) == "RamboGuideTarget" then
			table.insert(markers, marker)
		end
	end
	table.sort(markers, function(a, b)
		return (a:GetAttribute(Contract.Attributes.SequenceIndex) or 0)
			< (b:GetAttribute(Contract.Attributes.SequenceIndex) or 0)
	end)
	self.markers = markers
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

function FriendlyRamboService.Start(self: any)
	self:_discover()
	CollectionService:GetInstanceAddedSignal(Contract.Tags.NPCSpawn):Connect(function()
		self:_discover()
	end)
	CollectionService:GetInstanceAddedSignal(Contract.Tags.CinematicMarker):Connect(function()
		self:_discover()
	end)
	self.connection = RunService.Heartbeat:Connect(function(dt)
		if not self.active or not self.agent then
			return
		end
		self.elapsed += dt
		if self.elapsed < 0.75 then
			return
		end
		self.elapsed = 0
		local player = self.roleService:GetProtagonist()
		local root = player
			and player.Character
			and player.Character:FindFirstChild("HumanoidRootPart")
		local marker = self.markers[self.markerIndex]
		local destination = marker and positionOf(marker)
		if not root or not root:IsA("BasePart") or not destination then
			return
		end
		local separation = (self.agent.root.Position - root.Position).Magnitude
		if separation > 32 then
			self.agent:Cancel()
			return
		end
		self.agent:MoveTo(destination)
		if
			(self.agent.root.Position - destination).Magnitude < 6
			and (root.Position - destination).Magnitude < 12
		then
			self.markerIndex = math.min(self.markerIndex + 1, #self.markers)
		end
	end)
end

function FriendlyRamboService.SetActive(self: any, active: boolean)
	self.active = active
	if active then
		self:_discover()
	end
	if not active and self.agent then
		self.agent:Cancel()
	end
end

function FriendlyRamboService.Reset(self: any)
	self.active = false
	self.markerIndex = 1
	if self.agent then
		self.agent:Reset()
	end
end

return FriendlyRamboService
