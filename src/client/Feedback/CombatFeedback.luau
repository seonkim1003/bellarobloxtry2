--!strict
--[[
	Local humanoid hit / death / low-health SFX. Covers Bella TakeDamage without
	new remotes (HealthChanged on the local character).
]]

local Players = game:GetService("Players")

local ContentAudio =
	require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("ContentAudio"))

local CombatFeedback = {}

local healthConnection: RBXScriptConnection? = nil
local characterConnection: RBXScriptConnection? = nil
local lastHealth: number? = nil
local lowHealthArmed = true
local hitDebounceUntil = 0
local deathDebounceUntil = 0

local function disconnectHealth()
	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end
end

local function bindHumanoid(humanoid: Humanoid)
	disconnectHealth()
	lastHealth = humanoid.Health
	lowHealthArmed = humanoid.Health > 50
	healthConnection = humanoid.HealthChanged:Connect(function(health: number)
		local previous = lastHealth
		lastHealth = health
		if previous == nil then
			return
		end
		local now = os.clock()
		if health < previous then
			if health <= 0 then
				if now >= deathDebounceUntil then
					deathDebounceUntil = now + 1.2
					ContentAudio.playPlayerDeath()
					task.delay(0.15, function()
						ContentAudio.playRespawn()
					end)
				end
			elseif now >= hitDebounceUntil then
				hitDebounceUntil = now + 0.18
				ContentAudio.playPlayerHit()
			end
			if health <= 50 and previous > 50 and lowHealthArmed then
				lowHealthArmed = false
				ContentAudio.playHealthLow()
			end
		elseif health > 50 then
			lowHealthArmed = true
		end
	end)
end

local function onCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		bindHumanoid(humanoid)
	end
end

function CombatFeedback.start()
	CombatFeedback.stop()
	local player = Players.LocalPlayer
	if player.Character then
		onCharacter(player.Character)
	end
	characterConnection = player.CharacterAdded:Connect(onCharacter)
end

function CombatFeedback.stop()
	disconnectHealth()
	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end
	lastHealth = nil
end

return CombatFeedback
