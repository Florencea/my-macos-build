#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Upgrade system packages (Homebrew on macOS / winget on Windows), update Node.js (Active LTS via Vite+), and parallel-sync all Git repositories in the workspace.
.DESCRIPTION
    Cross-platform system & workspace updater for macOS and Windows 11 (PowerShell 7).
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
ua: Upgrade system packages (Homebrew / winget), update Node.js (Active LTS via Vite+), and sync git repositories
Usage: ua [options]
Options:
  --skip-brew     Skip Homebrew upgrade (macOS)
  --skip-winget   Skip winget upgrade (Windows)
  --skip-vite     Skip Vite+ and Node.js LTS update
  --skip-git      Skip workspace Git repositories sync
  -h, --help      Show this help message
'@
}

$SkipBrew = $false
$SkipWinget = $false
$SkipVite = $false
$SkipGit = $false

foreach ($rawArg in $args) {
    $arg = [string]$rawArg
    if ($arg -match '^--?h(elp)?$') {
        Show-Help
        exit 0
    }
    elseif ($arg -match '^--?skip-?brew$') {
        $SkipBrew = $true
    }
    elseif ($arg -match '^--?skip-?winget$') {
        $SkipWinget = $true
    }
    elseif ($arg -match '^--?skip-?vite$') {
        $SkipVite = $true
    }
    elseif ($arg -match '^--?skip-?git$') {
        $SkipGit = $true
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

Import-WindowsMachinePath

$projectsDir = (Resolve-Path -LiteralPath (Join-Path $scriptDir '../..')).Path

# 1. Upgrade OS Packages
if ($IsMacOS -and (-not $SkipBrew)) {
    if (-not (Test-RequiredCommand -Name 'brew')) {
        exit 1
    }
    Push-Location $HOME
    try {
        $env:HOMEBREW_NO_ENV_HINTS = '1'
        $env:HOMEBREW_NO_ASK = '1'
        $env:HOMEBREW_AUTO_UPDATE_QUIET = '1'
        $env:HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS = '1'
        & brew upgrade
        & brew cleanup
    }
    finally {
        Pop-Location
    }
}
elseif ($IsWindows -and (-not $SkipWinget)) {
    if (Get-Command 'winget' -ErrorAction SilentlyContinue) {
        & winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements
    }
}

function Get-VitePlusOxfmtSpec {
    param(
        [string]$VpCommandPath,
        [string]$VpVersion
    )

    $candidateRoots = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($env:VP_HOME)) {
        $candidateRoots.Add($env:VP_HOME.Trim())
    }
    if (-not [string]::IsNullOrWhiteSpace($VpCommandPath)) {
        $binDir = Split-Path -Parent $VpCommandPath
        if ($binDir) {
            $parentDir = Split-Path -Parent $binDir
            if ($parentDir) {
                $candidateRoots.Add($parentDir)
            }
        }
        $vpInfo = [System.IO.FileInfo]::new($VpCommandPath)
        $vpTarget = $vpInfo.ResolveLinkTarget($true)
        if ($null -ne $vpTarget) {
            $targetBinDir = Split-Path -Parent $vpTarget.FullName
            if ($targetBinDir) {
                $targetParentDir = Split-Path -Parent $targetBinDir
                if ($targetParentDir) {
                    $candidateRoots.Add($targetParentDir)
                }
            }
        }
    }

    if ($IsWindows) {
        $candidateRoots.Add('E:\vite-plus')
        $candidateRoots.Add((Join-Path $HOME '.vite-plus'))
    }
    else {
        $candidateRoots.Add((Join-Path $HOME '.local/share/vite-plus'))
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($root in $candidateRoots) {
        if ([string]::IsNullOrWhiteSpace($root) -or (-not $seen.Add($root)) -or (-not (Test-Path -LiteralPath $root -PathType Container))) {
            continue
        }

        $pkgCandidates = [System.Collections.Generic.List[string]]::new()
        $pkgCandidates.Add((Join-Path $root 'current/node_modules/vite-plus/package.json'))
        if ($VpVersion) {
            $pkgCandidates.Add((Join-Path $root "$VpVersion/node_modules/vite-plus/package.json"))
        }
        $pkgCandidates.Add((Join-Path $root 'node_modules/vite-plus/package.json'))

        foreach ($pkgPath in $pkgCandidates) {
            if (-not (Test-Path -LiteralPath $pkgPath -PathType Leaf)) {
                continue
            }

            $pkg = Get-Content -LiteralPath $pkgPath -Raw | ConvertFrom-Json -AsHashtable
            $deps = $pkg['dependencies']
            if ($deps -is [hashtable] -and $deps.ContainsKey('oxfmt')) {
                $rawVer = ([string]$deps['oxfmt']).Trim()
                $targetVer = $rawVer -replace '^[^0-9]*', ''
                if ($targetVer) {
                    $vpHomeDir = $root
                    if ($pkgPath -eq (Join-Path $root 'node_modules/vite-plus/package.json')) {
                        $vpHomeDir = Split-Path -Parent $root
                    }
                    return [PSCustomObject]@{
                        VpHome       = $vpHomeDir
                        OxfmtVersion = $targetVer
                    }
                }
            }
        }
    }

    return $null
}

function Sync-GlobalOxfmt {
    $vpCmd = Get-Command 'vp' -ErrorAction SilentlyContinue
    if ($null -eq $vpCmd) {
        return
    }

    $vpVerOut = @(& vp --version 2>$null)
    $vpVersion = ''
    foreach ($line in $vpVerOut) {
        if ([string]$line -match '^vp v([^\s]+)') {
            $vpVersion = $Matches[1]
            break
        }
    }

    $spec = Get-VitePlusOxfmtSpec -VpCommandPath $vpCmd.Source -VpVersion $vpVersion
    if ($null -eq $spec) {
        [Console]::Error.WriteLine('Warning: Unable to determine bundled oxfmt version from global vite-plus installation.')
        return
    }

    $targetVer = $spec.OxfmtVersion
    $shimName = $IsWindows ? 'oxfmt.exe' : 'oxfmt'
    $shimPath = Join-Path $spec.VpHome "bin/$shimName"
    $currentVer = ''

    if (Test-Path -LiteralPath $shimPath -PathType Leaf) {
        $verOut = @(& $shimPath --version 2>$null)
        foreach ($line in $verOut) {
            if ([string]$line -match '(\d+\.\d+\.\d+(?:-[^\s]+)?)') {
                $currentVer = $Matches[1]
                break
            }
        }
    }

    if ((-not (Test-Path -LiteralPath $shimPath -PathType Leaf)) -or ($currentVer -ne $targetVer)) {
        $installOut = @(& vp install -g "oxfmt@$targetVer" 2>&1)
        if ($LASTEXITCODE -ne 0) {
            foreach ($line in $installOut) {
                [Console]::Error.WriteLine($line)
            }
            throw "Failed to align global oxfmt to $targetVer"
        }

        if ($currentVer) {
            Write-Output "oxfmt: $currentVer -> $targetVer"
        }
        else {
            Write-Output "oxfmt: $targetVer"
        }
    }
}

# 2. Update Node.js & Vite+ Toolchain (Active LTS via vp)
if (-not $SkipVite) {
    if (-not (Test-RequiredCommand -Name 'vp')) {
        exit 1
    }

    $upgradeOut = @(& vp upgrade 2>&1)
    foreach ($line in $upgradeOut) {
        Write-Output $line
    }

    $oldNode = (& vp node -v 2>$null)
    if (-not $oldNode) {
        $oldNode = (& node -v 2>$null)
    }
    $installOut = @(& vp env install lts 2>&1)
    $newNode = (& vp node -v 2>$null)
    if (-not $newNode) {
        $newNode = (& node -v 2>$null)
    }

    if ($oldNode -and ($oldNode -ne $newNode)) {
        foreach ($line in $installOut) {
            Write-Output $line
        }
        & vp env clean >$null 2>&1
    }

    $legacyOptDir = Join-Path $HOME '.local/opt'
    if ($IsMacOS -and (Test-Path -LiteralPath $legacyOptDir -PathType Container)) {
        Get-ChildItem -LiteralPath $legacyOptDir -Filter 'node*' -ErrorAction SilentlyContinue |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Sync-GlobalOxfmt

    Write-Output "`nnode: $newNode`n"
}

# 3. Sync Git projects in workspace in parallel
if (-not $SkipGit) {
    $repos = @(Get-ChildItem -Directory -LiteralPath $projectsDir | Where-Object {
            Test-Path -LiteralPath (Join-Path $_.FullName '.git')
        })

    $total = $repos.Count
    if ($total -gt 0) {
        $results = @($repos | ForEach-Object -Parallel {
                $dir = $_.FullName
                $name = $_.Name
                $pullOut = @(& git -C $dir pull --all 2>&1)
                $isSuccess = ($LASTEXITCODE -eq 0)
                $outText = $pullOut -join "`n"
                $isUpdated = ($outText -match 'Updating |Fast-forward')

                [PSCustomObject]@{
                    Name    = $name
                    Path    = $dir
                    Success = $isSuccess
                    Updated = $isUpdated
                    Output  = $outText
                }
            } -ThrottleLimit 6)

        $updatedCount = @($results | Where-Object { $_.Updated }).Count
        $failedCount = @($results | Where-Object { -not $_.Success }).Count
        $syncTargets = [System.Collections.Generic.List[pscustomobject]]::new()

        foreach ($res in $results) {
            if (-not $res.Success) {
                $errDetail = ($res.Output -split '\r?\n' | Where-Object { $_.Trim() } | Select-Object -First 1) ?? 'unknown error'
                [Console]::Error.WriteLine("Sync $($res.Name) failed: $errDetail")
            }
            else {
                if ($res.Updated) {
                    Write-Output "Sync $($res.Name) updated"
                }
                if (Test-WorkspaceNodeSyncTarget -RepoPath $res.Path -PullUpdated ([bool]$res.Updated)) {
                    $syncTargets.Add($res)
                }
            }
        }

        if ($syncTargets.Count -gt 0) {
            if (-not (Test-RequiredCommand -Name 'vp')) {
                exit 1
            }

            $prevVpLog = $env:VP_LOG
            $env:VP_LOG = 'error'
            try {
                foreach ($target in $syncTargets) {
                    $depOut = @(& vp -C $target.Path install --frozen-lockfile --silent 2>&1)
                    if ($LASTEXITCODE -ne 0) {
                        $depErr = ($depOut | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() } | Select-Object -First 1) ?? "exit code $LASTEXITCODE"
                        [Console]::Error.WriteLine("Sync $($target.Name) dependencies failed: $depErr")
                        $failedCount++
                    }
                    else {
                        Write-Output "Sync $($target.Name) dependencies ok"
                    }
                }
            }
            finally {
                $env:VP_LOG = $prevVpLog
            }
        }

        if ($failedCount -eq 0) {
            if ($updatedCount -eq 0) {
                Write-Output "Sync workspace repositories ok ($total projects up to date)"
            }
            else {
                $upToDate = $total - $updatedCount
                Write-Output "Sync workspace repositories ok ($updatedCount updated, $upToDate up to date)"
            }
        }
        else {
            exit 1
        }
    }
}
