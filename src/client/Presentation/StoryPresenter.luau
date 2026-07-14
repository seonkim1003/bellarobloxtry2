--!strict
--[[
	Story presentation director: maps StoryCue states to lighting, audio, cinematics, props.
]]

local SharedAccess = require(script.Parent.Parent:WaitForChild("Net"):WaitForChild("SharedAccess"))
local ContentConfig = SharedAccess.requireContentConfig()

local Players = game:GetService("Players")

export type DirectorDeps = {
	gui: any,
	remotes: any,
	lighting: any,
	audio: any,
	cinematics: any,
	sprint: any,
	asmr: any,
	robber: any,
	dogFight: any,
	kidnapStage: any,
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
		_cueGeneration: number,
		_lockedHumanoid: Humanoid?,
		_savedWalkSpeed: number?,
	},
	StoryPresenter
))

function StoryPresenter.new(deps: DirectorDeps): StoryPresenter
	return setmetatable({
		_deps = deps,
		_state = nil,
		_cueGeneration = 0,
		_lockedHumanoid = nil,
		_savedWalkSpeed = nil,
	}, StoryPresenter)
end

function StoryPresenter:_restorePlayerMovement()
	local humanoid = self._lockedHumanoid
	local savedWalkSpeed = self._savedWalkSpeed
	self._lockedHumanoid = nil
	self._savedWalkSpeed = nil
	if humanoid and humanoid.Parent and savedWalkSpeed ~= nil then
		humanoid.WalkSpeed = savedWalkSpeed
	end
end

function StoryPresenter:_finishCue(payload: any)
	local state = if typeof(payload) == "table" then payload.state else payload
	local revision = if typeof(payload) == "table" then payload.revision else nil
	if typeof(state) == "string" and ContentConfig.cinematicAckStates[state] then
		self._deps.remotes:request("CinematicFinished", {
			cue = state,
			revision = if typeof(revision) == "number" then revision else 0,
		})
	end
end

function StoryPresenter:_finishCinematic(callback: (() -> ())?)
	-- CinematicPlayer restores the Roblox camera before invoking its callback.
	-- Re-apply the gameplay presentation lock here so every cutscene hands control
	-- back in first person, including sequences that began by releasing the lock.
	self._deps.firstPerson.apply()
	if callback then
		callback()
	end
end

function StoryPresenter:_schedule(_payload: any, delaySeconds: number, callback: () -> ())
	local generation = self._cueGeneration
	task.delay(delaySeconds, function()
		if self._cueGeneration ~= generation then
			return
		end
		callback()
	end)
end

