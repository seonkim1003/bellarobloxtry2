# Studio preflight checklist (content & marketplace)

Use this once before publishing or sharing a test place.

## Marketplace ownership

1. Open the place in Roblox Studio while signed in as the **place creator**.
2. For each ID in `art/export/MANIFEST.md` → Marketplace models:
   - Open the store link.
   - Click **Get** (or confirm already owned).
3. In Studio, open **Toolbox → My Models / Creations** and confirm each asset appears.
4. Press Play once and check Output for:
   - `[Content]` marketplace ready / mount messages
   - No repeated `InsertService` permission failures

## InsertService availability

1. Place must allow `InsertService:LoadAsset` for creator-owned assets.
2. Confirm `ReplicatedStorage.ContentModels` gets `Ready = true` after server start.
3. Confirm Lobby and Field mount `MarketplaceMap`; Maze and Tower intentionally retain deterministic authored gameplay geometry.
4. Soft-hidden stand-ins: Output should log how many stand-in parts were hidden after mount.

## Creator media placeholders

Until real IDs exist in `ContentConfig`:

- Sounds stay silent (no errors).
- Images stay blank.
- Animations remain `rbxassetid://0` under `assets.animations` (not sound keys).

Upload → copy asset ID → update `ContentConfig` + `art/export/MANIFEST.md` in one pass.

## Controller / accessibility quick check

1. Title: Ready via mouse, Enter, and gamepad A; focus ring visible.
2. Tab / Y unlocks cursor in first-person; CursorToggle button appears after Ready/story start.
3. Credits: Replay / Leave with confirm dialog before Kick.
4. Toggle Reduced Motion (M / D-Pad ↓) and confirm vignette / letter fade soften.

## Do not ship with

- Unowned marketplace inserts relied on as primary geometry
- Invented `rbxassetid` numbers
- Copyrighted audio dropped in without license documentation
