--!strict
--[[
	Session-scoped player preferences (not persisted).

	Handoff for runtime agent (CinematicPlayer / StoryPresenter):
	  local SessionPreferences = require(...Controls.SessionPreferences)
	  if SessionPreferences.isReducedMotion() then
	    -- skip camera shake, shorten cinematic pans, avoid large fades
	  end
	  SessionPreferences.onChanged(function(prefs)
	    -- react to mid-session toggles
	  end)

	Owned soft effects (Feedback / GuiShell) already honor this module.
]]

export type Preferences = {
	reducedMotion: boolean,
}

local SessionPreferences = {}

local prefs: Preferences = {
	reducedMotion = false,
}

local listeners: { (Preferences) -> () } = {}

local function notify()
	local snapshot: Preferences = {
		reducedMotion = prefs.reducedMotion,
	}
	for _, listener in listeners do
		listener(snapshot)
	end
end

function SessionPreferences.get(): Preferences
	return {
		reducedMotion = prefs.reducedMotion,
	}
end

function SessionPreferences.isReducedMotion(): boolean
	return prefs.reducedMotion
end

function SessionPreferences.setReducedMotion(enabled: boolean)
	if prefs.reducedMotion == enabled then
		return
	end
	prefs.reducedMotion = enabled
	notify()
end

function SessionPreferences.toggleReducedMotion(): boolean
	SessionPreferences.setReducedMotion(not prefs.reducedMotion)
	return prefs.reducedMotion
end

function SessionPreferences.onChanged(listener: (Preferences) -> ()): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function SessionPreferences.resetToDefaults()
	prefs.reducedMotion = false
	notify()
end

-- Motion helpers for Feedback / UI owners.
function SessionPreferences.tweenSeconds(normalSeconds: number, reducedSeconds: number?): number
	if prefs.reducedMotion then
		return reducedSeconds or math.min(normalSeconds * 0.25, 0.08)
	end
	return normalSeconds
end

function SessionPreferences.shouldSkipMotionEffects(): boolean
	return prefs.reducedMotion
end

return SessionPreferences
