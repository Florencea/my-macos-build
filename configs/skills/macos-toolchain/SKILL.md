---
name: macos-toolchain
description: Pre-installed high-performance CLI tools, web analysis tools (webread, htmlq), live query endpoints, macOS BSD constraints, shell execution rules, and idiomatic Zsh standards. Use when running terminal commands, inspecting docs, writing shell scripts, or managing macOS workflows.
compatibility: macOS Darwin, Zsh 5+, Vite+
---

# macOS Darwin Toolchain Rules & Agent Guidelines

## 1. Tool Selection Decision Tree

When selecting tools for common tasks, always follow this prioritized logic flow:

- **Web Page & Documentation Analysis**:
  - 1st Priority (Official LLM Docs) $\rightarrow$ Probe `/llms-full.txt` or `/llms.txt` via `webread --llms <url>`.
  - 2nd Priority (Clean Readability Markdown) $\rightarrow$ `webread <url>` (strips all scripts, SVGs, navbars, and headers).
  - 3rd Priority (Structured DOM Extraction) $\rightarrow$ `webread -s '<css-selector>' <url>` or `curl -sL <url> | htmlq '<selector>'`.
  - 4th Priority (Interactive Browsing) $\rightarrow$ Recommended `/browser` slash command.
  - STRICTLY FORBIDDEN to dump multi-hundred-kilobyte raw HTML into the conversation context.
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
  - HTML querying and node extraction $\rightarrow$ `htmlq`
  - YAML querying and editing $\rightarrow$ `yq` (supports in-place edits via `-i`)
  - Tabular / Big Data (CSV, Parquet, NDJSON) $\rightarrow$ `duckdb -c "<SQL>"`
- **Text Replacement**:
  - In-place text replacement $\rightarrow$ `sd 'pattern' 'replacement' <file>`. STRICTLY FORBIDDEN to use `sed`.
- **Formatting**:
  - Shell scripts (`.sh`, `.zsh`) $\rightarrow$ `shfmt -i 2 -ci -w <file>`
  - Markdown & code files $\rightarrow$ `vpx oxfmt <file>` (via Vite+)
- **Benchmarking & Workflows**:
  - Timing CLI commands or scripts $\rightarrow$ `hyperfine '<cmd>'` instead of raw `time`.
  - CI Workflow verification $\rightarrow$ `actionlint` locally before staging `.github/workflows/*.yml`.
- **Agent-Friendly Structured Outputs**:
  - Prioritize token-efficient, non-interactive formats (`--json`, `-f agent`, `--format json`, `--reporter=tap-flat`, `--no-color`, `--quiet`) over interactive progress bars, animations, or ASCII frames.

---

## 2. Scripts as Black Boxes (Pre-approved Local Helpers in `~/.local/bin`)

In accordance with Antigravity Best Practices, treat local project helper scripts (`cli/*.sh` exposed system-wide in `~/.local/bin`) as **black boxes**:

- **Check Usage First**: ALWAYS run `<command> --help` or `<command> -h` before invoking an unfamiliar tool. Do NOT read the entire script source code into the conversation context just to inspect parameters.
- **Available CLI Commands in `~/.local/bin`**:
  - `webread`: Clean, token-efficient webpage and doc reader via Jina Reader & htmlq (`webread --help`)
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

## 3. Pre-Execution Live Query & Authoritative Documentation Endpoints

Before executing unfamiliar commands or authoring configs, query these verified endpoints using `webread <url>` or `<command> --help`:

- **Vite+ Toolchain (`vp`, `vpx`, `vpr`)**:
  - LLM Full Reference: `webread --llms https://viteplus.dev` (or `https://viteplus.dev/llms-full.txt`)
  - CLI Help: `vp help` / `vp --help`
- **Oxc (`oxfmt`, `oxlint`)**:
  - LLM Reference: `webread --llms https://oxc.rs` (or `https://oxc.rs/llms.txt`)
  - CLI Help: `npx oxlint --help`, `npx oxfmt --help`
- **React**:
  - Official Reference: `webread https://react.dev/reference/react`
  - You Might Not Need an Effect: `webread https://react.dev/learn/you-might-not-need-an-effect`
- **ast-grep (`sg`)**:
  - LLM Reference: `webread --llms https://ast-grep.github.io`
  - CLI Help: `sg --help`
- **htmlq**:
  - CLI Help: `htmlq --help`
- **DuckDB**:
  - LLM Reference: `webread --llms https://duckdb.org`
  - CLI Help: `duckdb --help`
- **ripgrep (`rg`)**:
  - CLI Help: `rg --help`
- **fd**:
  - CLI Help: `fd --help`
- **bat**:
  - CLI Help: `bat --help`
- **jq**:
  - CLI Help: `jq --help`
- **yq**:
  - CLI Help: `yq --help`
- **sd**:
  - CLI Help: `sd --help`
- **actionlint**:
  - CLI Help: `actionlint -help`

---

## 4. macOS BSD Compatibility Invariants

- **`head` / `tail`**: Standard POSIX syntax only. NEVER use GNU extensions like `head -v` or `head -q`. For line ranges, use `bat --paging=never -r 1:3 <file>` or `awk 'NR>=1&&NR<=3' <file>`.
- **`grep`**: BSD grep DOES NOT support Perl-compatible regex (`-P`). ALWAYS use `rg` for advanced pattern matching.
- **`xargs`**: BSD xargs DOES NOT support `-r` (`--no-run-if-empty`). Use `fd -X` or standard POSIX `while read` loops instead.
- **`date`**: BSD date DOES NOT support GNU `date -d`. Use Node.js (`node -e "..."`) for relative date arithmetic.
- **`awk`**: Standard POSIX awk only; do NOT use GNU extensions like 3-argument `match()`.
- **`stat`**: BSD syntax. Use `stat -f "%z"` (never Linux `stat -c`).
- **Network**: Check open ports using `lsof -i :<PORT>` (never Linux `ss`).

---

## 5. Idiomatic Zsh Standards

- **Strict Header**:
  ```zsh
  #!/bin/zsh
  emulate -L zsh
  set -euo pipefail
  ```
- **1-Based Indexing**: Zsh arrays start at 1 (`$array[1]`).
- **Word Splitting**: Does not split unquoted variables by default; use `${(@s/:/)PATH}` when needed.
- **Modifiers**: Use native modifiers: `${file:A}` (abs), `${file:h}` (dir), `${file:t}` (name), `${file:r:t}` (basename).
