# Codex Handoff: Torso Build Variations

Date: 2026-05-02

## Repo And Branch

- Repository: `D:\DEV\GAME\godot_projects\KisekaeDressupGame`
- Project root: contains `project.godot`
- Branch: `master`
- Working tree at handoff time: uncommitted changes in `content/body_rig.json`, `tests/gut/TestSvgRuntimeLoad.gd`, and this handoff document.
- Godot executable configured in `.godot-workflow.json`: `G:\BIN\Godot_v4.6.1-stable_win64.exe`

## Context Note

This handoff is based on repository inspection and commands run during the handoff pass. The prior Codex chat transcript was not available in this context, so do not assume earlier tests passed unless they are listed below.

## Current Goal

Active implementation goal inferred from the existing working tree: add and verify authored torso body-build SVG variations for both female and male body rigs. The required variation IDs are:

- `lean`
- `athletic`
- `stocky`
- `muscular`

Immediate user goal for this pass: create a repo-local handoff document before archiving Codex history.

## Already Completed

- Added female torso SVG variations in `content/body_rig.json` under the female `torso` body part:
  - `lean`
  - `athletic`
  - `stocky`
  - `muscular`
- Added male torso SVG variations in `content/body_rig.json` under the male `torso` body part:
  - `lean`
  - `athletic`
  - `stocky`
  - `muscular`
- Each new torso variation uses `var(--doll-skin)` and shadow paths using `var(--doll-skin-shadow)`.
- Added test coverage in `tests/gut/TestSvgRuntimeLoad.gd`:
  - `TORSO_BUILD_VARIATION_IDS := ["lean", "athletic", "stocky", "muscular"]`
  - `test_torso_body_build_variations_are_authored_for_required_variants()`
  - The test checks that female and male torso parts exist, each required variation exists, markup passes `SvgSafety.is_safe_markup()`, and markup contains `var(--doll-skin)`.
- Targeted GUT validation for `res://tests/gut/TestSvgRuntimeLoad.gd` passed with exit code `0`.

## Files Touched

- `content/body_rig.json`
  - Existing uncommitted change before this handoff.
  - Adds four female and four male torso SVG build variations.
- `tests/gut/TestSvgRuntimeLoad.gd`
  - Existing uncommitted change before this handoff.
  - Adds required torso build variation IDs and validation coverage.
- `docs/codex-handoffs/2026-05-02-torso-build-variations.md`
  - Created during this handoff pass.

## Files Investigated

- `AGENTS.md`
  - Project-level instructions exist and are reflected in the user-provided prompt.
- `PROJECT.md`
  - Confirms Windows-native workflow, PowerShell defaults, Godot executable discovery, GUT validation expectations, and commit discipline.
- `DOCS.md`
  - Confirms `docs/wiki/` is reserved for technical wiki entries and templates. This handoff is intentionally stored in `docs/codex-handoffs/` instead.
- `.godot-workflow.json`
  - Confirms configured Godot executable and test script patterns.
- `tools/RunGut.ps1`
  - Project wrapper for full GUT runs.
- `tools/RunResourceAudit.ps1`
  - Project wrapper for resource audits.
- `scripts/doll/DollSvgBuilder.gd`
  - Confirms body part sprite selection reads `pose.sprites[part_id]` and uses `part["variations"][sprite_id]` or lattice variations when present.
- `scripts/content/ContentValidator.gd`
  - Confirms body part variations are validated as a dictionary of safe SVG markup strings.
- `scripts/content/ContentRepository.gd`
  - Confirmed via search as the source of `body_part()` and body rig normalization behavior.
- Existing tests under `tests/gut/`
  - Confirmed GUT test coverage exists for content repository, SVG safety/runtime loading, body rig preview, editor workflows, and imported content.

## Commands And Tests Already Run

Inspection commands:

