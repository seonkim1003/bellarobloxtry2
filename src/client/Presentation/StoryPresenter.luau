--!strict
--[[
	Story presentation director: maps StoryCue states to lighting, audio, cinematics, props.
]]

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()

export type DirectorDeps = {
	gui: any,
	remotes: any,
	lighting: any,
	audio: any,
	cinematics: any,
	sprint: any,
	asmr: any,
	robber: any,
	silhouettes: any,
	epilogueProps: any,
	fragmentFeedback: any,
	detection: any,
	letterPanel: any,
	firstPerson: any,
	fragmentPrompts: any,
	towerBuilder: any,
}

local StoryPresenter = {}
StoryPresenter.__index = StoryPresenter

export type StoryPresenter = typeof(setmetatable(
	{} :: {
		_deps: DirectorDeps,
		_state: string?,
	},
	StoryPresenter
))

function StoryPresenter.new(deps: DirectorDeps): StoryPresenter
	return setmetatable({
		_deps = deps,
		_state = nil,
	}, StoryPresenter)
end

function StoryPresenter:_finishCue(payload: any)
	if typeof(payload) == "table" and typeof(payload.cueId) == "string" then
		self._deps.remotes:request("CinematicFinished", { cueId = payload.cueId })
	end
end

function StoryPresenter:handleStoryCue(payload: any)
	local state = if typeof(payload) == "table" then payload.state else payload
	if typeof(state) ~= "string" then
		return
	end
	self._state = state
	local d = self._deps

	if state == "RoleLobby" then
		d.firstPerson.release()
		d.sprint.disable()
		d.asmr.stop()
		d.gui.showTitle(true)
		d.gui.showCredits(false)
		d.gui.showRevive(false)
		d.letterPanel.hide()
		d.detection.reset()
		d.silhouettes.clear()
		d.epilogueProps.clear()
		d.lighting.applyScene("Lobby")
		d.audio.ambienceForScene("Lobby")
		self:_finishCue(payload)
	elseif state == "MazeIntro" then
		d.gui.showTitle(false)
		d.firstPerson.apply()
		d.sprint.enable()
		d.lighting.applyScene("Maze")
		d.audio.ambienceForScene("Maze")
		d.gui.setObjective("Follow Rambo through the maze")
		d.gui.setSubtitle("Rambo", ContentConfig.dialogue.mazeIntro[1].text)
		task.delay(ContentConfig.dialogue.mazeIntro[1].durationSeconds, function()
			d.gui.clearSubtitle()
		end)
		self:_finishCue(payload)
	elseif state == "BellaChase" then
		d.gui.showTitle(false)
		d.firstPerson.apply()
		d.sprint.enable()
		d.lighting.applyScene("Maze")
		d.audio.ambienceForScene("Maze")
		d.detection.showChase(true)
		d.gui.setObjective("Donâ€™t let Bella catch you")
		d.gui.setSubtitle("System", ContentConfig.dialogue.bellaChase[1].text)
		task.delay(ContentConfig.dialogue.bellaChase[1].durationSeconds, function()
			d.gui.clearSubtitle()
		end)
		self:_finishCue(payload)
	elseif state == "RamboTaken" then
		d.detection.reset()
		d.gui.setObjective("Rambo was takenâ€¦")
		d.cinematics:playSequence("kidnap", function()
			self:_finishCue(payload)
		end)
	elseif state == "GuideEncounter" then
		d.lighting.applyScene("Tower")
		d.audio.ambienceForScene("Tower")
		d.robber.ensureAtSpawn()
		d.gui.setObjective("Listen to Robber Patterinson")
		d.cinematics:playSequence("guide", function()
			self:_finishCue(payload)
		end)
	elseif state == "TowerClimb" then
		d.lighting.applyScene("Tower")
		d.audio.ambienceForScene("Tower")
		d.towerBuilder.rebuildFlights()
		d.asmr.start()
		d.sprint.enable()
		d.gui.setObjective("Climb the tower â€” every step sings")
		d.gui.setSubtitle("Robber Patterinson", ContentConfig.dialogue.robberGuide[2].text)
		task.delay(4, function()
			d.gui.clearSubtitle()
		end)
		self:_finishCue(payload)
	elseif state == "RevivePrompt" then
		d.asmr.stop()
		d.gui.showRevive(true)
		d.cinematics:playSequence("revive", function()
			-- ReviveConfirmed is player-driven; do not auto-finish story here.
		end)
	elseif state == "Corruption" then
		d.gui.showRevive(false)
		d.cinematics:playSequence("corruption", function()
			self:_finishCue(payload)
		end)
	elseif state == "FieldHunt" then
		d.lighting.applyScene("Field")
		d.audio.ambienceForScene("Field")
		d.fragmentPrompts.start()
		d.sprint.enable()
		d.gui.setObjective("Find three letter fragments â€” stay quiet")
		d.gui.setSubtitle("System", ContentConfig.dialogue.fieldHunt[1].text)
		task.delay(ContentConfig.dialogue.fieldHunt[1].durationSeconds, function()
			d.gui.clearSubtitle()
		end)
		self:_finishCue(payload)
	elseif state == "LetterTheft" then
		d.gui.setObjective("The pieces are takenâ€¦")
		d.cinematics:playSequence("letterTheft", function()
			self:_finishCue(payload)
		end)
	elseif state == "DogFight" then
		d.silhouettes.mount()
		d.audio.playDogFightImpact()
		d.cinematics:playDogFightSilhouette(function()
			self:_finishCue(payload)
		end)
	elseif state == "Epilogue" then
		d.silhouettes.clear()
		d.lighting.applyScene("Epilogue")
		d.epilogueProps.mount()
		d.gui.setObjective("One hour later")
		d.gui.setSubtitle("Bella", ContentConfig.dialogue.epilogue[1].text)
		d.cinematics:playSequence("epilogue", function()
			d.gui.setSubtitle("Robber Patterinson", ContentConfig.dialogue.epilogue[2].text)
			task.delay(4, function()
				d.gui.clearSubtitle()
				self:_finishCue(payload)
			end)
		end)
	elseif state == "LetterReveal" then
		d.letterPanel.show(true)
		d.gui.setSubtitle("Gigi", ContentConfig.dialogue.letterReveal[1].text)
		d.cinematics:playSequence("letterReveal", function()
			d.gui.setSubtitle("", ContentConfig.finalLetterText.twist)
			self:_finishCue(payload)
		end)
	elseif state == "Credits" then
		d.letterPanel.hide()
		d.gui.showCredits(true)
		d.sprint.disable()
		d.asmr.stop()
		d.firstPerson.release()
		self:_finishCue(payload)
	else
		self:_finishCue(payload)
	end
