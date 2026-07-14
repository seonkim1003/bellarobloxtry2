--!strict
--[[
	Named animation asset IDs for cinematic presentation.
	Do not invent uploaded asset IDs here — keep placeholders until creator uploads.
]]

local PLACEHOLDER = "rbxassetid://0"

local AnimationIds = {
	Placeholder = PLACEHOLDER,

	-- Shared cinematic clips (awaiting creator upload).
	KidnapHold = PLACEHOLDER,
	ReviveKneel = PLACEHOLDER,
	CorruptionPulse = PLACEHOLDER,

	-- Kidnap phase fallbacks (procedural motion when placeholder).
	Kidnap = table.freeze({
		ApproachWindup = PLACEHOLDER,
		CloseIn = PLACEHOLDER,
		HoldGrasp = PLACEHOLDER,
		CarryAway = PLACEHOLDER,
	}),

	-- Dog fight beat clips (procedural DogPuppet when placeholder).
	DogFight = table.freeze({
		Establish = PLACEHOLDER,
		RamboStalk = PLACEHOLDER,
		AttackTelegraph = PLACEHOLDER,
		FirstClash = PLACEHOLDER,
		RamboAdvantage = PLACEHOLDER,
		GigiCounter = PLACEHOLDER,
		RamboBackDown = PLACEHOLDER,
		GigiVictory = PLACEHOLDER,
	}),
}

function AnimationIds.isPlaceholder(animationId: string?): boolean
	if typeof(animationId) ~= "string" then
		return true
	end
	local digits = string.match(animationId, "(%d+)$")
	return digits == nil or digits == "0"
end

return table.freeze(AnimationIds)
