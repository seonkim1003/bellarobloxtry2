--!strict
--[[
	Canonical Agent 2 content ownership path.
	Runtime mount modules currently sync via src/client/Content until coordinator
	maps ReplicatedStorage.Content → src/content in default.project.json.
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
	phase = 1,
	requiredMapping = table.freeze({
		parent = "ReplicatedStorage",
		name = "Content",
		path = "src/content",
	}),
})
