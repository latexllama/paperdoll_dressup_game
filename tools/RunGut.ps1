param(
    [string]$GodotExecutable = "",
    [string]$ProjectPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

if ([string]::IsNullOrWhiteSpace($GodotExecutable)) {
    $workflowPath = Join-Path $ProjectPath ".godot-workflow.json"
    if (Test-Path $workflowPath) {
        $workflow = Get-Content -Raw $workflowPath | ConvertFrom-Json
        $GodotExecutable = [string]$workflow.godot_executable
    }
}

if ([string]::IsNullOrWhiteSpace($GodotExecutable)) {
    $GodotExecutable = [Environment]::GetEnvironmentVariable("GODOT_EXECUTABLE")
}

if ([string]::IsNullOrWhiteSpace($GodotExecutable) -or -not (Test-Path $GodotExecutable)) {
    throw "Godot executable was not found. Set GODOT_EXECUTABLE or update .godot-workflow.json."
}

& $GodotExecutable --headless --path $ProjectPath --script res://addons/gut/gut_cmdln.gd -gexit -gdisable_colors
