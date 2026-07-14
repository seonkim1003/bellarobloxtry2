--!strict
--[[
	First-person presentation lock for horror camera feel.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local FirstPerson = {}

function FirstPerson.apply()
	local player = Players.LocalPlayer
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
end

function FirstPerson.release()
	local player = Players.LocalPlayer
	player.CameraMode = Enum.CameraMode.Classic
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
	end)
end

return FirstPerson
