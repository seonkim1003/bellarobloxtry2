--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local GameShared = ReplicatedStorage:WaitForChild("GameShared")
local Contract = require(GameShared:WaitForChild("StoryContract"))
local Config = require(GameShared:WaitForChild("SystemsConfig"))
local Secrets = require(script.Parent.Parent:WaitForChild("ServerSecrets"))

local AdminService = {}
AdminService.__index = AdminService

local function secureEquals(left: string, right: string): boolean
	local difference = #left ~= #right and 1 or 0
	local maximum = math.max(#left, #right)
	for index = 1, maximum do
		difference += if string.byte(left, index) == string.byte(right, index) then 0 else 1
	end
	return difference == 0
end

local function commandArgument(message: string, alias: string): string
	local trimmed = string.gsub(message, "^%s*(.-)%s*$", "%1")
	if string.sub(string.lower(trimmed), 1, #alias) == string.lower(alias) then
		return string.gsub(string.sub(trimmed, #alias + 1), "^%s+", "")
	end
	return trimmed
end

function AdminService.new(
	remotes: { [string]: RemoteEvent },
	validator: any,
	roleService: any,
	storyService: any
)
	return setmetatable({
		remotes = remotes,
		validator = validator,
		roleService = roleService,
		storyService = storyService,
		states = {} :: { [Player]: any },
		commands = {} :: { TextChatCommand },
		connection = nil,
	}, AdminService)
end

function AdminService._respond(self: any, player: Player, message: string, includeState: boolean?)
	local payload: { [string]: any } = { message = message }
	if includeState then
		payload.role = self.roleService:GetRole(player)
		payload.storyState = self.storyService:GetState()
		payload.revision = self.storyService:GetRevision()
	end
	self.remotes[Contract.ServerEvents.AdminDiagnostics]:FireClient(player, payload)
end

function AdminService._isAdmin(self: any, player: Player): boolean
	return self.validator.HasRole(self.roleService, player, Contract.Roles.Admin)
end

function AdminService._restoreCharacter(self: any, player: Player)
	local state = self.states[player]
	if not state then
		return
	end
	for instance, properties in state.originals do
		if instance.Parent then
			for property, value in properties do
				pcall(function()
					(instance :: any)[property] = value
				end)
			end
		end
	end
	local character = player.Character
	if character then
		local mover = character:FindFirstChild("AdminFlyVelocity", true)
		if mover then
			mover:Destroy()
		end
		local shield = character:FindFirstChild("AdminObserverShield")
		if shield then
			shield:Destroy()
		end
	end
	table.clear(state.originals)
end

function AdminService._remember(
	_self: any,
	state: any,
	instance: Instance,
	property: string,
	value: any
)
	local properties = state.originals[instance]
	if not properties then
		properties = {}
		state.originals[instance] = properties
	end
	if properties[property] == nil then
		properties[property] = value
	end
end

function AdminService._applyCharacter(self: any, player: Player)
	local state = self.states[player]
	local character = player.Character
	if not state or not character then
		return
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			self:_remember(state, descendant, "CanCollide", descendant.CanCollide)
			descendant.CanCollide = false
			if state.invisible then
				self:_remember(state, descendant, "Transparency", descendant.Transparency)
				descendant.Transparency = 1
			end
		elseif (descendant:IsA("Decal") or descendant:IsA("Texture")) and state.invisible then
			local visual = descendant :: any
			self:_remember(state, descendant, "Transparency", visual.Transparency)
			visual.Transparency = 1
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
	if not character:FindFirstChild("AdminObserverShield") then
		local shield = Instance.new("ForceField")
		shield.Name = "AdminObserverShield"
		shield.Visible = false
		shield.Parent = character
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local mover = root:FindFirstChild("AdminFlyVelocity")
		if state.fly and not mover then
			local newMover = Instance.new("BodyVelocity")
			newMover.Name = "AdminFlyVelocity"
			newMover.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			newMover.P = 12500
			newMover.Parent = root
		elseif not state.fly and mover then
			mover:Destroy()
		end
	end
end

function AdminService._makeAdmin(self: any, player: Player)
	if not self.states[player] then
		self.states[player] = {
			fly = false,
			invisible = true,
			vertical = 0,
			originals = {},
			characterConnection = nil,
		}
	end
	local state = self.states[player]
	if not state.characterConnection then
		state.characterConnection = player.CharacterAdded:Connect(function()
			task.defer(function()
				if self:_isAdmin(player) then
					table.clear(state.originals)
					self:_applyCharacter(player)
				end
			end)
		end)
	end
	player:SetAttribute("AdminObserver", true)
	self:_applyCharacter(player)
end

function AdminService._removeAdmin(self: any, player: Player)
	self:_restoreCharacter(player)
	local state = self.states[player]
	if state and state.characterConnection then
		state.characterConnection:Disconnect()
	end
	self.states[player] = nil
	player:SetAttribute("AdminObserver", nil)
end

function AdminService._createCommand(
	self: any,
	name: string,
	alias: string,
	callback: (Player, string) -> ()
)
	local existing = TextChatService:FindFirstChild(name)
	local command: TextChatCommand
	if existing and existing:IsA("TextChatCommand") then
		command = existing
	else
		command = Instance.new("TextChatCommand")
		command.Name = name
		command.PrimaryAlias = alias
		command.Parent = TextChatService
	end
	command.Triggered:Connect(function(origin, text)
		local player = Players:GetPlayerByUserId(origin.UserId)
		if player then
			callback(player, commandArgument(text, alias))
		end
	end)
	table.insert(self.commands, command)
end

function AdminService._adminCommand(
	self: any,
	name: string,
	alias: string,
	callback: (Player, string) -> ()
)
	self:_createCommand(name, alias, function(player, argument)
		if not self:_isAdmin(player) then
			self:_respond(player, "Command unavailable.")
			return
		end
		callback(player, argument)
	end)
end

function AdminService.Start(self: any)
	local adminLoginEnabled = Secrets.AdminPassword ~= ""
		and Secrets.AdminPassword ~= "CHANGE-ME-BEFORE-PUBLISHING"
	if not adminLoginEnabled then
		warn("[Admin] Observer login disabled until ServerSecrets.AdminPassword is configured")
	end

	self:_createCommand("ObserverAdminLogin", "/admin", function(player, password)
		if not adminLoginEnabled then
			self:_respond(player, "Command unavailable.")
			return
		end
		if
			not self.validator:AllowRate(
				player,
				"AdminPassword",
				Config.Admin.PasswordAttempts,
				Config.Admin.PasswordWindowSeconds
			)
		then
			self:_respond(player, "Command unavailable.")
			return
		end
		if not secureEquals(password, Secrets.AdminPassword) then
			self:_respond(player, "Command unavailable.")
			return
		end
		if self.roleService:PromoteToAdmin(player) then
			self:_makeAdmin(player)
			self:_respond(player, "Observer mode enabled.", true)
		else
			self:_respond(player, "Command unavailable.")
		end
	end)

	self:_adminCommand("ObserverFly", "/fly", function(player)
		local state = self.states[player]
		state.fly = not state.fly
		state.vertical = 0
		self:_applyCharacter(player)
		self:_respond(player, if state.fly then "Fly enabled." else "Fly disabled.")
	end)
	self:_adminCommand("ObserverNoclip", "/noclip", function(player)
		self:_applyCharacter(player)
		self:_respond(player, "Observer noclip enforced.")
	end)
	self:_adminCommand("ObserverInvisible", "/invisible", function(player)
		local state = self.states[player]
		self:_restoreCharacter(player)
		state.invisible = not state.invisible
		self:_applyCharacter(player)
		self:_respond(
			player,
			if state.invisible then "Invisibility enabled." else "Invisibility disabled."
		)
	end)
	self:_adminCommand("ObserverInvulnerable", "/invulnerable", function(player)
		self:_applyCharacter(player)
		self:_respond(player, "Observer invulnerability enforced.")
	end)
	self:_adminCommand("ObserverTeleport", "/tpplayer", function(player)
		local protagonist = self.roleService:GetProtagonist()
		if protagonist and protagonist.Character and player.Character then
			player.Character:PivotTo(protagonist.Character:GetPivot() * CFrame.new(4, 3, 4))
			self:_respond(player, "Teleported to player.")
		else
			self:_respond(player, "Player unavailable.")
		end
	end)
	self:_adminCommand("ObserverState", "/adminstate", function(player)
		self:_respond(player, "Read-only diagnostics.", true)
	end)
	self:_adminCommand("ObserverUp", "/adminup", function(player)
		self.states[player].vertical = Config.Admin.VerticalFlySpeed
		self:_respond(player, "Fly ascent enabled.")
	end)
	self:_adminCommand("ObserverDown", "/admindown", function(player)
		self.states[player].vertical = -Config.Admin.VerticalFlySpeed
		self:_respond(player, "Fly descent enabled.")
	end)
	self:_adminCommand("ObserverLevel", "/adminlevel", function(player)
		self.states[player].vertical = 0
		self:_respond(player, "Fly altitude held.")
	end)

	self.roleService:ObserveRoleChanged(function(player, role, previousRole)
		if role == Contract.Roles.Admin then
			self:_makeAdmin(player)
		elseif previousRole == Contract.Roles.Admin then
			self:_removeAdmin(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_removeAdmin(player)
	end)
	self.connection = RunService.Heartbeat:Connect(function()
		for player, state in self.states do
			if not self:_isAdmin(player) then
				continue
			end
			self:_applyCharacter(player)
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local mover = root and root:FindFirstChild("AdminFlyVelocity")
			if
				state.fly
				and humanoid
				and root
				and root:IsA("BasePart")
				and mover
				and mover:IsA("BodyVelocity")
			then
				mover.Velocity = humanoid.MoveDirection * Config.Admin.FlySpeed
					+ Vector3.new(0, state.vertical, 0)
			end
		end
	end)
end

return AdminService
