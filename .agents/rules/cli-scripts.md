---
trigger: glob
globs: "cli/*.ps1"
description: Rules for managing, authoring, and verifying cross-platform PowerShell 7 CLI scripts in cli/.
---

# Cross-Platform PowerShell 7 CLI Script Rules

## 1. Naming, Permissions & Strict Header

- Store executable cross-platform PowerShell 7 scripts under `cli/<command>.ps1`.
- Begin every script with the cross-platform `env -S` shebang (which runs `pwsh -NoLogo -NoProfile` on macOS/Linux and is treated as a comment on Windows):
  ```powershell
  #!/usr/bin/env -S pwsh -NoLogo -NoProfile
  ```
- Enforce strict mode and UTF-8 output encoding at the top of the script:
  ```powershell
  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
  ```
- Ensure scripts have executable permissions on macOS/Linux: `chmod +x cli/<command>.ps1`.

---

## 2. Direct `$args` Parsing & Symlink-Safe Path Resolution

- **Direct `$args` Parsing (No `[CmdletBinding()] param(...)`)**:
  - Parse CLI arguments directly from `$args` (`for ($i = 0; $i -lt $args.Count; $i++) { $arg = [string]$args[$i] ... }`) rather than `[CmdletBinding()] param(...)`.
  - Avoiding `[CmdletBinding()]` prevents PowerShell's `ParameterBinder` and CommonParameters (`-WarningAction`, `-OutVariable`, `-Verbose`, `-Debug`) from colliding with short POSIX flags (`-w`, `-o`, `-v`, `-d`).
  - Support both POSIX/GNU style (`--llms`, `--quality`, `-w`, `-h`, `--help`) and PowerShell style (`-Llms`, `-Quality`, `-Width`, `-Help`) via case-insensitive regex matching (`-match`).
- **Extensionless Shebang & Symlink Path Resolution (`CliCommon.psm1`)**:
  - When `pwsh` executes an extensionless file via shebang on macOS/Linux (e.g., `~/.local/bin/ua`), PowerShell's engine runs it as an anonymous `ScriptBlock` and leaves `$PSScriptRoot` and `$PSCommandPath` empty (`""`).
  - Furthermore, `~/.local/bin/<cmd>` is a symlink whose parent directory is `~/.local/bin`, not `cli/`.
  - Shared PowerShell CLI helpers (`Resolve-CliScriptDirectory`, `Test-RequiredCommand`, `Convert-TimeToSecond`, `ConvertTo-ValidatedInt`, `Format-ByteSize`, `Import-WindowsMachinePath`, `Invoke-YtDlpSegment`) live in `cli/helpers/CliCommon.psm1`.
  - Scripts importing `CliCommon.psm1` resolve `$scriptDir` via `$PSScriptRoot` with `[Environment]::GetCommandLineArgs()` + `[System.IO.FileInfo]::new(...).ResolveLinkTarget($true)` fallback (note: `ResolveLinkTarget` returns `FileSystemInfo`, so always use `.FullName` with `Split-Path -Parent` rather than `.DirectoryName`), then run `Import-Module -Name (Join-Path $scriptDir 'helpers' 'CliCommon.psm1') -Force`.
- **Strict CLI Flag Rejection**:
  - Reject unknown `-*` / `--*` options and unexpected positional arguments with a clear stderr message and non-zero exit code instead of silently ignoring them.
- **PowerShell 7.4+ Native Byte-Stream Piping**:
  - Pipe binary streams directly between external native commands (`& ffmpeg ... | & gifski ...`) relying on PowerShell 7.4+ default `PSNativeCommandPreserveBytePipe` rather than `sh -c` or `cmd.exe /c` string interpolation.

---

## 3. System Exposure (`~/.local/bin` on macOS & User `PATH` on Windows)

- **macOS**: All CLI scripts are exposed system-wide without the `.ps1` extension via `$HOME/.local/bin`:
  ```bash
  ln -sf "$PWD/cli/<command>.ps1" "$HOME/.local/bin/<command>"
  ```
- **Windows 11**: The `cli/` directory is registered in User `PATH` via `scripts/install.ps1`, allowing direct invocation without typing `.ps1`.

---

## 4. Cross-Platform Formatting, Static Analysis & AST Syntax Verification

- **Pre-Execution Live Documentation & Introspection Gate**:
  - Before using unfamiliar cmdlets, provider parameters, or `.NET` methods in `cli/*.ps1`, verify via `Get-Command <Cmdlet> -Syntax` (or `[Namespace.Type].GetMethods()`), or follow the two-stage GitHub Raw lookup in `modern-powershell`.
  - Always pass `-LiteralPath` (never `-Path`) to file cmdlets (`Test-Path`, `Get-Item`, `Get-ChildItem`, `Get-Content`, `Copy-Item`, `Move-Item`, `Remove-Item`, `Resolve-Path`) unless wildcard globbing is explicitly required, and pass resolved absolute paths to `.NET` `[System.IO.File]` methods.
- **Tiered Formatting, AST & Static Analysis Gates (`tests/verify-ps-*.ps1`)**:
  - Maintain `PSScriptAnalyzerSettings.psd1` at the repository root (synced with `plugins/common-modern-tools/PSScriptAnalyzerSettings.psd1`).
  - Run the Tier 1 inner-loop script after modifying any `cli/*.ps1` or `cli/helpers/*.psm1` file (enforces Stroustrup formatting + LF + UTF-8 without BOM, `Parser::ParseFile`, AST contract checks for Cmdlet parameters / `$env:PATH` / `-LiteralPath` / Tier A header):
    ```powershell
    pwsh -NoLogo -NoProfile -File tests/verify-ps-fast.ps1 --fix --path cli/<command>.ps1
    ```
  - Before finalizing changes, run the full Tier 3 gate (`vpr agent:verify:gate`, or `tests/verify-ps-lint.ps1` + `tests/verify-ps-compat.ps1` + `tests/cli.Tests.ps1` without `node_modules`) enforcing `Invoke-ScriptAnalyzer -IncludeSuppressed` = **0 violations** and cross-platform `PSUseCompatibleCommands` / `PSUseCompatibleTypes`.
  - Strictly prohibited to add `[Diagnostics.CodeAnalysis.SuppressMessageAttribute(...)]`, pass `-ExcludeRule`, or weaken `PSScriptAnalyzerSettings.psd1`.
  - Eliminate all cmdlet aliases (`select`, `where`, `dir`, `echo`, `gc`), empty catch blocks, `Write-Host` calls (use `Write-Output`, `[Console]::Error.WriteLine`, or `$Host.UI.Write` for terminal spinners, noting that `PSAvoidUsingWriteHost` also forbids `[Console]::Write`), single-line brace blocks, plural function nouns, uninitialized parallel runspace variables (`$using:`), and unapproved verbs.
