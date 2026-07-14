--!strict
--[[
	Procedural dog-fight puppets (Evil Rambo vs Gigi).
	Uses cinematic clones; live Field NPCs stay server-authoritative.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local AnimationIds = (require :: any)(SharedAccess.getSharedFolder(5):WaitForChild("AnimationIds"))
local NpcAnimationController = require(script.Parent:WaitForChild("NpcAnimationController"))

local DogPuppet = {}
DogPuppet.__index = DogPuppet

export type DogPuppet = typeof(setmetatable({} :: DogPuppetInternal, DogPuppet))

type DogPuppetInternal = {
	_folder: Folder?,
	_rambo: Model?,
	_gigi: Model?,
	_hiddenNpcs: { BasePart },
	_generation: number,
	_ready: boolean,
	_stageCFrame: CFrame,
}

local FOLDER_NAME = "ContentDogFight"
local HIDDEN_ATTR = "_DogFightHidden"

local BEAT_POSES: { [string]: { rambo: CFrame, gigi: CFrame } } = {
	Establish = {
		rambo = CFrame.new(3.5, 0, 1) * CFrame.Angles(0, math.rad(-25), 0),
		gigi = CFrame.new(-3.2, 0, -0.5) * CFrame.Angles(0, math.rad(35), 0),
	},
	RamboStalk = {
		rambo = CFrame.new(2.2, 0, 0.2) * CFrame.Angles(0, math.rad(-10), 0),
		gigi = CFrame.new(-3.4, 0, -0.8) * CFrame.Angles(0, math.rad(20), 0),
	},
	AttackTelegraph = {
		rambo = CFrame.new(1.4, 0.15, -0.4) * CFrame.Angles(0, math.rad(5), math.rad(-8)),
		gigi = CFrame.new(-2.6, 0, -0.2) * CFrame.Angles(0, math.rad(5), 0),
	},
	FirstClash = {
		rambo = CFrame.new(0.6, 0.25, -0.6) * CFrame.Angles(0, math.rad(15), math.rad(6)),
		gigi = CFrame.new(-0.4, 0.2, -0.5) * CFrame.Angles(0, math.rad(-15), math.rad(-4)),
	},
	RamboAdvantage = {
		rambo = CFrame.new(-0.2, 0.35, -0.8) * CFrame.Angles(0, math.rad(30), 0),
		gigi = CFrame.new(-1.8, -0.05, 0.4) * CFrame.Angles(0, math.rad(-40), math.rad(12)),
	},
	GigiCounter = {
		rambo = CFrame.new(1.1, 0.1, 0.3) * CFrame.Angles(0, math.rad(-45), math.rad(-10)),
		gigi = CFrame.new(0.2, 0.3, -0.9) * CFrame.Angles(0, math.rad(25), 0),
	},
	RamboBackDown = {
		rambo = CFrame.new(3.0, -0.1, 1.4) * CFrame.Angles(0, math.rad(-55), math.rad(8)),
		gigi = CFrame.new(0.4, 0.15, -0.4) * CFrame.Angles(0, math.rad(10), 0),
	},
	GigiVictory = {
		rambo = CFrame.new(3.6, -0.2, 2.0) * CFrame.Angles(0, math.rad(-70), math.rad(12)),
		gigi = CFrame.new(0.0, 0.25, -0.2) * CFrame.Angles(0, math.rad(0), 0),
	},
}

local function findMarker(markerId: string): BasePart?
	for _, tagged in CollectionService:GetTagged("CinematicMarker") do
		if tagged:IsA("BasePart") and tagged:GetAttribute("MarkerId") == markerId then
			return tagged
		end
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
	local ground = target.Position
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

local function prepareClone(model: Model)
	-- Keep Motor6D joints when present so uploaded clips can drive the rig.
	-- Otherwise parts stay anchored for procedural PivotTo posing.
	local motorParts: { [BasePart]: boolean } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			if descendant.Part0 then
				motorParts[descendant.Part0] = true
			end
			if descendant.Part1 then
				motorParts[descendant.Part1] = true
			end
		end
	end
	local hasMotors = next(motorParts) ~= nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			if hasMotors and motorParts[descendant] then
				descendant.Anchored = false
				descendant.Massless = true
			else
				descendant.Anchored = true
			end
		end
	end
	ensurePrimary(model)
	if hasMotors then
		NpcAnimationController.ensureAnimator(model)
	end
end

local function cloneTemplate(templateName: string, actorName: string): Model
	local templates = ReplicatedStorage:FindFirstChild("ContentModels")
	local template = if templates then templates:FindFirstChild(templateName) else nil
	if template and template:IsA("Model") then
		local model = template:Clone()
		model.Name = actorName
		prepareClone(model)
		return model
	end
	if templateName == "Gigi" then
		return createFallback(actorName, Vector3.new(2.5, 2.2, 3.2), Color3.fromRGB(190, 170, 140))
	end
	return createFallback(actorName, Vector3.new(4, 3.5, 5), Color3.fromRGB(90, 50, 40))
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
			if npcType == "EvilRambo" or npcType == "Gigi" then
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

function DogPuppet.new(): DogPuppet
	return setmetatable({
		_folder = nil,
		_rambo = nil,
		_gigi = nil,
		_hiddenNpcs = {},
		_generation = 0,
		_ready = false,
		_stageCFrame = CFrame.new(3612, 2, 10),
	}, DogPuppet)
end

function DogPuppet.isReady(self: DogPuppet): boolean
	return self._ready
end

function DogPuppet.getStageCFrame(self: DogPuppet): CFrame
	return self._stageCFrame
end

local CAMERA_MARKERS: { [string]: string } = {
	Establish = "FightEstablish",
	RamboStalk = "FightRamboStalk",
	AttackTelegraph = "FightAttackTelegraph",
	FirstClash = "FightFirstClash",
	RamboAdvantage = "FightRamboAdvantage",
	GigiCounter = "FightGigiCounter",
	RamboBackDown = "FightRamboBackDown",
	GigiVictory = "FightGigiVictory",
}

function DogPuppet.getFocusCFrame(self: DogPuppet, beatId: string?): CFrame?
	local cameraMarkerId = if beatId and CAMERA_MARKERS[beatId]
		then CAMERA_MARKERS[beatId]
		else "FightSilhouette"
	local cameraMarker = findMarker(cameraMarkerId)
	if cameraMarker then
		return cameraMarker.CFrame
	end

	local focus = self._stageCFrame.Position + Vector3.new(0, 2.5, 0)
	if self._rambo and self._gigi then
		focus = self._rambo:GetPivot().Position:Lerp(self._gigi:GetPivot().Position, 0.5)
			+ Vector3.new(0, 2.4, 0)
	end
	local offset = Vector3.new(7, 4.5, -8)
	return CFrame.lookAt(focus + offset, focus)
end

function DogPuppet.prepare(self: DogPuppet): boolean
	self:clear()
	self._generation += 1
	self._ready = false
	self._hiddenNpcs = hideLiveNpcs()
	waitForTemplates(8)

	local stage = findMarker("FightSilhouette")
	if stage then
		self._stageCFrame = stage.CFrame
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	self._folder = folder

	local rambo = cloneTemplate("RamboEvil", "FightRambo")
	local gigi = cloneTemplate("Gigi", "FightGigi")
	groundPivot(rambo, self._stageCFrame * BEAT_POSES.Establish.rambo)
	groundPivot(gigi, self._stageCFrame * BEAT_POSES.Establish.gigi)
	rambo.Parent = folder
	gigi.Parent = folder
	self._rambo = rambo
	self._gigi = gigi
	self._ready = true
	return true
end

function DogPuppet.beginBeat(
	self: DogPuppet,
	beatId: string,
	durationSeconds: number,
	reducedMotion: boolean?
)
	local rambo = self._rambo
	local gigi = self._gigi
	if rambo == nil or gigi == nil then
		return
	end
	local poses = BEAT_POSES[beatId]
	if poses == nil then
		return
	end

	local generation = self._generation
	local function stillCurrent(): boolean
		return self._generation == generation
	end

	local animId = AnimationIds.DogFight[beatId]
	NpcAnimationController.play(rambo, animId, 0.1, generation)
	NpcAnimationController.play(gigi, animId, 0.1, generation)

	local moveDuration = if reducedMotion
		then math.min(durationSeconds * 0.35, 0.35)
		else durationSeconds * 0.85

	task.spawn(function()
		local ramboTarget = self._stageCFrame * poses.rambo
		local gigiTarget = self._stageCFrame * poses.gigi
		task.spawn(function()
			if reducedMotion then
				if stillCurrent() then
					groundPivot(rambo, ramboTarget)
				end
				return
			end
			tweenPivot(rambo, ramboTarget, moveDuration, stillCurrent)
		end)
		if reducedMotion then
			if stillCurrent() then
				groundPivot(gigi, gigiTarget)
			end
			return
		end
		tweenPivot(gigi, gigiTarget, moveDuration, stillCurrent)
	end)
end

function DogPuppet.clear(self: DogPuppet)
	self._generation += 1
	self._ready = false
	if self._rambo then
		NpcAnimationController.cancel(self._rambo, self._generation)
	end
	if self._gigi then
		NpcAnimationController.cancel(self._gigi, self._generation)
	end
	restoreLiveNpcs(self._hiddenNpcs)
	self._hiddenNpcs = {}

	local folder = self._folder or Workspace:FindFirstChild(FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
	self._folder = nil
	self._rambo = nil
	self._gigi = nil
end

return DogPuppet
