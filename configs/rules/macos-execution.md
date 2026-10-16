---
trigger: always_on
description: macOS Darwin CLI toolchain constraints, live query mandates, web extraction rules, BSD compatibility traps, banned command rules, and agent-friendly execution formats.
---

# macOS Darwin Execution Rules & Environment Invariants

## 1. High-Performance Tool Priorities

- **Web Page & Documentation Extraction**: ALWAYS use `webread <url>` (clean, clutter-free Readability Markdown) or `curl -sL <url> | htmlq '<selector>'` (CSS selector extraction). STRICTLY FORBIDDEN to dump multi-hundred-kilobyte raw HTML or messy scripts into the agent context.
- **File Content Search**: ALWAYS use `rg` (ripgrep). NEVER use `grep -r`.
- **Path & File Traversal**: ALWAYS use `fd`. NEVER use raw `find`.
- **Directory Inspection**: ALWAYS use `tree -L 2 -I 'node_modules|.git'`.
- **File Preview & Slicing**: Prefer `bat --paging=never -r <start>:<end> <file>`.
- **Text Replacement**: STRICTLY FORBIDDEN to use `sed`. ALWAYS use `sd 'pattern' 'replacement' <file>`.
- **Structured Data**: Use `jq` for JSON, `yq` for YAML (supports in-place edits `-i`).
- **Tabular / Large Data**: Use `duckdb -c "<SQL>"` for CSV, Parquet, or NDJSON.
- **AST / Code Matching**: Use `ast-grep` (`sg`) for semantic structural search and rewrites.
- **Formatting**: Shell scripts with `shfmt -i 2 -ci -w`, Markdown files with `vpx oxfmt`.
- **CI Workflows**: ALWAYS validate GitHub workflows with `actionlint` locally before staging.
- **Agent-Friendly Output Formats**: Prioritize token-efficient, machine-readable formats (`--json`, `-f agent`, `--format json`, `--reporter=tap-flat`, `--no-color`, `--quiet`) over interactive terminal UI animations, spinners, or decorative frames.

---

## 2. Pre-Execution Live Query Mandate & No Fragile Version Pinning

- **Pre-Execution Verification Mandate**:
  - Before executing non-standard CLI flags, authoring configs, or writing code using external packages, agents MUST actively inspect live documentation or command-line help:
    1. CLI commands: Run `<tool> --help` or `<tool> -h`.
    2. Frameworks/Libraries: Inspect official `/llms.txt` or `/llms-full.txt` (e.g. `webread --llms <url>`), or fetch clean doc pages via `webread <url>`.
    3. NEVER guess CLI flags, option names, or configuration schemas from outdated model memory.
- **No Fragile Version Pinning**:
  - NEVER hardcode minor/patch version preferences or assume fixed runtime versions in rules and prompts.
  - Dynamically inspect project manifests (`package.json` `engines.node`, `dependencies`) and environment toolchain versions via `<tool> --version` or `vp toolchain`.

---

## 3. Shell Execution Anti-Patterns (STRICTLY FORBIDDEN)

- **NEVER use Package-Manager Specific Runners (`npx`, `pnpm dlx`, `bunx`, `npm run`)**: STRICTLY FORBIDDEN to invoke package-manager specific wrappers or runners. ALWAYS use the unified Vite+ toolchain: `vp` for package/runtime management, `vpx <tool>` for tool execution, and `vpr <script>` (or `vp run <script>`) for running scripts from `package.json`.
- **NEVER use Absolute Path Prefixes (Bare Commands Only)**: STRICTLY PROHIBITED to prefix CLI commands with absolute paths (e.g., `/usr/bin/git`, `/bin/zsh`, `/usr/bin/python`, `/usr/local/bin/...`, `/opt/homebrew/bin/...`). ALWAYS execute bare command names directly (e.g., `git`, `zsh`, `vp`, `node`, `rg`, `fd`, `webread`, `htmlq`) relying on `$PATH`. Prefixing absolute paths breaks Antigravity's security allowlist matching and triggers intrusive confirmation prompts.
- **NEVER use `sed`**: `sed` is completely prohibited and excluded from permission allowlists. For text replacements, use `sd`. For previewing lines, use `bat` or `awk`.
- **NEVER use `eval`** or dynamic variable execution (e.g. `cmd="..."; eval $cmd`). Execute commands directly.
- **NEVER use dynamic subshell wrappers** or ternary shell hacks just to view files (e.g. `view_file_or_head=...`).
- **NEVER access parent or sibling project directories** (e.g. `../<sibling>`) via shell commands without explicit user instruction.
- **NEVER suppress command failures** with `|| true` or `2>/dev/null` unless explicitly requested. Let errors surface cleanly.
- **Local Git Only**: Use native bare `git` (NEVER `/usr/bin/git`). Do NOT use `gh` (GitHub CLI) to query remote PRs or issues.

---

## 4. macOS BSD Compatibility Traps (Linux/GNU Forbidden)

- **`head` / `tail`**: Standard POSIX syntax only. NEVER use GNU extensions like `head -v` or `head -q`. For line ranges, use `bat --paging=never -r 1:3 <file>` or `awk 'NR>=1&&NR<=3' <file>`.
- **`grep`**: BSD grep DOES NOT support Perl-compatible regex (`-P`). ALWAYS use `rg` for advanced pattern matching.
- **`xargs`**: BSD xargs DOES NOT support `-r` (`--no-run-if-empty`). Use `fd -X` or standard POSIX `while read` loops instead.
- **`date`**: BSD date DOES NOT support GNU `date -d`. Use Node.js (`node -e "..."`) for relative date arithmetic.
- **`awk`**: Standard POSIX awk only; do NOT use GNU extensions like 3-argument `match()`.
- **`stat`**: BSD syntax. Use `stat -f "%z"` (never Linux `stat -c`).
- **Network**: Check open ports using `lsof -i :<PORT>` (never Linux `ss`).

---

## 5. Idiomatic Zsh Standards

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

---

## 6. Global Git Workflow (AI Direct Commits Prohibited)

- **Global Pre-Commit Hook Invariant**:
  - The system enforces a global Git hook (`~/.config/git/hooks/pre-commit`) via `core.hooksPath`.
  - When `ANTIGRAVITY_AGENT=1`, any direct `git commit` invocation is unconditionally rejected by the hook.
  - Individual repositories DO NOT need to declare this rule in their local `AGENTS.md`; it applies machine-wide across all workspaces.
- **Mandatory Workflow for AI Agents**:
  1. Apply code changes and verify correctness.
  2. Format modified files (`shfmt` for shell, `vpx oxfmt` for markdown/code).
  3. Stage verified changes using `git add <files>`.
  4. Output the exact `git commit -m "..."` command (following Conventional Commits) for manual execution by the user.
  5. NEVER execute `git commit` under any circumstance.
