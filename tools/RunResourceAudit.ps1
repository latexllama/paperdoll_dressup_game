param(
    [string]$ProjectPath = "",
    [string]$AuditScript = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

if ([string]::IsNullOrWhiteSpace($AuditScript)) {
    $candidates = @(
        "C:\Users\cfing\plugins\godot-engine-workflow\scripts\godot_resource_audit.py",
        "C:\Users\cfing\.codex\plugins\cache\cfing-local\godot-engine-workflow\0.1.0\scripts\godot_resource_audit.py"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $AuditScript = $candidate
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($AuditScript) -or -not (Test-Path $AuditScript)) {
    throw "Godot resource audit script was not found. Pass -AuditScript with the godot_resource_audit.py path."
}

$auditOutput = & py -3 $AuditScript --project $ProjectPath
if ($LASTEXITCODE -ne 0) {
    throw "Resource audit failed to run."
}

$audit = $auditOutput | ConvertFrom-Json
$projectIssues = @(
    $audit.issues | Where-Object {
        $issuePath = ([string]$_.path).Replace("/", "\")
        -not $issuePath.StartsWith("addons\gut\")
    }
)

if ($projectIssues.Count -gt 0) {
    Write-Error ("Resource audit found {0} project issue(s) outside addons\gut: {1}" -f $projectIssues.Count, ($projectIssues | ConvertTo-Json -Depth 8))
}

$auditOutput
