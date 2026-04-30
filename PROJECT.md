# Generic Godot Project Instructions

Read this file before making changes in this repository. These rules are project-specific workflow guidance and override `AGENTS.md` when they are more specific.

## Environment And Tooling

- Treat the project as Windows-native unless project policy or the user explicitly requests another environment.
- Use PowerShell commands, quote Windows paths, and prefer native executables.
- Locate the project root by finding `project.godot`; run commands from that directory unless a tool requires otherwise.
- Resolve the Godot executable in this order:
  1. Explicit user input or task context.
  2. Project-local workflow config such as `.godot-workflow.json`.
  3. Environment variables such as `GODOT_EXECUTABLE`, `GODOT_BIN`, `GODOT4`, or `GODOT`.
  4. `Get-Command godot` or `Get-Command godot4`.
  5. Common local install folders.
- If Godot cannot be resolved, report the checked locations and continue with non-engine validation that still applies.
- If `rg` is unavailable or blocked, use PowerShell-native search with `Get-ChildItem` and `Select-String`. Do not route the task through WSL unless explicitly requested.
- After moving or renaming Godot resources, scenes, scripts, or assets, run a real Godot load because `.tres`, `.tscn`, UID, and dependency issues often only surface in the engine.

Generic headless load pattern:

```powershell
$project = (Get-Location).Path
$godot = $env:GODOT_EXECUTABLE
& $godot --headless --path $project --quit
```

If the executable is discovered through `Get-Command`, assign the resolved path first:

```powershell
$project = (Get-Location).Path
$godot = (Get-Command godot -ErrorAction Stop).Source
& $godot --headless --path $project --quit
```

## Testing And Verification

- Prefer the smallest validation that exercises the changed behavior.
- Use project-local test runners when they exist, such as scripts under `tools/`, tests under `tests/`, or an addon-provided runner.
- If no automated test runner exists for the changed area, document that and run the strongest practical fallback: readback, static checks, a Godot headless load, editor/manual verification, or a small temporary validation scene when appropriate.
- Use broader validation for shared bootstrap, autoloads, main scene changes, project settings, broad resource moves, or release-style validation.
- If a targeted runner exceeds a reasonable timeout, report the timeout and stop any Godot processes started by that run. Do not claim the runner passed.
- Warnings from Godot should be reported when present, but command exit codes determine pass/fail unless the task is specifically about warning cleanup.
- For documentation-only changes, read back edited files and run `git diff --check` when the repository has git metadata.
- Before committing, check `git status`, stage only intended files, and leave unrelated untracked files untouched unless the task explicitly targets them.

## Scene And UI Workflow

- Prefer editor-authored `.tscn` scenes for stable UI and gameplay hierarchies so node structure, layout, exported values, and dependencies can be inspected visually.
- Do not create default UI `Control` scene-tree nodes from scripts unless editor-authored scenes, instanced UI scenes, or existing reusable scenes cannot reasonably solve the problem.
- Use scripts to bind behavior, connect signals, load data, and instance reusable scenes; avoid scripts that manually construct static UI layouts.
- Split scene-tree branches into new scenes whenever the branch has an encapsulated responsibility, repeated use, or enough local behavior to justify a public API.
- Instance extracted child scenes back into their parent scene and keep the child scene self-contained.
- Use base scenes and inherited scenes for same-structure variants that share behavior and differ mostly by exported values, visuals, resources, or minor additions.
- Prefer composition and instanced sub-scenes when variants need different node structure or optional feature branches.
- Keep required scene dependencies visible through exported references, parent-provided initialization, local APIs, or documented signals.

## Resource And Content Workflow

- Keep authored data in explicit, typed `Resource` classes when the data should be reused, inspected, serialized, or configured in the editor.
- Define base resource classes for shared fields and behavior, then extend them with specific resource types for concrete content categories.
- Register editor-facing resources with `class_name` so they can be created and assigned from the Inspector.
- Export important values with types and sensible defaults so designers and developers can manually tweak and visually inspect content from the editor.
- Store important authored resources as external `.tres` or `.res` files where practical; avoid hiding meaningful content inside large scene files unless scene-local ownership is intentional.
- Keep runtime-only state separate from authored resources. If a resource must be modified per instance, document whether duplication or `resource_local_to_scene` is required.
- Preserve `.uid`, `.import`, and companion metadata files unless intentionally regenerating or replacing the referenced asset.

## Project Organization

- Organize files around features or owned scene units when possible: scene, script, resources, and assets that change together should usually live near each other.
- Use `snake_case` for folders and files unless a language or project convention requires otherwise.
- Use `PascalCase` for node names to match Godot's built-in node naming style.
- Keep third-party addons and plugins under `addons/` when that structure fits ownership and update workflow.
- Keep generated files, caches, exports, and local-only tooling outputs out of source control unless project policy explicitly tracks them.
- Use `.gdignore` only for folders that Godot should not import. Do not add `.gdignore` to `docs/` when documentation is intentionally referenced through `res://docs/`.

## Commit And Worktree Discipline

- Check `git status --short` before staging.
- Stage only intended files. Do not stage unrelated user changes or generated/untracked files unless they are part of the task.
- Do not use destructive git commands such as `git reset --hard` or `git checkout --` unless explicitly requested.
- Commit only after relevant validation passes and only when this directory is inside a git repository.
- If validation is blocked, failing, or the project has no git metadata, report that instead of making an unsupported commit.
- Use concise commit messages that describe the actual completed change.
