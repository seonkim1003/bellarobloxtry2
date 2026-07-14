--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contract = require(ReplicatedStorage:WaitForChild("GameShared"):WaitForChild("StoryContract"))

local CheckpointService = {}
CheckpointService.__index = CheckpointService

export type CheckpointService = typeof(setmetatable({} :: {
	checkpoints: {[Player]: CFrame},
}, CheckpointService))

function CheckpointService.new(): CheckpointService
	return setmetatable({ checkpoints = {} }, CheckpointService)
end

local function markerCFrame(marker: Instance): CFrame?
	if marker:IsA("BasePart") then
		return marker.CFrame
	elseif marker:IsA("Model") then
		return marker:GetPivot()
	end
	return nil
end

function CheckpointService:FindSceneSpawn(sceneId: string): CFrame?
	for _, marker in CollectionService:GetTagged(Contract.Tags.SceneSpawn) do
		if marker:GetAttribute(Contract.Attributes.SceneId) == sceneId then
			local found = markerCFrame(marker)
			if found then
				return found
			end
		end
	end
	return nil
end

function CheckpointService:Set(player: Player, sceneId: string): boolean
	local found = self:FindSceneSpawn(sceneId)
	if not found then
		warn(`Missing SceneSpawn for checkpoint {sceneId}`)
		return false
	end
	self.checkpoints[player] = found
	return true
end

function CheckpointService:SetCurrent(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	self.checkpoints[player] = character:GetPivot()
	return true
end

function CheckpointService:Respawn(player: Player): boolean
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

function CheckpointService:Clear(player: Player)
	self.checkpoints[player] = nil
end

function CheckpointService:ClearAll()
	table.clear(self.checkpoints)
end

return CheckpointService
