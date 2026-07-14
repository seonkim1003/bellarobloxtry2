--!strict
--[[
	Unlimited sprint + keyboard / touch control presentation.
	Does not gate stamina — sprint is always available once enabled.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local SprintControls = {}
SprintControls.__index = SprintControls

export type SprintControls = typeof(setmetatable(
	{} :: {
		_enabled: boolean,
		_sprinting: boolean,
		_walkSpeed: number,
		_sprintSpeed: number,
		_connections: { RBXScriptConnection },
		_touchButton: TextButton?,
		_humanoid: Humanoid?,
	},
	SprintControls
))

local ACTION_SPRINT = "ContentSprint"

local function getHumanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

function SprintControls.new(walkSpeed: number?, sprintSpeed: number?): SprintControls
	return setmetatable({
		_enabled = false,
		_sprinting = false,
		_walkSpeed = walkSpeed or 16,
		_sprintSpeed = sprintSpeed or 24,
		_connections = {},
		_touchButton = nil,
		_humanoid = nil,
	}, SprintControls)
end

function SprintControls:_applySpeed()
	local humanoid = self._humanoid or getHumanoid()
	self._humanoid = humanoid
	if humanoid == nil then
		return
	end
	if self._enabled and self._sprinting then
		humanoid.WalkSpeed = self._sprintSpeed
	else
		humanoid.WalkSpeed = self._walkSpeed
	end
end

function SprintControls:_setSprinting(active: boolean)
	self._sprinting = active and self._enabled
	self:_applySpeed()
	if self._touchButton then
		self._touchButton.BackgroundColor3 = if self._sprinting
			then Color3.fromRGB(80, 140, 90)
			else Color3.fromRGB(35, 35, 48)
	end
end

function SprintControls:_ensureTouchButton()
	if self._touchButton then
		return
	end
	if not UserInputService.TouchEnabled then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("ContentHud")
	if gui == nil or not gui:IsA("ScreenGui") then
		return
	end

	local button = Instance.new("TextButton")
	button.Name = "SprintTouch"
	button.Text = "SPRINT"
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.TextColor3 = Color3.fromRGB(250, 250, 250)
	button.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
	button.BorderSizePixel = 0
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -24, 1, -24)
	button.Size = UDim2.fromOffset(96, 96)
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 48)
	corner.Parent = button

	button.MouseButton1Down:Connect(function()
		self:_setSprinting(true)
	end)
	button.MouseButton1Up:Connect(function()
		self:_setSprinting(false)
	end)
	button.MouseLeave:Connect(function()
		self:_setSprinting(false)
	end)

	self._touchButton = button
end

function SprintControls:enable()
	if self._enabled then
		return
	end
	self._enabled = true
	self:_ensureTouchButton()
	if self._touchButton then
		self._touchButton.Visible = true
	end

	ContextActionService:BindAction(ACTION_SPRINT, function(_name, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			self:_setSprinting(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			self:_setSprinting(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

	table.insert(
		self._connections,
		Players.LocalPlayer.CharacterAdded:Connect(function()
			task.defer(function()
				self._humanoid = getHumanoid()
				self:_applySpeed()
			end)
		end)
	)

	table.insert(
		self._connections,
		RunService.RenderStepped:Connect(function()
			if self._enabled then
				self:_applySpeed()
			end
		end)
	)

	self._humanoid = getHumanoid()
	self:_applySpeed()
end

function SprintControls:disable()
	self._enabled = false
	self:_setSprinting(false)
	ContextActionService:UnbindAction(ACTION_SPRINT)
	if self._touchButton then
		self._touchButton.Visible = false
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

function SprintControls:reset()
	self:disable()
	self:enable()
end

return SprintControls
