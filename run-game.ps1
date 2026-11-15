param(
    [string]$GodotPath = $env:GODOT_BIN,
    [string]$AgentUrl = '',
    [switch]$Model,
    [switch]$LessBlood,
    [switch]$Mute,
    [string]$Seed = ''
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
# Options for the game itself go after "--" (see the top of game/scripts/ui/main.gd).
$gameOptions = @()
if ($AgentUrl) {
    $gameOptions += "--agent-url=$AgentUrl"
    if ($Model) { $gameOptions += '--model' }
}
if ($LessBlood) { $gameOptions += '--less-blood' }
if ($Mute) { $gameOptions += '--mute' }
if ($Seed) { $gameOptions += "--seed=$Seed" }
$gameArguments = @('--path', (Join-Path $PSScriptRoot 'game'))
if ($gameOptions.Count -gt 0) { $gameArguments += @('--') + $gameOptions }
& $GodotPath @gameArguments
exit $LASTEXITCODE
