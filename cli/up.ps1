#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Check and update Node.js / Vite+ package dependencies and GitHub Actions exact versions with automated verification and rollback.
.DESCRIPTION
    Cross-platform Node.js dependency and GitHub Actions updater for macOS and Windows 11 (PowerShell 7).
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
    Write-Output @'
up: Check and update Node.js package dependencies and GitHub Actions exact versions with clean spinner feedback
Usage: up
'@
}

foreach ($rawArg in $args) {
    $arg = [string]$rawArg
    if ($arg -match '^--?h(elp)?$') {
        Show-Help
        exit 0
    }
    elseif ($arg.StartsWith('-')) {
        [Console]::Error.WriteLine("Error: Unknown option $arg")
        Show-Help
        exit 1
    }
    else {
        [Console]::Error.WriteLine("Error: Unexpected argument $arg")
        Show-Help
        exit 1
    }
}

if (-not (Test-RequiredCommand -Name 'git', 'jq', 'vp', 'vpr', 'vpx', 'yq')) {
    exit 1
}

if (-not (Test-Path -LiteralPath 'package.json' -PathType Leaf)) {
    [Console]::Error.WriteLine('Error: File package.json does not exist')
    exit 1
}

$currentBranch = ([string](& git rev-parse --abbrev-ref HEAD 2>$null)).Trim()
if ($currentBranch -ne 'main') {
    [Console]::Error.WriteLine("Error: Current branch is not 'main' ($currentBranch)")
    exit 1
}

$gitStatus = (& git status --porcelain 2>$null)
if ($gitStatus) {
    [Console]::Error.WriteLine('Error: Working directory is not clean. Please commit or stash your changes first.')
    exit 1
}

& git rev-parse --abbrev-ref '@{u}' >$null 2>&1
if ($LASTEXITCODE -eq 0) {
    & git fetch --tags --force --quiet
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine('Error: Failed to fetch remote tags.')
        exit 1
    }
    & git pull --ff-only --quiet
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine('Error: Cannot fast-forward with remote. Please sync your branch first.')
        exit 1
    }
}

function Invoke-Step {
    param(
        [string]$Message,
        [string]$Exe,
        [string[]]$Arguments = @()
    )
    $Arguments = $Arguments ?? @()
    $frames = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    $frameIdx = 0

    $prevLog = $env:VP_LOG
    $env:VP_LOG = 'error'

    $targetExe = $Exe
    $targetArgs = $Arguments

    $job = Start-ThreadJob -ScriptBlock {
        $runExe = $using:targetExe
        $runArgs = $using:targetArgs
        try {
            $output = @(& $runExe @runArgs 2>&1)
            [PSCustomObject]@{
                Output   = $output
                ExitCode = ($LASTEXITCODE ?? 0)
            }
        }
        catch {
            [PSCustomObject]@{
                Output   = @($_.ToString())
                ExitCode = 1
            }
        }
    }

    try {
        $Host.UI.Write("`e[?25l`r  $($frames[$frameIdx]) $Message...")
        $frameIdx = ($frameIdx + 1) % $frames.Count

        while (-not $job.Finished.WaitOne(80)) {
            $Host.UI.Write("`r  $($frames[$frameIdx]) $Message...")
            $frameIdx = ($frameIdx + 1) % $frames.Count
        }

        $res = Receive-Job -Job $job
        $resObj = ($res -is [array]) ? $res[-1] : $res
        $output = @()
        $code = 0
        if ($null -ne $resObj) {
            $output = $resObj.Output ?? @()
            $code = [int]($resObj.ExitCode ?? 0)
        }
        else {
            $code = 1
            $output = @("Step '$Message' terminated unexpectedly.")
        }

        $Host.UI.Write("`r`e[K")
        if ($code -ne 0) {
            foreach ($line in $output) {
                [Console]::Error.WriteLine($line)
            }
            throw "Step failed with exit code $code"
        }
    }
    finally {
        $Host.UI.Write("`e[?25h")
        if ($null -ne $job) {
            if ($job.JobStateInfo.State -eq [System.Management.Automation.JobState]::Running) {
                Stop-Job -Job $job -ErrorAction SilentlyContinue
            }
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
        $env:VP_LOG = $prevLog
    }
}

function Restore-GitHubWorkflow {
    # Prevent vp migrate and vp fmt from modifying CI workflows or action definitions during dependency updates.
    param(
        [switch]$IncludeActionsDir
    )

    $pathsToInspect = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath '.github' -PathType Container) {
        $pathsToInspect.Add('.github')
    }
    if ($IncludeActionsDir -and (Test-Path -LiteralPath 'actions' -PathType Container)) {
        $pathsToInspect.Add('actions')
    }

    if ($pathsToInspect.Count -eq 0) {
        return
    }

    $diffLines = @(& git -c core.quotePath=false diff --relative --name-only -- @pathsToInspect 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to inspect GitHub Actions workflow changes after vp migrate'
    }

    $changedWorkflowFiles = @($diffLines | Where-Object {
            ($_ -imatch '^\.github/(workflows/[^/]+\.ya?ml|(.+/)?action\.ya?ml)$') -or
            ($IncludeActionsDir -and ($_ -imatch '^actions/'))
        })
    if ($changedWorkflowFiles.Count -eq 0) {
        return
    }

    & git checkout -q -- @changedWorkflowFiles
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to restore GitHub Actions workflow files after vp migrate'
    }
}

