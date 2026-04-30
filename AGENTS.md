## Project-Specific Instructions

- Before making changes in this repository, read and follow [PROJECT.md](PROJECT.md).
- `PROJECT.md` contains project workflow rules: engine discovery, validation expectations, resource conventions, and repository-specific tooling.
- If `PROJECT.md` conflicts with this general guidance, follow the more specific rule in `PROJECT.md`.

## Documentation And Wiki Instructions

- Before editing `res://docs/`, wiki entries, documentation templates, or documentation standards, read and follow [DOCS.md](DOCS.md).
- `res://docs/wiki/` contains technical wiki entries for systems, scenes, resources, tools, workflows, and implementation behavior.
- `res://docs/templates/` contains Markdown templates for technical wiki entries.
- Wiki entries should document implementation-facing behavior and technical contracts, not marketing copy, unverified design claims, or fictional setting prose.

## Code Generation Policy

- Make the smallest change that fully solves the task.
- Reuse existing code, scenes, resources, naming, and project patterns before adding new abstractions.
- Do not invent missing requirements; ask when ambiguity would materially change behavior.
- Prefer strong types, explicit data models, and clear invariants over defensive branching.
- Keep control flow readable and correct, especially around state transitions, retries, loading, and fallbacks.
- Do not keep or support backward compatibility, compatibility shims, obsolete APIs, legacy behavior, or old call paths when implementing new code.
- Default to refactoring or rewriting still-required sections of old or obsolete code so the codebase has one current implementation path.
- Clean up obsolete code, adapters, fallback branches, tests, documentation, and call sites related to the task.
- Use parameterized queries, avoid unsafe rendering, and never hardcode secrets.
- Do not add dependencies without clear justification.
- Before finishing, check for duplication, broken call sites, dead code, stale references, and regressions at system boundaries.

## Architecture And Modularity

- Prefer small, focused scripts, resources, and scenes with one clear responsibility each.
- Keep game rules, UI wiring, persistence, authored data, and scene orchestration separated instead of mixing them in a single script.
- Extract reusable behavior only when duplication is real and the abstraction improves clarity.
- Favor composition and instanced sub-scenes for reusable parts whose node structure may vary.
- Use base scenes and inherited scenes for similar reusable variants that share the same root structure and behavior.
- Define explicit boundaries between systems and pass data through narrow, well-named interfaces.
- Avoid global state unless the project already uses an autoload for a clear cross-cutting service.
- Keep modules replaceable: callers should depend on behavior contracts, not internal implementation details.

## Data Modeling

- Model domain concepts explicitly with dedicated classes, resources, enums, typed arrays, and typed dictionaries.
- Keep important authored data in clear resource structures: base resource classes first, then specific resources extending them.
- Choose data structures that match access patterns, update frequency, and ownership semantics.
- Use maps for keyed lookup, arrays for ordered collections, set-like dictionaries for membership checks, and dedicated records for stable state.
- Keep data normalized when multiple systems read or mutate it, and document intentional denormalization when used for performance or simplicity.
- Encode invariants in the data model first rather than patching invalid states later in control flow.
- Prefer immutable-style handoff for shared data where practical; when mutation is required, keep ownership obvious.
- Make state transitions explicit and finite when modeling equipment, inventory, interaction modes, progression, or UI state.

## API And Interface Design

- Design functions and methods to have clear inputs, outputs, and side effects.
- Prefer returning structured results over using hidden mutation or ambiguous sentinel values.
- Keep public APIs minimal and stable; hide internal helpers unless they are truly reusable.
- Use names that communicate intent, domain meaning, and ownership rather than implementation trivia.
- Keep argument lists short; group related parameters into typed objects or resources when that improves clarity.
- Validate assumptions at module boundaries where incorrect data would corrupt state or produce hard-to-debug behavior.

## Control Flow And State

