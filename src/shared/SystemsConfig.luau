--!strict

return table.freeze({
	ContractVersion = 1,
	Startup = table.freeze({
		ContentMountTimeoutSeconds = 20,
	}),
	Roles = table.freeze({
		MaximumPlayers = 2,
	}),
	Validation = table.freeze({
		DefaultInteractionDistance = 14,
		MazeExitInteractionDistance = 22,
		RemoteBurstLimit = 8,
		RemoteWindowSeconds = 2,
		CinematicBurstLimit = 2,
		CinematicWindowSeconds = 2,
		RemoteActions = table.freeze({
			RoleReady = table.freeze({ Limit = 2, WindowSeconds = 2 }),
			CinematicFinished = table.freeze({ Limit = 2, WindowSeconds = 2 }),
			ReviveConfirmed = table.freeze({ Limit = 2, WindowSeconds = 2 }),
			ReplayRequested = table.freeze({ Limit = 1, WindowSeconds = 2 }),
		}),
	}),
	Story = table.freeze({
		InitialState = "RoleLobby",
		FragmentCount = 3,
		TowerStepCount = 28,
		LobbyCheckpointSceneId = "Lobby",
		MazeCheckpointSceneId = "MazeCheckpoint",
		TowerCheckpointSceneId = "TowerBase",
		FieldCheckpointSceneId = "FieldEntrance",
		EpilogueCheckpointSceneId = "EpilogueSeat",
		CinematicMinimumSeconds = table.freeze({
			-- MazeIntro is a synchronization cue, not a camera sequence.
			MazeIntro = 0,
			RamboTaken = 18,
			GuideEncounter = 4,
			Corruption = 3,
			LetterTheft = 6,
			DogFight = 5.5,
			Epilogue = 8,
			LetterReveal = 6,
		}),
		-- Server-owned escape hatch for a client that crashes or disconnects while
		-- presenting a cinematic. These comfortably exceed the authored duration.
		CinematicRecoverySeconds = table.freeze({
			MazeIntro = 5,
			RamboTaken = 30,
			GuideEncounter = 12,
			Corruption = 10,
			LetterTheft = 15,
			DogFight = 15,
			Epilogue = 18,
			LetterReveal = 15,
		}),
	}),
	NPC = table.freeze({
		RepathSeconds = 0.65,
		DetectionCooldownSeconds = 2,
		Bella = table.freeze({
			WalkSpeed = 17,
			CatchDistance = 5,
			ContactDamage = 25,
			DetectionDistance = 500,
			DisengageDistance = 600,
		}),
		EvilRambo = table.freeze({
			WalkSpeed = 19,
			CatchDistance = 12,
			DetectionDistance = 90,
			DisengageDistance = 120,
		}),
	}),
	Admin = table.freeze({
		PasswordAttempts = 4,
		PasswordWindowSeconds = 30,
		FlySpeed = 55,
		VerticalFlySpeed = 32,
	}),
})
