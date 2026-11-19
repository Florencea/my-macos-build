---
name: macos-toolchain
description: macOS Darwin recipes for Bash 3.2 portability, Fish fish_indent/fish_add_path, Zsh *(N) nullglob, shfmt verification, APFS cp -R -c cloning, Gatekeeper xattr, Darwin telemetry, and defaults/PlistBuddy. Use when authoring macOS scripts or configuring Darwin settings.
compatibility: macOS Darwin, Bash 3.2+, Fish, Zsh
---

# macOS Darwin Toolchain & System Administration Recipes

For universal CLI binaries (`rg`, `fd`, `ast-grep`, `jq`, `yq`, `fnm`, `npm`), use the `common-toolchain` skill.

---

## 1. Bash 3.2, Fish & Zsh Patterns

- **macOS Bash 3.2 Safety**:
  - Avoid `readarray`/`mapfile` (use `while IFS= read -r line; do ...; done`), `declare -A`, `${var,,}`, and `|&`.
  - Check array length before expanding under `set -euo pipefail`: `if [[ ${#items[@]} -gt 0 ]]; then cmd "${items[@]}"; fi`.
  - Verify syntax and format via `bash -n <file>`, `shellcheck <file>`, and `shfmt -i 2 -ci -w <file>`.
- **Fish Shell**:
  - Prepend paths idempotently with `fish_add_path -g --prepend --move "$HOME/.local/bin"`.
  - Verify and format via `fish -n <file>` and `fish_indent -w <file>`.
- **Zsh Nullglob (`*(N)`)**:
  ```zsh
  rm -f *.tmp(N)
  shfmt -i 2 -ci -w configs/zsh/*
  ```

---

## 2. Darwin Telemetry & BSD Recipes

```bash
# Hardware, OS & network inspection (no /proc or ss)
sysctl -n hw.ncpu hw.physicalcpu hw.memsize
vm_stat
sw_vers -productVersion
lsof -nP -iTCP:3000 -sTCP:LISTEN

# BSD metadata & temp files
realpath <file>
mktemp -t script.XXXXXX               # Or mktemp -d -t dir.XXXXXX
stat -f "%z %m" <file>                # Bytes and epoch mtime
```

For relative date math, run `node -e "..."` instead of GNU `date -d`.

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
