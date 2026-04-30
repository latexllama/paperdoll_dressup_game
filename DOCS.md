# Godot Technical Wiki Instructions

Read this file before creating or editing technical wiki entries, documentation templates, or any content under `res://docs/`.

## Purpose

- Technical wiki entries explain systems, scenes, authored content, resources, tools, workflows, and implementation behavior.
- Entries are for developers, designers, and technical artists who need to understand how the project works, how content is wired, and how changes should be validated.
- Entries are not marketing copy, broad design pitches, fictional setting prose, or speculative notes.
- Do not invent behavior, content, formulas, dependencies, or requirements. If a detail is not verified from code, resources, tests, tools, or an explicit decision, mark it as provisional or leave it as an open question.

## Required Locations

- Store wiki entries under `res://docs/wiki/`, which maps to `docs/wiki/` in the repository.
- Store reusable entry templates under `res://docs/templates/`, which maps to `docs/templates/` in the repository.
- Link Godot resources and project files with `res://` paths inside wiki content when the entry is intended to be read from a Godot-aware context.
- Use ordinary relative Markdown links only when linking between Markdown files in the repository.

## Wiki Entry Folder Layout

- Store each template-generated wiki entry in the `res://docs/wiki/` subfolder that matches its source template.
- Do not place template-generated entries directly in `res://docs/wiki/`; reserve the wiki root for an index, shared navigation, or directory keep files.
- Create the matching subfolder when writing the first entry for a template category.
- If an entry fits multiple templates, choose the folder for the primary template and cross-link related entries instead of duplicating the document.
- Use concise `snake_case` filenames for entries unless an existing category uses a different convention.

Recommended template folder mapping:

- `res://docs/templates/system_template.md` -> `res://docs/wiki/system/`
- `res://docs/templates/scene_template.md` -> `res://docs/wiki/scene/`
- `res://docs/templates/resource_template.md` -> `res://docs/wiki/resource/`
- `res://docs/templates/ui_workflow_template.md` -> `res://docs/wiki/ui_workflow/`
- `res://docs/templates/tool_template.md` -> `res://docs/wiki/tool/`
- `res://docs/templates/architecture_template.md` -> `res://docs/wiki/architecture/`

## When To Use This File

Read this file before work that touches any of the following:

- `res://docs/`
- `res://docs/wiki/`
- `res://docs/templates/`
- `DOCS.md`
- wiki entries, technical documentation templates, or documentation standards
- system, scene, content, resource, UI, tool, pipeline, or architecture topics intended for the technical wiki

## Entry Standards

- Write one primary topic per file. Split entries when a document starts mixing unrelated systems, content categories, scene responsibilities, or workflows.
- Use Markdown headings consistently. Start with a single `#` title, then use `##` for major sections and `###` only when a section genuinely needs subdivision.
- Keep prose concise and technical. Prefer concrete behavior, data ownership, state transitions, resource paths, scene boundaries, and validation steps over background description.
- Make claims source-backed. Reference relevant scripts, scenes, resources, tests, tools, or prior approved decisions.
- Use `res://` paths for Godot resources, scenes, scripts, tests, and tools.
- Preserve implementation truth over desired future behavior. If planned behavior differs from current behavior, label it clearly.
- Include explicit status when behavior or data is provisional, deprecated, superseded, inferred, or blocked by an open question.
- Document edge cases and failure modes when they affect gameplay state, persistence, resource loading, UI behavior, tool output, or validation.
- Keep tables small and purposeful. Use bullet lists for compact contracts and checklists.
- Avoid screenshots or generated visuals unless they materially clarify a technical interface, scene structure, or workflow.

## Writing Rules

- Document behavior at the level where another engineer can inspect, test, or change it.
- Describe data/resource contracts: required fields, stable identifiers, default values, ownership, runtime consumers, editor-facing fields, and compatibility constraints.
- Record scene contracts: root type, public methods, signals, exported dependencies, instanced child scenes, ownership boundaries, and expected parent responsibilities.
- Record integration points such as signals, direct calls, autoloads, scene ownership, resource loading, tool commands, and test runners.
- Call out state transitions, lifecycle assumptions, cache invalidation, fallback behavior, and error handling when relevant.
- List validation steps that are appropriate for the entry, including targeted tests, Godot load checks, tool dry-runs, or documentation-only checks.
- Keep user-facing names only when they are stable identifiers or labels needed to locate technical data.
- Do not use a template as a reason to add empty filler. Remove sections that do not apply or mark them as `Not applicable` when their absence is important.

## Scene And Resource Documentation

- Document when a scene branch was intentionally extracted into its own reusable scene and how the parent should instance or configure it.
- Document base scenes and inherited scene variants when multiple scenes share the same structure and behavior.
- Document composition boundaries when reusable parts are instanced instead of inherited.
- Document base resource classes before documenting specific resources that extend them.
- Include Inspector-tweakable exported properties, default values, and editor setup requirements when they are part of the contract.

## Template Selection Guide

- Use `res://docs/templates/system_template.md` for mechanics, rules, runtime systems, state machines, and gameplay loops.
- Use `res://docs/templates/scene_template.md` for reusable scenes, scene ownership, node structure, editor wiring, scene inheritance, and instancing contracts.
- Use `res://docs/templates/resource_template.md` for authored resources, content definitions, stable IDs, fixture data, and resource compatibility.
- Use `res://docs/templates/ui_workflow_template.md` for screens, editor workflows, player interactions, UI state, persistence, and input behavior.
- Use `res://docs/templates/tool_template.md` for generators, import/export flows, batch commands, caches, validation scripts, and generated outputs.
- Use `res://docs/templates/architecture_template.md` for cross-cutting module boundaries, autoloads, service contracts, data flow, and repository conventions.
- If more than one template fits, choose the one that matches the primary reason the entry exists and add cross-links to related entries.

## Maintenance And Verification

- For documentation-only changes, read back the edited files and run `git diff --check` when the repository has git metadata.
- Do not run Godot tests for pure Markdown changes unless a change also touches `.gd`, `.tscn`, `.tres`, `project.godot`, imported resources, generated Godot assets, or documentation tooling.
- Before committing, check `git status --short` and stage only the intended documentation files.
- Keep templates synchronized with current project terminology. Update `DOCS.md` when adding a new template category or changing the wiki location contract.
