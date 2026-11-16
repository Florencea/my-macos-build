#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Tier 2 PowerShell verification: full PSScriptAnalyzerSettings.psd1 static analysis.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

Import-Module -Name (Join-Path $PSScriptRoot 'VerifyCommon.psm1') -Force

$fixMode = $false
$serialMode = $false
$targetGroup = 'all'
$validGroups = @('all', 'cli', 'install')
$targetPaths = [System.Collections.Generic.List[string]]::new()

for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = [string]$args[$i]
    if ($arg -eq '--fix') {
        $fixMode = $true
    }
    elseif ($arg -eq '--serial') {
        $serialMode = $true
    }
    elseif ($arg -match '^--?target=(.+)$') {
        $targetGroup = $Matches[1].ToLowerInvariant()
    }
    elseif ($arg -match '^--?target$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --target requires a value (all|cli|install)')
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
        Write-Output 'Usage: pwsh -NoLogo -NoProfile -File tests/verify-ps-lint.ps1 [--fix] [--target all|cli|install] [--path <file>] [--serial]'
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
$settingsPath = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$failures = [System.Collections.Generic.List[string]]::new()

# Isolate install.ps1 PSUseCorrectCasing cold discovery from cli/tests in parallel worker processes.
if ((-not $serialMode) -and ($targetPaths.Count -eq 0) -and ($targetGroup -eq 'all')) {
    $workerArgsCli = @('-NoLogo', '-NoProfile', '-File', $PSCommandPath, '--target', 'cli')
    $workerArgsInstall = @('-NoLogo', '-NoProfile', '-File', $PSCommandPath, '--target', 'install')
    if ($fixMode) {
        $workerArgsCli += '--fix'
        $workerArgsInstall += '--fix'
    }
    $results = Invoke-ParallelProcessTask -Tasks @(
        @{ Label = 'ps-lint-cli'; FileName = 'pwsh'; Arguments = $workerArgsCli },
        @{ Label = 'ps-lint-install'; FileName = 'pwsh'; Arguments = $workerArgsInstall }
    )
    foreach ($res in $results) {
        if (-not [string]::IsNullOrWhiteSpace($res.Stdout)) {
            Write-Output $res.Stdout.TrimEnd()
        }
        if ($res.ExitCode -ne 0) {
            if (-not [string]::IsNullOrWhiteSpace($res.Stderr)) {
                [Console]::Error.WriteLine($res.Stderr.TrimEnd())
            }
            $failures.Add("$($res.Label) failed with exit code $($res.ExitCode)")
        }
    }
    if ($failures.Count -gt 0) {
        exit 1
    }
    exit 0
}

$psFiles = @(Resolve-VerifyTargetFile -RepoRoot $repoRoot -TargetPaths @($targetPaths) -TargetGroup $targetGroup)
foreach ($file in $psFiles) {
    $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName) -replace '\\', '/'
    $violations = @(Invoke-ScriptAnalyzerSafe -TargetPath $file.FullName -Settings $settingsPath -IncludeSuppressed)
    if ($fixMode -and ($violations | Where-Object { $_.RuleName -eq 'PSUseCorrectCasing' })) {
        $raw = [System.IO.File]::ReadAllText($file.FullName)
        $formatted = Invoke-Formatter -ScriptDefinition $raw -Settings $settingsPath
        $expected = ($formatted -replace "`r`n", "`n").TrimEnd() + "`n"
        [System.IO.File]::WriteAllText($file.FullName, $expected, $utf8NoBom)
        Write-Output "[FIXED] Casing $relPath"
        $violations = @(Invoke-ScriptAnalyzerSafe -TargetPath $file.FullName -Settings $settingsPath -IncludeSuppressed)
    }
    if ($violations.Count -gt 0) {
        $violations | Format-Table RuleName, Severity, Line, Message -AutoSize
        $failures.Add("PSScriptAnalyzer reported $($violations.Count) violation(s) in $relPath")
    }
}

if ($failures.Count -gt 0) {
    [Console]::Error.WriteLine("PowerShell static analysis failed with $($failures.Count) issue(s):")
    foreach ($item in $failures) {
        [Console]::Error.WriteLine("  - $item")
    }
    exit 1
}

Write-Output "PowerShell static analysis passed ($($psFiles.Count) file(s))."
