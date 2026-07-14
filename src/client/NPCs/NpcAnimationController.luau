--!strict
--[[
	Client animation helpers for cinematic NPC clones.
	Generation-safe play/stop; placeholders never invent uploaded clips.
]]

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))

local AnimationIdsModule = SharedAccess.getSharedFolder(5):WaitForChild("AnimationIds")
local AnimationIds = (require :: any)(AnimationIdsModule)

local NpcAnimationController = {}

local ATTR_GENERATION = "_NpcAnimGeneration"

local function findAnimator(model: Model): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local existing = humanoid:FindFirstChildOfClass("Animator")
		if existing then
			return existing
		end
		local animator = Instance.new("Animator")
		animator.Parent = humanoid
		return animator
	end

	local existingController = model:FindFirstChildOfClass("AnimationController")
	local controller: AnimationController
	if existingController then
		controller = existingController
	else
		controller = Instance.new("AnimationController")
		controller.Name = "CinematicAnimationController"
		controller.Parent = model
	end
	local existing = controller:FindFirstChildOfClass("Animator")
	if existing then
		return existing
	end
	local animator = Instance.new("Animator")
	animator.Parent = controller
	return animator
end

function NpcAnimationController.ensureAnimator(model: Model): Animator?
	if model.Parent == nil then
		return nil
	end
	return findAnimator(model)
end

function NpcAnimationController.stopAll(model: Model, fadeTime: number?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator: Animator? = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if animator == nil then
		local controller = model:FindFirstChildOfClass("AnimationController")
		animator = if controller then controller:FindFirstChildOfClass("Animator") else nil
	end
	if animator == nil then
		return
	end
	local fade = fadeTime or 0.1
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(fade)
	end
end

function NpcAnimationController.play(
	model: Model,
	animationId: string?,
	fadeTime: number?,
	generation: number?
): AnimationTrack?
	if AnimationIds.isPlaceholder(animationId) then
		return nil
	end
	local animator = NpcAnimationController.ensureAnimator(model)
	if animator == nil or typeof(animationId) ~= "string" then
		return nil
	end

	local token = generation or 0
	model:SetAttribute(ATTR_GENERATION, token)

	NpcAnimationController.stopAll(model, fadeTime or 0.08)

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local ok, trackOrErr = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok or typeof(trackOrErr) ~= "Instance" then
		return nil
	end

	local track = trackOrErr :: AnimationTrack
	track.Looped = false
	track:Play(fadeTime or 0.12)
	task.defer(function()
		if model:GetAttribute(ATTR_GENERATION) ~= token then
			track:Stop(0)
		end
	end)
	return track
end

function NpcAnimationController.cancel(model: Model, generation: number)
	model:SetAttribute(ATTR_GENERATION, generation + 1)
	NpcAnimationController.stopAll(model, 0)
end

return NpcAnimationController
