# Agent 2 → Agent 1 handoff

**Agent 2 source workspace:** `C:\Users\super\OneDrive\Desktop\Bella_Game`  
**Copied into Agent 1 workspace:** `C:\Users\super\Documents\Codex\2026-07-13\okay-my-idea-is-like-a`

## What was placed (Agent 2 owned)

| Path | Purpose |
| --- | --- |
| `src/client/**` | UI, remotes client, cinematics, controls, audio, presentation |
| `src/content/**` | Content ownership / Rojo mapping notes |
| `src/shared/ContentConfig.luau` | Assets, dialogue, lighting, marketplace IDs |
| `src/shared/ContentAssetMount.luau` | InsertService mount helpers |
| `src/shared/BuildInfo.luau` | Build label helper |
| `src/server/ContentAssetMount.server.luau` | Server bootstrap for marketplace assets |
| `src/workspace/Scenes/*.model.json` | Tagged placeholder scene markers |
| `art/export/MANIFEST.md` | Marketplace asset ID table |
| `tests/ContentSmoke.spec.luau` | Content contract smoke test |

Agent 1 files left untouched: `SystemsConfig`, `StoryContract`, all `Services/**`, `NPC/**`, `Bootstrap.server.luau`, `ServerSecrets.luau`.

## Integration wiring already adapted

- Client resolves **`GameShared` or `Shared`**
- Client remotes resolve **`GameRemotes` or `Remotes`** (matches Agent 1 `RemoteRegistry`)
- `default.project.json` now maps client → `StarterPlayerScripts.GameClient`, workspace → `Workspace.GameWorld`, content → `ReplicatedStorage.Content`

## Marketplace assets (need Toolbox “Get” on place creator)

See `art/export/MANIFEST.md` — lobby/maze/tower/farm + Bella/Rambo/Gigi/Robber/fragments.

## Reduced motion handoff (runtime agent)

Query from owned client module (do **not** invent a parallel flag):

```luau
local SessionPreferences = require(GameClient.Controls.SessionPreferences)
if SessionPreferences.isReducedMotion() then
	-- skip camera shake / soften long cinematic pans
end
```

Feedback, GuiShell, `CinematicPlayer`, and `StoryPresenter` now honor this preference.

## Letter twist

`LetterPanel` no longer appends the twist paragraph (API `includeTwist` kept). Twist still appears once via StoryPresenter subtitle. Runtime agent may consolidate later.

## Studio docs

- `docs/STUDIO_PREFLIGHT.md` — marketplace ownership + InsertService
- `docs/QA_MATRIX.md` — manual device / role matrix

## Rojo place location

No separate `.rbxl` was committed. Build with:

```powershell
rojo build default.project.json --output outputs/integrated.rbxl
```

Or live sync from this Codex folder with `rojo serve default.project.json`.
