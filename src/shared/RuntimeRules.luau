--!strict

-- Pure runtime policy shared by server services and Lune behavioral tests.

local RuntimeRules = {}

local transitions: { [string]: { [string]: boolean } } = {
	RoleLobby = { MazeIntro = true },
	MazeIntro = { BellaChase = true },
	BellaChase = { RamboTaken = true },
	RamboTaken = { GuideEncounter = true },
	GuideEncounter = { TowerClimb = true },
	TowerClimb = { RevivePrompt = true },
	RevivePrompt = { Corruption = true },
	Corruption = { FieldHunt = true },
	FieldHunt = { LetterTheft = true },
	LetterTheft = { DogFight = true },
	DogFight = { Epilogue = true },
	Epilogue = { LetterReveal = true },
	LetterReveal = { Credits = true },
}

local cinematicNextStates: { [string]: string } = {
	MazeIntro = "BellaChase",
	RamboTaken = "GuideEncounter",
	GuideEncounter = "TowerClimb",
	Corruption = "FieldHunt",
	LetterTheft = "DogFight",
	DogFight = "Epilogue",
	Epilogue = "LetterReveal",
	LetterReveal = "Credits",
}

function RuntimeRules.canTransition(currentState: string, nextState: string): boolean
	local allowed = transitions[currentState]
	return allowed ~= nil and allowed[nextState] == true
end

function RuntimeRules.cinematicNextState(state: string): string?
	return cinematicNextStates[state]
end

function RuntimeRules.canAdmitPlayer(currentCount: number, maximumPlayers: number): boolean
	return currentCount >= 0 and maximumPlayers > 0 and currentCount < maximumPlayers
end

function RuntimeRules.canStartStory(role: string, ready: boolean, state: string): boolean
	return role == "Protagonist" and ready and state == "RoleLobby"
end

function RuntimeRules.isCinematicAckValid(
	currentState: string,
	currentRevision: number,
	stateEnteredAt: number,
	cue: string,
	revision: number,
	now: number,
	minimumSeconds: number
): boolean
	return cue == currentState
		and revision == currentRevision
		and cinematicNextStates[currentState] ~= nil
		and now - stateEnteredAt >= math.max(minimumSeconds, 0)
end

function RuntimeRules.shouldEmitDetection(
	wasChasing: boolean,
	isChasing: boolean,
	lastDetectedAt: number,
	now: number,
	cooldownSeconds: number
): boolean
	return not wasChasing and isChasing and now - lastDetectedAt >= math.max(cooldownSeconds, 0)
end

function RuntimeRules.evaluateRateLimit(
	startedAt: number?,
	count: number?,
	now: number,
	limit: number,
	windowSeconds: number
): (boolean, number, number)
	if limit <= 0 or windowSeconds <= 0 then
		return false, startedAt or now, count or 0
	end
	if startedAt == nil or count == nil or now - startedAt >= windowSeconds then
		return true, now, 1
	end
	if count >= limit then
		return false, startedAt, count
	end
	return true, startedAt, count + 1
end

return table.freeze(RuntimeRules)