- Favor straightforward control flow over clever branching or compact but opaque expressions.
- Represent complex behavior as explicit states and transitions instead of scattered boolean flags.
- Minimize temporal coupling: a method should not require fragile call ordering unless the ordering is part of the contract.
- Keep async flows, signal handling, and deferred execution easy to trace.
- When failure is possible, define how state remains valid before, during, and after the failure path.

## Quality And Maintainability

- Write code that is easy to inspect, debug, and extend by another engineer without hidden assumptions.
- Add concise comments only where the intent, invariant, or non-obvious tradeoff is not self-evident from the code.
- Remove dead branches, stale helpers, and speculative hooks rather than leaving partial scaffolding behind.
- Remove legacy-only branches and compatibility layers when replacing behavior; do not leave old paths beside the new implementation.
- Prefer deterministic behavior and reproducible outcomes over incidental side effects.
- Keep files cohesive; if a file starts carrying multiple unrelated responsibilities, split it.
- Avoid premature optimization, but do not ignore obviously poor complexity in hot paths or frequently updated systems.

## Testing And Verification

- Add or update tests for changed behavior when the project has an established test path for that area.
- Verify both the happy path and the most likely failure or edge path introduced by the change.
- Test system boundaries where data crosses between gameplay logic, UI, persistence, resources, and scene loading.
- When a full automated test is not practical, add the smallest verification hook or manual validation path that materially reduces risk.
- After implementation and relevant verification pass, create a git commit when the repository has git metadata and project policy requires commits.
- Do not commit before relevant tests or validation steps pass. If verification is blocked or failing, report that instead of creating a commit.
- Use non-interactive git commands and a concise commit message that reflects the actual completed change.
- Check `git status` before committing so only intended files are included.

## Environment And Tooling

- Treat this project as Windows-native unless project policy or the user explicitly says otherwise.
- Use PowerShell semantics, quote Windows paths, and prefer native executables by default.
- Do not assume WSL, bash, GNU coreutils, or Unix path conventions unless explicitly requested.
- If `rg` is unavailable or blocked, fall back to PowerShell-native search with `Get-ChildItem` and `Select-String`.
- Use [PROJECT.md](PROJECT.md) for configured executable discovery, project paths, targeted test runners, and validation commands.
- After moving or renaming Godot resources, scenes, scripts, or assets, verify the resulting `.tres` / `.tscn` reference chain with a real Godot load.
- Prefer small verification passes immediately after environment-sensitive edits so path, resource, and parser issues are caught early.

## Godot Scene And Node Design

- Treat scenes as reusable, class-like units; the scene and its root script should define one coherent behavior boundary.
- Give each scene one primary responsibility and a small, understandable public surface.
- Move any scene-tree branch with encapsulated functionality into its own scene and instance it back into the original scene.
- Keep extracted child scenes self-contained: they should own their local nodes, expose a narrow API, and avoid assumptions about parent internals.
- Use base scenes and inherited scenes when creating variants with the same node structure, shared behavior, and different exported values or assets.
- Prefer composition with instanced sub-scenes when variants need different node composition or optional feature branches.
- Use parent-child relationships only when ownership, lifetime, and transform behavior are truly coupled.
- If two nodes must communicate but should not share lifetime, prefer sibling relationships coordinated by a parent, injected references, or signals.
- Use scenes when behavior depends on node hierarchy, editor wiring, transforms, or built-in lifecycle; use scripts alone when a scene adds no value.
- Avoid reaching deep through foreign scene trees with fragile `NodePath` assumptions when explicit references or local APIs would be clearer.

## Godot UI And Editor-Authored Layout

- Do not create default UI `Control` scene-tree nodes from scripts unless editor-authored scenes, instanced UI scenes, or existing reusable scenes cannot reasonably implement the solution.
- Prefer `.tscn` UI scenes authored in the Godot editor so layout, anchors, containers, themes, and node relationships are visible and tweakable.
- Use containers, anchors, size flags, and themes intentionally so UI adapts across viewport sizes and platforms.
- Use scripts to bind data, handle interaction, and instantiate already-authored UI scenes; avoid scripts that hand-build static UI hierarchies.
- Use programmatic UI creation only for genuinely dynamic runtime content, editor tools, generated lists where item scenes are still reusable, or cases where no practical scene-based alternative exists.
- Export UI dependencies and configurable values so designers can inspect and adjust them from the editor.

