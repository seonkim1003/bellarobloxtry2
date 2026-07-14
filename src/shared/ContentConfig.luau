--!strict
--[[
	Agent 2 content configuration.
	Aligned to the Phase 1 frozen shared contract (story states, tags, attributes).
	Pure Luau (no Roblox Instance types) so Lune smoke tests can require it.
	Asset IDs use rbxassetid://0 placeholders until Phase 4 swaps real exports.
]]

export type RGB = { r: number, g: number, b: number }

export type DialogueLine = {
	id: string,
	speaker: string,
	text: string,
	durationSeconds: number,
}

export type CinematicStep = {
	markerId: string,
	durationSeconds: number,
	fadeInSeconds: number,
	fadeOutSeconds: number,
	subtitleId: string?,
}

export type SoundEntry = {
	soundId: string,
	volume: number,
	looped: boolean,
}

export type LightingPreset = {
	ambient: RGB,
	brightness: number,
	clockTime: number,
	fogColor: RGB,
	fogEnd: number,
	fogStart: number,
	outdoorAmbient: RGB,
}

export type PlaceholderObject = {
	sceneId: string,
	name: string,
	tag: string,
	attributes: { [string]: string | number },
}

local PLACEHOLDER_SOUND = "rbxassetid://0"
local PLACEHOLDER_IMAGE = "rbxassetid://0"
-- Animations use their own placeholder namespace so audits never mistake a
-- missing KeyframeSequence for a missing Sound (both resolve to id 0 today).
local PLACEHOLDER_ANIMATION = "rbxassetid://0"

local function rgb(r: number, g: number, b: number): RGB
	return { r = r, g = g, b = b }
end

local function line(
	id: string,
	speaker: string,
	text: string,
	durationSeconds: number
): DialogueLine
	return {
		id = id,
		speaker = speaker,
		text = text,
		durationSeconds = durationSeconds,
	}
end

local function cinematicStep(
	markerId: string,
	durationSeconds: number,
	fadeInSeconds: number,
	fadeOutSeconds: number,
	subtitleId: string?
): CinematicStep
	return {
		markerId = markerId,
		durationSeconds = durationSeconds,
		fadeInSeconds = fadeInSeconds,
		fadeOutSeconds = fadeOutSeconds,
		subtitleId = subtitleId,
	}
end

