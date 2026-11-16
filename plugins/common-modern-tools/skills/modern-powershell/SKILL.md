---
name: modern-powershell
description: Strict cross-platform (macOS, Windows 11, Linux) and cross-version (PowerShell 7+ pwsh vs Windows PowerShell 5.1) authoring standards, pre-execution runtime introspection gate, AST and PSUseCompatibleSyntax grammar verification, VS Code Stroustrup formatting (LF, UTF-8 without BOM), and non-bypassable PSScriptAnalyzer static analysis. Use when writing, refactoring, formatting, or debugging PowerShell scripts (.ps1, .psm1, .psd1) or in-memory pwsh automation.
compatibility: PowerShell 7+ (pwsh), Windows PowerShell 5.1 (powershell.exe), PSScriptAnalyzer, macOS Darwin, Windows 11, Linux
---

# Modern PowerShell Authoring & Verification Guidelines

**CRITICAL:** Every PowerShell script (`.ps1`, `.psm1`, `.psd1`) and multi-line automation block must pass three mandatory gates on the first attempt: (1) `Invoke-Formatter` with LF (`\n`) and UTF-8 without BOM normalization, (2) AST parser grammar check (`[System.Management.Automation.Language.Parser]::ParseFile`) plus `PSUseCompatibleSyntax` for dual-version scripts, and (3) `Invoke-ScriptAnalyzer -IncludeSuppressed` yielding **0 ParseErrors, 0 Errors, 0 Warnings, and 0 Information violations**.

---

## 1. Two-Layer SSOT Verification Gate (Runtime + Official Docs)

`learn.microsoft.com` pages return empty anti-bot shells in `webread`, and local `Get-Help about_*` fails if `Update-Help` has not been run. Resolve syntax and standards through two ordered layers:

### Layer 1: Live Runtime Introspection (Zero Network Latency)

- **Cmdlet & Provider Syntax**: `pwsh -NoLogo -NoProfile -Command "Get-Command <CmdletName> -Syntax"` (probe dynamic provider parameters with `-ArgumentList 'HKLM:\'` or `$PWD.ProviderPath`).
- **.NET Method Overloads**: `pwsh -NoLogo -NoProfile -Command "[System.IO.File].GetMethods() | Where-Object Name -eq 'WriteAllText' | ForEach-Object { $_.ToString() }"`
- **Analyzer Rule Introspection**: `pwsh -NoLogo -NoProfile -Command "Get-ScriptAnalyzerRule -Name <RuleName> | Format-List *"`

### Layer 2: Two-Stage Raw GitHub Docs (Official & Style SSOT)

Fetch indexes first, then retrieve only the targeted `.md` section via `webread`:

- **Microsoft PowerShell Conceptual & Cross-Platform Docs**:
  1. Index: `webread https://raw.githubusercontent.com/MicrosoftDocs/PowerShell-Docs/main/reference/docs-conceptual/toc.yml`
  2. Targets: `dev-cross-plat/performance/script-authoring-considerations.md`, `dev-cross-plat/writing-portable-modules.md`, `whats-new/unix-support.md`, `learn/deep-dives/everything-about-null.md`, `reference/7.5/Microsoft.PowerShell.Core/About/about_Preference_Variables.md`
- **Microsoft `PSScriptAnalyzer` Rule Docs**:
  `webread https://raw.githubusercontent.com/MicrosoftDocs/PowerShell-Docs-Modules/main/reference/docs-conceptual/PSScriptAnalyzer/Rules/<RuleWithoutPSPrefix>.md` (e.g., `UseCompatibleCommands.md`)
- **PowerShell Practice & Style Guide (Community Standard)**:
  1. Index: `webread https://raw.githubusercontent.com/PoshCode/PowerShellPracticeAndStyle/master/README.md`
  2. Targets: `Best-Practices/Error-Handling.md`, `Best-Practices/Performance.md`, `Best-Practices/Security.md`, `Style-Guide/Function-Structure.md`

---

## 2. Zero-Suppression Policy & Non-Bypassable Static Analysis

- **Strict Ban on Suppression Attributes**:
  - NEVER add `[Diagnostics.CodeAnalysis.SuppressMessageAttribute(...)]`.
  - NEVER pass `-ExcludeRule` or narrow `-Severity` on the command line.
  - NEVER weaken `./PSScriptAnalyzerSettings.psd1`.
- **Structural Resolution of Violations**:
  - `PSAvoidUsingWriteHost`: Never use `Write-Host` or `[Console]::Write`. Use `Write-Output` for stdout, `[Console]::Error.WriteLine` for stderr, and `$Host.UI.Write` for in-place terminal progress.
  - `PSAvoidUsingEmptyCatchBlock`: Never leave `catch {}` empty. Log via `[Console]::Error.WriteLine` or rethrow (`throw`).
  - `PSPlaceOpenBrace` / `PSPlaceCloseBrace`: Stroustrup brace placement (`{` on same line, body indented on new line, `}` on its own line).
  - `PSUseSingularNouns` & `PSUseApprovedVerbs`: Name functions with approved verbs (`Get-Verb`) and singular nouns.
