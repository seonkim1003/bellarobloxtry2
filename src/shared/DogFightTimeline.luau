--!strict
--[[
	Canonical DogFight beat timeline.
	Server FightBeat and client DogFightPresenter share beatId/beatIndex identity.
]]

export type FightBeat = {
	beatIndex: number,
	beatId: string,
	durationSeconds: number,
	reducedMotionSeconds: number,
	cameraMarkerId: string,
	subtitleId: string?,
}

local DogFightTimeline = {}

local function beat(
	beatIndex: number,
	beatId: string,
	durationSeconds: number,
	reducedMotionSeconds: number,
	cameraMarkerId: string,
	subtitleId: string?
): FightBeat
	return table.freeze({
		beatIndex = beatIndex,
		beatId = beatId,
		durationSeconds = durationSeconds,
		reducedMotionSeconds = reducedMotionSeconds,
		cameraMarkerId = cameraMarkerId,
		subtitleId = subtitleId,
	})
end

local BEATS: { FightBeat } = table.freeze({
	beat(1, "Establish", 1.1, 0.7, "FightEstablish", "fight_1"),
	beat(2, "RamboStalk", 1.2, 0.7, "FightRamboStalk", nil),
	beat(3, "AttackTelegraph", 0.9, 0.55, "FightAttackTelegraph", nil),
	beat(4, "FirstClash", 1.0, 0.6, "FightFirstClash", nil),
	beat(5, "RamboAdvantage", 1.15, 0.7, "FightRamboAdvantage", nil),
	beat(6, "GigiCounter", 1.15, 0.7, "FightGigiCounter", nil),
	beat(7, "RamboBackDown", 1.0, 0.6, "FightRamboBackDown", nil),
	beat(8, "GigiVictory", 1.4, 0.85, "FightGigiVictory", nil),
})

DogFightTimeline.BeatCount = #BEATS
DogFightTimeline.Beats = BEATS

function DogFightTimeline.getBeat(beatIndex: number): FightBeat?
	return BEATS[beatIndex]
end

function DogFightTimeline.getBeatById(beatId: string): FightBeat?
	for _, entry in BEATS do
		if entry.beatId == beatId then
			return entry
		end
	end
	return nil
end

function DogFightTimeline.durationForBeat(entry: FightBeat, reducedMotion: boolean): number
	if reducedMotion then
		return entry.reducedMotionSeconds
	end
	return entry.durationSeconds
end

function DogFightTimeline.totalDuration(reducedMotion: boolean): number
	local total = 0
	for _, entry in BEATS do
		total += DogFightTimeline.durationForBeat(entry, reducedMotion)
	end
	return total
end

function DogFightTimeline.isValidBeatId(beatId: string): boolean
	return DogFightTimeline.getBeatById(beatId) ~= nil
end

return table.freeze(DogFightTimeline)
