param(
  [ValidateSet("v2", "v4_realistic", "v4_simplified")]
  [string] $Profile = "v4_simplified"
)

$ErrorActionPreference = "Stop"

$gameRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $gameRoot "scripts\solar_survivor_root.gd"

if (!(Test-Path -LiteralPath $scriptPath)) {
  throw "Cannot find Godot script: $scriptPath"
}

$content = [System.IO.File]::ReadAllText($scriptPath, [System.Text.Encoding]::UTF8)
$updated = [System.Text.RegularExpressions.Regex]::Replace(
  $content,
  'const ENEMY_ASSET_PROFILE := "[^"]+"',
  "const ENEMY_ASSET_PROFILE := `"$Profile`"",
  1
)

if ($updated -eq $content) {
  throw "ENEMY_ASSET_PROFILE was not found in $scriptPath"
}

[System.IO.File]::WriteAllText($scriptPath, $updated, [System.Text.Encoding]::UTF8)
Write-Output "Solar Survivor enemy asset profile set to '$Profile'."
