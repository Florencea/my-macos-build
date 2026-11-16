#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Sync and update Node.js version in package.json engines.node for all local workspace projects.
.DESCRIPTION
    Cross-platform workspace engines.node synchronizer for macOS and Windows 11 (PowerShell 7).
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

function Show-Help {
    Write-Output @'
unodev: Sync and update Node.js version in package.json engines.node for all local workspace projects
Usage: unodev
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

if (-not (Test-RequiredCommand -Name 'git', 'vp')) {
    exit 1
}

$env:VP_LOG = 'error'
$currentLocalVersion = (& vp node -v 2>$null)
if (-not $currentLocalVersion) {
    $currentLocalVersion = (& node -v 2>$null)
}
$currentLocalVersion = ([string]$currentLocalVersion).Trim()
Write-Output "`nnode: $currentLocalVersion`n"
$nodeVersion = $currentLocalVersion.TrimStart('v')

$commonModulePath = Join-Path $scriptDir 'helpers' 'CliCommon.psm1'
$nodeToolchainModulePath = Join-Path $scriptDir 'helpers' 'NodeToolchain.psm1'
$projectsDir = (Resolve-Path -LiteralPath (Join-Path $scriptDir '../..')).Path
$projects = @(Get-ChildItem -Directory -LiteralPath $projectsDir | Where-Object {
        (Test-Path -LiteralPath (Join-Path $_.FullName '.git')) -and
        (Test-Path -LiteralPath (Join-Path $_.FullName 'package.json') -PathType Leaf)
    })

$results = @($projects | ForEach-Object -Parallel {
        Import-Module -Name $using:commonModulePath -Force
        Import-Module -Name $using:nodeToolchainModulePath -Force
        $projDir = $_.FullName
        $projName = $_.Name
        $targetVer = $using:nodeVersion
        $env:VP_LOG = 'error'

        $oldVer = (& vp -C $projDir pm pkg get engines.node 2>$null)
        if ($oldVer) {
            $oldVer = ([string]$oldVer).Trim().Trim('"')
        }

        if ($oldVer -eq $targetVer) {
            Write-Output "engines.node ${projName}: $oldVer ok"
            return $true
        }

        $dirtyOut = @(& git -C $projDir status --porcelain -- package.json 2>&1)
        if ($LASTEXITCODE -ne 0) {
            $errDetail = Format-NativeErrorDetail -OutputLines $dirtyOut -ExitCode $LASTEXITCODE
            [Console]::Error.WriteLine("engines.node ${projName}: git status failed ($errDetail)")
            return $false
        }
        if (@($dirtyOut | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count -gt 0) {
            [Console]::Error.WriteLine("engines.node ${projName}: working tree has uncommitted changes in package.json")
            return $false
        }

        & vp -C $projDir pm pkg set "engines.node=$targetVer" >$null 2>&1
        if ($LASTEXITCODE -ne 0) {
            & git -C $projDir checkout -q -- package.json 2>$null
            [Console]::Error.WriteLine("engines.node ${projName}: failed to update package.json")
            return $false
        }

        $fmtRes = Format-ProjectPackageManifest -ProjectDir $projDir
        if (-not $fmtRes.Success) {
            & git -C $projDir checkout -q -- package.json 2>$null
            [Console]::Error.WriteLine("engines.node ${projName}: failed to format package.json ($($fmtRes.ErrorDetail))")
            return $false
        }

        $status = (& git -C $projDir status --short package.json 2>$null)
        if (-not $status) {
            Write-Output "engines.node ${projName}: $oldVer -> $targetVer ok"
            return $true
        }

        & git -C $projDir add -- package.json
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("engines.node ${projName}: failed to stage package.json")
            return $false
        }

        & git -C $projDir commit -q -m "chore(node): Update engines.node $oldVer -> $targetVer"
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("engines.node ${projName}: failed to commit")
            return $false
        }

        & git -C $projDir push -q >$null 2>&1
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("engines.node ${projName}: failed to push")
            return $false
        }

        Write-Output "engines.node ${projName}: $oldVer -> $targetVer ok"
        return $true
    } -ThrottleLimit 6)

if ($results -contains $false) {
    exit 1
}
