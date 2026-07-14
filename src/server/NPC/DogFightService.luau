--!strict
--[[
	Isolated server-owned DogFight beat broadcaster.
	Bootstrap/Gameplay wiring is coordinator-owned; this module stays self-contained.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameShared = ReplicatedStorage:WaitForChild("GameShared")
local Contract = require(GameShared:WaitForChild("StoryContract"))
local DogFightTimeline = require(GameShared:WaitForChild("DogFightTimeline"))

local DogFightService = {}
DogFightService.__index = DogFightService

export type DogFightService = typeof(setmetatable({} :: any, DogFightService))

function DogFightService.new(remotes: { [string]: RemoteEvent }): DogFightService
	return setmetatable({
		remotes = remotes,
		fightGeneration = 0,
		storyRevision = 0,
		active = false,
		_generation = 0,
		started = false,
		completed = Instance.new("BindableEvent"),
		completedFightGeneration = 0,
		completedStoryRevision = 0,
	}, DogFightService)
end

function DogFightService._fireBeat(self: any, beatIndex: number, beatId: string, token: number)
	if self._generation ~= token or not self.active then
		return
	end
	local remote = self.remotes[Contract.ServerEvents.FightBeat]
	if remote == nil then
		return
	end
	remote:FireAllClients({
		contractVersion = Contract.Version,
		storyRevision = self.storyRevision,
		fightGeneration = self.fightGeneration,
		beatIndex = beatIndex,
		beatId = beatId,
	})
end

function DogFightService.Begin(self: any, storyRevision: number)
	if not self.started then
		return
	end
	self:Cancel()
	self._generation += 1
	local token = self._generation
	self.fightGeneration += 1
	local fightGeneration = self.fightGeneration
	self.storyRevision = storyRevision
	self.active = true

	local reducedMotion = false
	task.spawn(function()
		for _, beat in DogFightTimeline.Beats do
			if self._generation ~= token or not self.active then
				return
			end
			self:_fireBeat(beat.beatIndex, beat.beatId, token)
			local dwell = DogFightTimeline.durationForBeat(beat, reducedMotion)
			task.wait(dwell)
		end
		if
			self._generation == token
			and self.active
			and self.fightGeneration == fightGeneration
			and self.storyRevision == storyRevision
		then
			self.active = false
			self.completedFightGeneration = fightGeneration
			self.completedStoryRevision = storyRevision
			self.completed:Fire(storyRevision, fightGeneration)
		end
	end)
end

function DogFightService.Cancel(self: any)
	self._generation += 1
	self.active = false
	self.completedFightGeneration = 0
	self.completedStoryRevision = 0
end

function DogFightService.Start(self: any)
	if self.started then
		return
	end
	self.started = true
end

function DogFightService.OnStoryStateChanged(self: any, state: string, storyRevision: number)
	if state == Contract.States.DogFight then
		self:Begin(storyRevision)
	else
		self:Cancel()
	end
end

function DogFightService.IsActive(self: any): boolean
	return self.active == true
end

function DogFightService.GetFightGeneration(self: any): number
	return self.fightGeneration
end

function DogFightService.IsCompletedGeneration(
	self: any,
	storyRevision: number,
	fightGeneration: number
): boolean
	return self.started
		and self.active == false
		and self.completedStoryRevision == storyRevision
		and self.completedFightGeneration == fightGeneration
end

function DogFightService.ObserveCompleted(
	self: any,
	callback: (number, number) -> ()
): RBXScriptConnection
	return self.completed.Event:Connect(callback)
end

return DogFightService