function Find-GitHubActionFile {
    if (-not (Test-Path -LiteralPath '.github' -PathType Container)) {
        return @()
    }

    $repoRoot = (Resolve-Path -LiteralPath '.').Path
    $githubDir = (Resolve-Path -LiteralPath '.github').Path
    $files = @(Get-ChildItem -LiteralPath $githubDir -Recurse -File | Where-Object {
            $_.Extension -in @('.yml', '.yaml')
        })

    $matched = [System.Collections.Generic.List[string]]::new()
    foreach ($file in $files) {
        $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName) -replace '\\', '/'
        if ($relPath -imatch '^\.github/(workflows/[^/]+\.ya?ml|(.+/)?action\.ya?ml)$') {
            $matched.Add($relPath)
        }
    }
    return @($matched | Sort-Object)
}

function ConvertFrom-GitHubActionVersion {
    param(
        [string]$Ref
    )

    if ($Ref -match '^(v)?(\d+)(?:\.(\d+)(?:\.(\d+))?)?$') {
        $hasVPrefix = $Matches.ContainsKey(1) -and (-not [string]::IsNullOrEmpty($Matches[1]))
        $hasMinor = $Matches.ContainsKey(3)
        $hasPatch = $Matches.ContainsKey(4)
        if ((-not $hasVPrefix) -and (-not $hasMinor)) {
            return $null
        }

        $precision = $hasPatch ? 3 : ($hasMinor ? 2 : 1)
        return [PSCustomObject]@{
            Raw       = $Ref
            Major     = [int]$Matches[2]
            Minor     = $hasMinor ? [int]$Matches[3] : 0
            Patch     = $hasPatch ? [int]$Matches[4] : 0
            Precision = $precision
        }
    }

    return $null
}

function Compare-GitHubActionVersion {
    param(
        [PSCustomObject]$Left,
        [PSCustomObject]$Right
    )

    foreach ($field in @('Major', 'Minor', 'Patch', 'Precision')) {
        $leftVal = [int]$Left.$field
        $rightVal = [int]$Right.$field
        if ($leftVal -ne $rightVal) {
            return ($leftVal -gt $rightVal) ? 1 : -1
        }
    }

    return 0
}

