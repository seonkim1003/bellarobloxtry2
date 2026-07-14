--!strict
--[[
	Unlimited sprint + keyboard / touch / late-bind touch control presentation.
	Does not gate stamina — sprint is always available once enabled.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()

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
		_touchWatchConnection: RBXScriptConnection?,
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
		_touchWatchConnection = nil,
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
		self._touchButton.Text = if self._sprinting then "SPRINTING" else "SPRINT"
	end
end

function SprintControls:_layoutTouchButton(button: TextButton)
	local minPx = ContentConfig.ui.touchMinButtonPx or 72
	local inset = ContentConfig.ui.touchSafeInsetScale or 0.04
	local guiInset = GuiService:GetGuiInset()
	local bottomPad = math.max(24, math.floor(guiInset.Y * 0.25) + 16)
	local rightPad = 24
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1 - inset, -rightPad, 1 - inset, -bottomPad)
	button.Size = UDim2.fromOffset(minPx, minPx)

	local constraint = button:FindFirstChildOfClass("UISizeConstraint")
	if constraint == nil then
		local createdConstraint = Instance.new("UISizeConstraint")
		createdConstraint.Parent = button
		constraint = createdConstraint
	end
	if constraint then
		(constraint :: UISizeConstraint).MinSize = Vector2.new(minPx, minPx)
	end
end

function SprintControls:_ensureTouchButton()
	if self._touchButton then
		self:_layoutTouchButton(self._touchButton)
		self._touchButton.Visible = self._enabled and UserInputService.TouchEnabled
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
	button.Selectable = false
	button.Parent = gui
	self:_layoutTouchButton(button)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
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
	button.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			self:_setSprinting(false)
		end
	end)

	self._touchButton = button
	button.Visible = self._enabled
end

function SprintControls:_watchTouchAvailability()
	if self._touchWatchConnection then
		return
	end
	self._touchWatchConnection = UserInputService:GetPropertyChangedSignal("TouchEnabled")
		:Connect(function()
			if not self._enabled then
				return
			end
			if UserInputService.TouchEnabled then
				self:_ensureTouchButton()
			elseif self._touchButton then
				self._touchButton.Visible = false
			end
		end)
	table.insert(
		self._connections,
		UserInputService.LastInputTypeChanged:Connect(function()
			if self._enabled then
				self:_ensureTouchButton()
			end
		end)
	)
end

function SprintControls:enable()
	if self._enabled then
		return
	end
	self._enabled = true
	self:_ensureTouchButton()
	self:_watchTouchAvailability()
	if self._touchButton then
		self._touchButton.Visible = UserInputService.TouchEnabled
	end

	ContextActionService:BindAction(ACTION_SPRINT, function(_name, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			self:_setSprinting(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			self:_setSprinting(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)

	table.insert(
		self._connections,
		Players.LocalPlayer.CharacterAdded:Connect(function()
			task.defer(function()
				self._humanoid = getHumanoid()
				self:_applySpeed()
			end)
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
	if self._touchWatchConnection ~= nil then
		(self._touchWatchConnection :: RBXScriptConnection):Disconnect()
		self._touchWatchConnection = nil
	end
	for _, connection in self._connections do
		(connection :: RBXScriptConnection):Disconnect()
	end
	table.clear(self._connections)
end

function SprintControls:reset()
	self:disable()
	self:enable()
end

return SprintControls
