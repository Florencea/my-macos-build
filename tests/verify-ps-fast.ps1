#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Tier 1 PowerShell verification: fast formatting, LF/UTF-8, AST syntax/contracts, and PS 5.1 syntax check.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

Import-Module -Name (Join-Path $PSScriptRoot 'VerifyCommon.psm1') -Force

$fixMode = $false
$targetPaths = [System.Collections.Generic.List[string]]::new()
for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = [string]$args[$i]
    if ($arg -eq '--fix') {
        $fixMode = $true
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
        Write-Output 'Usage: pwsh -NoLogo -NoProfile -File tests/verify-ps-fast.ps1 [--fix] [--path <file>]'
        exit 0
    }
    else {
        [Console]::Error.WriteLine("Error: Unknown option $arg")
        exit 1
    }
}

$repoRoot = Get-RepoRootPath
$scriptsRoot = Join-Path $repoRoot 'scripts'
$settingsPath = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$formatterSettings = Get-FormatterOnlySetting -SettingsPath $settingsPath
$psFiles = @(Resolve-VerifyTargetFile -RepoRoot $repoRoot -TargetPaths @($targetPaths) -TargetGroup 'all')
$failures = [System.Collections.Generic.List[string]]::new()

$installSyntaxSettings = @{
    IncludeRules = @('PSUseCompatibleSyntax')
    Rules        = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.4')
        }
    }
}

foreach ($file in $psFiles) {
    $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName) -replace '\\', '/'
    $raw = [System.IO.File]::ReadAllText($file.FullName)
    $formatted = Invoke-Formatter -ScriptDefinition $raw -Settings $formatterSettings
    $expected = ($formatted -replace "`r`n", "`n").TrimEnd() + "`n"

    $effectiveContent = $raw
    if ($raw -cne $expected) {
        if ($fixMode) {
            [System.IO.File]::WriteAllText($file.FullName, $expected, $utf8NoBom)
            $effectiveContent = $expected
            Write-Output "[FIXED] Format $relPath"
        }
        else {
            $failures.Add("Format drift in $relPath (run with --fix)")
        }
    }

    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$parseErrors)
    if ($parseErrors) {
        $failures.Add("AST syntax errors in ${relPath}: $($parseErrors -join '; ')")
    }
    else {
        foreach ($cf in @(Test-PowerShellAstContract -FileInfo $file -Ast $ast -RawContent $effectiveContent -RelativePath $relPath -RepoRoot $repoRoot)) {
            $failures.Add($cf)
        }
    }

    $isTierB = $file.FullName.StartsWith($scriptsRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
    if ($isTierB -and ($file.Extension -in @('.ps1', '.psm1'))) {
        $syntaxViolations = @(Invoke-ScriptAnalyzerSafe -TargetPath $file.FullName -Settings $installSyntaxSettings)
        if ($syntaxViolations.Count -gt 0) {
            $syntaxViolations | Format-Table RuleName, Severity, Line, Message -AutoSize
            $failures.Add("PSUseCompatibleSyntax failed on $relPath")
        }
    }
}

$psd1Files = @()
if ($targetPaths.Count -eq 0) {
    $psd1Files = @(Get-ChildItem -LiteralPath $scriptsRoot -Recurse -Filter '*.psd1' -File | Sort-Object FullName)
}
foreach ($dataFile in $psd1Files) {
    $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $dataFile.FullName) -replace '\\', '/'
    $raw = [System.IO.File]::ReadAllText($dataFile.FullName)
    $formatted = Invoke-Formatter -ScriptDefinition $raw -Settings $formatterSettings
    $expected = ($formatted -replace "`r`n", "`n").TrimEnd() + "`n"
    if ($raw -cne $expected) {
        if ($fixMode) {
            [System.IO.File]::WriteAllText($dataFile.FullName, $expected, $utf8NoBom)
            Write-Output "[FIXED] Format $relPath"
        }
        else {
            $failures.Add("Format drift in $relPath (run with --fix)")
        }
    }

    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($dataFile.FullName, [ref]$null, [ref]$parseErrors)
    if ($parseErrors) {
        $failures.Add("AST syntax errors in ${relPath}: $($parseErrors -join '; ')")
    }
    else {
        try {
            $null = Import-PowerShellDataFile -LiteralPath $dataFile.FullName -ErrorAction Stop
        }
        catch {
            $failures.Add("Invalid PowerShell data file ${relPath}: $($_.Exception.Message)")
        }
    }
}

if ($failures.Count -gt 0) {
    [Console]::Error.WriteLine("Tier 1 PowerShell check failed with $($failures.Count) issue(s):")
    foreach ($item in $failures) {
        [Console]::Error.WriteLine("  - $item")
    }
    exit 1
}

Write-Output "PowerShell fast check passed ($($psFiles.Count) script/module(s), $($psd1Files.Count) data file(s))."
