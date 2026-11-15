#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Backup and sync browser extension configuration files from Downloads to configs/.
.DESCRIPTION
    Cross-platform browser extension config backup script for macOS and Windows 11 (PowerShell 7).
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
ebk: Backup and sync browser extension configuration files
Usage: ebk
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

if (-not (Test-RequiredCommand -Name 'git', 'jq')) {
    exit 1
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir '..')).Path
$configHome = Join-Path $repoRoot 'configs'
$downloadsDir = Join-Path $HOME 'Downloads'
$script:needPush = $false
$script:hasError = $false

function Save-CommitFile {
    param([string]$FileName)

    & git -C $configHome add -- $FileName
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("Error: git add failed for $FileName")
        $script:hasError = $true
        return
    }

    $status = (& git -C $configHome status --porcelain -- $FileName)
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("Error: git status failed for $FileName")
        $script:hasError = $true
        return
    }

    if ($status) {
        & git -C $configHome commit -q -m "feat: Update $FileName by ebk"
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("Error: git commit failed for $FileName")
            $script:hasError = $true
            return
        }
        Write-Output "Backup $FileName ok"
        $script:needPush = $true
    }
    else {
        Write-Output "Backup $FileName ok (unchanged)"
    }
}

function Backup-ConfigFile {
    param(
        [string]$Pattern,
        [string]$TargetName,
        [switch]$FormatJson
    )

    if (-not (Test-Path -LiteralPath $downloadsDir -PathType Container)) {
        return
    }

    $matchedFiles = @(Get-ChildItem -LiteralPath $downloadsDir -Filter $Pattern -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($matchedFiles.Count -eq 0) {
        return
    }

    $latest = $matchedFiles[0].FullName
    $dest = Join-Path $configHome $TargetName

    if ($FormatJson) {
        $formatted = @(& jq . $latest 2>$null)
        if ($LASTEXITCODE -eq 0 -and $formatted.Count -gt 0) {
            [System.IO.File]::WriteAllText($dest, ($formatted -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
        }
        else {
            Move-Item -LiteralPath $latest -Destination $dest -Force
        }
        foreach ($m in $matchedFiles) {
            if (Test-Path -LiteralPath $m.FullName) {
                Remove-Item -LiteralPath $m.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }
    else {
        Move-Item -LiteralPath $latest -Destination $dest -Force
        if ($matchedFiles.Count -gt 1) {
            foreach ($old in $matchedFiles[1..($matchedFiles.Count - 1)]) {
                Remove-Item -LiteralPath $old.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Save-CommitFile -FileName $TargetName
}

Backup-ConfigFile -Pattern 'my-ublock-backup*.txt' -TargetName 'ubo-config.txt'
Backup-ConfigFile -Pattern 'my-ubol-settings*.json' -TargetName 'ubol-config.json' -FormatJson
Backup-ConfigFile -Pattern 'immersive-translate-config*.json' -TargetName 'immersive-translate-config.json' -FormatJson
Backup-ConfigFile -Pattern 'tampermonkey-backup*.*' -TargetName 'tampermonkey.json' -FormatJson
Backup-ConfigFile -Pattern 'tongwentang*.json' -TargetName 'tongwentang.json' -FormatJson
Backup-ConfigFile -Pattern 'stylus*.json' -TargetName 'stylus.json' -FormatJson

if ($script:needPush) {
    & git -C $configHome push -q
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine('Error: git push failed')
        $script:hasError = $true
    }
}

if ($script:hasError) {
    exit 1
}
