#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Pin and upgrade packageManager (pnpm) in package.json, sync pnpm-lock.yaml and node_modules across all local workspace projects.
.DESCRIPTION
    Cross-platform workspace pnpm synchronizer for macOS and Windows 11 (PowerShell 7).
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
upnpmv: Pin and upgrade packageManager (pnpm) in package.json, sync pnpm-lock.yaml and node_modules across all local workspace projects
Usage: upnpmv
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

Import-WindowsMachinePath

if (-not (Test-RequiredCommand -Name 'git', 'vp')) {
    exit 1
}

function Restore-ProjectManifest {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectDir,
        [bool]$LockTrackedBefore = $false,
        [bool]$LockExistedBefore = $false
    )

    & git -C $ProjectDir checkout -q -- package.json 2>$null
    if ($LockTrackedBefore) {
        & git -C $ProjectDir checkout -q -- pnpm-lock.yaml 2>$null
    }
    elseif (-not $LockExistedBefore) {
        $lockPath = Join-Path $ProjectDir 'pnpm-lock.yaml'
        if (Test-Path -LiteralPath $lockPath -PathType Leaf) {
            Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Update-ProjectPnpmVersion {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectDir,
        [Parameter(Mandatory)]
        [string]$ProjectName,
        [Parameter(Mandatory)]
        [string]$TargetVersion
    )

    $pkgPath = Join-Path $ProjectDir 'package.json'
    $pkg = Get-Content -LiteralPath $pkgPath -Raw | ConvertFrom-Json -AsHashtable
    $pmSpec = Get-PnpmPackageManagerSpec -PackageManagerField ([string]($pkg['packageManager'] ?? ''))
    $targetSpec = "pnpm@$TargetVersion"
    $lockPath = Join-Path $ProjectDir 'pnpm-lock.yaml'
    $hasLockfile = Test-Path -LiteralPath $lockPath -PathType Leaf
    $hasNodeModules = Test-Path -LiteralPath (Join-Path $ProjectDir 'node_modules') -PathType Container

    $needsPin = -not ($pmSpec.IsPnpm -and ($pmSpec.Version -eq $TargetVersion))
    if (-not $needsPin) {
        if ($hasLockfile) {
            & vp -C $ProjectDir install --frozen-lockfile --lockfile-only --silent >$null 2>&1
            if ($LASTEXITCODE -eq 0) {
                if (-not $hasNodeModules) {
                    if ($PSCmdlet.ShouldProcess($ProjectName, "Sync node_modules with $targetSpec")) {
                        $syncOut = @(& vp -C $ProjectDir install --frozen-lockfile --silent 2>&1)
                        if ($LASTEXITCODE -ne 0) {
                            $errDetail = Format-NativeErrorDetail -OutputLines $syncOut -ExitCode $LASTEXITCODE
                            [Console]::Error.WriteLine("packageManager ${ProjectName}: failed to sync node_modules ($errDetail)")
                            return $false
                        }
                        Write-Output "packageManager ${ProjectName}: $targetSpec (node_modules synced) ok"
                    }
                    return $true
                }

                Write-Output "packageManager ${ProjectName}: $targetSpec ok"
                return $true
            }
        }
    }

    if (-not $PSCmdlet.ShouldProcess($ProjectName, "Pin $targetSpec and sync lockfile/node_modules")) {
        return $true
    }

    $dirtyOut = @(& git -C $ProjectDir status --porcelain -- package.json pnpm-lock.yaml 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $errDetail = Format-NativeErrorDetail -OutputLines $dirtyOut -ExitCode $LASTEXITCODE
        [Console]::Error.WriteLine("packageManager ${ProjectName}: git status failed ($errDetail)")
        return $false
    }
    if (@($dirtyOut | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count -gt 0) {
        [Console]::Error.WriteLine("packageManager ${ProjectName}: working tree has uncommitted changes in package.json or pnpm-lock.yaml")
        return $false
    }

    & git -C $ProjectDir ls-files --error-unmatch pnpm-lock.yaml >$null 2>&1
    $lockTrackedBefore = ($LASTEXITCODE -eq 0)
    $lockExistedBefore = $hasLockfile

    if ($needsPin) {
        $pinOut = @(& vp -C $ProjectDir env pin $targetSpec --target package-manager --force --no-install 2>&1)
        if ($LASTEXITCODE -ne 0) {
            Restore-ProjectManifest -ProjectDir $ProjectDir -LockTrackedBefore $lockTrackedBefore -LockExistedBefore $lockExistedBefore
            $errDetail = Format-NativeErrorDetail -OutputLines $pinOut -ExitCode $LASTEXITCODE
            [Console]::Error.WriteLine("packageManager ${ProjectName}: failed to pin $targetSpec ($errDetail)")
            return $false
        }
    }

    $installOut = @(& vp -C $ProjectDir install --silent 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Restore-ProjectManifest -ProjectDir $ProjectDir -LockTrackedBefore $lockTrackedBefore -LockExistedBefore $lockExistedBefore
        $errDetail = Format-NativeErrorDetail -OutputLines $installOut -ExitCode $LASTEXITCODE
        [Console]::Error.WriteLine("packageManager ${ProjectName}: vp install failed ($errDetail)")
        return $false
    }

    $verifyOut = @(& vp -C $ProjectDir install --frozen-lockfile --lockfile-only --silent 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Restore-ProjectManifest -ProjectDir $ProjectDir -LockTrackedBefore $lockTrackedBefore -LockExistedBefore $lockExistedBefore
        $errDetail = Format-NativeErrorDetail -OutputLines $verifyOut -ExitCode $LASTEXITCODE
        [Console]::Error.WriteLine("packageManager ${ProjectName}: frozen lockfile verification failed ($errDetail)")
        return $false
    }

    $statusOut = @(& git -C $ProjectDir status --short -- package.json pnpm-lock.yaml 2>$null)
    $hasGitChanges = @($statusOut | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count -gt 0
    if (-not $hasGitChanges) {
        Write-Output "packageManager ${ProjectName}: $targetSpec ok"
        return $true
    }

    $filesToStage = [System.Collections.Generic.List[string]]::new()
    $filesToStage.Add('package.json')
    if (Test-Path -LiteralPath $lockPath -PathType Leaf) {
        $filesToStage.Add('pnpm-lock.yaml')
    }

    & git -C $ProjectDir add -- @filesToStage
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("packageManager ${ProjectName}: failed to stage package.json / pnpm-lock.yaml")
        return $false
    }

    $commitMsg = if (-not $needsPin) {
        "chore(pnpm): Sync lockfile for $targetSpec"
    }
    elseif ($pmSpec.IsPnpm) {
        "chore(pnpm): Update packageManager $($pmSpec.Raw) -> $targetSpec"
    }
    else {
        "chore(pnpm): Pin packageManager $targetSpec"
    }

    & git -C $ProjectDir commit -q -m $commitMsg
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("packageManager ${ProjectName}: failed to commit")
        return $false
    }

    & git -C $ProjectDir rev-parse --abbrev-ref '@{u}' >$null 2>&1
    if ($LASTEXITCODE -eq 0) {
        & git -C $ProjectDir push -q >$null 2>&1
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("packageManager ${ProjectName}: failed to push")
            return $false
        }
    }

    if ($pmSpec.IsPnpm -and $needsPin) {
        Write-Output "packageManager ${ProjectName}: $($pmSpec.Raw) -> $targetSpec ok"
    }
    else {
        Write-Output "packageManager ${ProjectName}: $targetSpec ok"
    }
    return $true
}

