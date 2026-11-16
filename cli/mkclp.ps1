#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Fast video clip maker supporting local files and YouTube streaming.
.DESCRIPTION
    Cross-platform video clip maker for macOS and Windows 11 (PowerShell 7).
    - Zero-second lossless stream copying (-c/--copy or compatible local MP4)
    - Hardware-accelerated HEVC (hevc_videotoolbox -tag:v hvc1) on macOS (default Quality: 50)
    - Universal libx264 + AAC fallback on Windows/Linux (default Quality: 23)
    - Uses yt-dlp --download-sections with browser cookies (default: chrome) and automatic cookie-less fallback
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$scriptDir = $PSScriptRoot
if ($scriptDir -and $PSCommandPath) {
    $commandInfo = [System.IO.FileInfo]::new($PSCommandPath)
    if ($null -ne $commandInfo.LinkTarget) {
        $scriptDir = Split-Path -Parent (($commandInfo.ResolveLinkTarget($true) ?? $commandInfo).FullName)
    }
}
elseif (-not $scriptDir) {
    $entryPath = [Environment]::GetCommandLineArgs() |
        Select-Object -Skip 1 |
        Where-Object { $_ -and (-not $_.StartsWith('-')) -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -First 1
    if (-not $entryPath) {
        throw 'Unable to determine script path.'
    }
    $entryInfo = [System.IO.FileInfo]::new((Resolve-Path -LiteralPath $entryPath).Path)
    $scriptDir = Split-Path -Parent (($entryInfo.ResolveLinkTarget($true) ?? $entryInfo).FullName)
}
Import-Module -Name (Join-Path $scriptDir 'helpers' 'CliCommon.psm1') -Force
Import-Module -Name (Join-Path $scriptDir 'helpers' 'MediaCommon.psm1') -Force

function Show-Help {
    Write-Output @"
mkclp: Clip Maker (Supports --quality [value], --copy, --browser, local files and YouTube videos)
Usage: mkclp [options] [input_file_or_url] [from(hh:mm:ss or sec)] [during(sec)]
Options:
  -q, --quality <num>   Set video quality factor (default: 50 on macOS HEVC, 23 on Windows x264)
  -c, --copy            Force lossless stream copy without re-encoding
  -b, --browser <name>  Browser for YouTube cookies (default: chrome, or `$env:YT_DLP_BROWSER)
  -o, --output <file>   Custom output file path
  -h, --help            Show this help message
Examples:
  mkclp 'input.mp4' 01:02:08 11.0
  mkclp 'input.mp4' 00:00:10 5.0 --copy
  mkclp JoSY6AWKqHs 00:01:59 2 --quality 45
"@
}

$Quality = $null
$Copy = $false
$Browser = ''
$Output = ''
$Help = $false
$positionals = [System.Collections.Generic.List[string]]::new()

for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = [string]$args[$i]
    if ($arg -match '^--?h(elp)?$') {
        $Help = $true
    }
    elseif ($arg -match '^--?q(uality)?$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --quality requires a value')
            exit 1
        }
        try {
            $Quality = ConvertTo-ValidatedInt -Value ([string]$args[++$i]) -OptionName '--quality' -MinValue 0 -MaxValue 100
        }
        catch [System.ArgumentException] {
            [Console]::Error.WriteLine("Error: $($_.Exception.Message)")
            exit 1
        }
    }
    elseif ($arg -match '^--?c(opy)?$') {
        $Copy = $true
    }
    elseif ($arg -match '^--?b(rowser)?$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --browser requires a browser name')
            exit 1
        }
        $Browser = [string]$args[++$i]
    }
    elseif ($arg -match '^--?o(utput)?$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --output requires a file path')
            exit 1
        }
        $Output = [string]$args[++$i]
    }
    elseif ($arg.StartsWith('-')) {
        [Console]::Error.WriteLine("Error: Unknown option $arg")
        Show-Help
        exit 1
    }
    else {
        $positionals.Add($arg)
    }
}

if ($Help) {
    Show-Help
    exit 0
}

if ($positionals.Count -ge 4 -and $positionals[0] -match '^mkclp(\.ps1)?$') {
    $positionals.RemoveAt(0)
}

if ($positionals.Count -lt 3) {
    Show-Help | ForEach-Object { [Console]::Error.WriteLine($_) }
    exit 1
}

if ($positionals.Count -gt 3) {
    [Console]::Error.WriteLine("Error: Unexpected argument $($positionals[3])")
    Show-Help
    exit 1
}

$InputFile = $positionals[0]
$Start = $positionals[1]
$Duration = $positionals[2]

try {
    $startSec = Convert-TimeToSecond -TimeText $Start
    $durSec = Convert-TimeToSecond -TimeText $Duration -PositiveOnly
}
catch [System.ArgumentException] {
    [Console]::Error.WriteLine("Error: $($_.Exception.Message)")
    exit 1
}

$qualityExplicitlySet = ($null -ne $Quality)
$effectiveQuality = $qualityExplicitlySet ? [int]$Quality : ($IsMacOS ? 50 : 23)

Import-WindowsMachinePath

if (-not (Test-RequiredCommand -Name 'ffmpeg', 'ffprobe')) {
    exit 1
}

$isLocal = Test-Path -LiteralPath $InputFile -PathType Leaf
$inputSource = $InputFile
$ffmpegStart = $Start
$tempSegment = $null

try {
    if (-not $isLocal) {
        if (-not (Test-RequiredCommand -Name 'yt-dlp')) {
            [Console]::Error.WriteLine("Error: File $InputFile does not exist and yt-dlp is required")
            exit 1
        }

        $endSec = $startSec + $durSec
        $ytFormat = 'bestvideo[height<=1080]+bestaudio/best[height<=1080]'
        $tempSegment = Invoke-YtDlpSegment `
            -InputSource $InputFile `
            -StartSecond $startSec `
            -EndSecond $endSec `
            -Format $ytFormat `
            -Browser $Browser `
            -ForceKeyframesAtCuts
        $inputSource = $tempSegment.FilePath
        $ffmpegStart = '0'
    }

    $ffmpegInputs = @('-ss', $ffmpegStart, '-i', $inputSource)
    $mapArgs = @('-map', '0:v:0', '-map', '0:a?')
    $vcArgs = @()

    $probeFormat = ''
    $probeCodec = ''
    $probeRaw = (& ffprobe -v error -select_streams v:0 -show_entries stream=codec_name:format=format_name -of json $inputSource 2>$null) -join "`n"
    if ($LASTEXITCODE -eq 0 -and (-not [string]::IsNullOrWhiteSpace($probeRaw))) {
        $probeObj = $probeRaw | ConvertFrom-Json
        if ($null -ne $probeObj.format -and $null -ne $probeObj.format.format_name) {
            $probeFormat = [string]$probeObj.format.format_name
        }
        if ($null -ne $probeObj.streams -and @($probeObj.streams).Count -gt 0) {
            $probeCodec = ([string]$probeObj.streams[0].codec_name).Trim()
        }
    }

    if ($Copy -or ($isLocal -and ($probeFormat -match 'mp4') -and ($probeCodec -in @('h264', 'hevc')) -and (-not $qualityExplicitlySet))) {
        $vcArgs = @('-c:v', 'copy', '-c:a', 'copy')
    }
    elseif ($IsMacOS) {
        $vcArgs = @(
            '-c:v', 'hevc_videotoolbox',
            '-q:v', "$effectiveQuality",
            '-profile:v', 'main',
            '-pix_fmt', 'yuv420p',
            '-tag:v', 'hvc1',
            '-c:a', 'aac',
            '-b:a', '192k'
        )
    }
    else {
        $vcArgs = @(
            '-c:v', 'libx264',
            '-crf', "$effectiveQuality",
            '-preset', 'fast',
            '-pix_fmt', 'yuv420p',
            '-c:a', 'aac',
            '-b:a', '192k'
        )
    }

    $outputFile = $Output ? $Output : ((Get-Date -Format 'yyyyMMddHHmmss') + '_clip.mp4')

    & ffmpeg -y -hide_banner `
        -loglevel error `
        @ffmpegInputs `
        -t $Duration `
        @mapArgs `
        @vcArgs `
        -map_chapters -1 `
        -movflags +faststart `
        $outputFile

    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("Error: ffmpeg failed with exit code $LASTEXITCODE")
        exit $LASTEXITCODE
    }

    if (Test-Path -LiteralPath $outputFile -PathType Leaf) {
        $size = (Get-Item -LiteralPath $outputFile).Length
        $readableSize = Format-ByteSize -ByteCount $size
        Write-Output "$outputFile $readableSize"
    }
}
finally {
    if ($null -ne $tempSegment -and (Test-Path -LiteralPath $tempSegment.TempDir)) {
        Remove-Item -LiteralPath $tempSegment.TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
