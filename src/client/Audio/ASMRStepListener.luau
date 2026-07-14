--!strict
--[[
	Local ASMR tower step sounds with per-step IDs, debounce, and progress callback.
	Volumes vary slightly by step index so feedback feels restrained but not identical.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()
local ContentAudio = require(script.Parent:WaitForChild("ContentAudio"))

local ASMRStepListener = {}
ASMRStepListener.__index = ASMRStepListener

export type ProgressHandler = (step: number, total: number) -> ()

export type ASMRStepListener = typeof(setmetatable(
	{} :: {
		_enabled: boolean,
		_debounceSeconds: number,
		_lastPlayed: { [Instance]: number },
		_connections: { RBXScriptConnection },
		_highestStep: number,
		_onProgress: ProgressHandler?,
	},
	ASMRStepListener
))

function ASMRStepListener.new(debounceSeconds: number?): ASMRStepListener
	return setmetatable({
		_enabled = false,
		_debounceSeconds = debounceSeconds or 0.45,
		_lastPlayed = {},
		_connections = {},
		_highestStep = 0,
		_onProgress = nil,
	}, ASMRStepListener)
end

function ASMRStepListener:setProgressHandler(handler: ProgressHandler?)
	self._onProgress = handler
end

local function resolveSoundId(part: BasePart): string
	local attributeId = part:GetAttribute("SoundId")
	if typeof(attributeId) == "string" and attributeId ~= "" then
		return attributeId
	end

	local sequenceIndex = part:GetAttribute("SequenceIndex")
	if typeof(sequenceIndex) == "number" then
		local configured = ContentConfig.sounds.asmrSteps[sequenceIndex]
		if typeof(configured) == "string" then
			return configured
		end
	end

	return "rbxassetid://0"
end

local function volumeForStep(index: number): number
	-- Subtle per-step variance (restrained ASMR feel) without needing unique assets yet.
	local wave = 0.5 + 0.08 * math.sin(index * 1.7)
	return math.clamp(wave, 0.42, 0.62)
end

function ASMRStepListener:_onTouched(part: BasePart, hit: BasePart)
	if not self._enabled then
		return
	end

	local character = Players.LocalPlayer.Character
	if character == nil or not hit:IsDescendantOf(character) then
		return
	end

	local now = os.clock()
	local last = self._lastPlayed[part]
	if last ~= nil and (now - last) < self._debounceSeconds then
		return
	end
	self._lastPlayed[part] = now

	local sequenceIndex = part:GetAttribute("SequenceIndex")
	local stepIndex = if typeof(sequenceIndex) == "number" then sequenceIndex else 0
	local soundId = resolveSoundId(part)
	local sound = ContentAudio.safePlay(soundId, volumeForStep(math.max(stepIndex, 1)), part)
	local playbackSpeed = part:GetAttribute("PlaybackSpeed")
	if sound and typeof(playbackSpeed) == "number" then
		sound.PlaybackSpeed = math.clamp(playbackSpeed, 0.5, 2)
	end

	if stepIndex > self._highestStep then
		self._highestStep = stepIndex
		if self._onProgress then
			self._onProgress(stepIndex, ContentConfig.towerStepCount)
		end
	end
end

function ASMRStepListener:_bindPart(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local connection = part.Touched:Connect(function(hit)
		if hit:IsA("BasePart") then
			self:_onTouched(part, hit)
		end
	end)
	table.insert(self._connections, connection)
end

function ASMRStepListener:start()
	if self._enabled then
		return
	end
	self._enabled = true
	self._highestStep = 0

	for _, tagged in CollectionService:GetTagged("ASMRStep") do
		self:_bindPart(tagged)
	end

	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal("ASMRStep"):Connect(function(instance)
			self:_bindPart(instance)
		end)
	)
end

function ASMRStepListener:stop()
	self._enabled = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._lastPlayed)
	self._highestStep = 0
end

function ASMRStepListener:reset()
	self:stop()
	self:start()
end

return ASMRStepListener