function Get-GitHubActionReference {
    param(
        [string[]]$FilePaths = @()
    )

    $references = [System.Collections.Generic.List[hashtable]]::new()
    $yqQuery = '[(.jobs[]?.uses, .jobs[]?.steps[]?.uses, .runs?.steps[]?.uses) | select(. != null and tag == "!!str") | {"uses": ., "line": line}]'

    foreach ($relPath in $FilePaths) {
        $absPath = (Resolve-Path -LiteralPath $relPath).Path
        $rawJson = (& yq -o=json $yqQuery $absPath 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to parse YAML file '${relPath}': $rawJson"
        }

        if (-not $rawJson -or $rawJson.Trim() -in @('', '[]')) {
            continue
        }

        $items = @($rawJson | ConvertFrom-Json -AsHashtable)
        foreach ($item in $items) {
            $usesValue = [string]($item['uses'] ?? '')
            if (-not $usesValue -or $usesValue.StartsWith('.') -or $usesValue.StartsWith('docker://') -or (-not $usesValue.Contains('@'))) {
                continue
            }

            if ($usesValue -match '^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)(?:/([^@]+))?@(.+)$') {
                $repoSlug = $Matches[1]
                $subpath = $Matches.ContainsKey(2) ? $Matches[2] : ''
                $currentRef = $Matches[3]
                $currentVersion = ConvertFrom-GitHubActionVersion -Ref $currentRef

                if ($null -ne $currentVersion) {
                    $actionTarget = $subpath ? "$repoSlug/$subpath" : $repoSlug
                    $references.Add(@{
                            FilePath       = $relPath
                            Line           = [int]$item['line']
                            OldUses        = $usesValue
                            RepoSlug       = $repoSlug
                            ActionTarget   = $actionTarget
                            CurrentRef     = $currentRef
                            CurrentVersion = $currentVersion
                        })
                }
            }
        }
    }

    return @($references)
}

function Resolve-GitHubActionLatestVersion {
    param(
        [string[]]$RepoSlugs = @()
    )

    $uniqueRepos = @($RepoSlugs | Sort-Object -Unique)
    $resultMap = @{}
    if ($uniqueRepos.Count -eq 0) {
        return $resultMap
    }

    $prevTerminalPrompt = $env:GIT_TERMINAL_PROMPT
    $env:GIT_TERMINAL_PROMPT = '0'
    try {
        $results = @($uniqueRepos | ForEach-Object -Parallel {
                $slug = $_
                $output = @(& git -c credential.interactive=never ls-remote --tags --refs "https://github.com/$slug.git" 2>&1)
                $code = $LASTEXITCODE
                if ($code -ne 0) {
                    $errLine = ($output | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() } | Select-Object -First 1) ?? "exit code $code"
                    [PSCustomObject]@{
                        RepoSlug = $slug
                        Success  = $false
                        Tags     = @()
                        Error    = $errLine
                    }
                    return
                }

                $tags = [System.Collections.Generic.List[string]]::new()
                foreach ($line in $output) {
                    $text = [string]$line
                    if ($text -match '\trefs/tags/([^\s]+)$') {
                        $tags.Add($Matches[1])
                    }
                }

                [PSCustomObject]@{
                    RepoSlug = $slug
                    Success  = $true
                    Tags     = @($tags)
                    Error    = ''
                }
            } -ThrottleLimit 6)
    }
    finally {
        $env:GIT_TERMINAL_PROMPT = $prevTerminalPrompt
    }

    foreach ($res in $results) {
        $latestByMajor = @{}
        if ($res.Success) {
            foreach ($tagName in $res.Tags) {
                $parsed = ConvertFrom-GitHubActionVersion -Ref ([string]$tagName)
                if ($null -eq $parsed) {
                    continue
                }
                $majorKey = [int]$parsed.Major
                if ((-not $latestByMajor.ContainsKey($majorKey)) -or ((Compare-GitHubActionVersion -Left $parsed -Right $latestByMajor[$majorKey]) -gt 0)) {
                    $latestByMajor[$majorKey] = $parsed
                }
            }
        }

        $resultMap[$res.RepoSlug] = [PSCustomObject]@{
            RepoSlug      = $res.RepoSlug
            Success       = $res.Success
            LatestByMajor = $latestByMajor
            Error         = $res.Error
        }
    }

    return $resultMap
}

