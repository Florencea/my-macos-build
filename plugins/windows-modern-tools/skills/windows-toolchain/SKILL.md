---
name: windows-toolchain
description: Windows 11 and Windows 10 IoT LTSC PowerShell recipes for double-shell -EncodedCommand, AppX 5.1 delegation, literal child copying, Dev Drive, and Defender exclusions. Use when running or debugging Windows scripts.
compatibility: Windows 11, Windows 10 IoT LTSC, PowerShell 7+, PowerShell 5.1, Vite+
---

# Windows Platform Toolchain & Execution Recipes

For universal CLI binaries (`rg`, `fd`, `sd`, `jq`, `yq`, `duckdb`, `xsv`, `xh`, Vite+), use the `common-toolchain` skill. For PowerShell verification gates, use the `modern-powershell` skill.

---

## 1. Double-Shell Invocation & `-EncodedCommand`

In Windows PowerShell 5.1 (`powershell.exe`) host shells, invoking `pwsh.exe -Command '...'` strips internal double quotes.

- **Single-Quote Literals**:
  ```powershell
  pwsh -NoLogo -NoProfile -Command '$src = ''C:\path\to\dir''; Get-ChildItem -LiteralPath $src'
  ```
- **UTF-16LE Base64 `-EncodedCommand` (Multi-Line Blocks)**:
  ```powershell
  $script = @'
  $ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
  $src = 'C:\path\to\dir'
  $dest = 'C:\path\to\target'
  if (-not (Test-Path -LiteralPath $src)) { throw "Source missing: $src" }
  $null = New-Item -ItemType Directory -Force -Path $dest
  Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
  '@
  $bytes = [System.Text.Encoding]::Unicode.GetBytes($script)
  $b64 = [Convert]::ToBase64String($bytes)
  pwsh -NoLogo -NoProfile -EncodedCommand $b64
  ```

---

## 2. Dev Drive (ReFS) & Windows 10 IoT LTSC Matrix

- **Windows 11 (Build 22621+)**: Place workspaces and caches on Dev Drive (`E:\_Workspace`, `VP_HOME = E:\vite-plus`).
- **Windows 10 IoT LTSC**: Dev Drive (`fsutil devdrv`) and `sudo.exe` are unavailable. Use NTFS paths (`$HOME\_Workspace`, `VP_HOME = $HOME\.vite-plus`), elevate with `Start-Process -Verb RunAs`, and ensure WinGet framework packages (VCLibs, WindowsAppRuntime) and `AppXSvc` are enabled.
- **Defender Exclusions**: Exclude `pwsh.exe`, `vp.exe`, `node.exe`, `git.exe`, and `dist/`, `build/`, `node_modules/` directories from real-time scanning.

---

## 3. Windows 10 IoT LTSC: AppX Delegation to PowerShell 5.1

On Windows 10, the in-box `Appx` module throws `PlatformNotSupportedException` (`0x80131539`) under PowerShell 7. Delegate to `powershell.exe`:

```powershell
function Get-AppxPackageCompat {
    param(
        [string]$Name,
        [switch]$AllUsers
    )
    $isWin10 = ([System.Environment]::OSVersion.Version.Major -eq 10 -and [System.Environment]::OSVersion.Version.Build -lt 22000)
    if ($isWin10 -and ($PSVersionTable.PSEdition -eq 'Core')) {
        $allArg = if ($AllUsers) { '-AllUsers' } else { '' }
        $cmd = "Get-AppxPackage -Name '$Name' $allArg | Select-Object -Property Name, PackageFullName, InstallLocation | ConvertTo-Json -Compress"
        $raw = (& powershell.exe -NoLogo -NoProfile -Command $cmd 2>$null)
        if ($raw) {
            return ($raw | ConvertFrom-Json)
        }
        return $null
    }
    if ($AllUsers) {
        return (Get-AppxPackage -Name $Name -AllUsers -ErrorAction SilentlyContinue)
    }
    return (Get-AppxPackage -Name $Name -ErrorAction SilentlyContinue)
}
```

---

## 4. Safe Directory Copying & Array Unrolling Guard

Enumerate child items explicitly with `-LiteralPath` instead of unanchored wildcards (`"$src\*"`), and wrap pipeline outputs in `@(...)` before indexing:

```powershell
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($src) -or -not (Test-Path -LiteralPath $src)) {
    throw "Source path is null, whitespace, or non-existent: '$src'"
}
if ([string]::IsNullOrWhiteSpace($dest)) {
    throw "Destination path cannot be null or whitespace"
}
if (Test-Path -LiteralPath $dest) {
    Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
}
$null = New-Item -ItemType Directory -Force -Path $dest
Get-ChildItem -LiteralPath $src | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force
}

$lines = @($output | Where-Object { $_ -match 'https' })
if ($lines.Count -gt 0) {
    $firstUrl = $lines[0]
}
```
