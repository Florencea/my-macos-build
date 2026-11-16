#!/usr/bin/env -S pwsh -NoLogo -NoProfile
<#
.SYNOPSIS
    Unified verification gate for PowerShell, Shell, TypeScript, and Markdown assets in my-machine-build.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$fixMode = $false
$scope = 'all'
$validScopes = @('all', 'ps', 'shell', 'vp', 'cli')
for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = [string]$args[$i]
    if ($arg -eq '--fix') {
        $fixMode = $true
    }
    elseif ($arg -match '^--?scope=(.+)$') {
        $scope = $Matches[1].ToLowerInvariant()
    }
    elseif ($arg -match '^--?scope$') {
        if ($i + 1 -ge $args.Count) {
            [Console]::Error.WriteLine('Error: --scope requires a value (all|ps|shell|vp|cli)')
            exit 1
        }
        $i++
        $scope = ([string]$args[$i]).ToLowerInvariant()
    }
    elseif ($arg -match '^--?h(elp)?$') {
        Write-Output 'Usage: pwsh -NoLogo -NoProfile -File tests/verify.ps1 [--fix] [--scope all|ps|shell|vp|cli]'
        exit 0
    }
    else {
        [Console]::Error.WriteLine("Error: Unknown option $arg")
        exit 1
    }
}

if ($scope -notin $validScopes) {
    [Console]::Error.WriteLine("Error: Invalid scope '$scope'. Expected one of: $($validScopes -join ', ')")
    exit 1
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$settingsPath = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$failures = [System.Collections.Generic.List[string]]::new()

function Invoke-AnalyzerSafe {
    param(
        [Parameter(Mandatory)]
        [string]$TargetPath,
        [Parameter(Mandatory)]
        [object]$Settings
    )

    # PowerShell 7.7.0 CommandInfo.Parameters can race once during PSScriptAnalyzer cold parallel analysis.
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            return @(Invoke-ScriptAnalyzer -Path $TargetPath -Settings $Settings -IncludeSuppressed -ErrorAction Stop)
        }
        catch [System.NullReferenceException] {
            if ($attempt -eq 2) {
                throw
            }
        }
    }
}

# 1. PowerShell Formatting, AST, Compatibility, and Static Analysis
if ($scope -in @('all', 'ps')) {
    $psFiles = @(
        Get-ChildItem -LiteralPath (Join-Path $repoRoot 'cli') -Filter '*.ps1' -File
        Get-ChildItem -LiteralPath (Join-Path $repoRoot 'cli' 'helpers') -Filter '*.psm1' -File
        Get-Item -LiteralPath (Join-Path $repoRoot 'scripts' 'install.ps1')
        Get-ChildItem -LiteralPath (Join-Path $repoRoot 'tests') -Filter '*.ps1' -File
    )

    foreach ($file in $psFiles) {
        $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName) -replace '\\', '/'
        $raw = [System.IO.File]::ReadAllText($file.FullName)
        $formatted = Invoke-Formatter -ScriptDefinition $raw -Settings $settingsPath
        $expected = ($formatted -replace "`r`n", "`n").TrimEnd() + "`n"

        if ($raw -cne $expected) {
            if ($fixMode) {
                [System.IO.File]::WriteAllText($file.FullName, $expected, $utf8NoBom)
                Write-Output "[FIXED] Format $relPath"
            }
            else {
                $failures.Add("Format drift in $relPath (run with --fix)")
            }
        }

        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$parseErrors)
        if ($parseErrors) {
            $failures.Add("AST syntax errors in ${relPath}: $($parseErrors -join '; ')")
        }

        $violations = @(Invoke-AnalyzerSafe -TargetPath $file.FullName -Settings $settingsPath)
        if ($violations.Count -gt 0) {
            $violations | Format-Table RuleName, Severity, Line, Message -AutoSize
            $failures.Add("PSScriptAnalyzer reported $($violations.Count) violation(s) in $relPath")
        }
    }

    # Verify PowerShell 5.1 + 7.4 dual compatibility for scripts/install.ps1
    $installPs1 = Join-Path $repoRoot 'scripts' 'install.ps1'
    $compatSettings = @{
        IncludeRules = @('PSUseCompatibleSyntax')
        Rules        = @{
            PSUseCompatibleSyntax = @{
                Enable         = $true
                TargetVersions = @('5.1', '7.4')
            }
        }
    }
    $compatViolations = @(Invoke-ScriptAnalyzer -Path $installPs1 -Settings $compatSettings -IncludeSuppressed -ErrorAction Stop)
    if ($compatViolations.Count -gt 0) {
        $compatViolations | Format-Table RuleName, Severity, Line, Message -AutoSize
        $failures.Add('PSUseCompatibleSyntax failed on scripts/install.ps1')
    }
}

# 2. Shell Syntax and shfmt Verification
if ($scope -in @('all', 'shell')) {
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
}

# 3. Vite+ Check (Format, Type-Aware Lint, Typecheck) & Vitest Unit Tests
if ($scope -in @('all', 'vp')) {
    if (Get-Command 'vp' -ErrorAction SilentlyContinue) {
        $hasVitePlus = Test-Path -LiteralPath (Join-Path $repoRoot 'node_modules' 'vite-plus') -PathType Container
        if (-not $hasVitePlus) {
            $failures.Add("node_modules/vite-plus missing in $repoRoot (run 'vp install')")
        }
        else {
            if ($fixMode) {
                & vp -C $repoRoot check --fix
            }
            else {
                & vp -C $repoRoot check
            }
            if ($LASTEXITCODE -ne 0) {
                $failures.Add('vp check failed')
            }

            & vp -C $repoRoot run typecheck
            if ($LASTEXITCODE -ne 0) {
                $failures.Add('vp run typecheck failed')
            }

            & vp -C $repoRoot test run --reporter=tap-flat --no-color
            if ($LASTEXITCODE -ne 0) {
                $failures.Add('vp test run failed')
            }
        }
    }
}

# 4. PowerShell Unit & Contract Tests
if ($scope -in @('all', 'cli')) {
    & pwsh -NoLogo -NoProfile -File (Join-Path $repoRoot 'tests' 'cli.Tests.ps1')
    if ($LASTEXITCODE -ne 0) {
        $failures.Add('cli.Tests.ps1 failed')
    }
}

if ($failures.Count -gt 0) {
    [Console]::Error.WriteLine("Verification failed with $($failures.Count) issue(s):")
    foreach ($item in $failures) {
        [Console]::Error.WriteLine("  - $item")
    }
    exit 1
}

Write-Output 'All repository script checks and tests passed.'
