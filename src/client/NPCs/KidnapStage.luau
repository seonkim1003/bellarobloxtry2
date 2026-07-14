--!strict
--[[
	Exit kidnap presentation: Bella takes Rambo using mounted marketplace models.
	Client-only cinematic clones so the live maze NPCs can stay server-authoritative.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local KidnapStage = {}
KidnapStage.__index = KidnapStage

export type KidnapStage = typeof(setmetatable({} :: KidnapStageInternal, KidnapStage))

type KidnapStageInternal = {
	_folder: Folder?,
	_bella: Model?,
	_rambo: Model?,
	_hiddenNpcs: { BasePart },
	_grabbed: boolean,
	_generation: number,
	_ready: boolean,
	_currentMarkerId: string?,
}

local FOLDER_NAME = "ContentKidnapCutscene"
local HIDDEN_ATTR = "_KidnapCutsceneHidden"

local function findMazeExit(): BasePart?
	for _, tagged in CollectionService:GetTagged("MazeExit") do
		if tagged:IsA("BasePart") then
			return tagged
		end
	end
	return nil
end

local function findMarker(markerId: string): BasePart?
	for _, tagged in CollectionService:GetTagged("CinematicMarker") do
		if tagged:IsA("BasePart") and tagged:GetAttribute("MarkerId") == markerId then
			return tagged
		end
	end
	if markerId == "KidnapStart" then
		return findMazeExit()
	end
	return nil
end

local function waitForTemplates(timeoutSeconds: number): boolean
	local deadline = os.clock() + timeoutSeconds
	while os.clock() < deadline do
		local folder = ReplicatedStorage:FindFirstChild("ContentModels")
		if folder and folder:IsA("Folder") and folder:GetAttribute("Ready") == true then
			return true
		end
		task.wait(0.1)
	end
	return ReplicatedStorage:FindFirstChild("ContentModels") ~= nil
end

local function ensurePrimary(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	if part then
		model.PrimaryPart = part
	end
	return part
end

local function groundPivot(model: Model, target: CFrame)
	local ok, bounds, size = pcall(function()
		return model:GetBoundingBox()
	end)
	if not ok then
		model:PivotTo(target)
		return
	end
	local bottom = Vector3.new(bounds.Position.X, bounds.Position.Y - size.Y / 2, bounds.Position.Z)
	local ground = Vector3.new(target.Position.X, target.Position.Y, target.Position.Z)
	model:PivotTo(model:GetPivot() + (ground - bottom))
	local _, yaw = target:ToEulerAnglesYXZ()
	model:PivotTo(CFrame.new(model:GetPivot().Position) * CFrame.Angles(0, yaw, 0))
end

local function createFallback(name: string, size: Vector3, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = name
	local part = Instance.new("Part")
	part.Name = "FallbackVisual"
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Parent = model
	model.PrimaryPart = part
	return model
end

local function cloneTemplate(templateName: string, actorName: string): Model
	local templates = ReplicatedStorage:FindFirstChild("ContentModels")
	local template = if templates then templates:FindFirstChild(templateName) else nil
	if template and template:IsA("Model") then
		local model = template:Clone()
		model.Name = actorName
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
			end
		end
		ensurePrimary(model)
		return model
	end

	if templateName == "Bella" then
		return createFallback(actorName, Vector3.new(4, 6, 3), Color3.fromRGB(120, 50, 55))
	end
	return createFallback(actorName, Vector3.new(3, 2.5, 4), Color3.fromRGB(145, 105, 70))
end

local function tweenPivot(
	model: Model,
	target: CFrame,
	duration: number,
	shouldContinue: (() -> boolean)?
)
	if not model:IsDescendantOf(Workspace) or (shouldContinue and not shouldContinue()) then
		return
	end
	local start = model:GetPivot()
	local alpha = Instance.new("NumberValue")
	alpha.Value = 0
	local tween = TweenService:Create(
		alpha,
		TweenInfo.new(math.max(duration, 0.05), Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Value = 1 }
	)
	local connection = alpha.Changed:Connect(function()
		if not model:IsDescendantOf(Workspace) or (shouldContinue and not shouldContinue()) then
			tween:Cancel()
			return
		end
		model:PivotTo(start:Lerp(target, alpha.Value))
	end)
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	alpha:Destroy()
	if model:IsDescendantOf(Workspace) and (shouldContinue == nil or shouldContinue()) then
		model:PivotTo(target)
	end
end

local function hideLiveNpcs(): { BasePart }
	local hidden: { BasePart } = {}
	local folder = Workspace:FindFirstChild("ContentNPCs")
	if folder == nil then
		return hidden
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			local npcType = child:GetAttribute("NPCType")
			if npcType == "Bella" or npcType == "FriendlyRambo" then
				child:SetAttribute(HIDDEN_ATTR, true)
				for _, descendant in child:GetDescendants() do
					if descendant:IsA("BasePart") then
						descendant.LocalTransparencyModifier = 1
						table.insert(hidden, descendant)
					end
				end
			end
		end
	end
	return hidden
end

local function restoreLiveNpcs(hidden: { BasePart })
	for _, part in hidden do
		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
	local folder = Workspace:FindFirstChild("ContentNPCs")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and child:GetAttribute(HIDDEN_ATTR) == true then
				child:SetAttribute(HIDDEN_ATTR, nil)
			end
		end
	end
end

function KidnapStage.new(): KidnapStage
	return setmetatable({
		_folder = nil,
		_bella = nil,
		_rambo = nil,
		_hiddenNpcs = {},
		_grabbed = false,
		_generation = 0,
		_ready = false,
		_currentMarkerId = nil,
	}, KidnapStage)
end

function KidnapStage.isReady(self: KidnapStage): boolean
	return self._ready
end

function KidnapStage.prepare(self: KidnapStage): boolean
	self:clear()
	self._generation += 1
	self._grabbed = false
	self._ready = false
	self._hiddenNpcs = hideLiveNpcs()
	waitForTemplates(8)

	local exitPart = findMazeExit() or findMarker("KidnapStart")
	local holdPart = findMarker("KidnapHold") or exitPart
	if exitPart == nil then
		warn("[KidnapStage] Missing MazeExit / KidnapStart marker; cutscene cannot stage")
		return false
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	self._folder = folder

	local rambo = cloneTemplate("RamboFriendly", "KidnapRambo")
	local bella = cloneTemplate("Bella", "KidnapBella")
	ensurePrimary(rambo)
	ensurePrimary(bella)

	local ramboAtExit = exitPart.CFrame * CFrame.new(0, 0, 2)
	local bellaWaiting = (holdPart or exitPart).CFrame
		* CFrame.new(-3.5, 0, -4)
		* CFrame.Angles(0, math.rad(25), 0)

	groundPivot(rambo, ramboAtExit)
	groundPivot(bella, bellaWaiting)

	rambo.Parent = folder
	bella.Parent = folder
	self._rambo = rambo
	self._bella = bella
	self._ready = true
	return true
end

function KidnapStage.setCurrentMarker(self: KidnapStage, markerId: string)
	self._currentMarkerId = markerId
end

function KidnapStage.getFocusCFrame(self: KidnapStage, markerId: string?): CFrame?
	local phaseId = markerId or self._currentMarkerId or "KidnapStart"
	local exitPart = findMazeExit() or findMarker("KidnapStart")
	local holdPart = findMarker("KidnapHold")
	local departPart = findMarker("KidnapDepart")

	local focus = Vector3.zero
	if phaseId == "KidnapStart" and self._rambo then
		focus = self._rambo:GetPivot().Position + Vector3.new(0, 2, 0)
	elseif phaseId == "KidnapApproach" then
		if self._bella and self._rambo then
			focus = self._bella:GetPivot().Position:Lerp(self._rambo:GetPivot().Position, 0.45)
				+ Vector3.new(0, 2.2, 0)
		elseif holdPart then
			focus = holdPart.Position + Vector3.new(0, 2, 0)
		end
	elseif phaseId == "KidnapHold" then
		if self._bella and self._rambo then
			focus = self._bella:GetPivot().Position:Lerp(self._rambo:GetPivot().Position, 0.65)
				+ Vector3.new(0, 2, 0)
		elseif holdPart then
			focus = holdPart.Position + Vector3.new(0, 2, 0)
		end
	elseif phaseId == "KidnapDepart" then
		if self._bella and self._rambo then
			focus = self._bella:GetPivot().Position:Lerp(self._rambo:GetPivot().Position, 0.5)
				+ Vector3.new(0, 2.5, 0)
		elseif departPart then
			focus = departPart.Position + Vector3.new(0, 2, 0)
		end
	elseif exitPart then
		focus = exitPart.Position + Vector3.new(0, 2, 0)
	end

	if focus == Vector3.zero then
		return nil
	end

	local cameraOffset = Vector3.new(8, 5, -8)
	return CFrame.lookAt(focus + cameraOffset, focus)
end

function KidnapStage.beginPhase(self: KidnapStage, markerId: string, durationSeconds: number)
	self._currentMarkerId = markerId
	local bella = self._bella
	local rambo = self._rambo
	if bella == nil or rambo == nil then
		return
	end

	local generation = self._generation
	local function stillCurrent(): boolean
		return self._generation == generation
	end
	task.spawn(function()
		local exitPart = findMazeExit() or findMarker("KidnapStart")
		if exitPart == nil then
			return
		end

		if markerId == "KidnapStart" then
			local approachStart = exitPart.CFrame
				* CFrame.new(-5, 0, -6)
				* CFrame.Angles(0, math.rad(20), 0)
			tweenPivot(bella, approachStart, durationSeconds * 0.35, stillCurrent)
			return
		end

		if markerId == "KidnapApproach" then
			local target = exitPart.CFrame
				* CFrame.new(-1.8, 0, -1.2)
				* CFrame.Angles(0, math.rad(-15), 0)
			tweenPivot(bella, target, durationSeconds * 0.92, stillCurrent)
			return
		end

		if markerId == "KidnapHold" and not self._grabbed then
			self._grabbed = true
			local grabPoint = bella:GetPivot() * CFrame.new(1.2, 0, 0.6)
			tweenPivot(rambo, grabPoint, durationSeconds * 0.55, stillCurrent)
			if self._generation ~= generation then
				return
			end
			task.wait(durationSeconds * 0.1)
			local lift = grabPoint * CFrame.new(0, 0.35, -0.2)
			tweenPivot(rambo, lift, durationSeconds * 0.25, stillCurrent)
			return
		end

		if markerId == "KidnapDepart" then
			local departPart = findMarker("KidnapDepart")
			local holdPart = findMarker("KidnapHold")
			local destination = if departPart
				then departPart.CFrame
				else (if holdPart
					then holdPart.CFrame * CFrame.new(-6, 0, -14)
					else bella:GetPivot() * CFrame.new(-6, 0, -14))

			local bellaTarget = destination * CFrame.Angles(0, math.rad(35), 0)
			local ramboTarget = bellaTarget * CFrame.new(1.1, 0.35, 0.5)
			local moveDuration = durationSeconds * 0.9
			task.spawn(function()
				tweenPivot(bella, bellaTarget, moveDuration, stillCurrent)
			end)
			tweenPivot(rambo, ramboTarget, moveDuration, stillCurrent)
		end
	end)
end

function KidnapStage.clear(self: KidnapStage)
	self._generation += 1
	self._grabbed = false
	self._ready = false
	self._currentMarkerId = nil
	restoreLiveNpcs(self._hiddenNpcs)
	self._hiddenNpcs = {}

	local folder = self._folder or Workspace:FindFirstChild(FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
	self._folder = nil
	self._bella = nil
	self._rambo = nil
end

return KidnapStage
