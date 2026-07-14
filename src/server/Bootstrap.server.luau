--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameShared = ReplicatedStorage:WaitForChild("GameShared")
local Contract = require(GameShared:WaitForChild("StoryContract"))
local Config = require(GameShared:WaitForChild("SystemsConfig"))
local ProgressionRules = require(GameShared:WaitForChild("ProgressionRules"))
local RuntimeRules = require(GameShared:WaitForChild("RuntimeRules"))

local Services = script.Parent:WaitForChild("Services")
local RemoteRegistry = require(Services:WaitForChild("RemoteRegistry"))
local Validation = require(Services:WaitForChild("Validation"))
local RoleService = require(Services:WaitForChild("RoleService"))
local StoryService = require(Services:WaitForChild("StoryService"))
local CheckpointService = require(Services:WaitForChild("CheckpointService"))
local GameplayService = require(Services:WaitForChild("GameplayService"))
local AdminService = require(Services:WaitForChild("AdminService"))
local WorldMarkerService = require(Services:WaitForChild("WorldMarkerService"))
local NPC = script.Parent:WaitForChild("NPC")
local DogFightService = require(NPC:WaitForChild("DogFightService"))
local FriendlyRamboService = require(NPC:WaitForChild("FriendlyRamboService"))
local HostileNpcService = require(NPC:WaitForChild("HostileNpcService"))

assert(Config.ContractVersion == Contract.Version, "SystemsConfig contract version mismatch")

-- Register tags before checkpoints and gameplay query CollectionService. This is
-- intentionally idempotent with ContentAssetMount's earlier registration.
WorldMarkerService.RegisterAuthoredMarkers()

local remotes = RemoteRegistry.Create()

local function waitForContentMount(timeoutSeconds: number): boolean
	local deadline = os.clock() + timeoutSeconds
	repeat
		local contentModels = ReplicatedStorage:FindFirstChild("ContentModels")
		if contentModels and contentModels:GetAttribute("Ready") == true then
			return contentModels:GetAttribute("MountFailed") ~= true
		end
		task.wait(0.1)
	until os.clock() >= deadline
	warn("[Bootstrap] Content mount timed out; continuing with runtime fallbacks")
	return false
end

waitForContentMount(Config.Startup.ContentMountTimeoutSeconds)
local validator = Validation.new()
local roles = RoleService.new(remotes)
local story = StoryService.new(remotes, roles)
local checkpoints = CheckpointService.new()
local dogFight = DogFightService.new(remotes)
local gameplay: any = nil
local friendlyRambo = FriendlyRamboService.new(roles)
local bella = HostileNpcService.new(roles, "Bella", Config.NPC.Bella, function(player, npcType)
	if gameplay then
		return gameplay:_onCatch(player, npcType)
	end
	return false
end)
local evilRambo = HostileNpcService.new(
	roles,
	"EvilRambo",
	Config.NPC.EvilRambo,
	function(player, npcType)
		if gameplay then
			return gameplay:_onCatch(player, npcType)
		end
		return false
	end,
	function(player, npcType)
		if gameplay then
			gameplay:_onDetected(player, npcType)
		end
	end
)
gameplay = GameplayService.new(
	remotes,
	validator,
	roles,
	story,
	checkpoints,
	friendlyRambo,
	bella,
	evilRambo
)
local admin = AdminService.new(remotes, validator, roles, story)

checkpoints:Start()

story:ObserveChanged(function(state)
	dogFight:OnStoryStateChanged(state, story:GetRevision())
end)

dogFight:ObserveCompleted(function(storyRevision, fightGeneration)
	if
		RuntimeRules.isDogFightCompletionValid(
			story:GetState(),
			story:GetRevision(),
			storyRevision,
			dogFight:GetFightGeneration(),
			fightGeneration
		)
		and dogFight:IsCompletedGeneration(storyRevision, fightGeneration)
		and validator:ConsumeOnce(`DogFight:{storyRevision}:{fightGeneration}`)
	then
		story:CompleteDogFight(storyRevision, dogFight:GetFightGeneration(), fightGeneration)
	end
end)

roles:ObserveRoleChanged(function(_player, role, previousRole)
	if role ~= Contract.Roles.Protagonist and previousRole == Contract.Roles.Protagonist then
		story:ResetToLobby("ProtagonistLeft")
	end
end)

remotes[Contract.ClientEvents.RoleReady].OnServerEvent:Connect(function(player, payload)
	if not validator:AllowAction(player, Contract.ClientEvents.RoleReady) then
		return
	end
	local roleChoice = ProgressionRules.parseRoleSelection(payload)
	if not roleChoice then
		return
	end
	if roleChoice == "Admin" then
		remotes[Contract.ServerEvents.AdminDiagnostics]:FireClient(player, {
			message = "Admin requires authentication. Use /admin <password> in chat.",
		})
		return
	end
	if roleChoice ~= "Bella" or not roles:ClaimProtagonist(player) then
		return
	end
	if roles:MarkReady(player) then
		remotes[Contract.ServerEvents.ObjectiveUpdate]:FireClient(player, {
			state = Contract.States.RoleLobby,
			objective = "Walk onto the Maze, Obby, or Scavenger Hunt teleporter",
		})
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if player == roles:GetProtagonist() then
		dogFight:Cancel()
	end
	validator:ForgetPlayer(player)
end)

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		if story:GetState() ~= Contract.States.RoleLobby then
			story:SendSnapshot(player)
		end
	end)
end)

friendlyRambo:Start()
bella:Start()
evilRambo:Start()
gameplay:Start()
dogFight:Start()
admin:Start()
roles:Start()

-- Studio/server tests may inspect these references without exposing authority to clients.
script:SetAttribute("ContractVersion", Contract.Version)
script:SetAttribute("Bootstrapped", true)
