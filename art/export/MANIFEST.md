# Runtime Export Manifest

Reviewed exports and Roblox asset IDs belong in `art/export`.

## Marketplace models (InsertService)

| Export / role | Roblox asset ID | Intended type | Store link | Ownership note | Review status |
| --- | --- | --- | --- | --- | --- |
| Lobby scene | `9271965383` | Model | [Lobby Island](https://create.roblox.com/store/asset/9271965383/Lobby-Island) | Marketplace free model — must be Get’d by place creator | Creator must confirm license |
| Maze scene | `114374837037591` | Model | [Backrooms Maze](https://create.roblox.com/store/asset/114374837037591/Backrooms-Map-Realistic-Maze-Escape-RP) | Retained as a reviewed reference; deterministic authored maze is active | Inactive reference |
| Tower scene | `14446703870` | Model | [Tower for Obby](https://create.roblox.com/store/asset/14446703870/Tower-for-Obby) | Retained as a reviewed reference; deterministic 28-step tower is active | Inactive reference |
| Field (farm) | `13088916306` | Model | [Farm Town Models](https://create.roblox.com/store/asset/13088916306/Farm-Town-Models) | Marketplace free model — must be Get’d by place creator | Creator must confirm license |
| Bella | `123711093849835` | Model | [Nikki Manaj](https://create.roblox.com/store/asset/123711093849835/Nikki-Manaj) | Stand-in template → Bella | Replace with creator-owned when ready |
| Rambo (friendly) | `285396402` | Model | [Puppy](https://create.roblox.com/store/asset/285396402/Puppy) | Stand-in template → friendly Rambo | Replace with creator-owned when ready |
| Rambo (scary) | `5292722268` | Model | [Cartoon Dog Killer](https://create.roblox.com/store/asset/5292722268/Cartoon-Dog-Killer) | Stand-in template → scary Rambo | Replace with creator-owned when ready |
| Robber Patterinson | `11851270` | Model | [Edward Cullen](https://create.roblox.com/store/asset/11851270/Edward-Cullen) | Stand-in template → Robber | Replace with creator-owned when ready |
| Gigi | `9747993459` | Model | [Pet The Dog](https://create.roblox.com/store/asset/9747993459/Pet-The-Dog) | Stand-in template → Gigi | Replace with creator-owned when ready |
| Letter fragments | `118658326038279` | Model | [95 Theses](https://create.roblox.com/store/asset/118658326038279/95-Theses) | Cloned to fragment markers | Creator must confirm license |

## Creator media still awaiting upload

| Role | ContentConfig key | Type | Asset ID | Status |
| --- | --- | --- | --- | --- |
| Title logo | `assets.images.titleLogo` | Image | `rbxassetid://0` | Placeholder |
| Fragment icon | `assets.images.fragmentIcon` | Image | `rbxassetid://0` | Placeholder |
| Credits backdrop | `assets.images.creditsBackdrop` | Image | `rbxassetid://0` | Placeholder |
| All ambience / stings / UI / ASMR | `sounds.*` | Audio | `rbxassetid://0` | Placeholder |
| Kidnap / revive / corruption | `assets.animations.*` | Animation | `rbxassetid://0` | Placeholder (not sound constants) |

**Studio requirement:** Get each free model with the Toolbox (or own the asset) for the place creator account before Play. `InsertService:LoadAsset` fails with a warn and keeps neon placeholders if an ID cannot be loaded.

See `docs/STUDIO_PREFLIGHT.md` for the ownership + InsertService checklist.
