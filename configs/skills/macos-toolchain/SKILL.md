---
name: macos-toolchain
description: Pre-installed high-performance CLI tools, pre-approved agent scripts, macOS BSD constraints, shell execution rules, and idiomatic Zsh standards. Use when running terminal commands, writing or debugging shell scripts, inspecting CLI tools, or managing development workflows on macOS Darwin.
compatibility: macOS Darwin, Zsh 5+, Vite+
---

# macOS Darwin Toolchain Rules & Agent Guidelines

## 1. Tool Selection Decision Tree

When selecting tools for common tasks, always follow this prioritized logic flow:

- **Structural Code Analysis & Refactoring**:
  - Semantic syntax matching or structural rewrites $\rightarrow$ `ast-grep` (`sg`)
  - File contents regex pattern search $\rightarrow$ `rg` (ripgrep). Avoid `grep -r`.
- **Path Traversal & File Discovery**:
  - Finding files and directories $\rightarrow$ `fd`. Avoid raw `find`.
  - Directory hierarchy visualization $\rightarrow$ `tree -L 2 -I 'node_modules|.git'`.
- **File Preview & Content Inspection**:
  - Non-interactive line-ranged previews $\rightarrow$ `bat --paging=never -r <start>:<end> <file>`.
- **Structured Data Manipulation**:
  - JSON querying and editing $\rightarrow$ `jq`
  - YAML querying and editing $\rightarrow$ `yq` (supports in-place edits via `-i`)
  - Tabular / Big Data (CSV, Parquet, NDJSON) $\rightarrow$ `duckdb -c "<SQL>"`
- **Text Replacement**:
  - In-place text replacement $\rightarrow$ `sd 'pattern' 'replacement' <file>`. STRICTLY FORBIDDEN to use `sed`.
- **Formatting**:
  - Shell scripts (`.sh`, `.zsh`) $\rightarrow$ `shfmt -i 2 -ci -w <file>`
  - Markdown (`.md`) $\rightarrow$ `vpx oxfmt <file>` (via Vite+)
- **Benchmarking & Workflows**:
  - Timing CLI commands or scripts $\rightarrow$ `hyperfine '<cmd>'` instead of raw `time`.
  - CI Workflow verification $\rightarrow$ `actionlint` when editing `.github/workflows/*.yml`.
- **Runtime & Web Toolchain**:
  - Always use modern Node.js (`.mjs`) managed globally via Vite+ (`vp`). NEVER use Python or Deno.

---

## 2. Scripts as Black Boxes (Pre-approved Local Helpers)

In accordance with Antigravity Best Practices, treat local project helper scripts (`cli/*.sh` exposed system-wide in `~/.local/bin`) as **black boxes**:

- **Check Usage First**: ALWAYS run `<command> --help` or `<command> -h` before invoking an unfamiliar tool. Do NOT read the entire script source code into the conversation context just to inspect parameters.
- **Available CLI Commands in `~/.local/bin`**:
  - `clall`: Batch clone all GitHub repositories for authenticated user (`clall --help`)
  - `ebk`: Backup and sync browser extension configs (`ebk --help`)
  - `mdig`: Query A and AAAA DNS records in parallel across resolvers (`mdig --help`)
  - `mkclp`: Clip video segment from local file or YouTube (`mkclp --help`)
  - `mkgif`: High-quality GIF generator via gifski (`mkgif --help`)
  - `mmb`: Open project workspace in VS Code (`mmb --help`)
  - `rea`: ASS subtitle combiner and cleaner for MKV (`rea --help`)
  - `ua`: Complete macOS upgrade (Homebrew, Node.js LTS via Vite+, workspace git sync) (`ua --help`)
  - `unodev`: Synchronize `engines.node` in `package.json` across workspace (`unodev --help`)
  - `up`: Interactive Node.js dependency update with spinner feedback (`up --help`)

---

## 3. Authoritative Documentation & LLM Query Endpoints

When agents need comprehensive API documentation or usage flags, query these verified authoritative endpoints using `read_url_content` or `curl -fsSL <url> | rg -C 10 '<topic>'`:

- **Vite+ Toolchain (`vp`, `vpx`, `vpr`)**:
  - Full Manual: `https://viteplus.dev/llms-full.txt` (Comprehensive reference for global CLI, task runner, caching, and shims)
  - Topic Index: `https://viteplus.dev/llms.txt`
  - Documentation: `https://viteplus.dev/guide.md`
  - CLI Help: `vp help` / `vp --help`
