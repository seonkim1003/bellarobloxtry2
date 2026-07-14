--!strict

return table.freeze({
	ContractVersion = 1,
	Roles = table.freeze({
		ClaimDelaySeconds = 3,
		UnassignedTimeoutSeconds = 15,
		MaximumPlayers = 2,
	}),
	Validation = table.freeze({
		DefaultInteractionDistance = 14,
		RemoteBurstLimit = 8,
		RemoteWindowSeconds = 2,
	}),
	Story = table.freeze({
		InitialState = "RoleLobby",
		FragmentCount = 3,
		MazeCheckpointSceneId = "MazeCheckpoint",
		FieldCheckpointSceneId = "FieldEntrance",
	}),
	NPC = table.freeze({
		RepathSeconds = 0.65,
		Bella = table.freeze({
			WalkSpeed = 17,
			CatchDistance = 5,
			DetectionDistance = 500,
			DisengageDistance = 600,
		}),
		EvilRambo = table.freeze({
			WalkSpeed = 19,
			CatchDistance = 5,
			DetectionDistance = 70,
			DisengageDistance = 110,
		}),
	}),
	Admin = table.freeze({
		PasswordAttempts = 4,
		PasswordWindowSeconds = 30,
		FlySpeed = 55,
		VerticalFlySpeed = 32,
	}),
})
