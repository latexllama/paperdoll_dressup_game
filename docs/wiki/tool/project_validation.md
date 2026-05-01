# Project Validation

## Status

Implemented as local workflow configuration plus GUT and Godot commands.

## Godot Executable

`res://.godot-workflow.json` records the local Godot executable path:

```powershell
G:\BIN\Godot_v4.6.1-stable_win64.exe
```

The helper scripts from the Godot workflow plugin and `res://tools/RunGut.ps1` use this path before falling back to environment variables.

## GUT

`res://.gutconfig.json` runs all PascalCase GUT scripts under `res://tests/gut/`.

Run the full suite with:

```powershell
tools\RunGut.ps1
```

## Headless Load

Run a project load check with:

```powershell
& 'G:\BIN\Godot_v4.6.1-stable_win64.exe' --headless --path 'D:\DEV\GAME\godot_projects\KisekaeDressupGame' --quit
```

## Resource Audit

Run:

```powershell
py -3 C:\Users\cfing\plugins\godot-engine-workflow\scripts\godot_resource_audit.py --project .
```

The current audit reports known third-party GUT addon `res://` false positives. Treat new non-`addons/gut` issues as project defects.

## Export Presets

No `export_presets.cfg` is currently authored because Godot 4.6.1 export templates were not installed under the user Godot template folders during this pass. After templates are installed, create a Windows Desktop preset in the Godot editor and rerun headless load plus resource audit.