$env:VP_LOG = 'error'

$remoteOut = @(& vp env list-remote --json --sort desc pnpm 2>&1)
if ($LASTEXITCODE -ne 0) {
    $errDetail = Format-NativeErrorDetail -OutputLines $remoteOut -ExitCode $LASTEXITCODE
    [Console]::Error.WriteLine("Error: Failed to query remote pnpm versions ($errDetail)")
    exit 1
}

$latestPnpm = Resolve-LatestPnpmVersionFromJson -JsonText ($remoteOut -join "`n")
if ($null -eq $latestPnpm) {
    [Console]::Error.WriteLine('Error: Unable to determine latest pnpm version from Vite+.')
    exit 1
}

$targetPnpmVersion = $latestPnpm.Version
if (-not $latestPnpm.Installed) {
    $envInstallOut = @(& vp env install "pnpm@$targetPnpmVersion" 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $errDetail = Format-NativeErrorDetail -OutputLines $envInstallOut -ExitCode $LASTEXITCODE
        [Console]::Error.WriteLine("Error: Failed to install pnpm@$targetPnpmVersion ($errDetail)")
        exit 1
    }
}

Write-Output "`npnpm: v$targetPnpmVersion`n"

$projectsDir = (Resolve-Path -LiteralPath (Join-Path $scriptDir '../..')).Path
$projects = @(Get-ChildItem -Directory -LiteralPath $projectsDir | Where-Object {
        Test-PnpmWorkspaceProject -RepoPath $_.FullName
    })

$failed = $false
foreach ($proj in $projects) {
    $ok = Update-ProjectPnpmVersion -ProjectDir $proj.FullName -ProjectName $proj.Name -TargetVersion $targetPnpmVersion
    if (-not $ok) {
        $failed = $true
    }
}

if ($failed) {
    exit 1
}
