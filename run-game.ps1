param(
    [string]$GodotPath = $env:GODOT_BIN,
    [string]$AgentUrl = '',
    [switch]$Model,
    [switch]$LessBlood,
    [switch]$Mute,
    [string]$Seed = '',
    [string]$TestNight = '',
    [switch]$ImportOnly,
    [string]$Patient = 'script',
    [switch]$CheckPatient
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
$patientChosen = $PSBoundParameters.ContainsKey('Patient')
if ($patientChosen -and ($Model -or $AgentUrl)) {
    throw 'Use -Patient by itself, or use the original -Model -AgentUrl pair.'
}
if ($Model -and -not $AgentUrl) { throw 'For -Model, pass -AgentUrl.' }
if ($CheckPatient -and $Patient -notin @('mock', 'timeout')) { throw '-CheckPatient takes -Patient mock or timeout.' }
if ($Patient -notin @('script', 'mock', 'timeout', 'live')) {
    $address = $null
    if (-not [Uri]::TryCreate($Patient, [UriKind]::Absolute, [ref]$address) -or
        $address.Scheme -notin @('http', 'https') -or $address.UserInfo -or $address.Query -or $address.Fragment) {
        throw '-Patient takes script, mock, timeout, live or an HTTP(S) service address.'
    }
    $AgentUrl = $address.AbsoluteUri.TrimEnd('/')
    $Model = $true
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

# A child server binds a free port itself. Only its environment changes.
$proxyProcess = $null
$readyFile = $null
try {
    if ($Patient -in @('mock', 'timeout', 'live')) {
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = (Get-Command node -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
        $info.WorkingDirectory = Join-Path $PSScriptRoot 'agent_proxy'
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.Arguments = 'src/dev_server.mjs'
        $info.EnvironmentVariables['BTC_HOST'] = '127.0.0.1'
        $info.EnvironmentVariables['BTC_PORT'] = '0'
        if ($Patient -eq 'live') {
            $limits = (Get-Content -LiteralPath (Join-Path $gameDir 'data/rules.json') -Raw -Encoding UTF8 | ConvertFrom-Json).agent
            Write-Host "Live patient dialogue and microphone transcription cost money. The process cap is $($limits.max_provider_calls_per_process) provider calls."
            if ((Read-Host 'Type LIVE to start the paid local service') -cne 'LIVE') { throw 'Live launch cancelled.' }
            $info.Arguments = '--env-file-if-exists=.dev.vars src/dev_server.mjs'
        } else {
            $info.EnvironmentVariables['BTC_PROVIDER'] = 'mock'
            $info.EnvironmentVariables['BTC_MOCK_FAIL'] = if ($Patient -eq 'timeout') { 'timeout' } else { '' }
        }
        $readyFile = [IO.Path]::GetTempFileName()
        $info.EnvironmentVariables['BTC_READY_FILE'] = $readyFile
        $proxyProcess = [Diagnostics.Process]::Start($info)
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $port = 0
        while ($port -eq 0 -and $watch.Elapsed.TotalSeconds -lt 10) {
            if ($proxyProcess.HasExited) { throw 'Patient service stopped during startup.' }
            [void][int]::TryParse([IO.File]::ReadAllText($readyFile), [ref]$port)
            if ($port -eq 0) { Start-Sleep -Milliseconds 50 }
        }
        if ($port -eq 0) { throw 'Patient service did not start in time.' }
        $AgentUrl = "http://127.0.0.1:$port"
        $health = Invoke-RestMethod -Uri "$AgentUrl/healthz" -TimeoutSec 2
        $expectsMock = $Patient -ne 'live'
        if ($health.protocol -ne '3' -or $health.disabled -or ($health.provider -eq 'mock') -ne $expectsMock) {
            throw 'Patient service health does not match the requested mode.'
        }
        $Model = $true
    }
    $gameOptions = @()
    if ($AgentUrl) { $gameOptions += "--agent-url=$AgentUrl" }
    if ($Model) { $gameOptions += '--model' }
    if ($patientChosen -and $Patient -eq 'script') { $gameOptions += '--script-patient' }
    if ($LessBlood) { $gameOptions += '--less-blood' }
    if ($Mute) { $gameOptions += '--mute' }
    if ($Seed) { $gameOptions += "--seed=$Seed" }
    if ($TestNight) { $gameOptions += "--test-night=$($TestNight.ToUpperInvariant())" }
    $gameArguments = @('--path', $gameDir)
    if ($CheckPatient) {
        $gameArguments += @('--headless', '--audio-driver', 'Dummy', '--script', 'res://tests/run_proxy_integration.gd')
        $gameOptions += @("--launch-check=$($Patient.ToLowerInvariant())", '--mute', '--no-surprises', '--test-night=A')
    }
    if ($gameOptions.Count -gt 0) { $gameArguments += @('--') + $gameOptions }
    & $GodotPath @gameArguments
    $gameExit = $LASTEXITCODE
} finally {
    if ($proxyProcess) {
        if (-not $proxyProcess.HasExited) { $proxyProcess.Kill(); $proxyProcess.WaitForExit() }
        $proxyProcess.Dispose()
    }
    if ($readyFile) { Remove-Item -LiteralPath $readyFile -ErrorAction SilentlyContinue }
}
exit $gameExit
