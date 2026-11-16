# Windows Platform Execution Rules & Safety Guardrails

## 1. PowerShell Runtime Isolation & Double-Shell Safety

- **System Binary Protection**: Never modify, replace, or symlink `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`. Keep bootstrap scripts (`scripts/install.ps1`) strictly compatible with Windows PowerShell 5.1 (`modern-powershell` Tier B).
- **Double-Shell Quote Defense**: Host shell on Windows is Windows PowerShell 5.1, which strips double quotes inside single quotes when invoking `pwsh`. Use inner single quotes (`pwsh -NoLogo -NoProfile -Command '$p = ''C:\path'''`) or UTF-16LE `-EncodedCommand` with `$ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest` and UTF-8 `[Console]::OutputEncoding`.
- **Array Unrolling Guard**: Wrap pipeline outputs in `@(...)` before indexing `[0]` or reading `.Count`.

---

## 2. Destructive File Operation Guardrails

- **Path Assertion Guard**: Validate source (`-not [string]::IsNullOrWhiteSpace($src)` and `Test-Path -LiteralPath $src`) and destination (`-not [string]::IsNullOrWhiteSpace($dest)`) before `Copy-Item -Recurse`, `Remove-Item -Recurse`, or `robocopy /MIR`.
- **No Unanchored Wildcards**: Never pass `"$src\*"` or `*.*` to copy/delete cmdlets; enumerate children via `Get-ChildItem -LiteralPath $src` and operate on `-LiteralPath $_.FullName`.

---

## 3. Windows 11 vs Windows 10 IoT LTSC Matrix

- **Dev Drive (ReFS) & Elevation**: `fsutil devdrv` requires Windows 11 Build 22621+ and native `sudo.exe` requires Build 26052+. On Windows 10 IoT LTSC, use standard NTFS storage without querying `fsutil devdrv` and elevate via `Start-Process -Verb RunAs`.
- **AppX & Defender**: On Windows 10, `Appx` fails under PowerShell 7; delegate queries to `powershell.exe`. Keep `pwsh.exe`, `vp.exe`, `node.exe`, `git.exe`, and build directories excluded from Windows Defender.
- Refer to the `windows-toolchain` skill for `Get-AppxPackageCompat` and `-EncodedCommand` recipes.
