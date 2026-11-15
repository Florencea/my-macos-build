Set-StrictMode -Version Latest

function Resolve-CliScriptDirectory {
    param(
        [string]$ScriptRoot = '',
        [string]$CommandPath = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($ScriptRoot)) {
        return $ScriptRoot
    }

    $targetPath = $CommandPath
    if ([string]::IsNullOrWhiteSpace($targetPath)) {
        $cmdArgs = [Environment]::GetCommandLineArgs()
        for ($i = 1; $i -lt $cmdArgs.Count; $i++) {
            $candidate = [string]$cmdArgs[$i]
            if ($candidate -and (-not $candidate.StartsWith('-')) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                $targetPath = $candidate
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($targetPath)) {
        throw [System.InvalidOperationException]::new('Unable to determine script path.')
    }

    $resolvedPath = (Resolve-Path -LiteralPath $targetPath).Path
    $fileInfo = [System.IO.FileInfo]::new($resolvedPath)
    $targetInfo = $fileInfo.ResolveLinkTarget($true)
    $realPath = ($null -ne $targetInfo) ? $targetInfo.FullName : $fileInfo.FullName
    return (Split-Path -Parent $realPath)
}

function Test-RequiredCommand {
    param(
        [Parameter(Mandatory)]
        [string[]]$Name,
        [switch]$Quiet
    )

    $allAvailable = $true
    foreach ($cmd in $Name) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            if (-not $Quiet) {
                [Console]::Error.WriteLine("Error: $cmd is not installed")
            }
            $allAvailable = $false
        }
    }
    return $allAvailable
}

function Convert-TimeToSecond {
    param(
        [Parameter(Mandatory)]
        [string]$TimeText,
        [switch]$PositiveOnly
    )

    $trimmed = $TimeText.Trim()
    $seconds = 0.0
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $styles = [System.Globalization.NumberStyles]::Float

    if ($trimmed -match '^(\d+):(\d{2}):(\d{2}(?:\.\d+)?)$') {
        $hours = [double]::Parse($Matches[1], $culture)
        $minutes = [double]::Parse($Matches[2], $culture)
        $secs = [double]::Parse($Matches[3], $culture)
        if ($minutes -ge 60 -or $secs -ge 60) {
            throw [System.ArgumentException]::new("Invalid time value '$TimeText' (minutes/seconds must be < 60).")
        }
        $seconds = ($hours * 3600) + ($minutes * 60) + $secs
    }
    elseif ($trimmed -match '^(\d+):(\d{2}(?:\.\d+)?)$') {
        $minutes = [double]::Parse($Matches[1], $culture)
        $secs = [double]::Parse($Matches[2], $culture)
        if ($secs -ge 60) {
            throw [System.ArgumentException]::new("Invalid time value '$TimeText' (seconds must be < 60).")
        }
        $seconds = ($minutes * 60) + $secs
    }
    elseif (-not [double]::TryParse($trimmed, $styles, $culture, [ref]$seconds)) {
        throw [System.ArgumentException]::new("Invalid time value '$TimeText' (expected HH:MM:SS, MM:SS, or seconds).")
    }

    if ([double]::IsNaN($seconds) -or [double]::IsInfinity($seconds) -or ($seconds -lt 0)) {
        throw [System.ArgumentException]::new("Time value '$TimeText' must be a finite non-negative number.")
    }
    if ($PositiveOnly -and ($seconds -le 0)) {
        throw [System.ArgumentException]::new("Duration '$TimeText' must be greater than zero.")
    }

    return $seconds
}

function ConvertTo-ValidatedInt {
    param(
        [Parameter(Mandatory)]
        [string]$Value,
        [Parameter(Mandatory)]
        [string]$OptionName,
        [int]$MinValue = [int]::MinValue,
        [int]$MaxValue = [int]::MaxValue
    )

    $parsed = 0
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if (-not [int]::TryParse($Value.Trim(), [System.Globalization.NumberStyles]::Integer, $culture, [ref]$parsed)) {
        throw [System.ArgumentException]::new("Invalid integer for ${OptionName}: '$Value'")
    }
    if ($parsed -lt $MinValue -or $parsed -gt $MaxValue) {
        throw [System.ArgumentException]::new("Value for $OptionName must be between $MinValue and $MaxValue (got $parsed).")
    }

    return $parsed
}

