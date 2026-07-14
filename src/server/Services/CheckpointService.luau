--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contract = require(ReplicatedStorage:WaitForChild("GameShared"):WaitForChild("StoryContract"))

local CheckpointService = {}
CheckpointService.__index = CheckpointService

export type CheckpointService = typeof(setmetatable(
	{} :: {
		checkpoints: { [Player]: CFrame? },
		spawns: { [string]: CFrame },
		playerConnections: { [Player]: RBXScriptConnection },
		started: boolean,
	},
	CheckpointService
))

function CheckpointService.new(): CheckpointService
	return setmetatable({
		checkpoints = {},
		spawns = {},
		playerConnections = {},
		started = false,
	}, CheckpointService)
end

local function markerCFrame(marker: Instance): CFrame?
	if marker:IsA("BasePart") then
		return marker.CFrame
	elseif marker:IsA("Model") then
		return marker:GetPivot()
	end
	return nil
end

function CheckpointService._cacheMarker(self: CheckpointService, marker: Instance)
	local sceneId = marker:GetAttribute(Contract.Attributes.SceneId)
	local found = markerCFrame(marker)
	if typeof(sceneId) == "string" and found then
		self.spawns[sceneId] = found
	end
end

function CheckpointService._restoreCharacter(
	self: CheckpointService,
	player: Player,
	character: Model
)
	if self.checkpoints[player] == nil then
		return
	end
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if
			root
			and root:IsA("BasePart")
			and player.Parent == Players
			and player.Character == character
		then
			self:Respawn(player)
		end
	end)
end

function CheckpointService._observePlayer(self: CheckpointService, player: Player)
	if self.playerConnections[player] then
		return
	end
	self.playerConnections[player] = player.CharacterAdded:Connect(function(character)
		self:_restoreCharacter(player, character)
	end)
	if player.Character then
		self:_restoreCharacter(player, player.Character)
	end
end

function CheckpointService._forgetPlayer(self: CheckpointService, player: Player)
	local connection = self.playerConnections[player]
	if connection then
		connection:Disconnect()
		self.playerConnections[player] = nil
	end
	self.checkpoints[player] = nil
end

function CheckpointService.Start(self: CheckpointService)
	if self.started then
		return
	end
	self.started = true
	for _, marker in CollectionService:GetTagged(Contract.Tags.SceneSpawn) do
		self:_cacheMarker(marker)
	end
	CollectionService:GetInstanceAddedSignal(Contract.Tags.SceneSpawn):Connect(function(marker)
		self:_cacheMarker(marker)
	end)
	CollectionService:GetInstanceRemovedSignal(Contract.Tags.SceneSpawn):Connect(function(marker)
		local sceneId = marker:GetAttribute(Contract.Attributes.SceneId)
		if typeof(sceneId) ~= "string" then
			return
		end
		self.spawns[sceneId] = nil
		for _, candidate in CollectionService:GetTagged(Contract.Tags.SceneSpawn) do
			if
				candidate ~= marker
				and candidate:GetAttribute(Contract.Attributes.SceneId) == sceneId
			then
				self:_cacheMarker(candidate)
				break
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		self:_observePlayer(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_forgetPlayer(player)
	end)
	for _, player in Players:GetPlayers() do
		self:_observePlayer(player)
	end
end

function CheckpointService.FindSceneSpawn(self: CheckpointService, sceneId: string): CFrame?
	return self.spawns[sceneId]
end

function CheckpointService.Set(self: CheckpointService, player: Player, sceneId: string): boolean
	local found = self:FindSceneSpawn(sceneId)
	if not found then
		warn(`Missing SceneSpawn for checkpoint {sceneId}`)
		return false
	end
	self.checkpoints[player] = found
	player:SetAttribute("CheckpointSceneId", sceneId)
	return true
end

function CheckpointService.SetCurrent(self: CheckpointService, player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	self.checkpoints[player] = character:GetPivot()
	player:SetAttribute("CheckpointSceneId", "CurrentPosition")
	return true
end

function CheckpointService.Respawn(self: CheckpointService, player: Player): boolean
	local destination = self.checkpoints[player]
	local character = player.Character
	if not destination or not character then
		return false
	end
	character:PivotTo(destination + Vector3.new(0, 3, 0))
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
	return true
end

function CheckpointService.Clear(self: CheckpointService, player: Player)
	self.checkpoints[player] = nil
	player:SetAttribute("CheckpointSceneId", nil)
end

function CheckpointService.ClearAll(self: CheckpointService)
	table.clear(self.checkpoints)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("CheckpointSceneId", nil)
	end
end

return CheckpointService
