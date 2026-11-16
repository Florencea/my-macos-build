#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Tier 1 Shell verification: zsh -n, bash -n, and shfmt formatting checks.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

Import-Module -Name (Join-Path $PSScriptRoot 'VerifyCommon.psm1') -Force

$fixMode = $false
for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = [string]$args[$i]
    if ($arg -eq '--fix') {
        $fixMode = $true
    }
    elseif ($arg -match '^--?h(elp)?$') {
        Write-Output 'Usage: pwsh -NoLogo -NoProfile -File tests/verify-shell.ps1 [--fix]'
        exit 0
    }
    else {
        [Console]::Error.WriteLine("Error: Unknown option $arg")
        exit 1
    }
}

$repoRoot = Get-RepoRootPath
$failures = [System.Collections.Generic.List[string]]::new()

$zshFiles = @(
    (Join-Path $repoRoot 'scripts' 'install.sh'),
    (Join-Path $repoRoot 'configs' 'zsh' 'zshenv'),
    (Join-Path $repoRoot 'configs' 'zsh' 'zprofile'),
    (Join-Path $repoRoot 'configs' 'zsh' 'zshrc')
) + @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'configs' 'zsh' 'completions') -File | ForEach-Object { $_.FullName })

$bashFiles = @(
    (Join-Path $repoRoot 'configs' 'bash' 'bash_profile'),
    (Join-Path $repoRoot 'configs' 'bash' 'bashrc'),
    (Join-Path $repoRoot 'configs' 'git' 'hooks' 'pre-commit.sh')
)

if (Get-Command 'zsh' -ErrorAction SilentlyContinue) {
    foreach ($zf in $zshFiles) {
        & zsh -n $zf
        if ($LASTEXITCODE -ne 0) {
            $failures.Add("zsh -n failed for $zf")
        }
    }
}

if (Get-Command 'bash' -ErrorAction SilentlyContinue) {
    foreach ($bf in $bashFiles) {
        & bash -n $bf
        if ($LASTEXITCODE -ne 0) {
            $failures.Add("bash -n failed for $bf")
        }
    }
}

if (Get-Command 'shfmt' -ErrorAction SilentlyContinue) {
    $allShellFiles = $zshFiles + $bashFiles
    $shfmtFlag = $fixMode ? '-w' : '-d'
    & shfmt -i 2 -ci $shfmtFlag @allShellFiles
    if ($LASTEXITCODE -ne 0) {
        $failures.Add('shfmt check failed')
    }
}

if ($failures.Count -gt 0) {
    [Console]::Error.WriteLine("Shell verification failed with $($failures.Count) issue(s):")
    foreach ($item in $failures) {
        [Console]::Error.WriteLine("  - $item")
    }
    exit 1
}

Write-Output "Shell verification passed ($($zshFiles.Count + $bashFiles.Count) file(s))."
