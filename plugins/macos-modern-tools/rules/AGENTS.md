# macOS Darwin Execution Rules & Environment Invariants

## 1. Shell Execution Invariants

- **Bare Commands Only**: Never prefix commands with `/usr/bin/...`, `/bin/...`, `/opt/homebrew/bin/...`, or `/usr/local/bin/...`; rely on `$PATH`.
- **Prohibited Tools**: Never invoke `sed`, `eval`, or `gh`. Use `edit_file` for file edits and local `git` directly.
- **Bash 3.2 Portability**: macOS ships `/bin/bash` 3.2. Avoid Bash 4+ features (`readarray`, `mapfile`, `declare -A`, `${var,,}`, `|&`, `&>>`). Guard array expansions under `set -u` (`if [[ ${#arr[@]} -gt 0 ]]`), use `shopt -s nullglob` with `while IFS= read -r`, and verify syntax via `bash -n`.
- **Fish & Zsh Guardrails**: Format Fish files via `fish_indent -w` and manage PATH via `fish_add_path`. In Zsh scripts, append `*(N)` nullglob qualifier (`rm -f *.tmp(N)`).

---

## 2. BSD & Darwin System Traps

- **No GNU Flags**: BSD `readlink` rejects `-f` (use `realpath <file>`); bare `mktemp` fails (pass `-t prefix.XXXXXX`); `stat` uses `-f "%z"` (never `-c`); `date` lacks `-d` (use `node -e`); `xargs` lacks `-r` (use `fd -X` or `while IFS= read -r`); `grep` lacks `-P` (use `rg`).
- **No `/proc` or `ss`**: Inspect Darwin telemetry via `sysctl -n hw.ncpu`, `sysctl -n hw.memsize`, `vm_stat`, `sw_vers`, and `lsof -nP -iTCP:<PORT> -sTCP:LISTEN`.

---

## 3. Filesystem & Recovery

- **Destructive Path Guard**: Before `rm -rf`, assert target variables are non-empty and exist as directories (`rm -rf "${TARGET_DIR:?}"/*`). On workspace pollution, reset with `git clean -ffdx && git checkout -- . && git status`.
- **APFS Case-Insensitive Renames**: Force case-only renames via `git mv -f a.ts A.ts` or a temporary rename hop.
- Refer to the `macos-toolchain` skill for APFS `cp -R -c` CoW cloning, Gatekeeper `xattr`, `COPYFILE_DISABLE=1`, and `defaults`/`PlistBuddy`.