local asmrStepSounds: { string } = {}
local obbyMaterials = {
	{
		name = "Jelly",
		assetId = 9827430032,
		soundId = "rbxasset://sounds/action_footsteps_plastic.mp3",
		playbackSpeed = 0.72,
	},
	{
		name = "Butter",
		assetId = 135865294874666,
		-- Pro Sound Effects floor creak (licensed Creator Store)
		soundId = "rbxassetid://9125563505",
		playbackSpeed = 0.95,
	},
	{
		name = "PopIt",
		assetId = 7234923605,
		soundId = "rbxasset://sounds/electronicpingshort.wav",
		playbackSpeed = 1.35,
	},
}
for index = 1, 28 do
	local material = obbyMaterials[((index - 1) % #obbyMaterials) + 1]
	table.insert(asmrStepSounds, material.soundId)
end

local placeholderObjects: { PlaceholderObject } = {
	{
		sceneId = "Lobby",
		name = "LobbySpawn",
		tag = "SceneSpawn",
		attributes = { SceneId = "Lobby", MarkerId = "LobbySpawn" },
	},
	{
		sceneId = "Lobby",
		name = "LobbyReadyTrigger",
		tag = "StoryTrigger",
		attributes = { SceneId = "Lobby", MarkerId = "RoleReadyZone" },
	},
	{
		sceneId = "Lobby",
		name = "MazeTeleporter",
		tag = "StageTeleporter",
		attributes = { SceneId = "Lobby", MarkerId = "MazeTeleporter", Stage = "Maze" },
	},
	{
		sceneId = "Lobby",
		name = "ObbyTeleporter",
		tag = "StageTeleporter",
		attributes = { SceneId = "Lobby", MarkerId = "ObbyTeleporter", Stage = "Obby" },
	},
	{
		sceneId = "Lobby",
		name = "ScavengerTeleporter",
		tag = "StageTeleporter",
		attributes = {
			SceneId = "Lobby",
			MarkerId = "ScavengerTeleporter",
			Stage = "Scavenger Hunt",
		},
	},
	{
		sceneId = "Maze",
		name = "MazeSpawn",
		tag = "SceneSpawn",
		attributes = { SceneId = "MazeCheckpoint", MarkerId = "MazeStart" },
	},
	{
		sceneId = "Maze",
		name = "BellaSpawn",
		tag = "NPCSpawn",
		attributes = { SceneId = "Maze", MarkerId = "BellaSpawn", NPCType = "Bella" },
	},
	{
		sceneId = "Maze",
		name = "RamboGuideSpawn",
		tag = "NPCSpawn",
		attributes = {
			SceneId = "Maze",
			MarkerId = "RamboGuideSpawn",
			NPCType = "FriendlyRambo",
		},
	},
	{
		sceneId = "Maze",
		name = "RamboGuideTarget1",
		tag = "CinematicMarker",
		attributes = { SceneId = "Maze", MarkerId = "RamboGuideTarget", SequenceIndex = 1 },
	},
	{
		sceneId = "Maze",
		name = "RamboGuideTarget2",
		tag = "CinematicMarker",
		attributes = { SceneId = "Maze", MarkerId = "RamboGuideTarget", SequenceIndex = 2 },
	},
	{
		sceneId = "Maze",
		name = "RamboGuideTarget3",
		tag = "CinematicMarker",
		attributes = { SceneId = "Maze", MarkerId = "RamboGuideTarget", SequenceIndex = 3 },
	},
	{
		sceneId = "Maze",
		name = "MazeExit",
		tag = "MazeExit",
		attributes = { SceneId = "Maze", MarkerId = "MazeExit" },
	},
	{
		sceneId = "Maze",
		name = "AmbushMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Maze", MarkerId = "KidnapStart", SequenceIndex = 1 },
	},
	{
		sceneId = "Maze",
		name = "KidnapHoldMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Maze", MarkerId = "KidnapHold", SequenceIndex = 2 },
	},
	{
		sceneId = "Maze",
		name = "KidnapDepartMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Maze", MarkerId = "KidnapDepart", SequenceIndex = 3 },
	},
	{
		sceneId = "Tower",
		name = "TowerSpawn",
		tag = "SceneSpawn",
		attributes = { SceneId = "TowerBase", MarkerId = "TowerBase" },
	},
	{
		sceneId = "Tower",
		name = "RobberSpawn",
		tag = "NPCSpawn",
		attributes = {
			SceneId = "Tower",
			MarkerId = "RobertSpawn",
			NPCType = "RobertPattinson",
		},
	},
	{
		sceneId = "Tower",
		name = "GuideMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Tower", MarkerId = "GuideMeet", SequenceIndex = 1 },
	},
	{
		sceneId = "Tower",
		name = "ReviveMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Tower", MarkerId = "ReviveCam", SequenceIndex = 1 },
	},
	{
		sceneId = "Tower",
		name = "TowerTopTrigger",
		tag = "StoryTrigger",
		attributes = { SceneId = "Tower", MarkerId = "TowerTop" },
	},
	{
		sceneId = "Field",
		name = "FieldSpawn",
		tag = "SceneSpawn",
		attributes = { SceneId = "FieldEntrance", MarkerId = "FieldEntrance" },
	},
	{
		sceneId = "Field",
		name = "EvilRamboSpawn",
		tag = "NPCSpawn",
		attributes = { SceneId = "Field", MarkerId = "EvilRamboSpawn", NPCType = "EvilRambo" },
	},
	{
		sceneId = "Field",
		name = "PatrolA",
		tag = "PatrolPoint",
		attributes = {
			SceneId = "Field",
			MarkerId = "PatrolA",
			NPCType = "EvilRambo",
			SequenceIndex = 1,
		},
	},
	{
		sceneId = "Field",
		name = "PatrolB",
		tag = "PatrolPoint",
		attributes = {
			SceneId = "Field",
			MarkerId = "PatrolB",
			NPCType = "EvilRambo",
			SequenceIndex = 2,
		},
	},
	{
		sceneId = "Field",
		name = "PatrolC",
		tag = "PatrolPoint",
		attributes = {
			SceneId = "Field",
			MarkerId = "PatrolC",
			NPCType = "EvilRambo",
			SequenceIndex = 3,
		},
	},
	{
		sceneId = "Field",
		name = "FragmentA",
		tag = "LetterFragment",
		attributes = { SceneId = "Field", MarkerId = "FragmentA", FragmentId = "A" },
	},
	{
		sceneId = "Field",
		name = "FragmentB",
		tag = "LetterFragment",
		attributes = { SceneId = "Field", MarkerId = "FragmentB", FragmentId = "B" },
	},
	{
		sceneId = "Field",
		name = "FragmentC",
		tag = "LetterFragment",
		attributes = { SceneId = "Field", MarkerId = "FragmentC", FragmentId = "C" },
	},
	{
		sceneId = "Field",
		name = "TheftMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Field", MarkerId = "TheftSteal", SequenceIndex = 1 },
	},
	{
		sceneId = "Field",
		name = "TheftGigiMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Field", MarkerId = "TheftGigi", SequenceIndex = 2 },
	},
	{
		sceneId = "Field",
		name = "FightSilhouetteMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Field", MarkerId = "FightSilhouette", SequenceIndex = 0 },
	},
	{
		sceneId = "Field",
		name = "FightEstablishMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Field", MarkerId = "FightEstablish", SequenceIndex = 1 },
	},
	{
		sceneId = "Field",
		name = "FightRamboStalkMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Field", MarkerId = "FightRamboStalk", SequenceIndex = 2 },
	},
	{
		sceneId = "Field",
		name = "FightAttackTelegraphMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Field", MarkerId = "FightAttackTelegraph", SequenceIndex = 3 },
	},
	{
		sceneId = "Field",
		name = "FightFirstClashMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Field", MarkerId = "FightFirstClash", SequenceIndex = 4 },
	},
	{
		sceneId = "Field",
		name = "FightRamboAdvantageMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Field", MarkerId = "FightRamboAdvantage", SequenceIndex = 5 },
	},
	{
		sceneId = "Field",
		name = "FightGigiCounterMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Field", MarkerId = "FightGigiCounter", SequenceIndex = 6 },
	},
	{
		sceneId = "Field",
		name = "FightRamboBackDownMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Field", MarkerId = "FightRamboBackDown", SequenceIndex = 7 },
	},
	{
		sceneId = "Field",
		name = "FightGigiVictoryMarker",
		tag = "CinematicMarker",
		attributes = { SceneId = "Field", MarkerId = "FightGigiVictory", SequenceIndex = 8 },
	},
	{
		sceneId = "Epilogue",
		name = "EpilogueSpawn",
		tag = "SceneSpawn",
		attributes = { SceneId = "EpilogueSeat", MarkerId = "EpilogueSeat" },
	},
	{
		sceneId = "Epilogue",
		name = "LetterFocus",
		tag = "CinematicMarker",
		attributes = { SceneId = "Epilogue", MarkerId = "LetterFocus", SequenceIndex = 1 },
	},
	{
		sceneId = "Epilogue",
		name = "GigiSpawn",
		tag = "NPCSpawn",
		attributes = { SceneId = "Epilogue", MarkerId = "GigiSpawn", NPCType = "Gigi" },
	},
}

