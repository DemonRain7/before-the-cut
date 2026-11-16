# Synthetic fixture only. This is not a recording of the student's microphone.
# Raw 16 kHz mono PCM goes to stdout; the caller must keep it in memory, not a log.
param([Parameter(Mandatory = $true)][string]$Text)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$stream = New-Object System.IO.MemoryStream
try {
    $synth.SelectVoice('Microsoft Zira Desktop')
    $format = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(
        16000,
        [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,
        [System.Speech.AudioFormat.AudioChannel]::Mono
    )
    $synth.SetOutputToAudioStream($stream, $format)
    $synth.Speak($Text)
    $synth.SetOutputToNull()
    $bytes = $stream.ToArray()
    $stdout = [Console]::OpenStandardOutput()
    $stdout.Write($bytes, 0, $bytes.Length)
    $stdout.Flush()
} finally {
    $synth.Dispose()
    $stream.Dispose()
}
