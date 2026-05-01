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
- Draw order follows layer order first, then equip order within each layer.
- Picking from the doll treats the doll stage as the pick area and removes the top visible equipped item according to rendered layer/equip order.
- Drag cancellation restores the pre-drag outfit snapshot without recording undo history.

## Persistence

Outfits are saved atomically to `user://outfits/*.json` through `res://scripts/game/OutfitPersistence.gd`. Saved outfit files store only canonical runtime outfit state, not source content.

Loaded outfits are validated against `ContentRepository` before being applied. Missing variants, poses, wardrobe ids, invalid colors, and non-canonical keys are reported as load errors.

The player UI confirms before overwriting an existing outfit, reports empty outfit lists, and supports deleting saved outfit files from the load dialog.

`res://scripts/game/OutfitHistory.gd` keeps bounded undo/redo snapshots and skips repeated identical snapshots.

## Content Loading

`ContentRepository.load_all()` reports missing files, invalid JSON, and wrong root types in `load_errors`, then combines those with content validation errors. Content saves use temporary files plus backup/replace behavior so a validation-blocked save does not replace the existing source JSON.

When a body rig is missing required renderer-known body parts, `ContentRepository` synthesizes default parts in memory and reports them through `generated_body_part_repairs`. The Dev Content Editor shows that repair state and requires an explicit repair/save action before those generated parts are persisted to `res://content/body_rig.json`.

`SvgTextureCache` keeps an LRU-bounded runtime texture cache and should be cleared after source content reloads.

Pose transforms support `x`, `y`, `rotate`, `scaleX`, `scaleY`, and `bend`. Runtime bend is a lightweight pivot-centered SVG `skewX()` transform so the Dev Editor bend slider has visible output; lattice deformation remains the body-part variation system for authored shape changes.

## Validation

Targeted tests:

- `res://tests/gut/TestOutfitState.gd`
- `res://tests/gut/TestOutfitPersistence.gd`
- `res://tests/gut/TestContentRepository.gd`
- `res://tests/gut/TestContentValidation.gd`
- `res://tests/gut/TestSvgSafety.gd`
- `res://tests/gut/TestLattice.gd`
- `res://tests/gut/TestPoseKinematics.gd`

Full validation can be run with:

```powershell
tools\RunGut.ps1
```

The project-local Godot workflow config points to `G:\BIN\Godot_v4.6.1-stable_win64.exe`. Full validation should also include a headless Godot project load.
