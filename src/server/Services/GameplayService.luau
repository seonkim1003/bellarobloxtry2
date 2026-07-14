--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameShared = ReplicatedStorage:WaitForChild("GameShared")
local Contract = require(GameShared:WaitForChild("StoryContract"))
local Config = require(GameShared:WaitForChild("SystemsConfig"))

local GameplayService = {}
GameplayService.__index = GameplayService

local cinematicTransitions = {
	[Contract.States.MazeIntro] = { cue = "MazeIntro", next = Contract.States.BellaChase },
	[Contract.States.RamboTaken] = { cue = "RamboTaken", next = Contract.States.GuideEncounter },
	[Contract.States.GuideEncounter] = { cue = "GuideEncounter", next = Contract.States.TowerClimb },
	[Contract.States.Corruption] = { cue = "Corruption", next = Contract.States.FieldHunt },
	[Contract.States.LetterTheft] = { cue = "LetterTheft", next = Contract.States.DogFight },
	[Contract.States.DogFight] = { cue = "DogFight", next = Contract.States.Epilogue },
	[Contract.States.Epilogue] = { cue = "Epilogue", next = Contract.States.LetterReveal },
	[Contract.States.LetterReveal] = { cue = "LetterReveal", next = Contract.States.Credits },
}

function GameplayService.new(
	remotes: { [string]: RemoteEvent },
	validator: any,
	roleService: any,
	storyService: any,
	checkpointService: any,
	friendlyRambo: any,
	bella: any,
	evilRambo: any
)
	return setmetatable({
		remotes = remotes,
		validator = validator,
		roleService = roleService,
		storyService = storyService,
		checkpoints = checkpointService,
		friendlyRambo = friendlyRambo,
		bella = bella,
		evilRambo = evilRambo,
		fragments = {} :: { [string]: boolean },
		fragmentCount = 0,
		bound = {} :: { [Instance]: boolean },
		promptBound = {} :: { [Instance]: boolean },
		fragmentPrompts = {} :: { [Instance]: ProximityPrompt },
	}, GameplayService)
end

function GameplayService._isProtagonist(self: any, player: Player): boolean
	return self.validator.HasRole(self.roleService, player, Contract.Roles.Protagonist)
end