- **Oxc (`oxfmt`, `oxlint`)**:
  - LLM Reference: `https://oxc.rs/llms.txt` (Formatting and linting rules)
  - Coding Agents: `https://oxc.rs/docs/guide/usage/coding-agents.md`
  - CLI Help: `npx oxlint --help`, `npx oxfmt --help`
- **ast-grep (`sg`)**:
  - LLM Reference: `https://ast-grep.github.io/llms.txt`
  - Guide: `https://ast-grep.github.io/guide/`
  - CLI Help: `sg --help`
- **DuckDB**:
  - LLM Reference: `https://duckdb.org/llms.txt`
  - Documentation: `https://duckdb.org/docs/`
  - CLI Help: `duckdb --help`
- **ripgrep (`rg`)**:
  - User Guide: `https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md`
  - CLI Help: `rg --help`
- **fd**:
  - Documentation: `https://github.com/sharkdp/fd`
  - CLI Help: `fd --help`
- **bat**:
  - Documentation: `https://github.com/sharkdp/bat`
  - CLI Help: `bat --help`
- **jq**:
  - Manual: `https://jqlang.github.io/jq/manual/`
  - CLI Help: `jq --help`
- **yq (mikefarah)**:
  - Documentation: `https://mikefarah.gitbook.io/yq`
  - CLI Help: `yq --help`
- **sd**:
  - Documentation: `https://github.com/chmln/sd`
  - CLI Help: `sd --help`
- **actionlint**:
  - Usage: `https://github.com/rhysd/actionlint/blob/main/docs/usage.md`
  - CLI Help: `actionlint -help`
- **hyperfine**:
  - Documentation: `https://github.com/sharkdp/hyperfine`
  - CLI Help: `hyperfine --help`
- **shfmt**:
  - Documentation: `https://github.com/mvdan/sh`
  - CLI Help: `shfmt --help`
- **FFmpeg**:
  - Documentation: `https://ffmpeg.org/ffmpeg.html`
  - CLI Help: `ffmpeg -h`
- **yt-dlp**:
  - Usage: `https://github.com/yt-dlp/yt-dlp#usage-and-options`
  - CLI Help: `yt-dlp --help`
- **gifski**:
  - Documentation: `https://gif.ski/`
  - CLI Help: `gifski --help`

---

## 4. Frictionless Agent Script Execution (Whitelist-First)

- **Package Script Inspection**: In Node.js / web projects, ALWAYS check `package.json` for scripts prefixed with `agent:*` (e.g. `jq -r '.scripts | keys[] | select(startswith("agent:"))' package.json`) before running verification, linting, formatting, or testing commands.
- **Frictionless Whitelist Priority**: Commands matching `vp run agent:*` and `vpr agent:*` are pre-approved in the global security whitelist (`command(regex:vp run agent:.*)` and `command(regex:vpr agent:.*)`) to bypass human approval prompts. All projects are managed via Vite+ (`vp` / `vpr`); `npm run` is deprecated and removed from the whitelist. ALWAYS prefer `vp run agent:*` (or `vpr agent:*`) over direct CLI tools or non-whitelisted commands.
- **Pre-Approved Whitelist Reference**:
  - Verification: `vp run agent:verify:gate` (or `vpr agent:verify:gate`), `vp run agent:verify:inner`, `vp run agent:verify:unit`
  - Linting & Formatting: `vp run agent:format` (or `vpr agent:format`), `vp run agent:lint`, `vp run agent:lint:fix`, `vp run agent:lint:ci`, `vp run agent:lint:oxlint`, `vp run agent:lint:oxlint:fix`, `vp run agent:lint:tailwind`, `vp run agent:lint:tailwind:fix` (Note: Prettier and ESLint are deprecated; all projects standardize on Oxlint via `vp lint` and Oxfmt via `vp fmt` / `vpx oxfmt`)
  - Type Checking: `vp run agent:typecheck` (or `vpr agent:typecheck`)
  - Testing: `vp run agent:test:unit` (or `vpr agent:test:unit`), `vp run agent:test:e2e`
- **Fallback**: Only fall back to standard project scripts or direct CLI tools when no matching `agent:*` script is defined in `package.json`.

---

## 5. Local Git & Subshell Rules

- Use native `/usr/bin/git`.
- Pure local git workflows only (commit suggestions, diff, branch, rebase).
- DO NOT use `gh` (GitHub CLI). Do not query remote issues or PRs.

