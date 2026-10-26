param(
    [string]$Godot = "godot"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$tests = @(
    "res://tests/powerup_test.gd",
    "res://tests/world_test.gd",
    "res://tests/scene_smoke_test.gd"
)

foreach ($test in $tests) {
    Write-Host "`n=== $test ==="
    & $Godot --headless --path $projectRoot --script $test
    if ($LASTEXITCODE -ne 0) {
        throw "Test failed: $test"
    }
}

Write-Host "`nAll tests passed."
