#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Tier 3 PowerShell verification: cross-platform and cross-version API compatibility profiles.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

Import-Module -Name (Join-Path $PSScriptRoot 'VerifyCommon.psm1') -Force

$targetGroup = 'all'
$validGroups = @('all', 'install')
$targetPaths = [System.Collections.Generic.List[string]]::new()

for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = [string]$args[$i]
    if ($arg -match '^--?target=(.+)$') {
        $targetGroup = $Matches[1].ToLowerInvariant()
    }
    elseif ($arg -match '^--?target$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --target requires a value (all|install)')
            exit 1
        }
        $i++
        $targetGroup = ([string]$args[$i]).ToLowerInvariant()
    }
    elseif ($arg -match '^--?path=(.+)$') {
        $targetPaths.Add($Matches[1])
    }
    elseif ($arg -match '^--?path$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --path requires a file path')
            exit 1
        }
        $i++
        $targetPaths.Add([string]$args[$i])
    }
    elseif ($arg -match '^--?h(elp)?$') {
        Write-Output 'Usage: pwsh -NoLogo -NoProfile -File tests/verify-ps-compat.ps1 [--target all|install] [--path <file>]'
        exit 0
    }
    else {
        [Console]::Error.WriteLine("Error: Unknown option $arg")
        exit 1
    }
}

if ($targetGroup -notin $validGroups) {
    [Console]::Error.WriteLine("Error: Invalid target '$targetGroup'. Expected one of: $($validGroups -join ', ')")
    exit 1
}

$repoRoot = Get-RepoRootPath
$scriptsRoot = Join-Path $repoRoot 'scripts'
$failures = [System.Collections.Generic.List[string]]::new()

$installCompatSettings = @{
    IncludeRules = @('PSUseCompatibleSyntax', 'PSUseCompatibleCommands', 'PSUseCompatibleTypes')
    Rules        = @{
        PSUseCompatibleSyntax   = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.4')
        }
        PSUseCompatibleCommands = @{
            Enable         = $true
            TargetProfiles = @(
                'win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework',
                'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'
            )
            IgnoreCommands = @('Set-ItemProperty')
        }
        PSUseCompatibleTypes    = @{
            Enable         = $true
            TargetProfiles = @(
                'win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework',
                'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'
            )
        }
    }
}

$psFiles = @(Resolve-VerifyTargetFile -RepoRoot $repoRoot -TargetPaths @($targetPaths) -TargetGroup $targetGroup)
$checkedCount = 0
foreach ($file in $psFiles) {
    $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName) -replace '\\', '/'
    if ($file.FullName.StartsWith($scriptsRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        $checkedCount++
        $installCompatViolations = @(Invoke-ScriptAnalyzerSafe -TargetPath $file.FullName -Settings $installCompatSettings)
        if ($installCompatViolations.Count -gt 0) {
            $installCompatViolations | Format-Table RuleName, Severity, Line, Message -AutoSize
            $failures.Add("PSUseCompatible* failed on $relPath")
        }
    }
}

if ($failures.Count -gt 0) {
    [Console]::Error.WriteLine("PowerShell compatibility check failed with $($failures.Count) issue(s):")
    foreach ($item in $failures) {
        [Console]::Error.WriteLine("  - $item")
    }
    exit 1
}

Write-Output "PowerShell compatibility check passed ($checkedCount file(s))."