function Get-GitHubActionUpdate {
    param(
        [hashtable[]]$References = @(),
        [hashtable]$LatestByMajorByRepo = @{}
    )

    $updates = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($refItem in $References) {
        $slug = [string]$refItem['RepoSlug']
        if (-not $LatestByMajorByRepo.ContainsKey($slug)) {
            continue
        }

        $majorMap = $LatestByMajorByRepo[$slug]
        $currentVersion = $refItem['CurrentVersion']
        $majorKey = [int]$currentVersion.Major
        if (-not $majorMap.ContainsKey($majorKey)) {
            continue
        }

        $latestVersion = $majorMap[$majorKey]
        $currentRef = [string]$refItem['CurrentRef']
        $targetRef = [string]$latestVersion.Raw
        $cmp = Compare-GitHubActionVersion -Left $latestVersion -Right $currentVersion

        if (($cmp -gt 0) -or (($cmp -eq 0) -and ($currentRef -ne $targetRef))) {
            $actionTarget = [string]$refItem['ActionTarget']
            $updates.Add(@{
                    FilePath     = [string]$refItem['FilePath']
                    Line         = [int]$refItem['Line']
                    OldUses      = [string]$refItem['OldUses']
                    NewUses      = "$actionTarget@$targetRef"
                    RepoSlug     = $slug
                    ActionTarget = $actionTarget
                    OldRef       = $currentRef
                    NewRef       = $targetRef
                })
        }
    }

    return @($updates)
}

function Update-GitHubActionFile {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([object[]])]
    param(
        [hashtable[]]$Updates = @()
    )

    $changedFiles = [System.Collections.Generic.List[string]]::new()
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $grouped = $Updates | Group-Object -Property { $_['FilePath'] }

    foreach ($group in $grouped) {
        $relPath = [string]$group.Name
        $absPath = (Resolve-Path -LiteralPath $relPath).Path
        $raw = [System.IO.File]::ReadAllText($absPath)
        $eol = $raw.Contains("`r`n") ? "`r`n" : "`n"
        $lines = [string[]]($raw -split '\r?\n')
        $fileModified = $false

        foreach ($item in $group.Group) {
            $lineIndex = [int]$item['Line'] - 1
            if ($lineIndex -lt 0 -or $lineIndex -ge $lines.Count) {
                throw "Line index $($item['Line']) out of range for '$relPath'"
            }

            $oldUses = [string]$item['OldUses']
            $newUses = [string]$item['NewUses']
            $safeReplacement = $newUses.Replace('$', '$$')
            $escapedOld = [regex]::Escape($oldUses)
            $usesPattern = '(?<=uses\s*:\s*[''"]?)' + $escapedOld + '(?=[''"]?(?:\s+#.*|\s*$))'
            $fallbackPattern = '(?<=^\s*[''"]?)' + $escapedOld + '(?=[''"]?(?:\s+#.*|\s*$))'
            $lineText = $lines[$lineIndex]

            if ($lineText -match $usesPattern) {
                $lines[$lineIndex] = [regex]::new($usesPattern).Replace($lineText, $safeReplacement, 1)
                $fileModified = $true
            }
            elseif ($lineText -match $fallbackPattern) {
                $lines[$lineIndex] = [regex]::new($fallbackPattern).Replace($lineText, $safeReplacement, 1)
                $fileModified = $true
            }
            else {
                throw "Failed to locate uses target '$oldUses' at ${relPath}:$($item['Line'])"
            }
        }

        if ($fileModified -and $PSCmdlet.ShouldProcess($relPath, 'Update GitHub Actions version references')) {
            [System.IO.File]::WriteAllText($absPath, ($lines -join $eol), $utf8NoBom)
            $changedFiles.Add($relPath)
        }
    }

    return @($changedFiles)
}

$pkgJson = Get-Content -LiteralPath 'package.json' -Raw | ConvertFrom-Json -AsHashtable
$deps = $pkgJson['dependencies'] ?? @{}
$devDeps = $pkgJson['devDependencies'] ?? @{}
$peerDeps = $pkgJson['peerDependencies'] ?? @{}
$optDeps = $pkgJson['optionalDependencies'] ?? @{}
$scriptsMap = $pkgJson['scripts'] ?? @{}

$isVitePlus = $deps.ContainsKey('vite-plus') -or $devDeps.ContainsKey('vite-plus')
$vpToolchainUpgraded = $false
$vpOldVer = ''
$vpNewVer = ''