function GameplayService._playerFromHit(_self: any, hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return if model then Players:GetPlayerFromCharacter(model) else nil
end

function GameplayService._fireObjective(self: any, player: Player, objective: string)
	self.remotes[Contract.ServerEvents.ObjectiveUpdate]:FireClient(player, {
		state = self.storyService:GetState(),
		objective = objective,
	})
end

function GameplayService._onCatch(self: any, player: Player, npcType: string)
	if not self:_isProtagonist(player) then
		return
	end
	local expectedState = if npcType == "Bella"
		then Contract.States.BellaChase
		else Contract.States.FieldHunt
	if not self.validator.IsStoryState(self.storyService, expectedState) then
		return
	end
	if npcType == "EvilRambo" then
		self.remotes[Contract.ServerEvents.FragmentUpdate]:FireClient(player, {
			count = self.fragmentCount,
			total = Config.Story.FragmentCount,
			caught = true,
		})
	end
	self.checkpoints:Respawn(player)
	self:_fireObjective(
		player,
		if npcType == "Bella" then "Escape Bella" else "Find the letter fragments"
	)
end

function GameplayService._onDetected(self: any, player: Player, npcType: string)
	if
		npcType == "EvilRambo"
		and self:_isProtagonist(player)
		and self.validator.IsStoryState(self.storyService, Contract.States.FieldHunt)
	then
		self.remotes[Contract.ServerEvents.FragmentUpdate]:FireClient(player, {
			count = self.fragmentCount,
			total = Config.Story.FragmentCount,
			detected = true,
		})
	end
end

function GameplayService._bindTouched(self: any, instance: Instance, callback: (Player) -> ())
	if self.bound[instance] or not instance:IsA("BasePart") then
		return
	end
	self.bound[instance] = true
	instance.Touched:Connect(function(hit)
		local player = self:_playerFromHit(hit)
		if player then
			callback(player)
		end
	end)
end

function GameplayService._bindPrompt(
	self: any,
	instance: Instance,
	actionText: string,
	callback: (Player) -> ()
): ProximityPrompt?
	if self.promptBound[instance] then
		return nil
	end
	local foundPrompt = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
	local prompt: ProximityPrompt? = if foundPrompt and foundPrompt:IsA("ProximityPrompt")
		then foundPrompt
		else nil
	if not prompt then
		local attachmentParent: Instance? = nil
		if instance:IsA("BasePart") then
			attachmentParent = instance
		elseif instance:IsA("Model") then
			attachmentParent = instance.PrimaryPart
				or instance:FindFirstChildWhichIsA("BasePart", true)
		end
		if not attachmentParent then
			warn(`Cannot create ProximityPrompt for {instance:GetFullName()}`)
			return nil
		end
		local newPrompt = Instance.new("ProximityPrompt")
		newPrompt.Name = "GameInteractionPrompt"
		newPrompt.ActionText = actionText
		newPrompt.ObjectText = ""
		newPrompt.RequiresLineOfSight = false
		newPrompt.HoldDuration = 0
		newPrompt.Parent = attachmentParent
		prompt = newPrompt
	end
	if not prompt then
		return nil
	end
	prompt.MaxActivationDistance = Config.Validation.DefaultInteractionDistance
	self.promptBound[instance] = true
	prompt.Triggered:Connect(function(player)
		callback(player)
	end)
	return prompt
end

function GameplayService._bindMazeExit(self: any, instance: Instance)
	self:_bindTouched(instance, function(player)
		if
			self:_isProtagonist(player)
			and self.validator.IsNear(
				player,
				instance,
				Config.Validation.DefaultInteractionDistance
			)
			and self.validator.IsStoryState(self.storyService, Contract.States.BellaChase)
			and self.validator:ConsumeOnce(`MazeExit:{self.storyService:GetRevision()}`)
		then
			self.storyService:Transition(Contract.States.RamboTaken, "MazeExitReached")
		end
	end)
end

function GameplayService._bindStoryTrigger(self: any, instance: Instance)
	if instance:GetAttribute(Contract.Attributes.MarkerId) ~= "TowerTop" then
		return
	end
	self:_bindPrompt(instance, "Reach the token", function(player)
		if
			self:_isProtagonist(player)
			and self.validator.IsNear(
				player,
				instance,
				Config.Validation.DefaultInteractionDistance
			)
			and self.validator.IsStoryState(self.storyService, Contract.States.TowerClimb)
		then
			self.storyService:Transition(Contract.States.RevivePrompt, "TowerTopReached")
		end
	end)
end

function GameplayService._bindFragment(self: any, instance: Instance)
	local prompt = self:_bindPrompt(instance, "Collect fragment", function(player)
		if
			not self:_isProtagonist(player)
			or not self.validator.IsNear(
				player,
				instance,
				Config.Validation.DefaultInteractionDistance
			)
			or not self.validator.IsStoryState(self.storyService, Contract.States.FieldHunt)
		then
			return
		end
		local fragmentId = instance:GetAttribute(Contract.Attributes.FragmentId)
		if typeof(fragmentId) ~= "string" or fragmentId == "" or self.fragments[fragmentId] then
			return
		end
		self.fragments[fragmentId] = true
		self.fragmentCount += 1
		instance:SetAttribute("Collected", true)
		local collectedPrompt = self.fragmentPrompts[instance]
		if collectedPrompt then
			collectedPrompt.Enabled = false
		end
		self.remotes[Contract.ServerEvents.FragmentUpdate]:FireClient(player, {
			count = self.fragmentCount,
			total = Config.Story.FragmentCount,
			fragmentId = fragmentId,
		})
		if self.fragmentCount >= Config.Story.FragmentCount then
			self.storyService:Transition(Contract.States.LetterTheft, "FragmentsCompleted")
		end
	end)
	if prompt then
		self.fragmentPrompts[instance] = prompt
		prompt.Enabled = instance:GetAttribute("Collected") ~= true
	end
end

function GameplayService._movePlayerToScene(self: any, player: Player, sceneId: string)
	if self.checkpoints:Set(player, sceneId) then
		if not self.checkpoints:Respawn(player) then
			task.spawn(function()
				player.CharacterAdded:Wait()
				if self:_isProtagonist(player) then
					self.checkpoints:Respawn(player)
				end
			end)
		end
	else
		warn(`Unable to move protagonist to missing SceneSpawn {sceneId}`)
		self.checkpoints:SetCurrent(player)
	end
end

function GameplayService._onStateChanged(self: any, state: string)
	self.friendlyRambo:SetActive(
		state == Contract.States.MazeIntro or state == Contract.States.BellaChase
	)
	self.bella:SetActive(state == Contract.States.BellaChase)
	self.evilRambo:SetActive(state == Contract.States.FieldHunt)
	if state == Contract.States.RoleLobby then
		table.clear(self.fragments)
		self.fragmentCount = 0
		self.validator:ClearConsumed()
		self.friendlyRambo:Reset()
		self.bella:Reset()
		self.evilRambo:Reset()
		self.checkpoints:ClearAll()
		for _, fragment in CollectionService:GetTagged(Contract.Tags.LetterFragment) do
			fragment:SetAttribute("Collected", false)
			local prompt = self.fragmentPrompts[fragment]
			if prompt then
				prompt.Enabled = true
			end
		end
	end
	local player = self.roleService:GetProtagonist()
	if not player then
		return
	end
	if state == Contract.States.MazeIntro then
		self:_movePlayerToScene(player, Config.Story.MazeCheckpointSceneId)
	elseif state == Contract.States.GuideEncounter then
		self:_movePlayerToScene(player, Config.Story.TowerCheckpointSceneId)
	elseif state == Contract.States.FieldHunt then
		self:_movePlayerToScene(player, Config.Story.FieldCheckpointSceneId)
	elseif state == Contract.States.Epilogue then
		self:_movePlayerToScene(player, Config.Story.EpilogueCheckpointSceneId)
	end
end

function GameplayService._resetRun(self: any, player: Player?)
	self.storyService:ResetToLobby("Replay")
	if player and self:_isProtagonist(player) then
		self.storyService:StartFor(player)
	end
end

function GameplayService.Start(self: any)
	for _, instance in CollectionService:GetTagged(Contract.Tags.MazeExit) do
		self:_bindMazeExit(instance)
	end
	for _, instance in CollectionService:GetTagged(Contract.Tags.StoryTrigger) do
		self:_bindStoryTrigger(instance)
	end
	for _, instance in CollectionService:GetTagged(Contract.Tags.LetterFragment) do
		self:_bindFragment(instance)
	end
	CollectionService:GetInstanceAddedSignal(Contract.Tags.MazeExit):Connect(function(instance)
		self:_bindMazeExit(instance)
	end)
	CollectionService:GetInstanceAddedSignal(Contract.Tags.StoryTrigger):Connect(function(instance)
		self:_bindStoryTrigger(instance)
	end)
	CollectionService:GetInstanceAddedSignal(Contract.Tags.LetterFragment)
		:Connect(function(instance)
			self:_bindFragment(instance)
		end)

	self.storyService:ObserveChanged(function(state)
		self:_onStateChanged(state)
	end)

	self.remotes[Contract.ClientEvents.CinematicFinished].OnServerEvent:Connect(
		function(player, cueId)
			if not self:_isProtagonist(player) or typeof(cueId) ~= "string" then
				return
			end
			if not self.validator:AllowRate(player, "CinematicFinished", 4, 2) then
				return
			end
			local transition = cinematicTransitions[self.storyService:GetState()]
			if transition and transition.cue == cueId then
				self.storyService:Transition(transition.next, `Cinematic:{cueId}`)
			end
		end
	)

	self.remotes[Contract.ClientEvents.ReviveConfirmed].OnServerEvent:Connect(
		function(player, confirmed)
			if
				not self:_isProtagonist(player)
				or typeof(confirmed) ~= "boolean"
				or not self.validator.IsStoryState(self.storyService, Contract.States.RevivePrompt)
				or not self.validator:AllowRate(
					player,
					Contract.ClientEvents.ReviveConfirmed,
					Config.Validation.RemoteBurstLimit,
					Config.Validation.RemoteWindowSeconds
				)
			then
				return
			end
			if
				confirmed and self.validator:ConsumeOnce(`Revive:{self.storyService:GetRevision()}`)
			then
				self.storyService:Transition(Contract.States.Corruption, "ReviveConfirmed")
			else
				self:_fireObjective(player, "Choose Revive to continue")
			end
		end
	)

	self.remotes[Contract.ClientEvents.ReplayRequested].OnServerEvent:Connect(function(player)
		if
			self:_isProtagonist(player)
			and self.validator.IsStoryState(self.storyService, Contract.States.Credits)
			and self.validator:AllowRate(player, Contract.ClientEvents.ReplayRequested, 1, 2)
		then
			self:_resetRun(player)
		end
	end)
end

return GameplayService