end

function StoryPresenter:handleFragment(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local collected = payload.collected
	local total = payload.total or 3
	if typeof(collected) == "number" then
		self._deps.fragmentFeedback.pulse(collected, total)
		self._deps.gui.setFragmentCount(collected, total)
	end
	if payload.detected == true then
		self._deps.detection.flashDetected()
		self._deps.gui.setSubtitle("System", ContentConfig.dialogue.fieldHunt[2].text)
		task.delay(1.5, function()
			self._deps.gui.clearSubtitle()
		end)
	end
	if payload.caught == true then
		self._deps.detection.showChase(true)
		self._deps.gui.setSubtitle("System", ContentConfig.dialogue.fieldHunt[3].text)
		task.delay(1.2, function()
			self._deps.detection.reset()
			self._deps.gui.clearSubtitle()
		end)
	end
end

function StoryPresenter:resetForReplay()
	local d = self._deps
	d.cinematics:reset()
	d.asmr.stop()
	d.sprint.disable()
	d.detection.reset()
	d.letterPanel.reset()
	d.silhouettes.clear()
	d.epilogueProps.clear()
	d.robber.clear()
	d.fragmentPrompts.stop()
	d.audio.reset()
	d.firstPerson.release()
	d.gui.showCredits(false)
	d.gui.showRevive(false)
	d.gui.showTitle(true)
	d.gui.clearSubtitle()
	d.lighting.applyScene("Lobby")
end

return StoryPresenter
