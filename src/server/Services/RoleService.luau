--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameShared = ReplicatedStorage:WaitForChild("GameShared")
local Contract = require(GameShared:WaitForChild("StoryContract"))
local Config = require(GameShared:WaitForChild("SystemsConfig"))
local RuntimeRules = require(GameShared:WaitForChild("RuntimeRules"))

local RoleService = {}
RoleService.__index = RoleService

export type RoleService = typeof(setmetatable(
	{} :: {
		remotes: { [string]: RemoteEvent },
		records: { [Player]: { role: string, ready: boolean } },
		protagonist: Player?,
		roleChanged: BindableEvent,
		started: boolean,
	},
	RoleService
))

function RoleService.new(remotes: { [string]: RemoteEvent }): RoleService
	return setmetatable({
		remotes = remotes,
		records = {},
		protagonist = nil,
		roleChanged = Instance.new("BindableEvent"),
		started = false,
	}, RoleService)
end

function RoleService._send(self: RoleService, player: Player)
	local record = self.records[player]
	if record then
		self.remotes[Contract.ServerEvents.RoleUpdate]:FireClient(player, {
			contractVersion = Contract.Version,
			role = record.role,
		})
	end
end

function RoleService._assign(self: RoleService, player: Player, role: string): boolean
	local record = self.records[player]
	if not record or player.Parent ~= Players then
		return false
	end
	local previousRole = record.role
	if role == Contract.Roles.Protagonist then
		if self.protagonist and self.protagonist ~= player then
			return false
		end
		self.protagonist = player
	elseif self.protagonist == player then
		self.protagonist = nil
	end
	record.role = role
	player:SetAttribute("GameRole", role)
	self:_send(player)
	self.roleChanged:Fire(player, role, previousRole)
	return true
end

function RoleService._onPlayerAdded(self: RoleService, player: Player)
	if self.records[player] then
		return
	end
	self.records[player] = {
		role = Contract.Roles.Unassigned,
		ready = false,
	}
	player:SetAttribute("GameRole", Contract.Roles.Unassigned)
	self:_send(player)
end

function RoleService._trackedCount(self: RoleService): number
	local count = 0
	for _ in self.records do
		count += 1
	end
	return count
end

function RoleService._admit(self: RoleService, player: Player): boolean
	if not RuntimeRules.canAdmitPlayer(self:_trackedCount(), Config.Roles.MaximumPlayers) then
		player:Kick("This server is full.")
		return false
	end
	self:_onPlayerAdded(player)
	return true
end

function RoleService._onPlayerRemoving(self: RoleService, player: Player)
	local record = self.records[player]
	local previousRole = if record then record.role else Contract.Roles.Unassigned
	if self.protagonist == player then
		self.protagonist = nil
	end
	self.records[player] = nil
	self.roleChanged:Fire(player, Contract.Roles.Unassigned, previousRole)
end

function RoleService.Start(self: RoleService)
	if self.started then
		return
	end
	self.started = true
	Players.PlayerAdded:Connect(function(player)
		self:_admit(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end)
	for _, player in Players:GetPlayers() do
		self:_admit(player)
	end
end

function RoleService.MarkReady(self: RoleService, player: Player): boolean
	local record = self.records[player]
	if not record then
		return false
	end
	record.ready = true
	self:_send(player)
	return true
end

function RoleService.ClaimProtagonist(self: RoleService, player: Player): boolean
	return self:_assign(player, Contract.Roles.Protagonist)
end

function RoleService.IsReady(self: RoleService, player: Player): boolean
	local record = self.records[player]
	return record ~= nil and record.ready
end

function RoleService.PromoteToAdmin(self: RoleService, player: Player): boolean
	return self:_assign(player, Contract.Roles.Admin)
end

function RoleService.GetRole(self: RoleService, player: Player): string
	local record = self.records[player]
	return if record then record.role else Contract.Roles.Unassigned
end

function RoleService.GetProtagonist(self: RoleService): Player?
	return self.protagonist
end

function RoleService.ObserveRoleChanged(
	self: RoleService,
	callback: (Player, string, string) -> ()
): RBXScriptConnection
	return self.roleChanged.Event:Connect(callback)
end

return RoleService
