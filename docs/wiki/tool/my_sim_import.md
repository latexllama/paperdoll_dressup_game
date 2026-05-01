# My Sim Content Import

## Status

Implemented as a project-local Python tool.

## Tool

`res://tools/import_my_sim_content.py` imports dress-up content from `D:\DEV\GAME\web_projects\my_sim` and writes Godot-friendly JSON source files under `res://content/`.

Generated collections:

- `res://content/body_rig.json`
- `res://content/equipment_assets.json`
- `res://content/equipment_visuals.json`
- `res://content/wardrobe.json`
- `res://content/poses.json`
- `res://content/sample_meta.json`
- `res://content/starting_outfit.json`
- `res://content/import_manifest.json`

## Imported Scope

- Female body rig parts: 25.
- Male body rig parts: 25.
- Wardrobe items: 10.
- Equipment visuals: 10.
- Equipment assets: 23 after combining CTA, original, and custom source assets.
- Poses: 4.

## Validation

Use dry-run mode before writing:

```powershell
py -3 tools\import_my_sim_content.py --dry-run
```

Use the normal import command to regenerate source content:

```powershell
py -3 tools\import_my_sim_content.py
```

After import, run content validation through the GUT suite and run a headless Godot load when an engine executable is available.

Dry-run and write modes validate generated references before source files are written. The import blocks duplicate ids, missing visual/asset/rig references, missing starting outfit references, and obsolete wardrobe fields.

Imported body-rig hair, brow, and iris SVG fills are normalized to semantic color tokens where known so runtime appearance settings can recolor them. `DollSvgBuilder` still keeps a fallback fixed-fill map for older or manually authored SVG that has not been reimported.
