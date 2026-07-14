--!strict
-- Frozen cross-boundary contract. Changes require coordinator approval.

local StoryContract = {}

StoryContract.Version = 2

StoryContract.Roles = table.freeze({
	Unassigned = "Unassigned",
	Protagonist = "Protagonist",
	Admin = "Admin",
})

StoryContract.States = table.freeze({
	RoleLobby = "RoleLobby",
	MazeIntro = "MazeIntro",
	BellaChase = "BellaChase",
	RamboTaken = "RamboTaken",
	GuideEncounter = "GuideEncounter",
	TowerClimb = "TowerClimb",
	RevivePrompt = "RevivePrompt",
	Corruption = "Corruption",
	FieldHunt = "FieldHunt",
	LetterTheft = "LetterTheft",
	DogFight = "DogFight",
	Epilogue = "Epilogue",
	LetterReveal = "LetterReveal",
	Credits = "Credits",
})

-- FightBeat payload (frozen):
-- {
-- 	contractVersion = 2,
-- 	storyRevision = number,
-- 	fightGeneration = number,
-- 	beatIndex = number,
-- 	beatId = string,
-- }
StoryContract.ServerEvents = table.freeze({
	StoryCue = "StoryCue",
	ObjectiveUpdate = "ObjectiveUpdate",
	FragmentUpdate = "FragmentUpdate",
	RoleUpdate = "RoleUpdate",
	AdminDiagnostics = "AdminDiagnostics",
	FightBeat = "FightBeat",
})

StoryContract.ClientEvents = table.freeze({
	CinematicFinished = "CinematicFinished",
	ReviveConfirmed = "ReviveConfirmed",
	ReplayRequested = "ReplayRequested",
	RoleReady = "RoleReady",
})

StoryContract.Tags = table.freeze({
	SceneSpawn = "SceneSpawn",
	MazeExit = "MazeExit",
	NPCSpawn = "NPCSpawn",
	PatrolPoint = "PatrolPoint",
	StoryTrigger = "StoryTrigger",
	LetterFragment = "LetterFragment",
	ASMRStep = "ASMRStep",
	CinematicMarker = "CinematicMarker",
	StageTeleporter = "StageTeleporter",
})

StoryContract.Attributes = table.freeze({
	SceneId = "SceneId",
	MarkerId = "MarkerId",
	NPCType = "NPCType",
	FragmentId = "FragmentId",
	SoundId = "SoundId",
	SequenceIndex = "SequenceIndex",
	Stage = "Stage",
})

StoryContract.Cues = table.freeze({
	StateChanged = "StateChanged",
	ReplayReset = "ReplayReset",
	RoleLobby = "RoleLobby",
})

return table.freeze(StoryContract)
