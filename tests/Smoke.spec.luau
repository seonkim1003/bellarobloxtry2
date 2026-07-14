--!strict

local function add(left: number, right: number): number
	return left + right
end

assert(add(2, 3) == 5, "add(2, 3) should equal 5")
print("smoke test passed")