## Godot Dependencies And Communication

- Prefer exported references, parent-provided initialization, or explicit dependency injection before relying on global lookups.
- Reserve autoloads for true application-wide services and persistent cross-scene state; do not use them as the default feature dependency.
- Use direct calls for simple local relationships and signals for decoupled cross-boundary events.
- Avoid oversized global signal buses or hidden event chains that make control flow difficult to trace.
- Use groups for broad discovery or coordination only when membership rules are explicit and the lookup cost and ambiguity are acceptable.
- Make required dependencies obvious in the API of a scene or script instead of assuming they will exist somewhere in the tree.

## Godot Data, Resources, And Lightweight Objects

- Use `Resource` for authored data, templates, configuration, and editor-tuned content that should exist independently from runtime node instances.
- Use `RefCounted` or plain script objects for state machines, calculations, and data containers that do not need `SceneTree` membership.
- Use `Node` only when tree membership, transforms, signals, processing, input, or lifecycle callbacks are actually required.
- Register reusable custom resources and editor-facing custom nodes with `class_name` so they are easy to create and assign in the Inspector.
- Keep authored resources external as `.tres` or `.res` where practical, instead of burying important data as opaque built-in subresources.
- Provide typed `@export` fields with sensible defaults for values that should be manually tweaked, changed, or visually inspected from the editor.
- Group related exported properties where useful, and keep Inspector surfaces focused enough that content can be tuned confidently.
- Treat resources as stable data carriers and nodes as runtime behavior owners; do not collapse both roles into one object without a clear reason.
- Avoid turning every gameplay concept into a node if it does not benefit from node behavior.

## Godot Lifecycle, Loading, And Performance

- Configure instances and inject dependencies before calling `add_child()` whenever practical.
- Use `_enter_tree()` for setup that depends on joining the tree, `_ready()` when child nodes must already exist, and notifications when reacting to parenting or unparenting events specifically.
- Prefer `_input()` or `_unhandled_input()` for event-driven input handling instead of polling input every frame when continuous polling is unnecessary.
- Use `preload` for stable, always-needed dependencies and on-demand loading for optional, heavy, or rarely used content.
- Split large scenes into smaller reusable chunks before introducing streaming or dynamic loading systems.
- Add dynamic loading, pooling, or streaming only when memory, load time, or runtime performance justifies the added complexity.
- Keep `_process()` and `_physics_process()` focused, and disable processing for nodes that are currently idle.
- When a script is used as a class-like dependency via `preload(...).new()`, ensure it extends a constructible type and still compiles after refactors.

## Godot Project Organization

- Organize scenes, scripts, resources, and assets around features or owned scene units instead of separating everything by file type alone.
- Keep third-party tools, plugins, and external packages under `addons/` when that structure fits their usage and ownership.
- Use consistent, descriptive naming conventions: `snake_case` for files and folders, `PascalCase` for node names, and clear names for scenes, scripts, and resources.
- Keep exported properties typed, intentional, and safe to configure in the editor with sensible defaults.
- Separate reusable templates, authored data, and runtime-only state so ownership remains obvious in both code and the editor.
- Keep scene files and their primary scripts aligned in naming and purpose when they represent the same reusable unit.

## Decision Standard

- Default to the simplest design that remains modular under expected growth.
- Increase abstraction only when it improves correctness, reuse, or change isolation.
- Favor designs that make invalid states difficult to represent and correct behavior easy to follow.
- When choosing between multiple workable approaches, prefer the one with clearer invariants, better module boundaries, and lower long-term maintenance cost.