```powershell
Get-Content -Raw -LiteralPath 'D:\DEV\GAME\godot_projects\KisekaeDressupGame\PROJECT.md'
Get-Content -Raw -LiteralPath 'D:\DEV\GAME\godot_projects\KisekaeDressupGame\DOCS.md'
git -C 'D:\DEV\GAME\godot_projects\KisekaeDressupGame' status --short --branch
git -C 'D:\DEV\GAME\godot_projects\KisekaeDressupGame' branch --show-current
git -C 'D:\DEV\GAME\godot_projects\KisekaeDressupGame' diff --stat
git -C 'D:\DEV\GAME\godot_projects\KisekaeDressupGame' diff -- 'content/body_rig.json'
git -C 'D:\DEV\GAME\godot_projects\KisekaeDressupGame' diff -- 'tests/gut/TestSvgRuntimeLoad.gd'
git -C 'D:\DEV\GAME\godot_projects\KisekaeDressupGame' log --oneline -5
rg -n "body_part\(|variations|SvgSafety|SvgTextureCache|TORSO_BUILD_VARIATION_IDS|body_rig" 'D:\DEV\GAME\godot_projects\KisekaeDressupGame\scripts' 'D:\DEV\GAME\godot_projects\KisekaeDressupGame\tests' 'D:\DEV\GAME\godot_projects\KisekaeDressupGame\content'
```

Directory creation:

```powershell
New-Item -ItemType Directory -Force -LiteralPath 'D:\DEV\GAME\godot_projects\KisekaeDressupGame\docs\codex-handoffs'
New-Item -ItemType Directory -Force -Path 'D:\DEV\GAME\godot_projects\KisekaeDressupGame\docs\codex-handoffs'
```

The first command failed because this PowerShell environment rejected `New-Item -LiteralPath`; the second command succeeded.

Targeted GUT validation:

