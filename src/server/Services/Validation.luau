--!strict

local Players = game:GetService("Players")

local Validation = {}
Validation.__index = Validation

export type Validator = typeof(setmetatable(
	{} :: {
		consumed: { [string]: boolean },
		rateBuckets: { [Player]: { [string]: { startedAt: number, count: number } } },
	},
	Validation
))

function Validation.new(): Validator
	return setmetatable({
		consumed = {},
		rateBuckets = {},
	}, Validation)
end

function Validation.IsCurrentPlayer(player: Player): boolean
	return player.Parent == Players
end

function Validation.HasRole(roleService: any, player: Player, expectedRole: string): boolean
	return Validation.IsCurrentPlayer(player) and roleService:GetRole(player) == expectedRole
end

function Validation.IsStoryState(storyService: any, expectedState: string): boolean
	return storyService:GetState() == expectedState
end

function Validation.IsNear(player: Player, target: Instance, maximumDistance: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local targetPosition: Vector3?
	if target:IsA("BasePart") then
		targetPosition = target.Position
	elseif target:IsA("Model") then
		targetPosition = target:GetPivot().Position
	end

	return targetPosition ~= nil and (root.Position - targetPosition).Magnitude <= maximumDistance
end

function Validation.ConsumeOnce(self: Validator, key: string): boolean
	if self.consumed[key] then
		return false
	end
	self.consumed[key] = true
	return true
end

function Validation.ClearConsumed(self: Validator, prefix: string?)
	if prefix == nil then
		table.clear(self.consumed)
		return
	end
	for key in self.consumed do
		if string.sub(key, 1, #prefix) == prefix then
			self.consumed[key] = nil
		end
	end
end

function Validation.AllowRate(
	self: Validator,
	player: Player,
	action: string,
	limit: number,
	windowSeconds: number
): boolean
	local now = os.clock()
	local playerBuckets = self.rateBuckets[player]
	if not playerBuckets then
		playerBuckets = {}
		self.rateBuckets[player] = playerBuckets
	end

	local bucket = playerBuckets[action]
	if not bucket or now - bucket.startedAt >= windowSeconds then
		playerBuckets[action] = { startedAt = now, count = 1 }
		return true
	end

	if bucket.count >= limit then
		return false
	end
	bucket.count += 1
	return true
end

function Validation.ForgetPlayer(self: Validator, player: Player)
	self.rateBuckets[player] = nil
end

return Validation
