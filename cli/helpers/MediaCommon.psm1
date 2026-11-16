Set-StrictMode -Version Latest

function Resolve-YtDlpBrowser {
    param(
        [string]$Browser = '',
        [string]$EnvBrowser = $env:YT_DLP_BROWSER
    )

    if (-not [string]::IsNullOrWhiteSpace($Browser)) {
        return $Browser.Trim()
    }
    if (-not [string]::IsNullOrWhiteSpace($EnvBrowser)) {
        return $EnvBrowser.Trim()
    }
    return 'chrome'
}

function Invoke-YtDlpSegment {
    param(
        [Parameter(Mandatory)]
        [string]$InputSource,
        [Parameter(Mandatory)]
        [double]$StartSecond,
        [Parameter(Mandatory)]
        [double]$EndSecond,
        [Parameter(Mandatory)]
        [string]$Format,
        [string]$Browser = '',
        [switch]$ForceKeyframesAtCuts
    )

    $targetBrowser = Resolve-YtDlpBrowser -Browser $Browser
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('yt_seg_' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    $outputTemplate = Join-Path $tempDir 'segment.%(ext)s'
    $commonArgs = @(
        '--quiet',
        '--no-warnings',
        '--force-overwrites',
        '--no-playlist',
        '--download-sections', "*${StartSecond}-${EndSecond}"
    )
    if ($ForceKeyframesAtCuts) {
        $commonArgs += '--force-keyframes-at-cuts'
    }
    $commonArgs += @('-f', $Format, '-o', $outputTemplate)

    try {
        # Try with browser cookies first, then fall back without cookies if unavailable.
        & yt-dlp --cookies-from-browser $targetBrowser @commonArgs $InputSource 2>$null
        $downloaded = @(
            Get-ChildItem -LiteralPath $tempDir -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -notin @('.part', '.ytdl') } |
                Select-Object -First 1
        )

        if ($LASTEXITCODE -ne 0 -or $downloaded.Count -eq 0) {
            Get-ChildItem -LiteralPath $tempDir -File -ErrorAction SilentlyContinue |
                ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
            & yt-dlp @commonArgs $InputSource
            $downloaded = @(
                Get-ChildItem -LiteralPath $tempDir -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Extension -notin @('.part', '.ytdl') } |
                    Select-Object -First 1
            )
            if ($LASTEXITCODE -ne 0 -or $downloaded.Count -eq 0) {
                throw [System.InvalidOperationException]::new("Failed to download YouTube video segment for input: $InputSource")
            }
        }

        return [PSCustomObject]@{
            TempDir  = $tempDir
            FilePath = $downloaded[0].FullName
        }
    }
    catch {
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

Export-ModuleMember -Function @(
    'Invoke-YtDlpSegment',
    'Resolve-YtDlpBrowser'
)
