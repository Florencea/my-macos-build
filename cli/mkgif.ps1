#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    High-quality GIF maker supporting local video files and YouTube streaming.
.DESCRIPTION
    Cross-platform GIF maker for macOS and Windows 11 (PowerShell 7).
    - Generates high-quality animated GIFs from local videos or YouTube URLs
    - Uses yt-dlp --download-sections with browser cookies (default: chrome) and cookie-less fallback
    - Uses gifski via PowerShell 7.4+ native byte-stream pipe (yuv4mpegpipe), or FFmpeg 256-color diff palette + Bayer dithering fallback
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

function Show-Help {
    Write-Output @"
mkgif: High-quality Gif Maker via gifski / FFmpeg palette
Usage: mkgif [-w 720] [--fps 10] [-q 70] [-l] [input_file_or_url] [from(hh:mm:ss or sec)] [during(sec)]
Options:
  -w, --width <num>     Output gif width in pixels (default: 720)
  --fps <num>           Frame rate per second (default: 10)
  -q, --quality <num>   Gifski encoding quality 1-100 (default: 70)
  -l, --lossy           Enable lossy optimization
  -b, --browser <name>  Browser for YouTube cookies (default: chrome, or `$env:YT_DLP_BROWSER)
  -o, --output <file>   Custom output file path
  -h, --help            Show this help message
Examples:
  mkgif 'input.mp4' 01:02:08 11.0
  mkgif JoSY6AWKqHs 00:01:59 20 --fps 10 -w 720
"@
}

$Width = 720
$Fps = 10
$Quality = 70
$Lossy = $false
$Browser = ''
$Output = ''
$Help = $false
$positionals = [System.Collections.Generic.List[string]]::new()

for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = [string]$args[$i]
    if ($arg -match '^--?h(elp)?$') {
        $Help = $true
    }
    elseif ($arg -match '^--?fps$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --fps requires a value')
            exit 1
        }
        try {
            $Fps = ConvertTo-ValidatedInt -Value ([string]$args[++$i]) -OptionName '--fps' -MinValue 1 -MaxValue 60
        }
        catch [System.ArgumentException] {
            [Console]::Error.WriteLine("Error: $($_.Exception.Message)")
            exit 1
        }
    }
    elseif ($arg -match '^--?w(idth)?$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: -w/--width requires a value')
            exit 1
        }
        try {
            $Width = ConvertTo-ValidatedInt -Value ([string]$args[++$i]) -OptionName '--width' -MinValue 16 -MaxValue 7680
        }
        catch [System.ArgumentException] {
            [Console]::Error.WriteLine("Error: $($_.Exception.Message)")
            exit 1
        }
    }
    elseif ($arg -match '^--?q(uality)?$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: -q/--quality requires a value')
            exit 1
        }
        try {
            $Quality = ConvertTo-ValidatedInt -Value ([string]$args[++$i]) -OptionName '--quality' -MinValue 1 -MaxValue 100
        }
        catch [System.ArgumentException] {
            [Console]::Error.WriteLine("Error: $($_.Exception.Message)")
            exit 1
        }
    }
    elseif ($arg -match '^--?l(ossy)?$') {
        $Lossy = $true
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
            [Console]::Error.WriteLine('Error: -o/--output requires a file path')
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

if ($positionals.Count -ge 4 -and $positionals[0] -match '^mkgif(\.ps1)?$') {
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

Import-WindowsMachinePath

if (-not (Test-RequiredCommand -Name 'ffmpeg')) {
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
        $ytHeight = ($Width -le 480) ? 480 : (($Width -le 720) ? 720 : (($Width -le 1280) ? 1080 : 2160))
        $ytFormat = "bestvideo[height<=$ytHeight]/best[height<=$ytHeight]/bestvideo/best"

        $tempSegment = Invoke-YtDlpSegment `
            -InputSource $InputFile `
            -StartSecond $startSec `
            -EndSecond $endSec `
            -Format $ytFormat `
            -Browser $Browser
        $inputSource = $tempSegment.FilePath
        $ffmpegStart = '0'
    }

    $outputFile = $Output ? $Output : ((Get-Date -Format 'yyyyMMddHHmmss') + "_fps${Fps}.gif")

    # Detect CLI-capable gifski binary (Windows GUI subsystem binaries cannot accept piped stdin)
    $gifskiCmd = Get-Command 'gifski' -ErrorAction SilentlyContinue
    $hasGifskiCli = $false

    if ($gifskiCmd) {
        if ($IsWindows) {
            try {
                $fs = [System.IO.File]::OpenRead($gifskiCmd.Source)
                try {
                    $headerBuf = [byte[]]::new(4096)
                    $bytesRead = $fs.Read($headerBuf, 0, $headerBuf.Length)
                    if ($bytesRead -ge 0x40) {
                        $peOffset = [BitConverter]::ToInt32($headerBuf, 0x3C)
                        if (($peOffset + 0x5E) -le $bytesRead) {
                            $subsystem = [BitConverter]::ToUInt16($headerBuf, $peOffset + 0x5C)
                            if ($subsystem -eq 3) {
                                $hasGifskiCli = $true
                            }
                        }
                    }
                }
                finally {
                    $fs.Dispose()
                }
            }
            catch {
                Write-Verbose "PE header inspection skipped for gifski: $($_.Exception.Message)"
            }
        }
        else {
            $hasGifskiCli = $true
        }
    }

    if ($hasGifskiCli) {
        $gifskiArgs = @('-q', '-Q', "$Quality", '-W', "$Width")
        if ($Lossy) {
            $gifskiArgs += @('--lossy-quality', '75')
        }
        $gifskiArgs += @('-o', $outputFile, '-')

        # PowerShell 7.4+ preserves raw byte streams when piping between native commands
        & ffmpeg -y -hide_banner `
            -loglevel error `
            -ss $ffmpegStart `
            -i $inputSource `
            -t $Duration `
            -vf "fps=$Fps,scale=${Width}:-2:flags=lanczos,format=yuv420p" `
            -f yuv4mpegpipe - | & gifski @gifskiArgs
    }
    else {
        & ffmpeg -y -hide_banner -loglevel error `
            -ss $ffmpegStart `
            -i $inputSource `
            -t $Duration `
            -filter_complex "[0:v] fps=$Fps,scale=${Width}:-1:flags=lanczos,split [a][b];[a] palettegen=max_colors=256:stats_mode=diff [p];[b][p] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" `
            $outputFile
    }

    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("Error: GIF generation failed with exit code $LASTEXITCODE")
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
