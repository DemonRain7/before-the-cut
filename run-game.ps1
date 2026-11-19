param(
    [string]$GodotPath = $env:GODOT_BIN,
    [string]$AgentUrl = '',
    [switch]$Model,
    [switch]$LessBlood,
    [switch]$Mute,
    [string]$Seed = '',
    [string]$TestNight = '',
    [switch]$ImportOnly
)

$ErrorActionPreference = 'Stop'
if (-not $GodotPath) {
    $portableGodot = Join-Path $env:LOCALAPPDATA 'CodexTools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
    if (Test-Path -LiteralPath $portableGodot) {
        $GodotPath = $portableGodot
    } else {
        $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
        if ($godotCommand) { $GodotPath = $godotCommand.Source }
    }
}
if (-not $GodotPath) {
    throw 'Godot was not found. Pass -GodotPath with the Godot 4 executable path, or open game/project.godot in Godot.'
}
if ($Model -and -not $AgentUrl) {
    throw 'For model transport, pass -AgentUrl. The default game uses the offline scripted baseline.'
}
if ($Seed -and $Seed -notmatch '^-?\d+$') {
    throw '-Seed takes a whole number.'
}
$gameDir = Join-Path $PSScriptRoot 'game'

# The game loads its pictures, fonts and sounds from Godot's import cache, game/.godot/imported,
# which is not in the repository: in a fresh clone not one of them would load. Each *.import file
# names the files its asset is imported into; the cache is complete when they all exist.
function Get-MissingImports([string]$Dir) {
    $cache = Join-Path $Dir '.godot\imported'
    $missing = 0
    foreach ($file in Get-ChildItem -LiteralPath $Dir -Recurse -File -Filter '*.import') {
        if ($file.FullName -like '*\.godot\*') { continue }
        $line = [regex]::Match([System.IO.File]::ReadAllText($file.FullName), '(?m)^dest_files=\[(.*)\]')
        if (-not $line.Success) { continue }
        foreach ($dest in [regex]::Matches($line.Groups[1].Value, '"res://\.godot/imported/([^"]+)"')) {
            if (-not (Test-Path -LiteralPath (Join-Path $cache $dest.Groups[1].Value))) { $missing++ }
        }
    }
    return $missing
}

# So the first run imports them. Godot 4.7.2's import from an empty cache sometimes crashes partway
# (on November 17, on the last commit as well as on the working tree; see game/README.md, Checks).
# A second import picks up where the first one stopped, so this tries up to three times.
$missing = Get-MissingImports $gameDir
for ($try = 1; $try -le 3 -and $missing -gt 0; $try++) {
    Write-Host "Importing the game's pictures, fonts and sounds: $missing to go (try $try of 3)..."
    $ErrorActionPreference = 'Continue'
    & $GodotPath --headless --path $gameDir --import | Out-Null
    $ErrorActionPreference = 'Stop'
    $missing = Get-MissingImports $gameDir
    if ($missing -eq 0) { Write-Host 'Import complete.' }
}
if ($missing -gt 0) {
    throw "After three imports $missing files are still missing. Open game/project.godot in the Godot editor once, then run this again."
}
if ($ImportOnly) { exit 0 }

# Options for the game itself go after "--" (see the top of game/scripts/ui/main.gd).
$gameOptions = @()
if ($AgentUrl) {
    $gameOptions += "--agent-url=$AgentUrl"
    if ($Model) { $gameOptions += '--model' }
}
if ($LessBlood) { $gameOptions += '--less-blood' }
if ($Mute) { $gameOptions += '--mute' }
if ($Seed) { $gameOptions += "--seed=$Seed" }
# A fixed night of game/data/nights.json every shift; the nights are named by capital letters.
if ($TestNight) { $gameOptions += "--test-night=$($TestNight.ToUpperInvariant())" }
$gameArguments = @('--path', $gameDir)
if ($gameOptions.Count -gt 0) { $gameArguments += @('--') + $gameOptions }
& $GodotPath @gameArguments
exit $LASTEXITCODE
