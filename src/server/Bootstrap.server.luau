--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameShared = ReplicatedStorage:WaitForChild("GameShared")
local Contract = require(GameShared:WaitForChild("StoryContract"))
local Config = require(GameShared:WaitForChild("SystemsConfig"))
local RuntimeRules = require(GameShared:WaitForChild("RuntimeRules"))

local Services = script.Parent:WaitForChild("Services")
local RemoteRegistry = require(Services:WaitForChild("RemoteRegistry"))
local Validation = require(Services:WaitForChild("Validation"))
local RoleService = require(Services:WaitForChild("RoleService"))
local StoryService = require(Services:WaitForChild("StoryService"))
local CheckpointService = require(Services:WaitForChild("CheckpointService"))
local GameplayService = require(Services:WaitForChild("GameplayService"))
local AdminService = require(Services:WaitForChild("AdminService"))
local NPC = script.Parent:WaitForChild("NPC")
local FriendlyRamboService = require(NPC:WaitForChild("FriendlyRamboService"))
local HostileNpcService = require(NPC:WaitForChild("HostileNpcService"))

assert(Config.ContractVersion == Contract.Version, "SystemsConfig contract version mismatch")

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

roles:ObserveRoleChanged(function(player, role, previousRole)
	if role == Contract.Roles.Protagonist then
		if RuntimeRules.canStartStory(role, roles:IsReady(player), story:GetState()) then
			story:StartFor(player)
		end
	elseif previousRole == Contract.Roles.Protagonist then
		story:ResetToLobby("ProtagonistLeft")
	end
end)

remotes[Contract.ClientEvents.RoleReady].OnServerEvent:Connect(function(player)
	if not validator:AllowAction(player, Contract.ClientEvents.RoleReady) then
		return
	end
	local markedReady = roles:MarkReady(player)
	local startedStory = false
	if
		markedReady
		and RuntimeRules.canStartStory(
			roles:GetRole(player),
			roles:IsReady(player),
			story:GetState()
		)
	then
		startedStory = story:StartFor(player)
	end
	if not startedStory then
		story:SendSnapshot(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	validator:ForgetPlayer(player)
end)

friendlyRambo:Start()
bella:Start()
evilRambo:Start()
gameplay:Start()
admin:Start()
roles:Start()

-- Studio/server tests may inspect these references without exposing authority to clients.
script:SetAttribute("ContractVersion", Contract.Version)
script:SetAttribute("Bootstrapped", true)
