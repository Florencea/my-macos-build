# Windows Platform Execution Rules & Safety Guardrails (Windows 11 & Windows 10 IoT LTSC)

## 1. PowerShell 7 (`pwsh`) Execution & Double-Shell Invocation Protocol

- **Runtime Isolation**:
  - Strictly distinguish between legacy in-box **Windows PowerShell 5.1** (`powershell.exe`) and high-performance **PowerShell 7+** (`pwsh.exe`).
  - NEVER modify, replace, or symlink `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`.
  - Bootstrap scripts (`scripts/install.ps1`) targeting fresh machines must remain strictly compatible with Windows PowerShell 5.1.
- **Double-Shell Quote Defense & Invocation**:
  - Host shell on Windows is Windows PowerShell 5.1, which strips double quotes inside single quotes when launching `pwsh`. Use inner single quotes (`pwsh -NoLogo -NoProfile -Command '$p = ''C:\path'''`) or UTF-16LE `-EncodedCommand` (see `windows-toolchain` skill) with `$ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest` and UTF-8 `[Console]::OutputEncoding`.
- **Array Unrolling & Indexing Guard**: Wrap pipeline outputs in `@(...)` before indexing `[0]` or checking `.Count`.

---

## 2. Cross-Version Compatibility Boundaries (PS 5.1 vs PS 7+)

- Enforce `modern-powershell` Tier B constraints on `#Requires -Version 5.1` scripts (`scripts/install.ps1`): guard `$IsWindows` via `($PSVersionTable.PSEdition -ne 'Core') -or $IsWindows`, forbid PS 7 operators (`? :`, `??`, `?.`, `&&`, `||`), `-Parallel`, and `-AsHashtable`, and use `-split` or `[char[]]` for multi-char splits.

---

## 3. Destructive File Operation Guardrails & Defensive Assertions

- **Defensive Path Assertion Guard**:
  - `Copy-Item -Recurse`, `Remove-Item -Recurse`, and `robocopy /MIR` are STRICTLY FORBIDDEN without prior defensive path validation: verify source is not null/whitespace and exists (`Test-Path -LiteralPath $src`), and destination is not null/whitespace.
- **Ban on Ambiguous Wildcards**:
  - Never use unanchored wildcards (`"$src\*"` or `*.*`) with unverified destination paths. Explicit directory structures must be pre-created via `New-Item -ItemType Directory -Force` before copy operations.
  - Batch operations must enumerate child items explicitly using `Get-ChildItem -LiteralPath $src` and copy each item via `-LiteralPath $_.FullName` to `-Destination $dest`.

---

## 4. Dev Drive (ReFS), Windows 10 IoT LTSC Matrix & Performance

- **Dev Drive (ReFS)**:
  - Supported exclusively on Windows 11 Build 22621+. Strictly unavailable on Windows 10 IoT LTSC.
  - On Windows 11, prioritize placing package caches (`PNPM_HOME`, `VITE_CACHE_DIR`) and Git workspaces on Dev Drive (`E:\_Workspace`). On Windows 10, use standard NTFS storage without querying `fsutil devdrv`.
- **Privilege Elevation & AppX**:
  - Native `sudo.exe` requires Windows 11 Build 26052+. On Windows 10, privileged operations must use `Start-Process -Verb RunAs`.
  - On Windows 10, the in-box `Appx` module cannot run under PowerShell 7 (.NET Core). AppX queries must be delegated to Windows PowerShell 5.1 (`powershell.exe -NoLogo -NoProfile -Command "..."`).
- **Windows Defender Process Exclusion**:
  - Verify developer processes (`pwsh.exe`, `vp.exe`, `node.exe`, `git.exe`) and build directories are excluded from real-time Defender monitoring to eliminate I/O bottlenecks.
