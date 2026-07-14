--!strict

-- Pure validation policy for every player-controlled progression ingress.

local ProgressionRules = {}

local validRoles: { [string]: boolean } = {
	Bella = true,
	Admin = true,
}

local stageStates: { [string]: string } = {
	Maze = "MazeIntro",
	Obby = "TowerClimb",
	["Scavenger Hunt"] = "FieldHunt",
}

function ProgressionRules.parseLobbySelection(payload: any): (string?, string?)
	if typeof(payload) ~= "table" then
		return nil, nil
	end
	for key in payload do
		if key ~= "role" and key ~= "stage" then
			return nil, nil
		end
	end
	local role = payload.role
	local stage = payload.stage
	if typeof(role) ~= "string" or not validRoles[role] then
		return nil, nil
	end
	if typeof(stage) ~= "string" or stageStates[stage] == nil then
		return nil, nil
	end
	return role, stage
end

function ProgressionRules.startStateForStage(stage: string): string?
	return stageStates[stage]
end

function ProgressionRules.isAllowedStartState(state: string): boolean
	for _, allowedState in stageStates do
		if state == allowedState then
			return true
		end
	end
	return false
end

function ProgressionRules.canCollectTowerStep(
	collected: { [number]: boolean },
	collectedCount: number,
	sequenceIndex: any,
	totalSteps: number
): boolean
	return typeof(sequenceIndex) == "number"
		and sequenceIndex % 1 == 0
		and sequenceIndex >= 1
		and sequenceIndex <= totalSteps
		and sequenceIndex == collectedCount + 1
		and collected[sequenceIndex] ~= true
end

function ProgressionRules.canCollectFragment(
	serverFragmentIds: { [string]: boolean },
	collected: { [string]: boolean },
	collectedCount: number,
	fragmentId: any,
	maximumFragments: number
): boolean
	return typeof(fragmentId) == "string"
		and fragmentId ~= ""
		and serverFragmentIds[fragmentId] == true
		and collected[fragmentId] ~= true
		and collectedCount >= 0
		and collectedCount < maximumFragments
end

return table.freeze(ProgressionRules)
