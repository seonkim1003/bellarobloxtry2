# Bella and Rambo

A story-driven Roblox prototype about escaping Bella, climbing an ASMR tower to revive Rambo, collecting letter fragments while hunted by corrupted Rambo, and reaching Gigi's final reveal.

## Toolchain

The pinned Rokit toolchain includes Rojo, Wally, StyLua, Selene, Luau LSP, and Lune. Install it with:

```powershell
rokit install
rojo plugin install
```

## Layout

- `src/client` -> `StarterPlayerScripts.GameClient`
- `src/server` -> `ServerScriptService.GameServer`
- `src/shared` -> `ReplicatedStorage.GameShared`
- `src/content` -> `ReplicatedStorage.Content`
- `src/workspace/Scenes` -> `Workspace.Scenes`
- `art/source` contains source notes; `art/export` contains reviewed asset manifests
- `tests` contains Lune smoke and integration-contract tests
- `types/roblox.d.luau` provides Roblox engine definitions for static analysis

## Live sync

Open a place in Roblox Studio, connect the Rojo plugin, and run:

```powershell
rojo serve default.project.json
```

Edit Rojo-managed scripts on disk, not directly in Studio.

## Validate

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate.ps1
```

Validation checks formatting, lint, strict Roblox types, every `tests/*.spec.luau` test, and builds `work/integrated.rbxl`. The bundled Roblox definitions file is selected automatically.

Before publishing, replace the disabled placeholder in `src/server/ServerSecrets.luau` with a private admin password. The `/admin` command fails closed while the placeholder remains.

## Build

```powershell
rojo build default.project.json --output work/integrated.rbxl
```

Open the built place in Studio for the final multiplayer playtest.
