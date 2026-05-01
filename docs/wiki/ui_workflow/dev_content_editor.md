# Dev Content Editor

## Status

Implemented as a draft-backed in-game content editing suite at `res://scenes/ui/DevContentEditor.tscn`.

## Scene Contract

Root scene: `Window`.

Primary script: `res://scripts/ui/DevContentEditor.gd`.

The main scene opens the editor through the `Dev Editor` top-bar button. The editor receives `ContentRepository` and `SvgTextureCache` instances from `MainScene`.

The UI intentionally does not expose JSON records. JSON remains the source storage format under `res://content/*.json`, but editing happens through form fields, list controls, dropdowns, color pickers, spin boxes, sliders, SVG source fields, and the lattice canvas.

## Editable Sections

The section selector exposes:

- Wardrobe: item identity, slot, description, visual assignment, colors, and visual-derived coverage.
- Visuals: equipment visual identity, slot, visual pieces, rig target, draw layer, SVG asset, color group, hide-body flag, and piece transforms.
- SVG Assets: asset identity, source type, actor-space flag, SVG import, SVG markup editing, safety validation, and preview.
- Body Rig: variant and part editing, parent and layer dropdowns, pivots, base SVG, SVG variations, and lattice variations.
- Poses: pose identity, interactive pose preview, part transform editing, arm IK handles, hand/foot sprite overrides, and variation override dropdowns from the selected rig.

Record lists support add, duplicate, and delete. Edits are applied to an in-memory `DevEditorDraft`; source content changes only when `Save All` succeeds.

## Draft Flow

`res://scripts/ui/DevEditorDraft.gd` deep-copies wardrobe, visuals, SVG assets, body rig, poses, sample metadata, and starting outfit data from `ContentRepository`.

Editor panels read and write only the draft. The dirty indicator compares the current draft signature with the loaded baseline. `Revert Draft` reloads from the repository and discards unsaved edits. Closing the window with dirty draft data opens a discard confirmation instead of silently hiding the editor.

`Save All` validates the draft repository clone, then writes collections through `ContentRepository.save_collection()` in this order:

- Equipment assets.
- Equipment visuals.
- Wardrobe.
- Body rig.
- Poses.

## Save Behavior

Saves call `ContentRepository.save_collection()`, which writes to `res://content/*.json` only when `OS.has_feature("editor")` is true. Exported builds receive an unsupported-save error instead of attempting to modify source content.

Each collection write is atomic at the file level. The draft save path validates against the full draft state without pre-mutating the live repository; if a write fails, repository memory is rolled back to the pre-save snapshot.

Before writing, content validation blocks:

- Duplicate ids.
- Missing equipment assets, visuals, rig targets, or pose parts.
- Invalid layers, colors, and transforms.
- Unknown fields or wrong field types in authored records.
- Unsafe SVG markup such as scripts, embedded images, external references, event handlers, and unsafe protocols.

## Preview

Wardrobe items and equipment visuals preview on the doll using a temporary outfit built from the draft repository clone. SVG assets preview only when `SvgSafety` accepts their markup. Body rig previews show the selected variant with pivots. Pose previews render the selected pose on the selected variant.

The body rig lattice variation editor uses `res://scripts/ui/LatticeCanvas.gd`. It draws the selected source SVG, grid lines, and draggable control points; moving a point updates the selected lattice variation in the draft.

The pose editor uses `res://scenes/ui/PosePreviewCanvas.tscn` and `res://scripts/doll/PoseKinematics.gd`. The canvas draws pose handles and guide lines over the rendered doll. Clicking a handle selects the part without dirtying the draft. Direct dragging is limited to hand and foot handles: hands solve the matching two-bone arm chain, and feet solve the matching thigh/shank chain. Numeric fields and sliders remain available for exact edits on any selected part.

Rendering a form should not create missing pose transforms or asset variant defaults. Missing optional authoring structures are surfaced as editor notes and must be created through explicit add/edit controls.

## Tests

Focused coverage exists in:

- `res://tests/gut/TestDevEditorDraft.gd`
- `res://tests/gut/TestDevEditorModels.gd`
- `res://tests/gut/TestDevContentEditorWindow.gd`
- `res://tests/gut/TestPoseKinematics.gd`
