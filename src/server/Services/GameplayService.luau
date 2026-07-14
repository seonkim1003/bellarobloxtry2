--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameShared = ReplicatedStorage:WaitForChild("GameShared")
local ContentConfig = require(GameShared:WaitForChild("ContentConfig"))
local Contract = require(GameShared:WaitForChild("StoryContract"))
local Config = require(GameShared:WaitForChild("SystemsConfig"))
local ProgressionRules = require(GameShared:WaitForChild("ProgressionRules"))
local RuntimeRules = require(GameShared:WaitForChild("RuntimeRules"))

local GameplayService = {}
GameplayService.__index = GameplayService

local function serverAuthoredFragmentIds(): { [string]: boolean }
	local result: { [string]: boolean } = {}
	for _, marker in ContentConfig.placeholderObjects do
		if marker.tag == Contract.Tags.LetterFragment then
			local fragmentId = marker.attributes[Contract.Attributes.FragmentId]
			if typeof(fragmentId) == "string" and fragmentId ~= "" then
				result[fragmentId] = true
			end
		end
	end
	return table.freeze(result)
end

local function setFragmentVisualVisible(fragmentId: string, visible: boolean)
	local contentProps = workspace:FindFirstChild("ContentProps")
	local visual = contentProps and contentProps:FindFirstChild(`LetterFragment_{fragmentId}`)
	if not visual then
		return
	end
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			local original = descendant:GetAttribute("FragmentOriginalTransparency")
			if visible then
				descendant.Transparency = if typeof(original) == "number" then original else 0
				descendant.CanQuery = true
			else
				if typeof(original) ~= "number" then
					descendant:SetAttribute("FragmentOriginalTransparency", descendant.Transparency)
				end
				descendant.Transparency = 1
				descendant.CanQuery = false
			end
		end
	end
end

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
		serverFragmentIds = serverAuthoredFragmentIds(),
		fragmentCount = 0,
		towerSteps = {} :: { [number]: boolean },
		towerStepCount = 0,
		promptBound = {} :: { [Instance]: boolean },
		fragmentPrompts = {} :: { [Instance]: ProximityPrompt },
		mazePrompts = {} :: { [Instance]: ProximityPrompt },
		mazeExitBound = {} :: { [Instance]: boolean },
		mazeExits = {} :: { [BasePart]: boolean },
		mazeExitPollElapsed = 0,
		storyPrompts = {} :: { [Instance]: ProximityPrompt },
		towerStepBound = {} :: { [Instance]: boolean },
	}, GameplayService)
end

function GameplayService._bindTowerStep(self: any, instance: Instance)
	if self.towerStepBound[instance] or not instance:IsA("BasePart") then
		return
	end
	self.towerStepBound[instance] = true
	instance.Touched:Connect(function(hit)
		if not self.validator.IsStoryState(self.storyService, Contract.States.TowerClimb) then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or player.Character ~= character or not self:_isProtagonist(player) then
			return
		end
		if not self.validator:AllowRate(player, "TowerStep", 64, 2) then
			return
		end
		local sequenceIndex = instance:GetAttribute(Contract.Attributes.SequenceIndex)
		if
			not ProgressionRules.canCollectTowerStep(
				self.towerSteps,
				self.towerStepCount,
				sequenceIndex,
				Config.Story.TowerStepCount
			)
		then
			return
		end
		assert(typeof(sequenceIndex) == "number", "validated tower index must be numeric")
		self.towerSteps[sequenceIndex] = true
		self.towerStepCount += 1
		self:_fireObjective(
			player,
			`Climb the tower: {self.towerStepCount}/{Config.Story.TowerStepCount} steps`
		)
	end)
end

function GameplayService._isProtagonist(self: any, player: Player): boolean
	return self.validator.HasRole(self.roleService, player, Contract.Roles.Protagonist)
end

function GameplayService._fireObjective(self: any, player: Player, objective: string)
	self.remotes[Contract.ServerEvents.ObjectiveUpdate]:FireClient(player, {
		state = self.storyService:GetState(),
		objective = objective,
	})
end