if ($isVitePlus) {
    $vpVerOut = @(& vp --version 2>$null)
    $globalVpVer = ''
    foreach ($line in $vpVerOut) {
        if ($line -match '^vp v([^\s]+)') {
            $globalVpVer = $Matches[1]
            break
        }
    }

    $localVpVer = $deps['vite-plus'] ?? $devDeps['vite-plus'] ?? ''
    if ($localVpVer -eq 'catalog:' -and (Test-Path -LiteralPath 'pnpm-workspace.yaml' -PathType Leaf)) {
        $localVpVer = ([string](& yq '.catalog.vite-plus // .catalogs.default.vite-plus // ""' pnpm-workspace.yaml 2>$null)).Trim()
    }

    if ($globalVpVer -and $localVpVer -and ($localVpVer -ne $globalVpVer)) {
        $vpToolchainUpgraded = $true
        $vpOldVer = $localVpVer
        $vpNewVer = $globalVpVer
    }
}

$ncuRaw = (& vpx -s npm-check-updates@latest -t minor --install never --jsonUpgraded 2>$null) -join "`n"
$ncuMap = @{}
if ($ncuRaw -and $ncuRaw.Trim() -notin @('', '{}')) {
    $ncuMap = $ncuRaw | ConvertFrom-Json -AsHashtable
}

$hasLockfileDrift = $false
if (Test-Path -LiteralPath 'pnpm-lock.yaml' -PathType Leaf) {
    $prevVpLog = $env:VP_LOG
    $env:VP_LOG = 'error'
    try {
        & vp install --frozen-lockfile --lockfile-only --silent >$null 2>&1
        if ($LASTEXITCODE -ne 0) {
            $hasLockfileDrift = $true
        }
    }
    finally {
        $env:VP_LOG = $prevVpLog
    }
}

$hasDepUpdates = ($isVitePlus -and $vpToolchainUpgraded) -or ($ncuMap.Count -gt 0) -or $hasLockfileDrift

$isGitHubActionsRepo = Test-Path -LiteralPath 'actions' -PathType Container
$ciFiles = $isGitHubActionsRepo ? @() : @(Find-GitHubActionFile)
$latestByMajorByRepo = @{}
$ciUpdates = @()
$ciDisplayEntries = [System.Collections.Generic.List[hashtable]]::new()
$seenCiDisplayKeys = [System.Collections.Generic.HashSet[string]]::new()

if ($ciFiles.Count -gt 0) {
    $ciRefs = @(Get-GitHubActionReference -FilePaths $ciFiles)
    if ($ciRefs.Count -gt 0) {
        $repoSlugs = @($ciRefs | ForEach-Object { $_['RepoSlug'] })
        $repoResults = Resolve-GitHubActionLatestVersion -RepoSlugs $repoSlugs

        foreach ($slug in ($repoSlugs | Sort-Object -Unique)) {
            $res = $repoResults[$slug]
            if (-not $res.Success) {
                [Console]::Error.WriteLine("Warning: Failed to query tags for ${slug}: $($res.Error)")
            }
            elseif ($res.LatestByMajor.Count -gt 0) {
                $latestByMajorByRepo[$slug] = $res.LatestByMajor
            }
        }

        $ciUpdates = @(Get-GitHubActionUpdate -References $ciRefs -LatestByMajorByRepo $latestByMajorByRepo)
        foreach ($updateItem in $ciUpdates) {
            $actionTarget = [string]$updateItem['ActionTarget']
            $currentRef = [string]$updateItem['OldRef']
            $targetRef = [string]$updateItem['NewRef']
            $displayKey = "$actionTarget|$currentRef|$targetRef"
            if ($seenCiDisplayKeys.Add($displayKey)) {
                $ciDisplayEntries.Add(@{
                        Target = $actionTarget
                        OldRef = $currentRef
                        NewRef = $targetRef
                    })
            }
        }
    }
}

$hasCiUpdates = $ciUpdates.Count -gt 0

if ((-not $hasDepUpdates) -and (-not $hasCiUpdates)) {
    exit 0
}

$depCount = 0
$depCommitBodyLines = [System.Collections.Generic.List[string]]::new()
$singlePkgSummary = ''
$hasVitePlusInTargets = $false

