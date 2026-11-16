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
Import-Module -Name (Join-Path $scriptDir 'helpers' 'NodeToolchain.psm1') -Force
Import-Module -Name (Join-Path $scriptDir 'helpers' 'GitHubActions.psm1') -Force

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

$vpQuietEnv = @{ VP_LOG = 'error' }
$tempBranch = "chore/deps-upgrade-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
& git checkout -q -b $tempBranch
$failedStep = 'Verification'
$createdCommits = [System.Collections.Generic.List[string]]::new()

try {
    if ($hasDepUpdates) {
        if ($isVitePlus) {
            if ($vpToolchainUpgraded -or ($ncuMap.Count -gt 0)) {
                $failedStep = 'vp migrate --no-interactive'
                Invoke-SpinnerStep -Message 'Aligning Vite+ toolchain (vp migrate)' -Exe 'vp' -Arguments @('migrate', '--no-interactive') -Environment $vpQuietEnv

                $failedStep = 'Restore GitHub Actions workflows'
                Restore-GitHubWorkflow -IncludeActionsDir:$isGitHubActionsRepo

                if ($ncuMap.Count -gt 0) {
                    $failedStep = 'vpx npm-check-updates'
                    Invoke-SpinnerStep -Message 'Updating packages (NCU)' -Exe 'vpx' -Arguments @('-s', 'npm-check-updates@latest', '-u', '-t', 'minor') -Environment $vpQuietEnv
                }

                $failedStep = 'vp pm pkg fix'
                Invoke-SpinnerStep -Message 'Normalizing manifest (vp pm pkg fix)' -Exe 'vp' -Arguments @('pm', 'pkg', 'fix') -Environment $vpQuietEnv
            }

            $failedStep = 'vp install'
            Invoke-SpinnerStep -Message 'Syncing dependencies (vp install)' -Exe 'vp' -Arguments @('install') -Environment $vpQuietEnv

            $failedStep = 'vp install (frozen verification)'
            Invoke-SpinnerStep -Message 'Verifying frozen lockfile' -Exe 'vp' -Arguments @('install', '--frozen-lockfile') -Environment $vpQuietEnv
        }
        else {
            if ($ncuMap.Count -gt 0) {
                $failedStep = 'vpx npm-check-updates'
                Invoke-SpinnerStep -Message 'Updating packages (NCU)' -Exe 'vpx' -Arguments @('-s', 'npm-check-updates@latest', '-u', '-t', 'minor') -Environment $vpQuietEnv

                $failedStep = 'vp pm pkg fix'
                Invoke-SpinnerStep -Message 'Normalizing manifest (vp pm pkg fix)' -Exe 'vp' -Arguments @('pm', 'pkg', 'fix') -Environment $vpQuietEnv
            }

            if (Test-Path -LiteralPath 'node_modules' -PathType Container) {
                Move-Item -LiteralPath 'node_modules' -Destination '.node_modules.bak' -Force
            }
            Remove-Item -LiteralPath 'package-lock.json' -Force -ErrorAction SilentlyContinue

            $failedStep = 'vp install (lockfile update)'
            Invoke-SpinnerStep -Message 'Writing lockfile' -Exe 'vp' -Arguments @('install', '--lockfile-only', '--ignore-scripts') -Environment $vpQuietEnv

            $failedStep = 'vp install'
            Invoke-SpinnerStep -Message 'Syncing dependencies (vp install)' -Exe 'vp' -Arguments @('install', '--frozen-lockfile') -Environment $vpQuietEnv
            Remove-Item -LiteralPath '.node_modules.bak' -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Re-read package.json scripts after migration/update
        $pkgJson = Get-Content -LiteralPath 'package.json' -Raw | ConvertFrom-Json -AsHashtable
        $deps = $pkgJson['dependencies'] ?? @{}
        $devDeps = $pkgJson['devDependencies'] ?? @{}
        $scriptsMap = $pkgJson['scripts'] ?? @{}

        $failedStep = 'vp fmt'
        Invoke-SpinnerStep -Message 'Formatting code & configs (vp fmt)' -Exe 'vp' -Arguments @('fmt') -Environment $vpQuietEnv

        if ($hasCiUpdates -or $isGitHubActionsRepo) {
            $failedStep = 'Restore GitHub Actions workflows before deps commit'
            Restore-GitHubWorkflow -IncludeActionsDir:$isGitHubActionsRepo
        }

        $failedStep = 'vp check'
        Invoke-SpinnerStep -Message 'Checking quality & lint (vp check)' -Exe 'vp' -Arguments @('check', '--quiet', '--no-error-on-unmatched-pattern') -Environment $vpQuietEnv

        if ($scriptsMap.ContainsKey('lint:tailwind')) {
            $failedStep = 'vpr lint:tailwind (lint)'
            Invoke-SpinnerStep -Message 'Verifying additional lint rules' -Exe 'vpr' -Arguments @('lint:tailwind') -Environment $vpQuietEnv
        }

        if (-not $hasCiUpdates) {
            foreach ($s in @('agent:lint:ci', 'lint:ci')) {
                if ($scriptsMap.ContainsKey($s)) {
                    $failedStep = "vpr $s (lint)"
                    Invoke-SpinnerStep -Message 'Verifying CI workflow rules' -Exe 'vpr' -Arguments @($s) -Environment $vpQuietEnv
                    break
                }
            }
        }

        $hasTypecheck = $false
        foreach ($s in @('agent:typecheck', 'typecheck')) {
            if ($scriptsMap.ContainsKey($s)) {
                $hasTypecheck = $true
                $failedStep = "vpr $s (typecheck)"
                Invoke-SpinnerStep -Message 'Verifying types' -Exe 'vpr' -Arguments @($s) -Environment $vpQuietEnv
                break
            }
        }

        if (-not $hasTypecheck -and ($deps.ContainsKey('typescript') -or $devDeps.ContainsKey('typescript'))) {
            $failedStep = 'vpx tsc --noEmit'
            Invoke-SpinnerStep -Message 'Verifying types' -Exe 'vpx' -Arguments @('tsc', '--noEmit') -Environment $vpQuietEnv
        }

        foreach ($s in @('check:deadcode', 'knip')) {
            if ($scriptsMap.ContainsKey($s)) {
                $failedStep = "vpr $s (deadcode)"
                Invoke-SpinnerStep -Message 'Verifying dead code' -Exe 'vpr' -Arguments @($s) -Environment $vpQuietEnv
                break
            }
        }

        $pwSyncStep = Resolve-PlaywrightSyncStep -PackageJson $pkgJson -ProjectRoot '.'
        if ($null -ne $pwSyncStep) {
            $failedStep = $pwSyncStep.StepLabel
            $prevPwSkipGc = $env:PLAYWRIGHT_SKIP_BROWSER_GC
            $env:PLAYWRIGHT_SKIP_BROWSER_GC = '1'
            try {
                Invoke-SpinnerStep -Message 'Syncing Playwright browsers' -Exe $pwSyncStep.Exe -Arguments $pwSyncStep.Arguments -Environment $vpQuietEnv
            }
            finally {
                $env:PLAYWRIGHT_SKIP_BROWSER_GC = $prevPwSkipGc
            }
        }

        $verifySteps = @(Resolve-ProjectVerifyStep -ScriptsMap $scriptsMap)
        foreach ($step in $verifySteps) {
            $failedStep = $step.StepLabel
            Invoke-SpinnerStep -Message $step.Message -Exe $step.Exe -Arguments $step.Arguments -Environment $vpQuietEnv
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
            Invoke-SpinnerStep -Message 'Formatting GitHub Actions files (vp fmt)' -Exe 'vp' -Arguments $fmtArgs -Environment $vpQuietEnv
        }

        if ($workflowFiles.Count -gt 0) {
            $failedStep = 'actionlint'
            Invoke-SpinnerStep -Message 'Verifying GitHub Actions workflows (actionlint)' -Exe 'actionlint' -Environment $vpQuietEnv
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
        Invoke-SpinnerStep -Message 'Pushing to remote' -Exe 'git' -Arguments @('push', '-q', 'origin', 'main') -Environment $vpQuietEnv
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