function GameplayService._onCatch(self: any, player: Player, npcType: string): boolean
	if not self:_isProtagonist(player) then
		return false
	end
	local expectedState = if npcType == "Bella"
		then Contract.States.BellaChase
		else Contract.States.FieldHunt
	if not self.validator.IsStoryState(self.storyService, expectedState) then
		return false
	end
	if npcType == "EvilRambo" then
		self.remotes[Contract.ServerEvents.FragmentUpdate]:FireClient(player, {
			count = self.fragmentCount,
			total = Config.Story.FragmentCount,
			caught = true,
		})
	else
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid:TakeDamage(Config.NPC.Bella.ContactDamage)
			self:_fireObjective(player, `Escape Bella - health {math.ceil(humanoid.Health)}`)
			return true
		end
	end
	self.checkpoints:Respawn(player)
	self:_fireObjective(
		player,
		if npcType == "Bella" then "Escape Bella" else "Find the letter fragments"
	)
	return true
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
	prompt.ActionText = actionText
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Validation.DefaultInteractionDistance
	self.promptBound[instance] = true
	prompt.Triggered:Connect(function(player)
		callback(player)
	end)
	return prompt
end

function GameplayService._tryCompleteMazeExit(self: any, instance: Instance, player: Player)
	if not self:_isProtagonist(player) then
		return
	end
	if not self.validator:AllowRate(player, "MazeExit", 4, 2) then
		return
	end
	if
		not self.validator.IsNear(player, instance, Config.Validation.MazeExitInteractionDistance)
	then
		return
	end
	-- server repairs the state before completing the exit instead of leaving the
	-- player stranded at a valid finish.
	if self.storyService:GetState() == Contract.States.MazeIntro then
		self.storyService:Transition(Contract.States.BellaChase, "MazeExitRecoveredIntro")
	end
	if not self.validator.IsStoryState(self.storyService, Contract.States.BellaChase) then
		return
	end
	if self.validator:ConsumeOnce(`MazeExit:{self.storyService:GetRevision()}`) then
		self.storyService:Transition(Contract.States.RamboTaken, "MazeExitReached")
	end
end

function GameplayService._pollMazeExit(self: any, dt: number)
	self.mazeExitPollElapsed += dt
	if self.mazeExitPollElapsed < 0.1 then
		return
	end
	self.mazeExitPollElapsed = 0

	local state = self.storyService:GetState()
	if state ~= Contract.States.MazeIntro and state ~= Contract.States.BellaChase then
		return
	end
	local player = self.roleService:GetProtagonist()
	if not player then
		return
	end
	for exitPart in self.mazeExits do
		if exitPart.Parent == nil then
			self.mazeExits[exitPart] = nil
		elseif
			self.validator.IsNear(player, exitPart, Config.Validation.MazeExitInteractionDistance)
		then
			self:_tryCompleteMazeExit(exitPart, player)
			return
		end
	end
end

function GameplayService._bindMazeExit(self: any, instance: Instance)
	if self.mazeExitBound[instance] or not instance:IsA("BasePart") then
		return
	end
	self.mazeExitBound[instance] = true
	self.mazeExits[instance] = true
	instance.CanTouch = true

	local prompt = self:_bindPrompt(instance, "Escape the maze", function(player)
		self:_tryCompleteMazeExit(instance, player)
	end)
	if prompt then
		self.mazePrompts[instance] = prompt
		prompt.MaxActivationDistance = Config.Validation.MazeExitInteractionDistance
		local state = self.storyService:GetState()
		prompt.Enabled = state == Contract.States.MazeIntro or state == Contract.States.BellaChase
	end

	-- Touch is the reliable cross-input fallback. The same authoritative checks
	-- used by the prompt prevent observers or out-of-state touches from advancing.
	instance.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player and player.Character == character then
			self:_tryCompleteMazeExit(instance, player)
		end
	end)
end

function GameplayService._bindStoryTrigger(self: any, instance: Instance)
	if instance:GetAttribute(Contract.Attributes.MarkerId) ~= "TowerTop" then
		return
	end
	local prompt = self:_bindPrompt(instance, "Reach the top", function(player)
		if
			self:_isProtagonist(player)
			and self.validator:AllowRate(player, "TowerTop", 2, 2)
			and self.validator.IsNear(
				player,
				instance,
				Config.Validation.DefaultInteractionDistance
			)
			and self.validator.IsStoryState(self.storyService, Contract.States.TowerClimb)
		then
			if self.towerStepCount >= Config.Story.TowerStepCount then
				self.storyService:Transition(Contract.States.RevivePrompt, "TowerTopReached")
			else
				self:_fireObjective(
					player,
					`Steps missing: {self.towerStepCount}/{Config.Story.TowerStepCount}`
				)
			end
		end
	end)
	if prompt then
		self.storyPrompts[instance] = prompt
		prompt.Enabled = self.storyService:GetState() == Contract.States.TowerClimb
	end
end

