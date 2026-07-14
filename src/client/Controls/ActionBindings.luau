--!strict
--[[
	Keyboard / gamepad bindings for mandatory HUD actions.
	Buttons remain Activated for mouse/touch; this covers keys when panels are open.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local ActionBindings = {}

export type Handlers = {
	ready: (() -> ())?,
	reviveAccept: (() -> ())?,
	reviveRefuse: (() -> ())?,
	replay: (() -> ())?,
	leave: (() -> ())?,
	leaveConfirm: (() -> ())?,
	leaveCancel: (() -> ())?,
	reducedMotionToggle: (() -> ())?,
}

export type PanelVisibility = {
	title: boolean,
	revive: boolean,
	credits: boolean,
	leaveConfirm: boolean,
}

local PREFIX = "BellaHud_"

local handlers: Handlers = {}
local visibility: PanelVisibility = {
	title = false,
	revive = false,
	credits = false,
	leaveConfirm = false,
}

local bound = false

local function fire(callback: (() -> ())?)
	if callback then
		callback()
	end
end

local function bind(
	name: string,
	priority: number,
	callback: () -> Enum.ContextActionResult,
	...: Enum.KeyCode
)
	ContextActionService:BindActionAtPriority(PREFIX .. name, function(_action, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		return callback()
	end, false, priority, ...)
end

local function unbindAll()
	for _, name in
		{
			"Ready",
			"ReviveAccept",
			"ReviveRefuse",
			"Replay",
			"Leave",
			"LeaveConfirm",
			"LeaveCancel",
			"ReducedMotion",
		}
	do
		ContextActionService:UnbindAction(PREFIX .. name)
	end
end

local function rebind()
	unbindAll()
	if not bound then
		return
	end

	local high = Enum.ContextActionPriority.High.Value

	if visibility.title then
		bind("Ready", high, function()
			fire(handlers.ready)
			return Enum.ContextActionResult.Sink
		end, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)
	end

	if visibility.revive then
		bind("ReviveAccept", high, function()
			fire(handlers.reviveAccept)
			return Enum.ContextActionResult.Sink
		end, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)
		bind("ReviveRefuse", high, function()
			fire(handlers.reviveRefuse)
			return Enum.ContextActionResult.Sink
		end, Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB)
	end

	if visibility.leaveConfirm then
		bind("LeaveConfirm", high, function()
			fire(handlers.leaveConfirm)
			return Enum.ContextActionResult.Sink
		end, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)
		bind("LeaveCancel", high, function()
			fire(handlers.leaveCancel)
			return Enum.ContextActionResult.Sink
		end, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
	elseif visibility.credits then
		bind("Replay", high, function()
			fire(handlers.replay)
			return Enum.ContextActionResult.Sink
		end, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
		bind("Leave", high, function()
			fire(handlers.leave)
			return Enum.ContextActionResult.Sink
		end, Enum.KeyCode.L, Enum.KeyCode.ButtonB)
	end

	-- Always available so accessibility preference is reachable mid-session.
	bind("ReducedMotion", Enum.ContextActionPriority.Medium.Value, function()
		fire(handlers.reducedMotionToggle)
		return Enum.ContextActionResult.Sink
	end, Enum.KeyCode.M, Enum.KeyCode.DPadDown)
end

function ActionBindings.setHandlers(nextHandlers: Handlers)
	handlers = nextHandlers
	rebind()
end

function ActionBindings.setPanelVisibility(nextVisibility: PanelVisibility)
	visibility = nextVisibility
	rebind()
end

function ActionBindings.start()
	bound = true
	rebind()
end

function ActionBindings.stop()
	bound = false
	unbindAll()
	GuiService.SelectedObject = nil
end

function ActionBindings.focus(guiObject: GuiObject?)
	if guiObject and guiObject.Visible and guiObject.Selectable then
		GuiService.SelectedObject = guiObject
	end
end

function ActionBindings.clearFocus()
	GuiService.SelectedObject = nil
end

-- Pure config surface for tests / documentation (string KeyCode names).
ActionBindings.bindingTable = table.freeze({
	ready = table.freeze({ "Return", "ButtonA" }),
	reviveAccept = table.freeze({ "Return", "ButtonA" }),
	reviveRefuse = table.freeze({ "Backspace", "ButtonB" }),
	replay = table.freeze({ "R", "ButtonX" }),
	leave = table.freeze({ "L", "ButtonB" }),
	leaveConfirm = table.freeze({ "Return", "ButtonA" }),
	leaveCancel = table.freeze({ "Escape", "ButtonB" }),
	reducedMotion = table.freeze({ "M", "DPadDown" }),
	cursorToggle = table.freeze({ "Tab", "ButtonY" }),
})

return ActionBindings
