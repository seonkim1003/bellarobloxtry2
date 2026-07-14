--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameShared = ReplicatedStorage:WaitForChild("GameShared")
local Contract = require(GameShared:WaitForChild("StoryContract"))
local Config = require(GameShared:WaitForChild("SystemsConfig"))

local RoleService = {}
RoleService.__index = RoleService

export type RoleService = typeof(setmetatable({} :: {
	remotes: {[string]: RemoteEvent},
	records: {[Player]: {role: string, joinedAt: number, ready: boolean}},
	protagonist: Player?,
	roleChanged: BindableEvent,
	started: boolean,
}, RoleService))

function RoleService.new(remotes: {[string]: RemoteEvent}): RoleService
	return setmetatable({
		remotes = remotes,
		records = {},
		protagonist = nil,
		roleChanged = Instance.new("BindableEvent"),
		started = false,
	}, RoleService)
end

function RoleService:_send(player: Player)
	local record = self.records[player]
	if record then
		self.remotes[Contract.ServerEvents.RoleUpdate]:FireClient(player, {
			contractVersion = Contract.Version,
			role = record.role,
		})
	end
end

function RoleService:_assign(player: Player, role: string): boolean
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
	if previousRole == Contract.Roles.Protagonist and role ~= Contract.Roles.Protagonist then
		task.defer(function()
			self:_promoteNextCandidate()
		end)
	end
	return true
end

function RoleService:_promoteNextCandidate()
	if self.protagonist then
		return
	end
	local now = os.clock()
	local candidate: Player? = nil
	local oldestJoin = math.huge
	for player, record in self.records do
		if record.role == Contract.Roles.Unassigned
			and now - record.joinedAt >= Config.Roles.ClaimDelaySeconds
			and record.joinedAt < oldestJoin
		then
			candidate = player
			oldestJoin = record.joinedAt
		end
	end
	if candidate then
		self:_assign(candidate, Contract.Roles.Protagonist)
	end
end

function RoleService:_considerProtagonist(player: Player)
	local record = self.records[player]
	if not record or record.role ~= Contract.Roles.Unassigned then
		return
	end
	if not self.protagonist then
		self:_assign(player, Contract.Roles.Protagonist)
	end
end

function RoleService:_onPlayerAdded(player: Player)
	self.records[player] = {
		role = Contract.Roles.Unassigned,
		joinedAt = os.clock(),
		ready = false,
	}
	player:SetAttribute("GameRole", Contract.Roles.Unassigned)
	self:_send(player)

	task.delay(Config.Roles.ClaimDelaySeconds, function()
		self:_considerProtagonist(player)
	end)
	task.delay(Config.Roles.UnassignedTimeoutSeconds, function()
		local record = self.records[player]
		if not record or record.role ~= Contract.Roles.Unassigned or player.Parent ~= Players then
			return
		end
		if not self.protagonist then
			self:_considerProtagonist(player)
		else
			player:Kick("This server already has an active player.")
		end
	end)
end

function RoleService:_onPlayerRemoving(player: Player)
	local record = self.records[player]
	local previousRole = if record then record.role else Contract.Roles.Unassigned
	if self.protagonist == player then
		self.protagonist = nil
	end
	self.records[player] = nil
	self.roleChanged:Fire(player, Contract.Roles.Unassigned, previousRole)
	if previousRole == Contract.Roles.Protagonist then
		task.defer(function()
			self:_promoteNextCandidate()
		end)
	end
end

function RoleService:Start()
	if self.started then
		return
	end
	self.started = true
	Players.PlayerAdded:Connect(function(player)
		local count = 0
		for _ in self.records do
			count += 1
		end
		if count >= Config.Roles.MaximumPlayers then
			player:Kick("This server is full.")
			return
		end
		self:_onPlayerAdded(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end)
	for _, player in Players:GetPlayers() do
		self:_onPlayerAdded(player)
	end
end

function RoleService:MarkReady(player: Player)
	local record = self.records[player]
	if not record then
		return
	end
	record.ready = true
	-- Readiness only confirms that the client loaded. The claim-delay window remains
	-- authoritative so a newly joined observer has time to authenticate in Phase 4.
	self:_send(player)
end

function RoleService:PromoteToAdmin(player: Player): boolean
	return self:_assign(player, Contract.Roles.Admin)
end

function RoleService:GetRole(player: Player): string
	local record = self.records[player]
	return if record then record.role else Contract.Roles.Unassigned
end

function RoleService:GetProtagonist(): Player?
	return self.protagonist
end

function RoleService:ObserveRoleChanged(callback: (Player, string, string) -> ()): RBXScriptConnection
	return self.roleChanged.Event:Connect(callback)
end

return RoleService
