--!strict
--[[
	First-person presentation lock for horror camera feel.
	Menus unlock the cursor but NEVER switch to Classic third-person.
]]

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local ContentAudio =
	require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("ContentAudio"))

local FirstPerson = {}

local ACTION_TOGGLE_CURSOR = "BellaToggleCursor"
local RENDER_STEP_CURSOR = "BellaFreeCursor"
local RENDER_STEP_LOCK = "BellaForceFirstPerson"

local firstPersonActive = false
local cursorEnabled = true
local cursorChangedHandler: ((boolean) -> ())? = nil
local controlsBound = false
local characterConnection: RBXScriptConnection? = nil

local function forceFirstPersonCamera(player: Player)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
end

local function applyCursorState()
	RunService:UnbindFromRenderStep(RENDER_STEP_CURSOR)

	if cursorEnabled then
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default

		-- Keep free cursor even while LockFirstPerson fights to center the mouse.
		RunService:BindToRenderStep(
			RENDER_STEP_CURSOR,
			Enum.RenderPriority.Camera.Value + 1,
			function()
				local player = Players.LocalPlayer
				forceFirstPersonCamera(player)
				UserInputService.MouseIconEnabled = true
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		)
	else
		UserInputService.MouseIconEnabled = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
end

local function ensureForceLockLoop()
	RunService:UnbindFromRenderStep(RENDER_STEP_LOCK)
	RunService:BindToRenderStep(RENDER_STEP_LOCK, Enum.RenderPriority.Camera.Value, function()
		local player = Players.LocalPlayer
		-- Only force while we aren't in a Scriptable cinematic camera.
		local camera = workspace.CurrentCamera
		if camera and camera.CameraType == Enum.CameraType.Scriptable then
			return
		end
		forceFirstPersonCamera(player)
		if camera and camera.CameraType ~= Enum.CameraType.Custom then
			camera.CameraType = Enum.CameraType.Custom
		end
	end)
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

function FirstPerson.isActive(): boolean
	return firstPersonActive
end

function FirstPerson.toggleCursor()
	FirstPerson.setCursorEnabled(not cursorEnabled)
	ContentAudio.playCursorToggle()
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
			if inputState == Enum.UserInputState.Begin then
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
	local wasActive = firstPersonActive
	firstPersonActive = true
	forceFirstPersonCamera(player)
	ensureForceLockLoop()
	FirstPerson.setCursorEnabled(false)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	if not wasActive then
		ContentAudio.playCameraLock()
	end
end

-- Menu / UI mode: unlock cursor but stay locked in first person (never Classic).
function FirstPerson.release()
	local player = Players.LocalPlayer
	local wasLockedCursor = not cursorEnabled
	firstPersonActive = true
	forceFirstPersonCamera(player)
	ensureForceLockLoop()
	FirstPerson.setCursorEnabled(true)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	if wasLockedCursor then
		ContentAudio.playCameraLock()
	end
end

function FirstPerson.start()
	local player = Players.LocalPlayer
	forceFirstPersonCamera(player)
	ensureForceLockLoop()
	if characterConnection then
		characterConnection:Disconnect()
	end
	characterConnection = player.CharacterAdded:Connect(function()
		task.defer(function()
			forceFirstPersonCamera(player)
			applyCursorState()
		end)
	end)
	FirstPerson.apply()
end

return FirstPerson
