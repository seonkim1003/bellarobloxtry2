--!strict
--[[
	First-person presentation lock for horror camera feel.
]]

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local FirstPerson = {}

local ACTION_TOGGLE_CURSOR = "BellaToggleCursor"
local RENDER_STEP_CURSOR = "BellaFreeCursor"

local firstPersonActive = false
local cursorEnabled = true
local cursorChangedHandler: ((boolean) -> ())? = nil
local controlsBound = false

local function applyCursorState()
	RunService:UnbindFromRenderStep(RENDER_STEP_CURSOR)

	if cursorEnabled then
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default

		-- Roblox's first-person camera tries to lock the mouse every frame. Apply the
		-- menu cursor state immediately after the camera has updated.
		if firstPersonActive then
			RunService:BindToRenderStep(
				RENDER_STEP_CURSOR,
				Enum.RenderPriority.Camera.Value + 1,
				function()
					UserInputService.MouseIconEnabled = true
					UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				end
			)
		end
	else
		UserInputService.MouseIconEnabled = false
		if firstPersonActive then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	end
end

function FirstPerson.setCursorEnabled(enabled: boolean)
	local changed = cursorEnabled ~= enabled
	cursorEnabled = enabled
	applyCursorState()

	if changed and cursorChangedHandler then
		cursorChangedHandler(cursorEnabled)
	end
end

function FirstPerson.isCursorEnabled(): boolean
	return cursorEnabled
end

function FirstPerson.toggleCursor()
	if firstPersonActive then
		FirstPerson.setCursorEnabled(not cursorEnabled)
	end
end

function FirstPerson.bindCursorToggle(handler: ((boolean) -> ())?)
	cursorChangedHandler = handler
	if handler then
		handler(cursorEnabled)
	end

	if controlsBound then
		return
	end
	controlsBound = true

	ContextActionService:BindActionAtPriority(
		ACTION_TOGGLE_CURSOR,
		function(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
			if inputState == Enum.UserInputState.Begin and firstPersonActive then
				FirstPerson.toggleCursor()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Tab,
		Enum.KeyCode.ButtonY
	)
end

function FirstPerson.apply()
	local player = Players.LocalPlayer
	firstPersonActive = true
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	FirstPerson.setCursorEnabled(false)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
end

function FirstPerson.release()
	local player = Players.LocalPlayer
	firstPersonActive = false
	player.CameraMode = Enum.CameraMode.Classic
	FirstPerson.setCursorEnabled(true)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
	end)
end

return FirstPerson
