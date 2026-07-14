# Studio QA matrix (Agent 2 — player-facing)

Studio MCP was unavailable at handoff time. Run these checks manually in Studio.

| Scenario | Pass criteria |
| --- | --- |
| One protagonist | Role label shows Protagonist; Ready accepted feedback; story starts |
| Two-player session | Second player Observer/Waiting; lobby capacity hint visible (not only kick) |
| Observer / waiting | Clear role + hint; Ready still works for presence |
| Replay after credits | Credits → Replay returns to title; focus on Ready |
| Respawn — Maze / Tower / Field | Objective + HUD survive; sprint / ASMR rebind if needed |
| Keyboard / mouse | Ready, revive, replay, leave+confirm, Tab cursor toggle |
| Controller | A/B/X/L/Y paths; Selectable focus never stuck behind hidden UI |
| Touch | Sprint ≥72px, safe inset; late TouchEnabled still spawns sprint button |
| Reduced motion on | No strong vignette pulse; letter/revive fades near-instant; HUD still readable |
| Marketplace assets available | Lobby/Field maps mount, are anchored and normalized; deterministic Maze/Tower geometry remains authoritative |
| Marketplace assets unavailable | Placeholders remain; no thrown errors; UI still usable |

## Reduced motion implementation

`src/client/Controls/SessionPreferences.luau` exposes:

- `isReducedMotion(): boolean`
- `onChanged(listener)`
- `tweenSeconds(normal, reduced?)`

`CinematicPlayer`, `StoryPresenter`, UI, and feedback effects honor this preference.

## Letter twist dedupe

`LetterPanel` no longer appends twist text (even if `show(true)`). Twist remains via StoryPresenter subtitle once. Runtime agent may later remove subtitle twist if letter should own it exclusively.