foreach ($pkg in $ncuMap.Keys) {
    $newVer = $ncuMap[$pkg]
    $oldVer = $deps[$pkg] ?? $devDeps[$pkg] ?? $peerDeps[$pkg] ?? $optDeps[$pkg] ?? '?'
    if ($pkg -eq 'vite-plus') {
        $hasVitePlusInTargets = $true
    }
    Write-Output "  $pkg  $oldVer  ->  $newVer"
    $depCommitBodyLines.Add("- ${pkg}: ${oldVer} -> ${newVer}")
    $singlePkgSummary = "$pkg $oldVer -> $newVer"
    $depCount++
}

if ($vpToolchainUpgraded -and (-not $hasVitePlusInTargets)) {
    Write-Output "  vite-plus  $vpOldVer  ->  $vpNewVer"
    $depCommitBodyLines.Add("- vite-plus: ${vpOldVer} -> ${vpNewVer}")
    $singlePkgSummary = "vite-plus $vpOldVer -> $vpNewVer"
    $depCount++
}

$ciCount = 0
$ciCommitBodyLines = [System.Collections.Generic.List[string]]::new()
$singleCiSummary = ''

foreach ($entry in $ciDisplayEntries) {
    Write-Output "  $($entry['Target'])  $($entry['OldRef'])  ->  $($entry['NewRef'])"
    $ciCommitBodyLines.Add("- $($entry['Target']): $($entry['OldRef']) -> $($entry['NewRef'])")
    $singleCiSummary = "$($entry['Target']) $($entry['OldRef']) -> $($entry['NewRef'])"
    $ciCount++
}

$tempBranch = "chore/deps-upgrade-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
& git checkout -q -b $tempBranch
$failedStep = 'Verification'
$createdCommits = [System.Collections.Generic.List[string]]::new()

