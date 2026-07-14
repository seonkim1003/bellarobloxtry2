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
	self:Cancel()
	self._generation += 1
	local token = self._generation
	self.fightGeneration += 1
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
		if self._generation == token then
			self.active = false
		end
	end)
end

function DogFightService.Cancel(self: any)
	self._generation += 1
	self.active = false
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

return DogFightService