function StoryPresenter.handleStoryCue(self: StoryPresenter, payload: any)
	local state = if typeof(payload) == "table" then payload.state else payload
	if typeof(state) ~= "string" then
		return
	end
	self._cueGeneration = (self._cueGeneration :: number) + 1
	self:_restorePlayerMovement()
	self._state = state
	local d = self._deps
	if state ~= "RoleLobby" and state ~= "Credits" then
		d.gui.showTitle(false)
	end

	if state == "RoleLobby" then
		d.firstPerson.release()
		d.sprint:enable()
		d.asmr:stop()
		d.fragmentPrompts.stop()
		d.gui.showTitle(true)
		d.gui.showCredits(false)
		d.gui.showRevive(false)
		d.letterPanel.hide()
		d.detection.reset()
		d.dogFight:clear()
		d.epilogueProps.clear()
		d.lighting.applyScene("Lobby")
		d.audio.ambienceForScene("Lobby")
		self:_finishCue(payload)
	elseif state == "MazeIntro" then
		d.gui.showTitle(false)
		d.firstPerson.apply()
		d.sprint:enable()
		d.lighting.applyScene("Maze")
		d.audio.ambienceForScene("Maze")
		d.gui.setObjective("Follow Rambo through the maze")
		d.gui.setSubtitle("Rambo", ContentConfig.dialogue.mazeIntro[1].text)
		self:_schedule(payload, ContentConfig.dialogue.mazeIntro[1].durationSeconds, function()
			d.gui.clearSubtitle()
		end)
		self:_finishCue(payload)
	elseif state == "BellaChase" then
		d.gui.showTitle(false)
		d.firstPerson.apply()
		d.sprint:enable()
		d.lighting.applyScene("Maze")
		d.audio.ambienceForScene("Maze")
		d.detection.showChase(true)
		d.gui.setObjective("Don't let Bella catch you")
		d.gui.setSubtitle("System", ContentConfig.dialogue.bellaChase[1].text)
		self:_schedule(payload, ContentConfig.dialogue.bellaChase[1].durationSeconds, function()
			d.gui.clearSubtitle()
		end)
		self:_finishCue(payload)
	elseif state == "RamboTaken" then
		d.detection.reset()
		d.sprint:disable()
		d.firstPerson.release()
		d.gui.setObjective("Rambo was taken...")
		local humanoid = Players.LocalPlayer.Character
			and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			self._lockedHumanoid = humanoid
			self._savedWalkSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = 0
		end
		local ok, err = pcall(function()
			d.cinematics:playKidnapCutscene(d.kidnapStage, function()
				self:_restorePlayerMovement()
				d.kidnapStage:clear()
				self:_finishCinematic(function()
					self:_finishCue(payload)
				end)
			end)
		end)
		if not ok then
			warn(`[StoryPresenter] Kidnap cutscene failed to start: {tostring(err)}`)
			d.cinematics:reset()
			self:_restorePlayerMovement()
			d.kidnapStage:clear()
			self:_finishCinematic(function()
				self:_finishCue(payload)
			end)
		end
	elseif state == "GuideEncounter" then
		d.lighting.applyScene("Tower")
		d.audio.ambienceForScene("Tower")
		d.robber.ensureAtSpawn()
		d.gui.setObjective("Listen to Robert Pattinson")
		d.cinematics:playSequence("guide", function()
			self:_finishCinematic(function()
				self:_finishCue(payload)
			end)
		end)
	elseif state == "TowerClimb" then
		d.firstPerson.apply()
		d.lighting.applyScene("Tower")
		d.audio.ambienceForScene("Tower")
		d.towerBuilder.rebuildFlights()
		d.asmr:start()
		d.sprint:enable()
		d.gui.setObjective("Climb the tower - every step sings")
		d.gui.setSubtitle("Robert Pattinson", ContentConfig.dialogue.robberGuide[2].text)
		self:_schedule(payload, 4, function()
			d.gui.clearSubtitle()
		end)
		self:_finishCue(payload)
	elseif state == "RevivePrompt" then
		d.asmr:stop()
		d.gui.showRevive(false)
		d.cinematics:playSequence("revive", function()
			self:_finishCinematic(function()
				-- Do not expose the choice while another sequence owns the camera.
				d.gui.showRevive(true)
			end)
		end)
	elseif state == "Corruption" then
		d.gui.showRevive(false)
		d.cinematics:playSequence("corruption", function()
			self:_finishCinematic(function()
				self:_finishCue(payload)
			end)
		end)
	elseif state == "FieldHunt" then
		d.firstPerson.apply()
		d.lighting.applyScene("Field")
		d.audio.ambienceForScene("Field")
		d.fragmentPrompts.start()
		d.sprint:enable()
		d.gui.setObjective("Find three letter fragments - stay quiet")
		d.gui.setSubtitle("System", ContentConfig.dialogue.fieldHunt[1].text)
		self:_schedule(payload, ContentConfig.dialogue.fieldHunt[1].durationSeconds, function()
			d.gui.clearSubtitle()
		end)
		self:_finishCue(payload)
	elseif state == "LetterTheft" then
		d.gui.setObjective("The pieces are taken...")
		d.cinematics:playSequence("letterTheft", function()
			self:_finishCinematic(function()
				self:_finishCue(payload)
			end)
		end)
	elseif state == "DogFight" then
		d.sprint:disable()
		d.firstPerson.release()
		d.gui.setObjective("Shapes in the fog...")
		local humanoid = Players.LocalPlayer.Character
			and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			self._lockedHumanoid = humanoid
			self._savedWalkSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = 0
		end
		local revision = if typeof(payload) == "table" then payload.revision else nil
		d.dogFight:play(revision, function()
			self:_restorePlayerMovement()
			d.sprint:enable()
			self:_finishCinematic(function()
				self:_finishCue(payload)
			end)
		end)
	elseif state == "Epilogue" then
		d.dogFight:clear()
		d.lighting.applyScene("Epilogue")
		d.epilogueProps.mount()
		d.gui.setObjective("One hour later")
		d.gui.setSubtitle("Bella", ContentConfig.dialogue.epilogue[1].text)
		d.cinematics:playSequence("epilogue", function()
			self:_finishCinematic(function()
				d.gui.setSubtitle("Robert Pattinson", ContentConfig.dialogue.epilogue[2].text)
				self:_schedule(payload, 4, function()
					d.gui.clearSubtitle()
					self:_finishCue(payload)
				end)
			end)
		end)
	elseif state == "LetterReveal" then
		-- LetterPanel owns the twist body copy; avoid repeating it as a subtitle.
		-- Keep epilogue actors/props mounted through Credits.
		d.letterPanel.show(true)
		d.gui.setSubtitle("Gigi", ContentConfig.dialogue.letterReveal[1].text)
		d.cinematics:playSequence("letterReveal", function()
			self:_finishCinematic(function()
				self:_finishCue(payload)
			end)
		end)
	elseif state == "Credits" then
		-- Epilogue props intentionally remain until lobby/reset.
		d.letterPanel.hide()
		d.gui.showCredits(true)
		d.sprint:disable()
		d.asmr:stop()
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
	local generation = self._cueGeneration
	local collected = payload.count
	local total = payload.total or 3
	if typeof(collected) == "number" then
		self._deps.fragmentFeedback.pulse(collected, total)
		self._deps.gui.setFragmentCount(collected, total)
	end
	if payload.detected == true then
		self._deps.detection.flashDetected()
		self._deps.gui.setSubtitle("System", ContentConfig.dialogue.fieldHunt[2].text)
		task.delay(1.5, function()
			if self._cueGeneration ~= generation then
				return
			end
			self._deps.gui.clearSubtitle()
		end)
	end
	if payload.caught == true then
		self._deps.detection.showChase(true)
		self._deps.gui.setSubtitle("System", ContentConfig.dialogue.fieldHunt[3].text)
		task.delay(1.2, function()
			if self._cueGeneration ~= generation then
				return
			end
			self._deps.detection.reset()
			self._deps.gui.clearSubtitle()
		end)
	end
end

function StoryPresenter.resetForReplay(self: StoryPresenter)
	self._cueGeneration = (self._cueGeneration :: number) + 1
	local d = self._deps
	self:_restorePlayerMovement()
	d.cinematics:reset()
	d.asmr:stop()
	d.sprint:enable()
	d.detection.reset()
	d.letterPanel.reset()
	d.dogFight:clear()
	d.kidnapStage:clear()
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
