---
name: macos-toolchain
description: macOS Darwin platform execution rules, subshell stdin defense, Zsh glob nomatch guardrails, APFS Copy-on-Write cloning, BSD compatibility recipes, Apple system administration (defaults, scutil, PlistBuddy, launchservices), and PowerShell 7 symlink resolution. Use when running Darwin-specific workflows or configuring macOS system settings.
compatibility: macOS Darwin, Zsh, PowerShell 7+
---

# macOS Darwin Toolchain & System Administration Guidelines

> [!NOTE]
> For universal CLI binaries (`rg`, `fd`, `bat`, `sd`, `jq`, `yq`, `duckdb`, `xsv`, `xh`, Vite+), refer to the **`common-toolchain`** skill.
> For PowerShell authoring standards and verification pipelines, refer to the **`modern-powershell`** skill.

---

## 1. Zsh Shell Invariants & Pitfalls

- **Nomatch Fatal Error Guard (`*(N)`)**:
  - In Zsh, unmatched globs trigger a fatal error (`zsh: no matches found: <pattern>`).
  - Always append the `*(N)` nullglob qualifier when matches might be empty:
    ```zsh
    rm -f *.tmp(N)
    vpx oxfmt docs/*.md(N)
    ```
- **Word Splitting Discipline**:
  - Zsh DOES NOT split unquoted variables on spaces by default. Use native arrays or explicit splitting:
    ```zsh
    local -a files=(file1.txt file2.txt)
    for f in "${files[@]}"; do ...; done
    # Or explicit expansion modifier:
    for f in ${(s: :)files_str}; do ...; done
    ```

---

## 2. macOS BSD Compatibility Recipes

Darwin userland utilities lack GNU extensions. Follow these verified patterns:

- **Canonical Physical Paths**: BSD `readlink` lacks `-f`. Use Zsh parameter expansion `${file:A}` or `realpath <file>`.
- **Temporary Files (`mktemp`)**: Always pass `-t` or a template: `mktemp -t script.XXXXXX` or `mktemp -d -t dir.XXXXXX`.
- **File Metadata (`stat`)**: BSD syntax only: `stat -f "%z" <file>` for bytes, `stat -f "%m" <file>` for epoch modification time.
- **Line Ranges**: Use `bat --paging=never --style=plain -r N:M <file>` or `awk 'NR>=N&&NR<=M' <file>`.
- **Date Arithmetic**: Darwin `date` lacks GNU `-d`. Run relative date calculations via Node.js (`node -e "..."`) or `pwsh`.

---

## 3. Darwin System Inspection (Absence of `/proc`)

Darwin does not mount a `/proc` filesystem. Query system state using native Darwin utilities:

```bash
# CPU core counts (physical and logical)
sysctl -n hw.ncpu
sysctl -n hw.physicalcpu

# Physical RAM in bytes
sysctl -n hw.memsize

# Virtual memory statistics
vm_stat

# macOS product and build version
sw_vers -productVersion

# Non-blocking numeric socket probing (replaces ss / netstat -p)
lsof -nP -iTCP:3000 -sTCP:LISTEN
```

---

## 4. APFS Copy-on-Write (CoW) Instant Cloning & Renaming

- **Instant Zero-Byte Cloning**:
  APFS supports native block-level cloning. Use `cp -c` (or `cp -R -c` for directories) before large refactorings:
  ```bash
  cp -R -c src/ src.bak/
  ```
- **Case-Insensitive Rename Guard**:
  APFS is case-preserving but case-insensitive. In Git, force the rename:
  ```bash
  git mv -f file.ts File.ts
  ```

---

## 5. Gatekeeper Quarantine & Archive Hygiene

- **Strip Gatekeeper Quarantine**:
  Binaries downloaded via curl or browser acquire `com.apple.quarantine`, causing Gatekeeper kills (`Killed: 9`):
  ```bash
  xattr -d com.apple.quarantine <file> 2>/dev/null || true
  ```
- **AppleDouble (`._*`) Hygiene**:
  Set `COPYFILE_DISABLE=1` when packaging tarballs to prevent metadata archive pollution:
  ```bash
  COPYFILE_DISABLE=1 tar -czf release.tar.gz src/
  fd -H "^\.DS_Store$" -X rm
  ```

---

## 6. macOS System Configuration & Automation (`defaults`, `PlistBuddy`)

- **Domain Preferences (`defaults`)**:
  ```bash
  defaults read com.apple.finder AppleShowAllFiles 2>/dev/null || true
  defaults write com.apple.finder AppleShowAllFiles -bool true
  ```
- **Property List Manipulation (`/usr/libexec/PlistBuddy`)**:
  ```bash
  /usr/libexec/PlistBuddy -c "Print :AppleSymbolicHotKeys:64:enabled" ~/Library/Preferences/com.apple.symbolichotkeys.plist
  ```

---

## 7. Extensionless Shebang Symlink Resolution (`~/.local/bin/*`)

When executing extensionless PowerShell scripts symlinked into `~/.local/bin/<cmd>` via `#!/usr/bin/env -S pwsh -NoLogo -NoProfile`, `$PSScriptRoot` is empty. Always resolve physical paths via `ResolveLinkTarget($true)`:

```powershell
$fileInfo = [System.IO.FileInfo]::new((Resolve-Path -LiteralPath $scriptPath).Path)
$targetInfo = $fileInfo.ResolveLinkTarget($true)
$realPath = $targetInfo ? $targetInfo.FullName : $fileInfo.FullName
```
