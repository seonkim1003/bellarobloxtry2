# Agent rules

- Roblox Studio is the engine, Rojo is the filesystem bridge, and Luau is the language.
- Edit Rojo-managed scripts on disk, never in Studio.
- Never manually edit generated `Packages`, `ServerPackages`, `artifacts`, builds, or sourcemaps.
- Client code belongs in `src/client`.
- Authoritative server code belongs in `src/server`.
- Shared types and pure utilities belong in `src/shared`.
- Asset sources belong in `art/source`; reviewed exports belong in `art/export`.
- New Luau modules use `--!strict`.
- The server owns currency, inventory, progression, damage, rewards, purchases, and saved data.
- Validate and rate-limit every client-triggered server action.
- Keep remotes behind a small networking boundary.
- Preserve touch, keyboard/mouse, and controller support.
- Do not add Wally packages without a concrete consumer.
- The project is not complete unless the full validation script passes.
