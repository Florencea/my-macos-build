---
name: macos-toolchain
description: Pre-installed high-performance CLI tools, pre-approved agent scripts, macOS BSD constraints, shell execution rules, and idiomatic Zsh standards
trigger: always_on
---

# macOS Darwin Toolchain Rules

## Pre-installed High-Performance CLI Tools

- Fast Search: ALWAYS use `rg` (ripgrep) for searching file contents. Avoid `grep -r`.
- Path Traversal: ALWAYS use `fd` for finding files and directories. Avoid raw `find`.
- Directory Inspection: ALWAYS use `tree -L 2 -I 'node_modules|.git'`.
- File Inspection / Slicing: Prefer `bat --paging=never -r <start>:<end> <file>` for non-interactive line-ranged previews.
- Structured Data: Use `jq` for JSON and `yq` for YAML (both query and in-place `-i` edits).
- Tabular / Big Data: Use `duckdb -c "<SQL>"` for direct SQL queries over CSV, Parquet, or NDJSON.
- Text Replacement: ALWAYS prefer `sd 'pattern' 'replacement' <file>` for in-place replacements.
- AST / Structural Code Search: Prefer `ast-grep` (`sg`) for semantic code pattern queries or structural rewrites over regex.
- Shell Script Formatting: ALWAYS format `.sh` or `.zsh` scripts using `shfmt -i 2 -ci -w <file>`.
- CI Workflow Verification: ALWAYS run `actionlint` when editing `.github/workflows/*.yml`.
- Benchmarking: ALWAYS use `hyperfine` for timing CLI commands or scripts instead of raw `time`.
- Scripting Runtime: ALWAYS use modern Node.js (`.mjs`). NEVER use Python (to avoid venv/pip breakage) or Deno.
- HTTP Requests: `curl -fsSL` and `wget` are both available.

## Frictionless Agent Script Execution (Whitelist-First)

- Package Script Inspection: In Node.js / web projects, ALWAYS check `package.json` for scripts prefixed with `agent:*` (e.g. `jq -r '.scripts | keys[] | select(startswith("agent:"))' package.json`) before running verification, linting, formatting, or testing commands.
- Frictionless Whitelist Priority: Commands matching `npm run agent:*` are pre-approved in the global security whitelist to bypass human approval prompts. ALWAYS prefer them over generic commands (such as `npm test`, `npm run lint`, `npx tsc`, or direct CLI tools).
- Pre-Approved Whitelist Reference:
  - Verification: `npm run agent:verify:gate`, `npm run agent:verify:inner`, `npm run agent:verify:unit`
  - Linting & Formatting: `npm run agent:format`, `npm run agent:lint`, `npm run agent:lint:fix`, `npm run agent:lint:ci`, `npm run agent:lint:eslint`, `npm run agent:lint:eslint:fix`, `npm run agent:lint:tailwind`, `npm run agent:lint:tailwind:fix`
  - Type Checking: `npm run agent:typecheck`
  - Testing: `npm run agent:test:unit`, `npm run agent:test:e2e`
- Fallback: Only fall back to standard project scripts or direct CLI tools when no matching `agent:*` script is defined in `package.json`.

## Local Git & Subshell Rules

- Use native `/usr/bin/git`.
- Pure local git workflows only (commit suggestions, diff, branch, rebase).
- DO NOT use `gh` (GitHub CLI). Do not query remote issues or PRs.

## Shell Execution Anti-Patterns (STRICTLY FORBIDDEN)

- NEVER use `eval` or dynamic variable execution (e.g., `cmd="..."; eval $cmd`). Always execute commands directly.
- NEVER use dynamic subshell wrappers or ternary shell hacks just to view files (e.g., `view_file_or_head=...`).
- NEVER access parent or sibling directory paths (e.g., `../<project>`) via shell commands without explicit user instruction.
- NEVER suppress command failures using `|| true` or `2>/dev/null` unless explicitly requested. Let errors surface cleanly.

## Idiomatic Zsh Standards & Scripting Guidelines

- Strict Header: Always begin Zsh scripts with:
  ```zsh
  #!/bin/zsh
  set -euo pipefail
  emulate -L zsh
  ```
- Indexing: Remember Zsh arrays are **1-based** (`$arr[1]` is the first item).
- Word Splitting: Zsh does NOT split unquoted variables on whitespace by default. Do not rely on unquoted word splitting; use parameter expansion flags like `"${(@s/:/)PATH}"` when splitting is needed.
- Path Resolution: Prefer native Zsh modifiers over external forks (`dirname`, `basename`, `realpath`):
  - Absolute path: `${file:A}`
  - Directory: `${file:h}`
  - Filename only: `${file:t}`
  - Extension: `${file:e}`
  - Basename without extension: `${file:r:t}`
- Glob Qualifiers: Prefer native qualifiers over `find`/`sort` pipes:
  - Regular files only: `*(.)`
  - Directories only: `*(/)`
  - Nullglob (no error if empty): `*(N)`
  - Sort by modification time (newest first): `*(om)`
- Floating-Point Math: Use native arithmetic `(( result = 1.5 * 2.0 ))` instead of calling `bc` or `awk`.
- Temporary Files: Prefer process substitution `=(cmd)` when a seekable temporary file is required (Zsh automatically handles cleanup).

## macOS BSD Compatibility Traps (Linux/GNU Forbidden)

- `head` / `tail`: Standard POSIX syntax only. NEVER use GNU extensions like `head -v` or `head -q`. For line ranges, use `sed -n '1,3p' <file>` or `bat`.
- `grep`: BSD grep DOES NOT support Perl-compatible regex (`-P`). ALWAYS use `rg` for advanced pattern matching.
- `xargs`: BSD xargs DOES NOT support `-r` (`--no-run-if-empty`). Use `fd -X` or standard POSIX `while read` loops instead.
- `date`: BSD date DOES NOT support GNU `date -d`. Use Node.js (`node -e "..."`) for relative date arithmetic.
- `sed`: Always prefer `sd`. If `sed` must be used, use BSD syntax: `sed -i '' 's/.../.../' <file>`.
- `awk`: Standard POSIX awk only; do NOT use GNU extensions like 3-argument `match()`.
- `stat`: BSD syntax. Use `stat -f "%z"` (never Linux `stat -c`).
- Network: Check open ports using `lsof -i :<PORT>` (never Linux `ss`).
