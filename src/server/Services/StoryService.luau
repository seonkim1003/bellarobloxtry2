--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameShared = ReplicatedStorage:WaitForChild("GameShared")
local Contract = require(GameShared:WaitForChild("StoryContract"))
local RuntimeRules = require(GameShared:WaitForChild("RuntimeRules"))

local StoryService = {}
StoryService.__index = StoryService

export type StoryService = typeof(setmetatable(
	{} :: {
		remotes: { [string]: RemoteEvent },
		roleService: any,
		state: string,
		revision: number,
		stateEnteredAt: number,
		changed: BindableEvent,
	},
	StoryService
))

function StoryService.new(remotes: { [string]: RemoteEvent }, roleService: any): StoryService
	return setmetatable({
		remotes = remotes,
		roleService = roleService,
		state = Contract.States.RoleLobby,
		revision = 0,
		stateEnteredAt = os.clock(),
		changed = Instance.new("BindableEvent"),
	}, StoryService)
end

function StoryService._broadcast(self: StoryService, cue: string)
	self.remotes[Contract.ServerEvents.StoryCue]:FireAllClients({
		contractVersion = Contract.Version,
		cue = cue,
		state = self.state,
		revision = self.revision,
	})
end

function StoryService.GetState(self: StoryService): string
	return self.state
end

function StoryService.GetRevision(self: StoryService): number
	return self.revision
end

function StoryService.GetStateEnteredAt(self: StoryService): number
	return self.stateEnteredAt
end

function StoryService.CanTransition(self: StoryService, nextState: string): boolean
	return RuntimeRules.canTransition(self.state, nextState)
end

function StoryService.Transition(self: StoryService, nextState: string, reason: string?): boolean
	if not self:CanTransition(nextState) then
		warn(`Rejected story transition {self.state} -> {nextState}`)
		return false
	end
	local previous = self.state
	self.state = nextState
	self.revision += 1
	self.stateEnteredAt = os.clock()
	self:_broadcast(Contract.Cues.StateChanged)
	self.changed:Fire(nextState, previous, reason)
	return true
end

function StoryService.StartFor(self: StoryService, player: Player): boolean
	if player ~= self.roleService:GetProtagonist() or self.state ~= Contract.States.RoleLobby then
		return false
	end
	return self:Transition(Contract.States.MazeIntro, "ProtagonistAssigned")
end

function StoryService.ResetToLobby(self: StoryService, reason: string?)
	self.state = Contract.States.RoleLobby
	self.revision += 1
	self.stateEnteredAt = os.clock()
	self:_broadcast(Contract.Cues.ReplayReset)
	self.changed:Fire(self.state, nil, reason or "Reset")
end

function StoryService.SendSnapshot(self: StoryService, player: Player)
	self.remotes[Contract.ServerEvents.StoryCue]:FireClient(player, {
		contractVersion = Contract.Version,
		cue = Contract.Cues.StateChanged,
		state = self.state,
		revision = self.revision,
	})
end

function StoryService.ObserveChanged(
	self: StoryService,
	callback: (string, string?, string?) -> ()
): RBXScriptConnection
	return self.changed.Event:Connect(callback)
end

return StoryService
