--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameShared = ReplicatedStorage:WaitForChild("GameShared")
local Contract = require(GameShared:WaitForChild("StoryContract"))
local Config = require(GameShared:WaitForChild("SystemsConfig"))

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
local validator = Validation.new()
local roles = RoleService.new(remotes)
local story = StoryService.new(remotes, roles)
local checkpoints = CheckpointService.new()
local gameplay: any = nil
local friendlyRambo = FriendlyRamboService.new(roles)
local bella = HostileNpcService.new(roles, "Bella", Config.NPC.Bella, function(player, npcType)
	if gameplay then
		gameplay:_onCatch(player, npcType)
	end
end)
local evilRambo = HostileNpcService.new(
	roles,
	"EvilRambo",
	Config.NPC.EvilRambo,
	function(player, npcType)
		if gameplay then
			gameplay:_onCatch(player, npcType)
		end
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

roles:ObserveRoleChanged(function(player, role, previousRole)
	if role == Contract.Roles.Protagonist then
		story:StartFor(player)
	elseif previousRole == Contract.Roles.Protagonist then
		story:ResetToLobby("ProtagonistLeft")
	end
end)

remotes[Contract.ClientEvents.RoleReady].OnServerEvent:Connect(function(player)
	if
		not validator:AllowRate(
			player,
			Contract.ClientEvents.RoleReady,
			Config.Validation.RemoteBurstLimit,
			Config.Validation.RemoteWindowSeconds
		)
	then
		return
	end
	roles:MarkReady(player)
	story:SendSnapshot(player)
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
