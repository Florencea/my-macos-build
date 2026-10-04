---
trigger: always_on
description: macOS Darwin CLI toolchain constraints, BSD compatibility traps, and banned command rules.
---

# macOS Darwin Execution Rules & Environment Invariants

## 1. High-Performance Tool Priorities

- **File Content Search**: ALWAYS use `rg` (ripgrep). NEVER use `grep -r`.
- **Path & File Traversal**: ALWAYS use `fd`. NEVER use raw `find`.
- **Directory Inspection**: ALWAYS use `tree -L 2 -I 'node_modules|.git'`.
- **File Preview & Slicing**: Prefer `bat --paging=never -r <start>:<end> <file>`.
- **Text Replacement**: STRICTLY FORBIDDEN to use `sed`. ALWAYS use `sd 'pattern' 'replacement' <file>`.
- **Structured Data**: Use `jq` for JSON, `yq` for YAML (supports in-place edits `-i`).
- **Tabular / Large Data**: Use `duckdb -c "<SQL>"` for CSV, Parquet, or NDJSON.
- **AST / Code Matching**: Use `ast-grep` (`sg`) for semantic structural search and rewrites.
- **Formatting**: Shell scripts with `shfmt -i 2 -ci -w`, Markdown files with `vpx oxfmt`.
- **CI Workflows**: ALWAYS validate GitHub workflows with `actionlint`.

---

## 2. Shell Execution Anti-Patterns (STRICTLY FORBIDDEN)

- **NEVER use `sed`**: `sed` is completely prohibited and excluded from permission allowlists. For text replacements, use `sd`. For previewing lines, use `bat` or `awk`.
- **NEVER use `eval`** or dynamic variable execution (e.g. `cmd="..."; eval $cmd`). Execute commands directly.
- **NEVER use dynamic subshell wrappers** or ternary shell hacks just to view files (e.g. `view_file_or_head=...`).
- **NEVER access parent or sibling project directories** (e.g. `../<sibling>`) via shell commands without explicit user instruction.
- **NEVER suppress command failures** with `|| true` or `2>/dev/null` unless explicitly requested. Let errors surface cleanly.
- **Local Git Only**: Use native `/usr/bin/git`. Do NOT use `gh` (GitHub CLI) to query remote PRs or issues.

---

## 3. macOS BSD Compatibility Traps (Linux/GNU Forbidden)

- **`head` / `tail`**: Standard POSIX syntax only. NEVER use GNU extensions like `head -v` or `head -q`. For line ranges, use `bat --paging=never -r 1:3 <file>` or `awk 'NR>=1&&NR<=3' <file>`.
- **`grep`**: BSD grep DOES NOT support Perl-compatible regex (`-P`). ALWAYS use `rg` for advanced pattern matching.
- **`xargs`**: BSD xargs DOES NOT support `-r` (`--no-run-if-empty`). Use `fd -X` or standard POSIX `while read` loops instead.
- **`date`**: BSD date DOES NOT support GNU `date -d`. Use Node.js (`node -e "..."`) for relative date arithmetic.
- **`awk`**: Standard POSIX awk only; do NOT use GNU extensions like 3-argument `match()`.
- **`stat`**: BSD syntax. Use `stat -f "%z"` (never Linux `stat -c`).
- **Network**: Check open ports using `lsof -i :<PORT>` (never Linux `ss`).

---

## 4. Idiomatic Zsh Standards

- **Strict Header**: Always begin Zsh scripts with:
  ```zsh
  #!/bin/zsh
  emulate -L zsh
  set -euo pipefail
  ```
- **Indexing**: Remember Zsh arrays are **1-based** (`$arr[1]` is the first item).
- **Word Splitting**: Zsh does NOT split unquoted variables on whitespace by default. Use parameter expansion flags like `"${(@s/:/)PATH}"` when splitting is needed.
- **Path Resolution**: Prefer native Zsh modifiers: `${file:A}` (abs), `${file:h}` (dir), `${file:t}` (name), `${file:e}` (ext), `${file:r:t}` (basename).
- **Glob Qualifiers**: Native qualifiers: `*(.)` (files), `*(/)` (dirs), `*(N)` (nullglob), `*(om)` (by mtime).
