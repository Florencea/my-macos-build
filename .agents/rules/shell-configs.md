---
trigger: glob
globs: "configs/bash/*, configs/zsh/*, configs/zsh/completions/*, configs/git/hooks/*, scripts/*.sh, scripts/*.ps1, scripts/windows/*, tests/verify-ps-*.ps1, tests/VerifyCommon.psm1, tests/verify-shell.ts"
description: Rules for shell configuration parity and cross-platform installer script idempotency.
---

# Shell Configuration & Cross-Platform Installer Rules

## 1. Directory Layout & Platform Installers

The repository provides automated, idempotent environment provisioning across **macOS** and **Windows 11**:

- **macOS Shell Configs**:
  - `configs/bash/`: `bash_profile`, `bashrc` (deployed to `~/.bash_profile`, `~/.bashrc`).
  - `configs/zsh/`: `zshenv`, `zprofile`, `zshrc`, `completions/_*` (deployed to `~/.zshenv`, `~/.zprofile`, `~/.zshrc`, `~/.local/share/zsh/site-functions/`).
- **macOS Installer (`scripts/install.sh`)**:
  - Written in idiomatic Zsh (`#!/bin/zsh`, `emulate -L zsh`, `set -euo pipefail`).
  - Bootstraps Homebrew, installs `powershell` (`pwsh`) and modern CLI formulas/casks, links `cli/bin/*` (excluding `*.cmd`) to `~/.local/bin/<cmd>`, and deploys `common-modern-tools`, `macos-modern-tools` and `modern-web-stack` plugins to `~/.gemini/config/plugins/`.
- **Windows Installer (`scripts/install.ps1` & `scripts/windows/`)**:
  - Must be **strictly compatible with both Windows PowerShell 5.1 (`powershell.exe`, default on fresh Windows 10/11) and PowerShell 7+ (`pwsh.exe`)** across `scripts/install.ps1` and all modules under `scripts/windows/` (`WinGetBootstrap.psm1`, `WindowsProvisioning.psm1`, `Packages.psd1`).
  - **Prohibited in `scripts/**/*.ps1` and `scripts/**/*.psm1`** (enforced via `PSUseCompatibleSyntax` with `TargetVersions = @('5.1', '7.4')`): Never use PowerShell 7-only operators (`? :`, `??`, `??=`, `?.`, `&&`, `||`, `ForEach-Object -Parallel`, `ConvertFrom-Json -AsHashtable`), unprotected `$IsWindows` reads (undefined in PS 5.1 under `Set-StrictMode`), or multi-character string `.Split('ab')` overloads.
  - Always write UTF-8 files without BOM using `[System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))` with resolved absolute paths.
  - Deploys `common-modern-tools`, `windows-modern-tools` and `modern-web-stack` plugins to `$HOME\.gemini\config\plugins\` and registers `cli\bin` in User `PATH` (pruning legacy `cli`).

---

## 2. Idempotency & Formatting Standards

- All shell configurations and installer tasks must be idempotent (safe to run repeatedly without duplicate `PATH` entries or side effects).
- Format Zsh/Bash files with: `shfmt -i 2 -ci -w <file>` (installed on both macOS via Homebrew and Windows 11 via WinGet `mvdan.shfmt`).
- Format and lint PowerShell files with `Invoke-Formatter` (normalizing `\r\n` to LF `\n` and saving as UTF-8 without BOM), verify AST syntax and `PSUseCompatibleSyntax` (`TargetVersions = @('5.1', '7.4')`), and run `Invoke-ScriptAnalyzer` across `scripts/install.ps1` and `scripts/windows/*.psm1` (`-Settings ./PSScriptAnalyzerSettings.psd1 -IncludeSuppressed`) achieving zero violations and zero `SuppressMessageAttribute` suppressions.
