---
name: macos-toolchain
description: macOS Darwin recipes for Zsh *(N) nullglob, shfmt verification, APFS cp -R -c cloning, Gatekeeper xattr, Darwin telemetry, defaults/PlistBuddy, and pwsh ResolveLinkTarget. Use when authoring macOS scripts or configuring Darwin settings.
compatibility: macOS Darwin, Zsh, PowerShell 7+
---

# macOS Darwin Toolchain & System Administration Recipes

For universal CLI binaries (`rg`, `fd`, `sd`, `jq`, `yq`, `duckdb`, `xsv`, `xh`, Vite+), use the `common-toolchain` skill. For PowerShell standards, use the `modern-powershell` skill.

---

## 1. Zsh Patterns & Shell Formatting

- **Nomatch Nullglob (`*(N)`)**: Append `*(N)` when globs may match zero files:
  ```zsh
  rm -f *.tmp(N)
  vp fmt docs/*.md(N)
  ```
- **Array Iteration**:
  ```zsh
  local -a files=(file1.txt file2.txt)
  for f in "${files[@]}"; do ...; done
  for f in ${(s: :)files_str}; do ...; done
  ```
- **Syntax & Format Verification**: Run `zsh -n <file>` and `shfmt -i 2 -ci -w <file>` (or `vpx tests/verify-shell.ts` in `my-machine-build`).

---

## 2. Darwin Telemetry & BSD Recipes

```bash
# Hardware, OS & network inspection (no /proc or ss)
sysctl -n hw.ncpu hw.physicalcpu hw.memsize
vm_stat
sw_vers -productVersion
lsof -nP -iTCP:3000 -sTCP:LISTEN

# BSD metadata & temp files
realpath <file>                       # Or Zsh ${file:A}
mktemp -t script.XXXXXX               # Or mktemp -d -t dir.XXXXXX
stat -f "%z %m" <file>                # Bytes and epoch mtime
```

For relative date math, run `node -e "..."` or `pwsh -NoLogo -NoProfile -Command "..."` instead of `date`.

---

## 3. APFS CoW Cloning, Quarantine & Archive Hygiene

- **Zero-Block APFS Cloning**: `cp -R -c src/ src.bak/`
- **Case-Only Git Rename**: `git mv -f file.ts File.ts`
- **Strip Gatekeeper Quarantine**: `xattr -d com.apple.quarantine <file> 2>/dev/null || true`
- **Clean Tarballs**:
  ```bash
  COPYFILE_DISABLE=1 tar -czf release.tar.gz src/
  fd -H "^\.DS_Store$" -X rm
  ```

---

## 4. System Defaults & `PlistBuddy`

```bash
defaults read com.apple.finder AppleShowAllFiles 2>/dev/null || true
defaults write com.apple.finder AppleShowAllFiles -bool true
/usr/libexec/PlistBuddy -c "Print :AppleSymbolicHotKeys:64:enabled" ~/Library/Preferences/com.apple.symbolichotkeys.plist
```

---

## 5. Extensionless `pwsh` Symlink Resolution (`~/.local/bin/*`)

When `pwsh` executes extensionless symlinks via `#!/usr/bin/env -S pwsh -NoLogo -NoProfile`, `$PSScriptRoot` is empty. Resolve the target path via `ResolveLinkTarget($true)`:

```powershell
$fileInfo = [System.IO.FileInfo]::new((Resolve-Path -LiteralPath $scriptPath).Path)
$targetInfo = $fileInfo.ResolveLinkTarget($true)
$realPath = $targetInfo ? $targetInfo.FullName : $fileInfo.FullName
```