function Format-ByteSize {
    param(
        [Parameter(Mandatory)]
        [long]$ByteCount
    )

    if ($ByteCount -ge 1GB) {
        return ('{0:N1}G' -f ($ByteCount / 1GB))
    }
    if ($ByteCount -ge 1MB) {
        return ('{0:N1}M' -f ($ByteCount / 1MB))
    }
    return ('{0:N0}K' -f ($ByteCount / 1KB))
}

function Import-WindowsMachinePath {
    if (-not $IsWindows) {
        return
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $entries = [System.Collections.Generic.List[string]]::new()

    $rawSources = @(
        $env:PATH,
        [Environment]::GetEnvironmentVariable('Path', 'User'),
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
    )

    foreach ($raw in $rawSources) {
        if ([string]::IsNullOrWhiteSpace($raw)) {
            continue
        }
        foreach ($segment in ($raw -split ';')) {
            $trimmed = $segment.Trim()
            if ($trimmed -and $seen.Add($trimmed)) {
                $entries.Add($trimmed)
            }
        }
    }

    $env:PATH = $entries -join ';'
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

    $targetBrowser = $Browser ? $Browser : ($env:YT_DLP_BROWSER ? $env:YT_DLP_BROWSER : 'edge')
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

function Resolve-PlaywrightSyncStep {
    param(
        [Parameter(Mandatory)]
        [hashtable]$PackageJson,
        [string]$ProjectRoot = '.'
    )

    $scriptsMap = ($PackageJson['scripts'] -is [hashtable]) ? $PackageJson['scripts'] : @{}
    $depSections = @(
        (($PackageJson['dependencies'] -is [hashtable]) ? $PackageJson['dependencies'] : @{}),
        (($PackageJson['devDependencies'] -is [hashtable]) ? $PackageJson['devDependencies'] : @{}),
        (($PackageJson['optionalDependencies'] -is [hashtable]) ? $PackageJson['optionalDependencies'] : @{}),
        (($PackageJson['peerDependencies'] -is [hashtable]) ? $PackageJson['peerDependencies'] : @{})
    )

    $hasFullPlaywrightDep = $false
    $hasCoreOnlyDep = $false
    foreach ($section in $depSections) {
        foreach ($pkgName in @('playwright', '@playwright/test', '@vitest/browser-playwright')) {
            if ($section.ContainsKey($pkgName)) {
                $hasFullPlaywrightDep = $true
            }
        }
        if ($section.ContainsKey('playwright-core')) {
            $hasCoreOnlyDep = $true
        }
    }

    $binDir = Join-Path $ProjectRoot 'node_modules' '.bin'
    $hasPlaywrightBin = $false
    foreach ($binName in @('playwright', 'playwright.cmd', 'playwright.ps1')) {
        if (Test-Path -LiteralPath (Join-Path $binDir $binName) -PathType Leaf) {
            $hasPlaywrightBin = $true
            break
        }
    }

    $hasCoreBin = $false
    foreach ($binName in @('playwright-core', 'playwright-core.cmd', 'playwright-core.ps1')) {
        if (Test-Path -LiteralPath (Join-Path $binDir $binName) -PathType Leaf) {
            $hasCoreBin = $true
            break
        }
    }

    $hasAnyPlaywright = $hasFullPlaywrightDep -or $hasCoreOnlyDep -or $hasPlaywrightBin -or $hasCoreBin

    if ($scriptsMap.ContainsKey('test:setup')) {
        $setupCmd = [string]$scriptsMap['test:setup']
        if ($hasAnyPlaywright -or ($setupCmd -match '\bplaywright\b')) {
            return [PSCustomObject]@{
                Exe       = 'vpr'
                Arguments = @('--no-cache', 'test:setup')
                StepLabel = 'vpr --no-cache test:setup'
            }
        }
    }

    if ($hasFullPlaywrightDep -or $hasPlaywrightBin) {
        return [PSCustomObject]@{
            Exe       = 'vp'
            Arguments = @('exec', 'playwright', 'install', 'chromium', '--no-progress')
            StepLabel = 'vp exec playwright install chromium'
        }
    }

    if ($hasCoreOnlyDep -or $hasCoreBin) {
        return [PSCustomObject]@{
            Exe       = 'vp'
            Arguments = @('exec', 'playwright-core', 'install', 'chromium', '--no-progress')
            StepLabel = 'vp exec playwright-core install chromium'
        }
    }

    return $null
}

function Resolve-ProjectVerifyStep {
    param(
        [Parameter(Mandatory)]
        [hashtable]$ScriptsMap
    )

    $steps = [System.Collections.Generic.List[pscustomobject]]::new()
    if ($ScriptsMap.ContainsKey('agent:verify:gate')) {
        $steps.Add([PSCustomObject]@{
                Exe       = 'vpr'
                Arguments = @('agent:verify:gate')
                Message   = 'Verifying gate (unit, build, e2e)'
                StepLabel = 'vpr agent:verify:gate (gate)'
            })
        return @($steps)
    }

    foreach ($s in @('agent:verify:unit', 'agent:test:unit', 'test:unit')) {
        if ($ScriptsMap.ContainsKey($s)) {
            $steps.Add([PSCustomObject]@{
                    Exe       = 'vpr'
                    Arguments = @($s)
                    Message   = 'Verifying unit tests'
                    StepLabel = "vpr $s (unit-test)"
                })
            break
        }
    }

    $e2eScript = ''
    foreach ($s in @('agent:test:e2e', 'test:e2e')) {
        if ($ScriptsMap.ContainsKey($s)) {
            $e2eScript = $s
            break
        }
    }

    if ($e2eScript) {
        foreach ($b in @('build:all', 'build')) {
            if ($ScriptsMap.ContainsKey($b)) {
                $steps.Add([PSCustomObject]@{
                        Exe       = 'vpr'
                        Arguments = @($b)
                        Message   = 'Building project for E2E'
                        StepLabel = "vpr $b (build)"
                    })
                break
            }
        }

        $steps.Add([PSCustomObject]@{
                Exe       = 'vpr'
                Arguments = @($e2eScript)
                Message   = 'Verifying E2E tests'
                StepLabel = "vpr $e2eScript (e2e-test)"
            })
    }

    return @($steps)
}

function Test-WorkspaceNodeSyncTarget {
    param(
        [Parameter(Mandatory)]
        [string]$RepoPath,
        [bool]$PullUpdated = $false
    )

    if (-not (Test-Path -LiteralPath (Join-Path $RepoPath 'package.json') -PathType Leaf)) {
        return $false
    }

    $hasLockfile = $false
    foreach ($lockfile in @('pnpm-lock.yaml', 'package-lock.json', 'npm-shrinkwrap.json', 'yarn.lock', 'bun.lock', 'bun.lockb')) {
        if (Test-Path -LiteralPath (Join-Path $RepoPath $lockfile) -PathType Leaf) {
            $hasLockfile = $true
            break
        }
    }

    if (-not $hasLockfile) {
        return $false
    }

    $hasNodeModules = Test-Path -LiteralPath (Join-Path $RepoPath 'node_modules') -PathType Container
    return ($PullUpdated -or (-not $hasNodeModules))
}

function Format-NativeErrorDetail {
    param(
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]]$OutputLines = @(),
        [int]$ExitCode = 1
    )

    $lines = @(
        foreach ($line in @($OutputLines)) {
            if ($null -eq $line) {
                continue
            }
            $text = ([string]$line).Trim()
            if ($text) {
                $text
            }
        }
    )

    if ($lines.Count -gt 0) {
        return ($lines -join ' | ')
    }
    return "exit code $ExitCode"
}

Export-ModuleMember -Function @(
    'Resolve-CliScriptDirectory',
    'Test-RequiredCommand',
    'Convert-TimeToSecond',
    'ConvertTo-ValidatedInt',
    'Format-ByteSize',
    'Format-NativeErrorDetail',
    'Import-WindowsMachinePath',
    'Invoke-YtDlpSegment',
    'Resolve-PlaywrightSyncStep',
    'Resolve-ProjectVerifyStep',
    'Test-WorkspaceNodeSyncTarget'
)
