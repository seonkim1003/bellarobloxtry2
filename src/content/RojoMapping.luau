--!strict
--[[
	Canonical Agent 2 content ownership path.

	ReplicatedStorage.Content  →  src/content   (ownership notes / future shared content modules)
	StarterPlayerScripts.GameClient/Content → src/client/Content  (runtime presentation helpers)

	Do not move Presentation / UI / Audio into src/content without coordinator approval.
	Shared configuration stays in src/shared/ContentConfig.luau.
]]

return table.freeze({
	rojoPath = "src/content",
	replicatedStorageName = "Content",
	runtimeMirror = "src/client/Content",
	owns = table.freeze({
		"src/client",
		"src/content",
		"src/shared/ContentConfig.luau",
		"src/workspace/Scenes",
	}),
	phase = 4,
	purpose = "Ownership + mapping documentation for content packages; not UI/runtime presentation.",
	requiredMapping = table.freeze({
		parent = "ReplicatedStorage",
		name = "Content",
		path = "src/content",
	}),
})