- **Project Configuration SSOT**:
  - Maintain `PSScriptAnalyzerSettings.psd1` directly in the project root to guarantee VS Code zero-configuration discovery without path conflicts in Settings Sync.

---

## 3. Cross-Version Compatibility Matrix (PS 7+ vs PS 5.1)

- **Tier A — Cross-Platform CLI Tools (`cli/*.ps1`, general automation)**:
  - Header: `#!/usr/bin/env -S pwsh -NoLogo -NoProfile` (LF, UTF-8 without BOM).
  - Modern syntax permitted: `? :`, `??`, `&&`, `||`, `ForEach-Object -Parallel`, `ConvertFrom-Json -AsHashtable`.
- **Tier B — Dual-Version Bootstrap Scripts (`scripts/install.ps1`)**:
  - Header: `#Requires -Version 5.1` (must execute on default Windows PowerShell 5.1 and PowerShell 7+).
  - Guard `$IsWindows`: `$isWin = ($PSVersionTable.PSEdition -ne 'Core') -or $IsWindows`.
  - No PS 7 operators (`? :`, `??`, `&&`, `||`). Use standard `if/else`.
  - Multi-character string split: Always use `-split` regex operator.
  - UTF-8 file output: `$utf8NoBom = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($absPath, $text, $utf8NoBom)`.

---

## 4. Cross-Platform Portability Invariants

- **Mandatory `-LiteralPath`**:
  - Wildcard brackets `[` and `]` in filenames break `-Path`. Always pass `-LiteralPath` to `Test-Path`, `Get-Item`, `Get-Content`, `Copy-Item`, `Remove-Item`.
- **.NET Working Directory Defense**:
  - Static `.NET` methods resolve relative paths against `[System.Environment]::CurrentDirectory` (which does NOT sync with `Set-Location`). Always resolve absolute paths: `Join-Path $PWD.ProviderPath 'output.json'`.
- **Case-Sensitive Environment Variables on Unix**:
  - Always use `$env:PATH` (capitalized) across scripts.
- **Pipeline Scalar Unrolling Guard**:
  - Single pipeline outputs unroll into scalar values. Always wrap in `@(...)` before indexing `[0]` or checking `.Count`.
- **Extensionless Shebang Symlink Resolution**:
  - When `pwsh` runs symlinks without extension in `~/.local/bin`, resolve physical paths via `[System.IO.FileInfo]::new(...).ResolveLinkTarget($true)`.
- **Native Command Exit Codes & Encoding**:
  - Do not set `$PSNativeCommandUseErrorActionPreference = $true` globally when calling tools with valid non-zero exit codes (`rg`, `diff`, `git status`); check `$LASTEXITCODE` explicitly or scope it to narrow `try/catch` blocks.
  - Set `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)` (and `$OutputEncoding` when piping UTF-8 strings into native executables).
- **Loop Output Suppression**:
  - Use `$null = <expr>` or `[void]<expr>` instead of `| Out-Null` inside loops to avoid pipeline overhead.

---

## 5. Three-Stage Mandatory Verification Pipeline

In repositories providing tiered PowerShell verification scripts (`tests/verify-ps-fast.ps1`, `tests/verify-ps-lint.ps1`, `tests/verify-ps-compat.ps1`), run the fast Tier 1 script during active editing and the full gate (`vpr agent:verify:gate`) before completion:

```powershell
pwsh -NoLogo -NoProfile -File tests/verify-ps-fast.ps1 --fix --path cli/command.ps1
pwsh -NoLogo -NoProfile -File tests/verify-ps-lint.ps1 --path cli/command.ps1
```

In standalone workspaces without repository verification scripts, execute all three stages directly:

```powershell
$targetFile = 'cli/command.ps1'
$settings = './PSScriptAnalyzerSettings.psd1'
$absPath = (Resolve-Path -LiteralPath $targetFile).Path

# Stage 1: VS Code Stroustrup formatting with LF & UTF-8 without BOM
$raw = [System.IO.File]::ReadAllText($absPath)
$formatted = Invoke-Formatter -ScriptDefinition $raw -Settings $settings
$normalized = ($formatted -replace "`r`n", "`n").TrimEnd() + "`n"
[System.IO.File]::WriteAllText($absPath, $normalized, [System.Text.UTF8Encoding]::new($false))

# Stage 2: AST grammar verification (and PSUseCompatibleSyntax for Tier B)
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($absPath, [ref]$null, [ref]$parseErrors)
if ($parseErrors) { throw "AST syntax error: $parseErrors" }

# Stage 3: Non-bypassable static analysis gate
$violations = @(Invoke-ScriptAnalyzer -Path $absPath -Settings $settings -IncludeSuppressed)
if ($violations.Count -gt 0) {
    $violations | Format-Table -AutoSize
    throw "PSScriptAnalyzer failed with $($violations.Count) violation(s) on $targetFile"
}
```