function GameplayService._bindFragment(self: any, instance: Instance)
	local authoredFragmentId = instance:GetAttribute(Contract.Attributes.FragmentId)
	if
		typeof(authoredFragmentId) ~= "string"
		or self.serverFragmentIds[authoredFragmentId] ~= true
	then
		return
	end
	local prompt = self:_bindPrompt(instance, "Collect fragment", function(player)
		if
			not self:_isProtagonist(player)
			or not self.validator:AllowRate(player, "FragmentCollect", 6, 2)
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
		if
			not ProgressionRules.canCollectFragment(
				self.serverFragmentIds,
				self.fragments,
				self.fragmentCount,
				fragmentId,
				Config.Story.FragmentCount
			)
		then
			return
		end
		assert(typeof(fragmentId) == "string", "validated fragment ID must be a string")
		self.fragments[fragmentId] = true
		self.fragmentCount += 1
		instance:SetAttribute("Collected", true)
		setFragmentVisualVisible(fragmentId, false)
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
		prompt.Enabled = self.storyService:GetState() == Contract.States.FieldHunt
			and instance:GetAttribute("Collected") ~= true
	end
end

function GameplayService._movePlayerToScene(self: any, player: Player, sceneId: string)
	self.checkpoints:Clear(player)
	if self.checkpoints:Set(player, sceneId) then
		if not self.checkpoints:Respawn(player) then
			local connection: RBXScriptConnection?
			connection = player.CharacterAdded:Connect(function()
				if connection then
					connection:Disconnect()
					connection = nil
				end
				task.defer(function()
					if
						player.Parent == Players
						and (
							sceneId == Config.Story.LobbyCheckpointSceneId
							or self:_isProtagonist(player)
						)
					then
						self.checkpoints:Respawn(player)
					end
				end)
			end)
			task.delay(10, function()
				if connection then
					connection:Disconnect()
					connection = nil
				end
			end)
		end
	else
		warn(`Unable to move protagonist to missing SceneSpawn {sceneId}`)
		self.checkpoints:SetCurrent(player)
	end
end

function GameplayService._armCinematicRecovery(self: any, state: string)
	local recoverySeconds = Config.Story.CinematicRecoverySeconds[state]
	local nextState = RuntimeRules.cinematicNextState(state)
	if typeof(recoverySeconds) ~= "number" or recoverySeconds <= 0 or not nextState then
		return
	end

	local revision = self.storyService:GetRevision()
	local stateEnteredAt = self.storyService:GetStateEnteredAt()
	task.delay(recoverySeconds, function()
		if
			RuntimeRules.shouldRecoverCinematic(
				self.storyService:GetState(),
				self.storyService:GetRevision(),
				stateEnteredAt,
				state,
				revision,
				os.clock(),
				recoverySeconds
			)
		then
			warn(
				`Recovering cinematic {state} revision {revision} after {recoverySeconds} seconds without a valid acknowledgement`
			)
			self.storyService:Transition(nextState, `CinematicRecovery:{state}`)
		end
	end)
end

function GameplayService._onStateChanged(self: any, state: string)
	self:_armCinematicRecovery(state)
	self.friendlyRambo:SetActive(
		state == Contract.States.MazeIntro or state == Contract.States.BellaChase
	)
	self.bella:SetActive(state == Contract.States.BellaChase)
	self.evilRambo:SetActive(state == Contract.States.FieldHunt)
	for _, prompt in self.mazePrompts do
		prompt.Enabled = state == Contract.States.MazeIntro or state == Contract.States.BellaChase
	end
	for _, prompt in self.storyPrompts do
		prompt.Enabled = state == Contract.States.TowerClimb
	end
	for fragment, prompt in self.fragmentPrompts do
		prompt.Enabled = state == Contract.States.FieldHunt
			and fragment:GetAttribute("Collected") ~= true
	end
	if state == Contract.States.RoleLobby then
		table.clear(self.fragments)
		self.fragmentCount = 0
		table.clear(self.towerSteps)
		self.towerStepCount = 0
		self.validator:ClearConsumed()
		self.friendlyRambo:Reset()
		self.bella:Reset()
		self.evilRambo:Reset()
		self.checkpoints:ClearAll()
		for _, fragment in CollectionService:GetTagged(Contract.Tags.LetterFragment) do
			fragment:SetAttribute("Collected", false)
			local fragmentId = fragment:GetAttribute(Contract.Attributes.FragmentId)
			if typeof(fragmentId) == "string" then
				setFragmentVisualVisible(fragmentId, true)
			end
			local prompt = self.fragmentPrompts[fragment]
			if prompt then
				prompt.Enabled = false
			end
		end
		for _, lobbyPlayer in Players:GetPlayers() do
			self:_movePlayerToScene(lobbyPlayer, Config.Story.LobbyCheckpointSceneId)
		end
		return
	end
	local player = self.roleService:GetProtagonist()
	if not player then
		return
	end
	if state == Contract.States.MazeIntro then
		self:_movePlayerToScene(player, Config.Story.MazeCheckpointSceneId)
		local revision = self.storyService:GetRevision()
		task.delay(1, function()
			if
				self.storyService:GetState() == Contract.States.MazeIntro
				and self.storyService:GetRevision() == revision
			then
				self.storyService:Transition(Contract.States.BellaChase, "MazeIntroComplete")
			end
		end)
	elseif state == Contract.States.GuideEncounter or state == Contract.States.TowerClimb then
		table.clear(self.towerSteps)
		self.towerStepCount = 0
		self:_movePlayerToScene(player, Config.Story.TowerCheckpointSceneId)
	elseif state == Contract.States.FieldHunt then
		table.clear(self.fragments)
		self.fragmentCount = 0
		for _, fragment in CollectionService:GetTagged(Contract.Tags.LetterFragment) do
			fragment:SetAttribute("Collected", false)
			local fragmentId = fragment:GetAttribute(Contract.Attributes.FragmentId)
			if typeof(fragmentId) == "string" then
				setFragmentVisualVisible(fragmentId, true)
			end
			local prompt = self.fragmentPrompts[fragment]
			if prompt then
				prompt.Enabled = true
			end
		end
		self:_movePlayerToScene(player, Config.Story.FieldCheckpointSceneId)
	elseif state == Contract.States.Epilogue then
		self:_movePlayerToScene(player, Config.Story.EpilogueCheckpointSceneId)
	end
end

function GameplayService._resetRun(self: any)
	self.storyService:ResetToLobby("Replay")
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
	for _, instance in CollectionService:GetTagged(Contract.Tags.ASMRStep) do
		self:_bindTowerStep(instance)
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
	CollectionService:GetInstanceAddedSignal(Contract.Tags.ASMRStep):Connect(function(instance)
		self:_bindTowerStep(instance)
	end)
	RunService.Heartbeat:Connect(function(dt)
		self:_pollMazeExit(dt)
	end)

	self.storyService:ObserveChanged(function(state)
		self:_onStateChanged(state)
	end)

	self.remotes[Contract.ClientEvents.CinematicFinished].OnServerEvent:Connect(
		function(player, payload)
			if not self.validator:AllowAction(player, Contract.ClientEvents.CinematicFinished) then
				return
			end
			if not self:_isProtagonist(player) or typeof(payload) ~= "table" then
				return
			end
			local cueId = payload.cue
			local revision = payload.revision
			if typeof(cueId) ~= "string" or typeof(revision) ~= "number" then
				return
			end
			local state = self.storyService:GetState()
			if state == Contract.States.DogFight then
				return
			end
			local minimumSeconds = Config.Story.CinematicMinimumSeconds[state] or 0
			if
				not RuntimeRules.isCinematicAckValid(
					state,
					self.storyService:GetRevision(),
					self.storyService:GetStateEnteredAt(),
					cueId,
					revision,
					os.clock(),
					minimumSeconds
				)
			then
				return
			end
			local nextState = RuntimeRules.cinematicNextState(state)
			if nextState and self.validator:ConsumeOnce(`Cinematic:{state}:{revision}`) then
				self.storyService:Transition(nextState, `Cinematic:{cueId}`)
			end
		end
	)

	self.remotes[Contract.ClientEvents.ReviveConfirmed].OnServerEvent:Connect(
		function(player, confirmed)
			if not self.validator:AllowAction(player, Contract.ClientEvents.ReviveConfirmed) then
				return
			end
			if
				not self:_isProtagonist(player)
				or typeof(confirmed) ~= "boolean"
				or not self.validator.IsStoryState(self.storyService, Contract.States.RevivePrompt)
			then
				return
			end
			if
				confirmed
				and self.validator:ConsumeOnce(`Revive:{self.storyService:GetRevision()}`)
			then
				self.storyService:Transition(Contract.States.Corruption, "ReviveConfirmed")
			else
				self:_fireObjective(player, "Choose Revive to continue")
			end
		end
	)

	self.remotes[Contract.ClientEvents.ReplayRequested].OnServerEvent:Connect(function(player)
		if not self.validator:AllowAction(player, Contract.ClientEvents.ReplayRequested) then
			return
		end
		if
			self:_isProtagonist(player)
			and self.validator.IsStoryState(self.storyService, Contract.States.Credits)
		then
			self:_resetRun()
		end
	end)
end

return GameplayService
