--!strict
--[[
	Local ASMR tower step sounds with per-step IDs and debounce.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()
local ContentAudio = require(script.Parent:WaitForChild("ContentAudio"))

local ASMRStepListener = {}
ASMRStepListener.__index = ASMRStepListener

export type ASMRStepListener = typeof(setmetatable(
	{} :: {
		_enabled: boolean,
		_debounceSeconds: number,
		_lastPlayed: { [Instance]: number },
		_connections: { RBXScriptConnection },
	},
	ASMRStepListener
))

function ASMRStepListener.new(debounceSeconds: number?): ASMRStepListener
	return setmetatable({
		_enabled = false,
		_debounceSeconds = debounceSeconds or 0.45,
		_lastPlayed = {},
		_connections = {},
	}, ASMRStepListener)
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

	local soundId = resolveSoundId(part)
	ContentAudio.safePlay(soundId, 0.55, part)
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
end

function ASMRStepListener:reset()
	self:stop()
	self:start()
end

return ASMRStepListener
