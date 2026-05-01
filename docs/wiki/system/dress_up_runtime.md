# Dress-Up Runtime

## Status

Implemented as the v1 player-facing dress-up loop.

## Runtime Boundaries

- `res://scripts/content/ContentRepository.gd` loads JSON content from `res://content/` and exposes indexed lookup for wardrobe, visuals, assets, poses, and body rig parts.
- `res://scripts/game/OutfitState.gd` owns the current outfit stack and appearance settings.
- `res://scripts/game/OutfitHistory.gd` owns undo and redo snapshots.
- `res://scripts/doll/DollSvgBuilder.gd` converts rig, pose, body SVG, and equipment SVG data into a single actor-space SVG.
- `res://scripts/doll/SvgTextureCache.gd` converts generated SVG strings to `ImageTexture` instances with `Image.load_svg_from_string()`.
- `res://scripts/ui/MainScene.gd` coordinates UI signals and runtime state changes.

## Equipment Rules

- Wardrobe items are equipped by appending their id to `OutfitState.equipped_item_ids`.
- No slot exclusivity, overlap validation, or body-part conflict validation is applied at runtime.
- Draw order follows equip order after body rig rendering.
- Picking from the doll removes the top equipped item from the stack. The current v1 hit behavior treats the doll stage as the pick area and uses stack order for topmost selection.
- Drag cancellation restores the pre-drag outfit snapshot without recording undo history.

## Persistence

Outfits are saved to `user://outfits/*.json` through `res://scripts/game/OutfitPersistence.gd`. Saved outfit files store only runtime outfit state, not source content.

## Validation

Targeted tests:

- `res://tests/gut/TestOutfitState.gd`
- `res://tests/gut/TestOutfitPersistence.gd`
- `res://tests/gut/TestContentValidation.gd`
- `res://tests/gut/TestSvgSafety.gd`
- `res://tests/gut/TestLattice.gd`

Full validation should also include a headless Godot project load after a Godot executable is configured.