local asmrStepPlaceholders: { PlaceholderObject } = {}
for index = 1, 28 do
	table.insert(asmrStepPlaceholders, {
		sceneId = "Tower",
		name = `ASMRStep_{index}`,
		tag = "ASMRStep",
		attributes = {
			SceneId = "Tower",
			MarkerId = `ASMRStep_{index}`,
			SoundId = asmrStepSounds[index],
			SequenceIndex = index,
		},
	})
end

local ContentConfig = {
	projectTitle = "Bella and Rambo’s Weight Loss Journey",
	version = "0.5.0-content",

	storyStates = {
		"RoleLobby",
		"MazeIntro",
		"BellaChase",
		"RamboTaken",
		"GuideEncounter",
		"TowerClimb",
		"RevivePrompt",
		"Corruption",
		"FieldHunt",
		"LetterTheft",
		"DogFight",
		"Epilogue",
		"LetterReveal",
		"Credits",
	},

	requiredTags = {
		"SceneSpawn",
		"MazeExit",
		"NPCSpawn",
		"PatrolPoint",
		"StoryTrigger",
		"LetterFragment",
		"ASMRStep",
		"CinematicMarker",
		"StageTeleporter",
	},

	requiredAttributes = {
		"SceneId",
		"MarkerId",
		"NPCType",
		"FragmentId",
		"SoundId",
		"SequenceIndex",
		"Stage",
	},

	sceneIds = {
		"Lobby",
		"Maze",
		"Tower",
		"Field",
		"Epilogue",
	},

	assets = {
		images = {
			titleLogo = PLACEHOLDER_IMAGE,
			fragmentIcon = PLACEHOLDER_IMAGE,
			creditsBackdrop = PLACEHOLDER_IMAGE,
		},
		-- Marketplace model asset IDs (InsertService). Must be owned/gettable by the place creator.
		marketplace = {
			scenes = {
				lobby = 9271965383, -- Lobby Island
				maze = 114374837037591, -- Backrooms Map Realistic Maze Escape RP
				tower = 14446703870, -- Tower for Obby
				field = 13088916306, -- Farm Town Models (used as field hunt area)
			},
			characters = {
				bella = 123711093849835, -- provided as "Nikki Manaj" stand-in → Bella
				ramboFriendly = 285396402, -- Puppy → friendly Rambo
				ramboEvil = 5292722268, -- Cartoon Dog Killer → scary Rambo
				robertPattinson = 11851270, -- Edward Cullen stand-in → Robert Pattinson
				gigi = 9747993459, -- Pet The Dog → Gigi
			},
			props = {
				letterFragments = 17475591057, -- Clickable Note
				fatBart = 102058945923521, -- title-screen character decoration
				mazeExitDoor = 132074708194112,
				jelly = 9827430032,
				butter = 135865294874666,
				popIt = 7234923605,
			},
			sources = {
				lobby = "https://create.roblox.com/store/asset/9271965383/Lobby-Island",
				maze = "https://create.roblox.com/store/asset/114374837037591/Backrooms-Map-Realistic-Maze-Escape-RP",
				tower = "https://create.roblox.com/store/asset/14446703870/Tower-for-Obby",
				field = "https://create.roblox.com/store/asset/13088916306/Farm-Town-Models",
				bella = "https://create.roblox.com/store/asset/123711093849835/Nikki-Manaj",
				ramboFriendly = "https://create.roblox.com/store/asset/285396402/Puppy",
				ramboEvil = "https://create.roblox.com/store/asset/5292722268/Cartoon-Dog-Killer",
				robertPattinson = "https://create.roblox.com/store/asset/11851270/Edward-Cullen",
				gigi = "https://create.roblox.com/store/asset/9747993459/Pet-The-Dog",
				letterFragments = "https://create.roblox.com/store/asset/17475591057/Clickable-Note",
				fatBart = "https://create.roblox.com/store/asset/102058945923521/Fat-Bart",
				mazeExitDoor = "https://create.roblox.com/store/asset/132074708194112/Backrooms-Exit-Door-Lost-Backrooms-Entity-Carpet",
				jelly = "https://create.roblox.com/store/asset/9827430032/Jelly",
				butter = "https://create.roblox.com/store/asset/135865294874666/Butter-ASMR-Virus-removed",
				popIt = "https://create.roblox.com/store/asset/7234923605/popit-functional",
			},
		},
		models = {
			bella = "rbxassetid://123711093849835",
			rambo = "rbxassetid://285396402",
			ramboEvil = "rbxassetid://5292722268",
			gigi = "rbxassetid://9747993459",
			robertPattinson = "rbxassetid://11851270",
			lobby = "rbxassetid://9271965383",
			maze = "rbxassetid://114374837037591",
			tower = "rbxassetid://14446703870",
			field = "rbxassetid://13088916306",
			letterFragments = "rbxassetid://17475591057",
			fatBart = "rbxassetid://102058945923521",
			mazeExitDoor = "rbxassetid://132074708194112",
			jelly = "rbxassetid://9827430032",
			butter = "rbxassetid://135865294874666",
			popIt = "rbxassetid://7234923605",
		},
		-- Animation asset IDs (NOT sounds). Remain placeholders until creator uploads.
		animations = {
			kidnapHold = PLACEHOLDER_ANIMATION,
			reviveKneel = PLACEHOLDER_ANIMATION,
			corruptionPulse = PLACEHOLDER_ANIMATION,
		},
	},

	-- World placement for InsertService scene models (keeps gameplay markers nearby).
	sceneLayouts = {
		-- Each story stage is an isolated gameplay cell. Marketplace maps are much
		-- larger than the old placeholder floors, so small offsets caused maps,
		-- NPC aggro, and pathfinding to bleed into adjacent stages.
		Lobby = {
			marketplaceKey = "lobby",
			position = { x = 0, y = 0, z = 0 },
			maxMarketplaceExtent = 160,
			marketplaceCollision = true,
		},
		-- Catalog maps are mounted as a sanitized visual layer. Deterministic
		-- authored geometry remains authoritative for routes, checkpoints, and
		-- touch sensors so a free-model update cannot break story progression.
		Maze = {
			marketplaceKey = nil,
			position = { x = 1200, y = 0, z = 0 },
		},
		Tower = {
			marketplaceKey = "tower",
			position = { x = 2400, y = 0, z = 0 },
			-- The authored ASMR route occupies the tower's inner 24x24-stud ring
			-- and reaches y=22/top trigger y=23.
			maxMarketplaceExtent = 44,
			maxMarketplaceHeight = 24,
			marketplaceCollision = false,
		},
		Field = {
			marketplaceKey = "field",
			position = { x = 3600, y = 0, z = 0 },
			maxMarketplaceExtent = 170,
			marketplaceCollision = true,
		},
		Epilogue = { marketplaceKey = nil, position = { x = 4800, y = 0, z = 0 } },
	},
	worldLayout = {
		SceneSpacing = 1200,
		MaxMarketplaceExtent = 800,
	},

	sounds = {
		-- Licensed free audio: Pro Sound Effects + APM Official (+ soft UI click).
		ambienceLobby = { soundId = "rbxassetid://9112828235", volume = 0.32, looped = true }, -- Marina Ambience 2
		ambienceMaze = { soundId = "rbxassetid://9119386548", volume = 0.38, looped = true }, -- Spacecraft Engine Idle
		ambienceTower = { soundId = "rbxassetid://9112772977", volume = 0.28, looped = true }, -- Dock Ambience (creaks)
		ambienceField = { soundId = "rbxassetid://9112865688", volume = 0.4, looped = true }, -- Salton Sea 1
		ambienceEpilogue = { soundId = "rbxassetid://9112828235", volume = 0.28, looped = true }, -- Marina (softer)
		musicCredits = { soundId = "rbxassetid://131704363201949", volume = 0.35, looped = true }, -- Floating (Distrokid)
		chaseTension = { soundId = "rbxassetid://1843867314", volume = 0.42, looped = true }, -- Tension Repeat Drones 29
		chaseSting = { soundId = "rbxassetid://1846435267", volume = 0.72, looped = false }, -- Dramatic Statement B
		corruptionSting = { soundId = "rbxassetid://9125899104", volume = 0.65, looped = false }, -- Sci Fi Transformation
		stateTransition = { soundId = "rbxassetid://9113840530", volume = 0.45, looped = false }, -- Cloth Whoosh
		fragmentPickup = { soundId = "rbxassetid://9126076118", volume = 0.55, looped = false }, -- Synth Sparkle
		uiClick = { soundId = "rbxassetid://17582213219", volume = 0.45, looped = false }, -- Click Soft UI
		uiConfirm = { soundId = "rbxassetid://17582213219", volume = 0.6, looped = false },
		kidnapGrab = { soundId = "rbxassetid://9118716580", volume = 0.6, looped = false }, -- Rope Grab
		kidnapDrag = { soundId = "rbxassetid://9125563505", volume = 0.5, looped = false }, -- Floor Creak
		cinematicWhoosh = { soundId = "rbxassetid://9113840280", volume = 0.5, looped = false }, -- Cloth Whoosh
		dogFightImpact = { soundId = "rbxassetid://9113535048", volume = 0.58, looped = false }, -- Body Slam
		dogFightClash = { soundId = "rbxassetid://9047224047", volume = 0.6, looped = false }, -- Blazing Smack Hit1
		dogFightVictory = { soundId = "rbxassetid://1841760614", volume = 0.65, looped = false }, -- Sacred Skyline sting
		letterOpen = { soundId = "rbxassetid://9118834867", volume = 0.55, looped = false }, -- Scrapbook Open
		respawnSoft = { soundId = "rbxassetid://9113840154", volume = 0.4, looped = false }, -- Cloth Whoosh
		teleporterActivate = { soundId = "rbxassetid://9113840530", volume = 0.5, looped = false }, -- Cloth Whoosh
		-- Full-coverage cues (reuse licensed IDs already claimed — no Studio MCP inserts)
		sprintStart = { soundId = "rbxassetid://9113840530", volume = 0.35, looped = false },
		sprintStop = { soundId = "rbxassetid://9113840154", volume = 0.28, looped = false },
		playerHit = { soundId = "rbxassetid://9113535048", volume = 0.62, looped = false },
		playerDeath = { soundId = "rbxassetid://1846435267", volume = 0.55, looped = false },
		healthLow = { soundId = "rbxassetid://1843867314", volume = 0.4, looped = false },
		hostileApproach = {
			soundId = "rbxasset://sounds/action_footsteps_wood.mp3",
			volume = 0.35,
			looped = true,
		},
		friendlyApproach = {
			soundId = "rbxasset://sounds/action_footsteps_plastic.mp3",
			volume = 0.22,
			looped = true,
		},
		evilApproach = {
			soundId = "rbxasset://sounds/action_footsteps_wood.mp3",
			volume = 0.3,
			looped = true,
		},
		mazeExit = { soundId = "rbxassetid://9113840280", volume = 0.55, looped = false },
		towerSummit = { soundId = "rbxassetid://1841760614", volume = 0.5, looped = false },
		revivePanelOpen = { soundId = "rbxassetid://9125899104", volume = 0.4, looped = false },
		threatClear = { soundId = "rbxassetid://9126076118", volume = 0.35, looped = false },
		promptShown = { soundId = "rbxassetid://17582213219", volume = 0.3, looped = false },
		promptHold = { soundId = "rbxassetid://17582213219", volume = 0.2, looped = false },
		subtitleTick = { soundId = "rbxassetid://17582213219", volume = 0.18, looped = false },
		objectiveTick = { soundId = "rbxassetid://17582213219", volume = 0.16, looped = false },
		uiError = {
			soundId = "rbxasset://sounds/electronicpingshort.wav",
			volume = 0.35,
			looped = false,
		},
		cursorToggle = { soundId = "rbxassetid://17582213219", volume = 0.4, looped = false },
		cameraLock = { soundId = "rbxassetid://9113840154", volume = 0.32, looped = false },
		cinematicCut = { soundId = "rbxassetid://9113840530", volume = 0.22, looped = false },
		letterClose = { soundId = "rbxassetid://9118834867", volume = 0.4, looped = false }, -- Scrapbook (close)
		creditsOpen = { soundId = "rbxassetid://9113840280", volume = 0.35, looped = false },
		asmrSteps = asmrStepSounds,
		obbyMaterials = obbyMaterials,
	},

	lighting = {
		Lobby = {
			ambient = rgb(90, 90, 110),
			brightness = 1.5,
			clockTime = 18.5,
			fogColor = rgb(40, 40, 55),
			fogEnd = 220,
			fogStart = 40,
			outdoorAmbient = rgb(70, 70, 90),
		},
		Maze = {
			ambient = rgb(35, 30, 45),
			brightness = 0.6,
			clockTime = 0.5,
			fogColor = rgb(20, 15, 30),
			fogEnd = 70,
			fogStart = 8,
			outdoorAmbient = rgb(25, 20, 35),
		},
		Tower = {
			ambient = rgb(55, 50, 70),
			brightness = 1.0,
			clockTime = 21,
			fogColor = rgb(30, 28, 45),
			fogEnd = 120,
			fogStart = 20,
			outdoorAmbient = rgb(40, 35, 55),
		},
		Field = {
			ambient = rgb(45, 55, 40),
			brightness = 0.9,
			clockTime = 5.2,
			fogColor = rgb(55, 70, 60),
			fogEnd = 160,
			fogStart = 25,
			outdoorAmbient = rgb(50, 65, 55),
		},
		Epilogue = {
			ambient = rgb(120, 110, 100),
			brightness = 2.0,
			clockTime = 12,
			fogColor = rgb(180, 170, 160),
			fogEnd = 300,
			fogStart = 80,
			outdoorAmbient = rgb(140, 130, 120),
		},
	},

	dialogue = {
		lobby = {
			line("lobby_ready", "System", "Wait for your role. Only one protagonist may begin.", 4),
		},
		mazeIntro = {
			line("maze_rambo_1", "Rambo", "Stay close. I’ll wait if we get split up.", 3.5),
			line(
				"maze_rambo_2",
				"Rambo",
				"Left at the dripping pipe. I know the smell of the exit.",
				3.5
			),
		},
		bellaChase = {
			line("bella_near", "System", "Footsteps behind you. Don’t stop.", 2.5),
		},
		kidnap = {
			line("kidnap_rambo", "Rambo", "We made it—stay right there!", 4.5),
			line("kidnap_bella", "Bella", "Did you really think you could keep him?", 5),
			line("kidnap_take", "Bella", "Come on, boy. She’s not saving anyone tonight.", 4.5),
			line("kidnap_gone", "System", "Bella dragged Rambo back into the dark.", 5),
		},
		robberGuide = {
			line(
				"robber_1",
				"Robert Pattinson",
				"Easy now. Eyes up the tower — every step has a story.",
				4
			),
			line(
				"robber_2",
				"Robert Pattinson",
				"I’m no celebrity. Just a guy who knows which stairs squeak.",
				4
			),
			line(
				"robber_3",
				"Robert Pattinson",
				"Twenty-eight creaks. Count them if it keeps you brave.",
				3.5
			),
		},
		revive = {
			line("revive_prompt", "System", "Will you get back up?", 0),
			line("revive_refuse", "System", "Still here. Still waiting.", 2),
		},
		corruption = {
			line("corruption_1", "System", "Something kind in you goes dim.", 3),
		},
		fieldHunt = {
			line("field_1", "System", "Three scraps of a letter. Don’t get seen.", 3),
			line("field_detect", "System", "He heard you.", 1.5),
			line("field_catch", "System", "Caught — fragments kept. Back to the gate.", 3),
		},
		letterTheft = {
			line("theft_rambo", "Rambo", "Those scraps were never yours.", 3),
			line("theft_gigi", "Gigi", "I kept the last piece safe.", 3),
		},
		dogFight = {
			line("fight_1", "System", "Shapes in the fog. Don’t watch too closely.", 3),
		},
		epilogue = {
			line(
				"epi_bella",
				"Bella",
				"One hour later… we finished what we started — his collar says enough.",
				5
			),
			line(
				"epi_robber",
				"Robert Pattinson",
				"No leftovers talk. Just the tag. Just the truth.",
				4
			),
			line(
				"epi_table",
				"System",
				"On the table: a collar, a name tag, and a finished letter. Nothing else.",
				4
			),
		},
		letterReveal = {
			line("letter_gigi", "Gigi", "Read it. All of it.", 3),
		},
	},

	finalLetterText = {
		title = "The Completed Letter",
		body = {
			"To whoever finds this,",
			"",
			"We weren’t hunting for weight loss.",
			"We were collecting proof of who walked the maze with us —",
			"and who waited for the tower lights to go out.",
			"",
			"The collar was never a trophy.",
			"It was a signature.",
			"",
			"— Bella, Rambo, and Gigi",
		},
		twist = "The journey was never about losing weight. It was about who gets remembered when the fog clears.",
	},

	cinematics = {
		kidnap = {
			cinematicStep("KidnapStart", 5, 0.55, 0.12, "kidnap_rambo"),
			cinematicStep("KidnapApproach", 5.5, 0.08, 0.08, "kidnap_bella"),
			cinematicStep("KidnapHold", 4.5, 0.05, 0.08, "kidnap_take"),
			cinematicStep("KidnapDepart", 5.5, 0.05, 0.35, "kidnap_gone"),
		},
		guide = {
			cinematicStep("GuideMeet", 5, 0.5, 0.3, "robber_1"),
		},
		revive = {
			cinematicStep("ReviveCam", 2.5, 0.3, 0.3, "revive_prompt"),
		},
		corruption = {
			cinematicStep("CorruptionPulse", 4, 0.2, 0.6, nil),
		},
		letterTheft = {
			cinematicStep("TheftSteal", 4, 0.35, 0.25, "theft_rambo"),
			cinematicStep("TheftGigi", 3.5, 0.2, 0.4, "theft_gigi"),
		},
		dogFight = {
			-- Legacy single-step fallback; DogFightTimeline owns the eight beats.
			cinematicStep("FightSilhouette", 5, 0.4, 0.4, "fight_1"),
		},
		epilogue = {
			cinematicStep("EpilogueTable", 6, 0.5, 0.4, "epi_bella"),
		},
		letterReveal = {
			cinematicStep("LetterFocus", 7, 0.4, 0.5, "letter_gigi"),
		},
	},

	ui = {
		titlePrompt = "Choose Bella, then walk onto a stage teleporter",
		objectiveFallback = "Awaiting objective…",
		fragmentLabel = "Letter pieces",
		reviveAccept = "Get up",
		reviveRefuse = "Stay down",
		replayLabel = "Replay",
		leaveLabel = "Leave",
		readyLabel = "Ready",
		readyIdle = "Not ready yet",
		readyAccepted = "Ready — waiting for the story to begin",
		leaveConfirmPrompt = "Leave the experience? You will be disconnected.",
		leaveConfirmYes = "Leave",
		leaveConfirmNo = "Stay",
		reducedMotionOff = "Reduced motion: Off  [M / D-Pad ↓]",
		reducedMotionOn = "Reduced motion: On  [M / D-Pad ↓]",
		lobbyCapacityHint = "Two players max — one protagonist, one observer (or waiting).",
		lobbyProtagonistHint = "You are Bella. Walk onto a lobby teleporter to choose a stage.",
		lobbyObserverHint = "You are observing. Follow along — Ready confirms you are present.",
		lobbyWaitingHint = "Waiting for role assignment. A second player can join as observer.",
		towerProgressLabel = "Tower steps",
		towerGoalStart = "Climb all 28 steps across 7 flights. Reach the top.",
		towerGoalNearTop = "Almost there — the top door opens the next chapter.",
		mazeExitHint = "Look for the upright exit door — do not reverse back into Bella.",
		threatSafe = "● Clear",
		threatDetected = "⚠ DETECTED — move",
		threatChase = "‼ CHASE — run",
		creditsLines = {
			"Bella and Rambo’s Weight Loss Journey",
			"A short first-person Roblox horror experience",
			"Systems · Content · Creator review",
			"Thank you for playing",
		},
		touchSafeInsetScale = 0.04,
		touchMinButtonPx = 72,
		subtitleMaxWidthScale = 0.8,
		minReadableTextPx = 14,
	},

	accessibility = {
		reducedMotionDefault = false,
		suppressCameraShakeWhenReduced = true,
		softenVignetteWhenReduced = true,
		shortenUiTweensWhenReduced = true,
	},

	placeholderObjects = placeholderObjects,
	asmrStepPlaceholders = asmrStepPlaceholders,
	towerStepCount = 28,
	towerFlights = 7,

	-- Expected remote names from Agent 1 (frozen contract).
	serverSignals = {
		"StoryCue",
		"ObjectiveUpdate",
		"FragmentUpdate",
		"RoleUpdate",
		"AdminDiagnostics",
		"FightBeat",
	},
	clientRequests = {
		"CinematicFinished",
		"ReviveConfirmed",
		"ReplayRequested",
		"RoleReady",
	},
	cinematicAckStates = {
		MazeIntro = true,
		RamboTaken = true,
		GuideEncounter = true,
		Corruption = true,
		LetterTheft = true,
		DogFight = true,
		Epilogue = true,
		LetterReveal = true,
	},

	controls = {
		walkSpeed = 16,
		sprintSpeed = 32,
		asmrDebounceSeconds = 0.45,
		unlimitedSprint = true,
	},

	assetFallback = {
		soundId = PLACEHOLDER_SOUND,
		imageId = PLACEHOLDER_IMAGE,
		animationId = PLACEHOLDER_ANIMATION,
		note = "Missing assets stay silent/blank; presentation continues.",
	},

	-- Content package ownership (see also src/content/RojoMapping.luau).
	contentOwnership = {
		sharedConfig = "src/shared/ContentConfig.luau",
		clientPresentation = "src/client",
		rojoContentFolder = "src/content",
		rojoContentPurpose = "ReplicatedStorage.Content ownership notes + future shared content modules (not runtime presentation).",
	},
}

return ContentConfig
