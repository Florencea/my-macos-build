# macOS Darwin Execution Rules & Environment Invariants

## 1. Shell Execution Invariants

- **Bare Commands Only**: Never prefix commands with `/usr/bin/...`, `/bin/...`, `/opt/homebrew/bin/...`, or `/usr/local/bin/...`; rely on `$PATH`.
- **Prohibited Tools**: Never invoke `sed`, `eval`, or `gh`. Use `edit_file` or `sd` for edits and local `git` directly.
- **Zsh Guardrails**: Append `*(N)` nullglob qualifier to patterns that may match zero files (`rm -f *.tmp(N)`). Zsh does not split unquoted `$var` on spaces; use arrays (`local -a items=(...)`) or `${(s: :)var}`. Chain dependent commands with `&&` or `set -euo pipefail`.

---

## 2. BSD & Darwin System Traps

- **No GNU Flags**: BSD `readlink` rejects `-f` (use `realpath <file>` or `${file:A}`); bare `mktemp` fails (pass `-t prefix.XXXXXX`); `stat` uses `-f "%z"` (never `-c`); `date` lacks `-d` (use `node` or `pwsh`); `xargs` lacks `-r` (use `fd -X` or `while read`); `grep` lacks `-P` (use `rg`).
- **No `/proc` or `ss`**: Inspect Darwin telemetry via `sysctl -n hw.ncpu`, `sysctl -n hw.memsize`, `vm_stat`, `sw_vers`, and `lsof -nP -iTCP:<PORT> -sTCP:LISTEN`.

---

## 3. Filesystem, Recovery & PowerShell Parity

- **Destructive Path Guard**: Before `rm -rf`, assert target variables are non-empty and exist as directories (`rm -rf "${TARGET_DIR:?}"/*`). On workspace pollution, reset with `git clean -ffdx && git checkout -- . && git status`.
- **APFS Case-Insensitive Renames**: Force case-only renames via `git mv -f a.ts A.ts` or a temporary rename hop.
- **Case-Sensitive Env Keys**: Darwin environment keys are case-sensitive; always use `$env:PATH` (uppercase) in PowerShell.
- Refer to the `macos-toolchain` skill for APFS `cp -R -c` CoW cloning, Gatekeeper `xattr`, `COPYFILE_DISABLE=1`, `defaults`/`PlistBuddy`, and extensionless `pwsh` symlink resolution (`ResolveLinkTarget`).
