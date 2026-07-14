--!strict

local RunService = game:GetService("RunService")

local NpcLocomotion = {}

type LocomotionHandle = {
	motor: Motor6D,
	connection: RBXScriptConnection,
	phase: number,
	bobScale: number,
}

local handles: { [Model]: LocomotionHandle } = {}

local function findLocomotionMotor(model: Model): Motor6D?
	local joint = model:FindFirstChild("LocomotionJoint", true)
	if joint and joint:IsA("Motor6D") then
		return joint
	end
	return nil
end

local function bobScaleFor(model: Model): number
	local npcType = model:GetAttribute("NPCType")
	if npcType == "EvilRambo" then
		return 1.35
	end
	return 1
end

function NpcLocomotion.attach(model: Model, root: BasePart)
	if handles[model] then
		return
	end

	local motor = findLocomotionMotor(model)
	if motor == nil then
		return
	end

	local phase = 0
	local bobScale = bobScaleFor(model)
	local connection = RunService.Heartbeat:Connect(function(dt: number)
		if model.Parent == nil then
			NpcLocomotion.detach(model)
			return
		end

		local velocity = root.AssemblyLinearVelocity
		local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local isMoving = horizontalSpeed > 0.35

		if isMoving then
			phase += dt * math.clamp(horizontalSpeed / 4, 6, 14)
			local cycle = phase * math.pi * 2
			local bob = math.sin(cycle) * 0.14 * bobScale
			local pitch = math.sin(cycle) * 0.1 * bobScale
			local roll = math.sin(phase * math.pi) * 0.06 * bobScale
			motor.Transform = CFrame.new(0, bob, 0) * CFrame.Angles(pitch, 0, roll)
		else
			phase = 0
			motor.Transform = motor.Transform:Lerp(CFrame.identity, math.clamp(dt * 12, 0, 1))
		end
	end)

	handles[model] = {
		motor = motor,
		connection = connection,
		phase = phase,
		bobScale = bobScale,
	}
end

function NpcLocomotion.detach(model: Model)
	local handle = handles[model]
	if handle == nil then
		return
	end
	handle.connection:Disconnect()
	handle.motor.Transform = CFrame.identity
	handles[model] = nil
end

return NpcLocomotion
