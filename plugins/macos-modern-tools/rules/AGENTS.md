# macOS Darwin Execution Rules & Environment Invariants

## 1. Shell Execution Invariants & Anti-Patterns

- **Bare Commands Only**: STRICTLY PROHIBITED to prefix commands with absolute paths (`/usr/bin/...`, `/bin/...`, `/opt/homebrew/bin/...`, `/usr/local/bin/...`). Invoke bare names (`git`, `zsh`, `pwsh`, `vp`, `node`, `rg`, `fd`, `webread`) so `$PATH` and Antigravity allowlists match without extra prompts.
- **Homebrew Resolution**: Rely on inherited `$PATH` (`/opt/homebrew/bin` on Apple Silicon, `/usr/local/bin` on Intel) without hardcoding Homebrew prefixes.
- **Strict Ban on `sed`, `eval`, and `gh`**: Use `sd` for edits and `bat` or `awk` for line slices; NEVER invoke `sed` or `eval`. Use local `git` directly; do NOT use `gh` to query remote PRs or issues.

---

## 2. Zsh Shell Traps & Execution Safety

- **Nomatch Fatal Error Guard (`*(N)`)**: Unmatched Zsh globs abort with `zsh: no matches found`. Append `*(N)` for batch patterns that may match nothing (e.g., `rm -f *.tmp(N)`).
- **Word Splitting Discipline**: Zsh does not split unquoted `$var` by default; use arrays (`local -a items=(...)`) or explicit splitting (`${(s: :)var}`).
- **Fail-Fast & Quoting**: Chain dependent commands with `&&` or set `set -euo pipefail`. Zsh `'...'` single quotes forbid `\'`; use `$'...\'...'` or double quotes when nesting single quotes.

---

## 3. macOS BSD Compatibility Traps & GNU Prohibitions

- **No `readlink -f`**: BSD `readlink` rejects `-f`. Resolve canonical paths with Zsh `${file:A}` or `realpath <file>`.
- **`mktemp` Template Required**: Bare `mktemp` fails on BSD. Always pass a template or prefix (`mktemp -t prefix.XXXXXX` or `mktemp /tmp/prefix.XXXXXX`).
- **No `/proc` Filesystem**: `/proc/cpuinfo` and `/proc/meminfo` do not exist. Use `sysctl -n hw.ncpu`, `sysctl -n hw.memsize`, `vm_stat`, `sw_vers`, and `system_profiler SPHardwareDataType`.
- **Listening Port Inspection**: Linux `ss` and `netstat -p` are unavailable; use `lsof -nP -iTCP:<PORT> -sTCP:LISTEN`.
- **BSD Tool Differences**:
  - `head`/`tail`: POSIX flags only (no `head -v`/`-q`); use `bat -r <start>:<end>` or `awk 'NR>=start&&NR<=end'` for line ranges.
  - Date arithmetic: BSD `date` lacks GNU `-d`; use `node -e "..."` or `pwsh -NoLogo -NoProfile -Command "..."`.
  - `stat`: use BSD `stat -f "%z" <file>` (never `stat -c`).
  - Regex & xargs: use `rg` (BSD grep lacks `-P`) and `fd -X` / `while read` loops (BSD xargs lacks `-r`).

---

## 4. APFS & Darwin Filesystem Guardrails

- **APFS Copy-on-Write (`cp -c`)**: Clone snapshots and backups instantaneously with zero extra blocks via `cp -R -c src/ src.bak/`.
- **Case-Insensitive Rename Trap**: APFS defaults to case-insensitive names. Rename case changes via `git mv -f a.ts A.ts` or a temporary hop (`mv a.ts a.ts.tmp && mv a.ts.tmp A.ts`).
- **Gatekeeper Quarantine**: Strip quarantine attributes before running downloaded binaries: `xattr -d com.apple.quarantine <file> 2>/dev/null || true`.
- **Archive & Finder Hygiene**: Export tarballs with `COPYFILE_DISABLE=1 tar -czf release.tar.gz <target>` to avoid `._*` AppleDouble files. Remove `.DS_Store` via `fd -H "^\.DS_Store$" -X rm`.
- **Unicode Normalization (NFD vs NFC)**: APFS stores decomposed NFD paths; normalize strings via `str.normalize('NFC')` before comparisons.

---

## 5. Destructive File Guardrails & Git Recovery

- **Defensive Path Assertion**: NEVER run `rm -rf` without verifying the target variable is non-empty and exists as a directory:
  ```zsh
  if [[ -z "${TARGET_DIR:-}" || ! -d "$TARGET_DIR" ]]; then
    echo "Error: Target directory invalid: '${TARGET_DIR:-}'" >&2
    exit 1
  fi
  rm -rf "${TARGET_DIR:?}"/*
  ```
- **Git Incident Recovery**: On accidental workspace pollution, halt edits and restore via `git clean -ffdx && git checkout -- . && git status`.

---

## 6. Darwin Utilities & PowerShell Symlink Resolution

- **Architecture & System Tools**: Check `uname -m` (`arm64` vs `x86_64`). Use `pbcopy`/`pbpaste`, `defaults write`, and `/usr/libexec/PlistBuddy`.
- **Extensionless `pwsh` Symlinks**: Scripts symlinked without `.ps1` into `~/.local/bin/<cmd>` leave `$PSScriptRoot` and `$PSCommandPath` empty. Resolve the true script directory from `[Environment]::GetCommandLineArgs()` and `[System.IO.FileInfo]::new(...).ResolveLinkTarget($true)`.
- **Case-Sensitive Env Vars**: Darwin env keys are case-sensitive (`$env:PATH` works; `$env:Path` is `$null`). Always use `$env:PATH`, `Join-Path`, `-LiteralPath`, and `[System.IO.Path]::PathSeparator`.