try {
    if ($hasDepUpdates) {
        if ($isVitePlus) {
            if ($vpToolchainUpgraded -or ($ncuMap.Count -gt 0)) {
                $failedStep = 'vp migrate --no-interactive'
                Invoke-Step -Message 'Aligning Vite+ toolchain (vp migrate)' -Exe 'vp' -Arguments @('migrate', '--no-interactive')

                $failedStep = 'Restore GitHub Actions workflows'
                Restore-GitHubWorkflow -IncludeActionsDir:$isGitHubActionsRepo

                if ($ncuMap.Count -gt 0) {
                    $failedStep = 'vpx npm-check-updates'
                    Invoke-Step -Message 'Updating packages (NCU)' -Exe 'vpx' -Arguments @('-s', 'npm-check-updates@latest', '-u', '-t', 'minor')
                }

                $failedStep = 'vp pm pkg fix'
                Invoke-Step -Message 'Normalizing manifest (vp pm pkg fix)' -Exe 'vp' -Arguments @('pm', 'pkg', 'fix')
            }

            $failedStep = 'vp install'
            Invoke-Step -Message 'Syncing dependencies (vp install)' -Exe 'vp' -Arguments @('install')

            $failedStep = 'vp install (frozen verification)'
            Invoke-Step -Message 'Verifying frozen lockfile' -Exe 'vp' -Arguments @('install', '--frozen-lockfile')
        }
        else {
            if ($ncuMap.Count -gt 0) {
                $failedStep = 'vpx npm-check-updates'
                Invoke-Step -Message 'Updating packages (NCU)' -Exe 'vpx' -Arguments @('-s', 'npm-check-updates@latest', '-u', '-t', 'minor')

                $failedStep = 'vp pm pkg fix'
                Invoke-Step -Message 'Normalizing manifest (vp pm pkg fix)' -Exe 'vp' -Arguments @('pm', 'pkg', 'fix')
            }

            if (Test-Path -LiteralPath 'node_modules' -PathType Container) {
                Move-Item -LiteralPath 'node_modules' -Destination '.node_modules.bak' -Force
            }
            Remove-Item -LiteralPath 'package-lock.json' -Force -ErrorAction SilentlyContinue

            $failedStep = 'vp install (lockfile update)'
            Invoke-Step -Message 'Writing lockfile' -Exe 'vp' -Arguments @('install', '--lockfile-only', '--ignore-scripts')

            $failedStep = 'vp install'
            Invoke-Step -Message 'Syncing dependencies (vp install)' -Exe 'vp' -Arguments @('install', '--frozen-lockfile')
            Remove-Item -LiteralPath '.node_modules.bak' -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Re-read package.json scripts after migration/update
        $pkgJson = Get-Content -LiteralPath 'package.json' -Raw | ConvertFrom-Json -AsHashtable
        $deps = $pkgJson['dependencies'] ?? @{}
        $devDeps = $pkgJson['devDependencies'] ?? @{}
        $scriptsMap = $pkgJson['scripts'] ?? @{}

        $failedStep = 'vp fmt'
        Invoke-Step -Message 'Formatting code & configs (vp fmt)' -Exe 'vp' -Arguments @('fmt')

        if ($hasCiUpdates -or $isGitHubActionsRepo) {
            $failedStep = 'Restore GitHub Actions workflows before deps commit'
            Restore-GitHubWorkflow -IncludeActionsDir:$isGitHubActionsRepo
        }

        $failedStep = 'vp check'
        Invoke-Step -Message 'Checking quality & lint (vp check)' -Exe 'vp' -Arguments @('check', '--quiet', '--no-error-on-unmatched-pattern')

        if ($scriptsMap.ContainsKey('lint:tailwind')) {
            $failedStep = 'vpr lint:tailwind (lint)'
            Invoke-Step -Message 'Verifying additional lint rules' -Exe 'vpr' -Arguments @('lint:tailwind')
        }

        if (-not $hasCiUpdates) {
            foreach ($s in @('agent:lint:ci', 'lint:ci')) {
                if ($scriptsMap.ContainsKey($s)) {
                    $failedStep = "vpr $s (lint)"
                    Invoke-Step -Message 'Verifying CI workflow rules' -Exe 'vpr' -Arguments @($s)
                    break
                }
            }
        }

        $hasTypecheck = $false
        foreach ($s in @('agent:typecheck', 'typecheck')) {
            if ($scriptsMap.ContainsKey($s)) {
                $hasTypecheck = $true
                $failedStep = "vpr $s (typecheck)"
                Invoke-Step -Message 'Verifying types' -Exe 'vpr' -Arguments @($s)
                break
            }
        }

        if (-not $hasTypecheck -and ($deps.ContainsKey('typescript') -or $devDeps.ContainsKey('typescript'))) {
            $failedStep = 'vpx tsc --noEmit'
            Invoke-Step -Message 'Verifying types' -Exe 'vpx' -Arguments @('tsc', '--noEmit')
        }

        foreach ($s in @('check:deadcode', 'knip')) {
            if ($scriptsMap.ContainsKey($s)) {
                $failedStep = "vpr $s (deadcode)"
                Invoke-Step -Message 'Verifying dead code' -Exe 'vpr' -Arguments @($s)
                break
            }
        }

        $pwSyncStep = Resolve-PlaywrightSyncStep -PackageJson $pkgJson -ProjectRoot '.'
        if ($null -ne $pwSyncStep) {
            $failedStep = $pwSyncStep.StepLabel
            $prevPwSkipGc = $env:PLAYWRIGHT_SKIP_BROWSER_GC
            $env:PLAYWRIGHT_SKIP_BROWSER_GC = '1'
            try {
                Invoke-Step -Message 'Syncing Playwright browsers' -Exe $pwSyncStep.Exe -Arguments $pwSyncStep.Arguments
            }
            finally {
                $env:PLAYWRIGHT_SKIP_BROWSER_GC = $prevPwSkipGc
            }
        }

        $verifySteps = @(Resolve-ProjectVerifyStep -ScriptsMap $scriptsMap)
        foreach ($step in $verifySteps) {
            $failedStep = $step.StepLabel
            Invoke-Step -Message $step.Message -Exe $step.Exe -Arguments $step.Arguments
        }

        $depPendingChanges = (& git status --porcelain 2>$null)
        if ($depPendingChanges) {
            $depCommitTitle = if ($depCount -eq 0) {
                'chore: sync lockfile'
            }
            elseif ($depCount -eq 1) {
                "chore(deps): update dependency $singlePkgSummary"
            }
            else {
                "chore(deps): update dependencies ($depCount packages)"
            }
            $depCommitMsg = ($depCount -le 1) ? $depCommitTitle : ($depCommitTitle + "`n`nUpgrade details:`n" + ($depCommitBodyLines -join "`n"))

            $failedStep = 'git commit (deps)'
            & git add -A
            & git commit -q -m $depCommitMsg
            if ($LASTEXITCODE -ne 0) {
                throw 'git commit (deps) failed'
            }
            $createdCommits.Add($depCommitTitle)
        }
    }

    if ($hasCiUpdates) {
        $workflowFiles = @($ciFiles | Where-Object { $_ -imatch '^\.github/workflows/[^/]+\.ya?ml$' })
        if (($workflowFiles.Count -gt 0) -and (-not (Get-Command 'actionlint' -ErrorAction SilentlyContinue))) {
            $failedStep = 'actionlint pre-check'
            throw 'actionlint is not installed'
        }

        $failedStep = 'Update GitHub Actions versions'
        $freshCiRefs = @(Get-GitHubActionReference -FilePaths $ciFiles)
        $updatesToApply = @(Get-GitHubActionUpdate -References $freshCiRefs -LatestByMajorByRepo $latestByMajorByRepo)

        $changedCiFiles = @(Update-GitHubActionFile -Updates $updatesToApply)
        if ($changedCiFiles.Count -gt 0) {
            $failedStep = 'vp fmt (CI)'
            $fmtArgs = @('fmt', '--no-error-on-unmatched-pattern') + $changedCiFiles
            Invoke-Step -Message 'Formatting GitHub Actions files (vp fmt)' -Exe 'vp' -Arguments $fmtArgs
        }

        if ($workflowFiles.Count -gt 0) {
            $failedStep = 'actionlint'
            Invoke-Step -Message 'Verifying GitHub Actions workflows (actionlint)' -Exe 'actionlint'
        }

        $ciPendingChanges = (& git status --porcelain 2>$null)
        if ($ciPendingChanges) {
            $ciCommitTitle = ($ciCount -eq 1) ? "chore(ci): update action $singleCiSummary" : "chore(ci): update GitHub Actions ($ciCount actions)"
            $ciCommitMsg = ($ciCount -eq 1) ? $ciCommitTitle : ($ciCommitTitle + "`n`nUpgrade details:`n" + ($ciCommitBodyLines -join "`n"))

            $failedStep = 'git commit (ci)'
            & git add -A
            & git commit -q -m $ciCommitMsg
            if ($LASTEXITCODE -ne 0) {
                throw 'git commit (ci) failed'
            }
            $createdCommits.Add($ciCommitTitle)
        }
    }
}
catch {
    $Host.UI.Write("`r`e[K")
    [Console]::Error.WriteLine("Error: Pre-checks failed at step '$failedStep'. Rolling back changes to 'main'...")
    & git reset --hard -q 2>$null
    & git checkout -q main 2>$null
    & git branch -D $tempBranch >$null 2>&1
    if (Test-Path -LiteralPath '.node_modules.bak' -PathType Container) {
        Remove-Item -LiteralPath 'node_modules' -Recurse -Force -ErrorAction SilentlyContinue
        Move-Item -LiteralPath '.node_modules.bak' -Destination 'node_modules' -Force
    }
    elseif ($hasDepUpdates) {
        $env:VP_LOG = 'error'
        & vp install --frozen-lockfile --silent 2>$null
    }
    exit 1
}

& git checkout -q main
& git merge --ff-only -q $tempBranch
& git branch -D -q $tempBranch

if ($createdCommits.Count -gt 0) {
    & git rev-parse --abbrev-ref '@{u}' >$null 2>&1
    if ($LASTEXITCODE -eq 0) {
        $failedStep = 'git push'
        Invoke-Step -Message 'Pushing to remote' -Exe 'git' -Arguments @('push', '-q', 'origin', 'main')
        foreach ($title in $createdCommits) {
            Write-Output "Pushed: $title"
        }
    }
    else {
        foreach ($title in $createdCommits) {
            Write-Output "Committed and merged: $title"
        }
    }
}