---

## 6. Shell Execution Anti-Patterns (STRICTLY FORBIDDEN)

- NEVER use `eval` or dynamic variable execution (e.g., `cmd="..."; eval $cmd`). Always execute commands directly.
- NEVER use dynamic subshell wrappers or ternary shell hacks just to view files (e.g., `view_file_or_head=...`).
- NEVER use `sed` under any circumstance (`sed` is excluded from permission allowlists and strictly banned). For in-place replacement, ALWAYS use `sd`. For previewing line ranges, use `bat --paging=never -r <start>:<end> <file>` or `awk`.
- NEVER access parent or sibling directory paths (e.g., `../<project>`) via shell commands without explicit user instruction.
- NEVER suppress command failures using `|| true` or `2>/dev/null` unless explicitly requested. Let errors surface cleanly.

---

## 7. Idiomatic Zsh Standards & Scripting Guidelines

- **Strict Header**: Always begin Zsh scripts with:
  ```zsh
  #!/bin/zsh
  emulate -L zsh
  set -euo pipefail
  ```
- **Indexing**: Remember Zsh arrays are **1-based** (`$arr[1]` is the first item).
- **Word Splitting**: Zsh does NOT split unquoted variables on whitespace by default. Do not rely on unquoted word splitting; use parameter expansion flags like `"${(@s/:/)PATH}"` when splitting is needed.
- **Path Resolution**: Prefer native Zsh modifiers over external forks (`dirname`, `basename`, `realpath`):
  - Absolute path: `${file:A}`
  - Directory: `${file:h}`
  - Filename only: `${file:t}`
  - Extension: `${file:e}`
  - Basename without extension: `${file:r:t}`
- **Glob Qualifiers**: Prefer native qualifiers over `find`/`sort` pipes:
  - Regular files only: `*(.)`
  - Directories only: `*(/)`
  - Nullglob (no error if empty): `*(N)`
  - Sort by modification time (newest first): `*(om)`
- **Floating-Point Math**: Use native arithmetic `(( result = 1.5 * 2.0 ))` instead of calling `bc` or `awk`.
- **Temporary Files**: Prefer process substitution `=(cmd)` when a seekable temporary file is required (Zsh automatically handles cleanup).
- **Unix Rule of Silence & Interactive CLI Feedback**: Background automation routines and unattended maintenance jobs must strictly adhere to the Unix Rule of Silence (silence on success, errors to `stderr`). However, user-facing interactive CLI commands (`cli/*.sh` such as `ua`, `up`, `clall`, `ebk`, `unodev`) MUST provide clear operational feedback, real-time command progress (e.g. `brew upgrade`), version transitions, and completion confirmations. To suppress repetitive interactive TTY banners from toolchains like Vite+, pipe commands through `cat` rather than blanket suppression (`>/dev/null 2>&1 || true`).
- **Multi-Target Batch Feedback**: When a script inspects, updates, or clones multiple user workspaces or files in batch (such as `unodev`, `clall`, or `ebk`), explicitly print per-target outcomes (`[ok]`, updated version transitions, or backed-up filenames) so the user has immediate visibility into which projects or files were affected.

---

## 8. macOS BSD Compatibility Traps (Linux/GNU Forbidden)

- `head` / `tail`: Standard POSIX syntax only. NEVER use GNU extensions like `head -v` or `head -q`. For line ranges, use `bat --paging=never -r 1:3 <file>` or `awk 'NR>=1&&NR<=3' <file>`.
- `grep`: BSD grep DOES NOT support Perl-compatible regex (`-P`). ALWAYS use `rg` for advanced pattern matching.
- `xargs`: BSD xargs DOES NOT support `-r` (`--no-run-if-empty`). Use `fd -X` or standard POSIX `while read` loops instead.
- `date`: BSD date DOES NOT support GNU `date -d`. Use Node.js (`node -e "..."`) for relative date arithmetic.
- `sed`: STRICTLY FORBIDDEN. `sed` is prohibited in agent workflows and excluded from permission allowlists. ALWAYS use `sd` for in-place text replacement, and `bat` or `awk` for line extraction.
- `awk`: Standard POSIX awk only; do NOT use GNU extensions like 3-argument `match()`.
- `stat`: BSD syntax. Use `stat -f "%z"` (never Linux `stat -c`).
- `network`: Check open ports using `lsof -i :<PORT>` (never Linux `ss`).
