--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameShared = ReplicatedStorage:WaitForChild("GameShared")
local Contract = require(GameShared:WaitForChild("StoryContract"))

local StoryService = {}
StoryService.__index = StoryService

local transitions: {[string]: {[string]: boolean}} = {
	[Contract.States.RoleLobby] = { [Contract.States.MazeIntro] = true },
	[Contract.States.MazeIntro] = { [Contract.States.BellaChase] = true },
	[Contract.States.BellaChase] = { [Contract.States.RamboTaken] = true },
	[Contract.States.RamboTaken] = { [Contract.States.GuideEncounter] = true },
	[Contract.States.GuideEncounter] = { [Contract.States.TowerClimb] = true },
	[Contract.States.TowerClimb] = { [Contract.States.RevivePrompt] = true },
	[Contract.States.RevivePrompt] = { [Contract.States.Corruption] = true },
	[Contract.States.Corruption] = { [Contract.States.FieldHunt] = true },
	[Contract.States.FieldHunt] = { [Contract.States.LetterTheft] = true },
	[Contract.States.LetterTheft] = { [Contract.States.DogFight] = true },
	[Contract.States.DogFight] = { [Contract.States.Epilogue] = true },
	[Contract.States.Epilogue] = { [Contract.States.LetterReveal] = true },
	[Contract.States.LetterReveal] = { [Contract.States.Credits] = true },
}

export type StoryService = typeof(setmetatable({} :: {
	remotes: {[string]: RemoteEvent},
	roleService: any,
	state: string,
	revision: number,
	changed: BindableEvent,
}, StoryService))

function StoryService.new(remotes: {[string]: RemoteEvent}, roleService: any): StoryService
	return setmetatable({
		remotes = remotes,
		roleService = roleService,
		state = Contract.States.RoleLobby,
		revision = 0,
		changed = Instance.new("BindableEvent"),
	}, StoryService)
end

function StoryService:_broadcast(cue: string)
	self.remotes[Contract.ServerEvents.StoryCue]:FireAllClients({
		contractVersion = Contract.Version,
		cue = cue,
		state = self.state,
		revision = self.revision,
	})
end

function StoryService:GetState(): string
	return self.state
end

function StoryService:GetRevision(): number
	return self.revision
end

function StoryService:CanTransition(nextState: string): boolean
	local allowed = transitions[self.state]
	return allowed ~= nil and allowed[nextState] == true
end

function StoryService:Transition(nextState: string, reason: string?): boolean
	if not self:CanTransition(nextState) then
		warn(`Rejected story transition {self.state} -> {nextState}`)
		return false
	end
	local previous = self.state
	self.state = nextState
	self.revision += 1
	self:_broadcast(Contract.Cues.StateChanged)
	self.changed:Fire(nextState, previous, reason)
	return true
end

function StoryService:StartFor(player: Player): boolean
	if player ~= self.roleService:GetProtagonist() or self.state ~= Contract.States.RoleLobby then
		return false
	end
	return self:Transition(Contract.States.MazeIntro, "ProtagonistAssigned")
end

function StoryService:ResetToLobby(reason: string?)
	self.state = Contract.States.RoleLobby
	self.revision += 1
	self:_broadcast(Contract.Cues.ReplayReset)
	self.changed:Fire(self.state, nil, reason or "Reset")
end

function StoryService:SendSnapshot(player: Player)
	self.remotes[Contract.ServerEvents.StoryCue]:FireClient(player, {
		contractVersion = Contract.Version,
		cue = Contract.Cues.StateChanged,
		state = self.state,
		revision = self.revision,
	})
end

function StoryService:ObserveChanged(callback: (string, string?, string?) -> ()): RBXScriptConnection
	return self.changed.Event:Connect(callback)
end

return StoryService
