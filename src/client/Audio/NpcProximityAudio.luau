--!strict
--[[
	Spatial approach loops parented to NPC roots during chase / escort states.
	Client-only presentation; does not touch server NPC authority.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()
local ContentAudio = require(script.Parent:WaitForChild("ContentAudio"))

local NpcProximityAudio = {}

local SOUND_NAME = "ContentNpcApproach"
local activeProfiles: { [string]: boolean } = {}
local heartbeat: RBXScriptConnection? = nil
local lastTick = 0

local PROFILE_ENTRY: { [string]: any } = {
	Bella = ContentConfig.sounds.hostileApproach,
	FriendlyRambo = ContentConfig.sounds.friendlyApproach,
	EvilRambo = ContentConfig.sounds.evilApproach,
}

local function findRoot(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		return instance.PrimaryPart
			or instance:FindFirstChild("HumanoidRootPart", true) :: BasePart?
	end
	return nil
end

local function matchNpcType(instance: Instance, npcType: string): boolean
	local attr = instance:GetAttribute("NPCType")
	if attr == npcType then
		return true
	end
	local model = if instance:IsA("Model")
		then instance
		else instance:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("NPCType") == npcType then
		return true
	end
	if string.find(string.lower(instance.Name), string.lower(npcType), 1, true) then
		return true
	end
	return false
end

local function rootsFor(npcType: string): { BasePart }
	local roots: { BasePart } = {}
	local seen: { [BasePart]: boolean } = {}
	local function consider(instance: Instance)
		if not matchNpcType(instance, npcType) then
			return
		end
		local root = findRoot(instance)
		if root and not seen[root] then
			seen[root] = true
			table.insert(roots, root)
		end
	end
	for _, tag in { "NPCSpawn", "HostileNpc", "FriendlyNpc", "NPC" } do
		for _, tagged in CollectionService:GetTagged(tag) do
			consider(tagged)
		end
	end
	for _, child in Workspace:GetDescendants() do
		if child:IsA("Model") and matchNpcType(child, npcType) then
			consider(child)
		end
	end
	return roots
end

local function syncProfile(npcType: string, enabled: boolean)
	local entry = PROFILE_ENTRY[npcType]
	if entry == nil then
		return
	end
	local roots = rootsFor(npcType)
	if not enabled then
		for _, root in roots do
			ContentAudio.stopSpatialLoop(root, SOUND_NAME)
		end
		return
	end
	for _, root in roots do
		local sound = ContentAudio.playSpatialLoop(entry, root, SOUND_NAME)
		if sound then
			local camera = Workspace.CurrentCamera
			if camera then
				local distance = (camera.CFrame.Position - root.Position).Magnitude
				local nearFactor = math.clamp(1 - (distance / 65), 0.15, 1)
				sound.Volume = entry.volume * nearFactor
				sound.PlaybackSpeed = 0.85 + (1 - nearFactor) * 0.25
			end
		end
	end
end

local function tick()
	for npcType in activeProfiles do
		syncProfile(npcType, true)
	end
end

local function ensureLoop()
	if heartbeat then
		return
	end
	heartbeat = RunService.Heartbeat:Connect(function()
		if next(activeProfiles) == nil then
			return
		end
		local now = os.clock()
		if now - lastTick < 0.2 then
			return
		end
		lastTick = now
		tick()
	end)
end

function NpcProximityAudio.setProfile(npcType: string, enabled: boolean)
	if enabled then
		activeProfiles[npcType] = true
		ensureLoop()
		syncProfile(npcType, true)
	else
		activeProfiles[npcType] = nil
		syncProfile(npcType, false)
		if next(activeProfiles) == nil and heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
	end
end

function NpcProximityAudio.applyStoryState(state: string)
	NpcProximityAudio.setProfile("Bella", state == "BellaChase")
	NpcProximityAudio.setProfile("FriendlyRambo", state == "MazeIntro" or state == "BellaChase")
	NpcProximityAudio.setProfile("EvilRambo", state == "FieldHunt")
	if state == "RoleLobby" or state == "Credits" then
		NpcProximityAudio.reset()
	end
end

function NpcProximityAudio.reset()
	for npcType in activeProfiles do
		syncProfile(npcType, false)
	end
	table.clear(activeProfiles)
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

return NpcProximityAudio
