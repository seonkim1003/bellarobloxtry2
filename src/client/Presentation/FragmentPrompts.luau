--!strict
--[[
	Client-side ProximityPrompt presentation for letter fragments (server still owns pickup).
]]

local CollectionService = game:GetService("CollectionService")

local ContentAudio =
	require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("ContentAudio"))

local FragmentPrompts = {}

local connections: { RBXScriptConnection } = {}
local lastHoldTick = 0

local function attachPrompt(target: Instance)
	local part: BasePart? = nil
	if target:IsA("BasePart") then
		part = target
	elseif target:IsA("Model") then
		part = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	if part == nil then
		return
	end
	if part:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FragmentPrompt"
	prompt.ActionText = "Take piece"
	prompt.ObjectText = "Letter fragment"
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = part

	table.insert(
		connections,
		prompt.PromptShown:Connect(function()
			ContentAudio.playPromptShown()
		end)
	)
	table.insert(
		connections,
		prompt.PromptButtonHoldBegan:Connect(function()
			local now = os.clock()
			if now - lastHoldTick < 0.35 then
				return
			end
			lastHoldTick = now
			ContentAudio.playPromptHold()
		end)
	)
end

function FragmentPrompts.start()
	FragmentPrompts.stop()
	for _, tagged in CollectionService:GetTagged("LetterFragment") do
		attachPrompt(tagged)
	end
	table.insert(
		connections,
		CollectionService:GetInstanceAddedSignal("LetterFragment"):Connect(function(instance)
			attachPrompt(instance)
		end)
	)
end

function FragmentPrompts.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

function FragmentPrompts.reset()
	FragmentPrompts.start()
end

return FragmentPrompts