```powershell
$ErrorActionPreference = 'Stop'
$project = 'D:\DEV\GAME\godot_projects\KisekaeDressupGame'
$workflow = Get-Content -Raw -LiteralPath (Join-Path $project '.godot-workflow.json') | ConvertFrom-Json
$godot = [string]$workflow.godot_executable
if (-not (Test-Path -LiteralPath $godot)) { throw "Godot executable not found: $godot" }
& $godot --headless --path $project --script res://addons/gut/gut_cmdln.gd -gtest=res://tests/gut/TestSvgRuntimeLoad.gd -gexit -gdisable_colors
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

Result: passed, exit code `0`. The command produced no meaningful stdout in this environment.

Post-write handoff validation:

```powershell
Get-Content -Raw -LiteralPath 'D:\DEV\GAME\godot_projects\KisekaeDressupGame\docs\codex-handoffs\2026-05-02-torso-build-variations.md'
git -C 'D:\DEV\GAME\godot_projects\KisekaeDressupGame' diff --check
git -C 'D:\DEV\GAME\godot_projects\KisekaeDressupGame' status --short --branch
```

Result: handoff readback succeeded. `git diff --check` exited `0`.

## Known Errors, Warnings, And Failing Checks

- `git diff --stat` and `git diff -- content/body_rig.json` emitted:
  - `warning: in the working copy of 'content/body_rig.json', CRLF will be replaced by LF the next time Git touches it`
- `git diff --check` exited `0` but emitted the same `content/body_rig.json` CRLF-to-LF warning.
- `New-Item -LiteralPath` failed for handoff directory creation; retrying with `New-Item -Path` succeeded.
- No failing Godot/GUT checks were observed in this handoff pass.
- Full GUT suite was not run during this handoff pass.
- Headless project load with `--quit` was not run during this handoff pass.
- Resource audit was not run during this handoff pass.

## Open Decisions

- Decide whether the current hand-authored/provisional torso variation SVG silhouettes are final enough, or whether they need another art pass against Figma/source art before commit.
- Decide whether the four build variation IDs are final authored content IDs or temporary placeholders.
- Decide whether additional UI/editor affordances are needed to expose torso build variation selection, or whether existing `pose.sprites`/body rig variation handling is sufficient for the current milestone.
- Decide whether to normalize `content/body_rig.json` line endings now or leave Git to normalize on the next write.
- Decide whether to include this handoff document in the eventual commit or keep it as local archive-only documentation.

## Constraints And Preferences

- Treat this repository as Windows-native.
- Use PowerShell-native commands and `C:\...`/`D:\...`/`G:\...` paths.
- Prefer `py -3` for Python.
- Do not route work through WSL unless explicitly requested.
- Read `PROJECT.md` before changing repo files.
- Read `DOCS.md` before editing `docs/wiki/`, `docs/templates/`, technical wiki entries, or documentation standards.
- Keep changes small and focused.
- Reuse existing Godot scenes, scripts, content schemas, and GUT patterns before adding abstractions.
- Do not add dependencies without clear justification.
- Do not preserve obsolete compatibility paths unless explicitly required.
- Clean up obsolete code related to the task.
- Do not create static Godot UI trees from script when editor-authored scenes are practical.
- Preserve `.uid`, `.import`, and Godot resource references unless intentionally regenerating or moving assets.
- Do not revert user or pre-existing working tree changes.
- Before committing, run relevant validation, check `git status --short`, and stage only intended files.

## Do-Not-Touch Areas For This Continuation

- Do not rewrite unrelated content JSON, wardrobe data, equipment assets, poses, animations, or editor UI code unless needed for torso build variations.
- Do not alter `addons/gut/` or third-party addon files unless the task explicitly targets test infrastructure.
- Do not move or rename Godot resources/scenes/scripts/assets without running a real Godot load afterward.
- Do not mix this handoff into `docs/wiki/`; it is not a technical wiki entry.
- Do not commit until the relevant checks for the active implementation goal pass.

## Next Concrete Steps

1. Review `content/body_rig.json` around the female and male `torso` entries to confirm the variation SVG markup is visually and semantically correct.
2. Preview the body rigs in the existing dev/editor UI or by generating SVGs that select each torso variation through `pose.sprites["torso"]`.
3. Re-run the targeted GUT test after any further edits:

   ```powershell
   $project = 'D:\DEV\GAME\godot_projects\KisekaeDressupGame'
   $workflow = Get-Content -Raw -LiteralPath (Join-Path $project '.godot-workflow.json') | ConvertFrom-Json
   & ([string]$workflow.godot_executable) --headless --path $project --script res://addons/gut/gut_cmdln.gd -gtest=res://tests/gut/TestSvgRuntimeLoad.gd -gexit -gdisable_colors
   ```

4. Run broader validation before commit:

   ```powershell
   powershell -ExecutionPolicy Bypass -File 'D:\DEV\GAME\godot_projects\KisekaeDressupGame\tools\RunGut.ps1'
   ```

5. Run a headless project load if content or Godot resource references are changed further:

   ```powershell
   $project = 'D:\DEV\GAME\godot_projects\KisekaeDressupGame'
   $workflow = Get-Content -Raw -LiteralPath (Join-Path $project '.godot-workflow.json') | ConvertFrom-Json
   & ([string]$workflow.godot_executable) --headless --path $project --quit
   ```

6. Address or consciously accept the `content/body_rig.json` CRLF-to-LF Git warning.
7. Check `git status --short`, stage only intended files, and create a concise commit if validation passes.

## Reactivation Prompt

Paste this into a fresh Codex chat:

```text
You are continuing work in D:\DEV\GAME\godot_projects\KisekaeDressupGame on branch master.

Read and follow AGENTS.md, PROJECT.md, and DOCS.md before editing. Treat this as a Windows-native Godot project. Use PowerShell, do not use WSL, prefer project-local tools, and do not revert existing user changes.

The current implementation goal is to finish and verify torso body-build SVG variations for both female and male body rigs. The working tree already has uncommitted changes:
- content/body_rig.json: adds female and male torso SVG variations for lean, athletic, stocky, and muscular.
- tests/gut/TestSvgRuntimeLoad.gd: adds TORSO_BUILD_VARIATION_IDS and a test that female/male torso variations exist, pass SvgSafety, and contain var(--doll-skin).
- docs/codex-handoffs/2026-05-02-torso-build-variations.md: handoff document.

Known validation from the handoff pass:
- Targeted GUT command for res://tests/gut/TestSvgRuntimeLoad.gd passed with exit code 0 using G:\BIN\Godot_v4.6.1-stable_win64.exe.
- Full GUT suite, resource audit, and headless --quit project load were not run.
- Git warned that content/body_rig.json has CRLF that will be replaced by LF next time Git touches it.

Continue by inspecting the existing diff, visually or programmatically verifying the new torso variations, running appropriate GUT/headless validation, addressing any failures or line-ending concerns, then checking git status and committing only the intended files if validation passes. Do not stage unrelated changes.
```
