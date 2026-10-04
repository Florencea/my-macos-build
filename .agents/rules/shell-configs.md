---
trigger: glob
globs: "configs/bash/*, configs/zsh/*, scripts/*.sh"
description: Rules for shell configuration parity and installer script idempotency.
---

# Shell Configuration & Installer Rules

## 1. Directory Layout & Shell Parity

The repository provides unified environment parity across **Zsh** and **Bash**:

- **Directory Layout**:
  - `configs/bash/`: `bash_profile`, `bashrc` (deployed to `~/.bash_profile`, `~/.bashrc`).
  - `configs/zsh/`: `zshenv`, `zprofile`, `zshrc` (deployed to `~/.zshenv`, `~/.zprofile`, `~/.zshrc`).
- **Toolchain Alignment**:
  - **Homebrew**: Initialize `brew shellenv`.
  - **PATH Priority**: Prepend `$HOME/.local/bin` and `$HOME/.local/share/vite-plus/bin`.
  - **Node.js**: Managed globally via Vite+ (`vp` CLI, `vpr` task runner). Tasks are executed using `vp run` or `vpr`.
  - **Aliases**: Maintain common shortcuts (`nr`, `la`, `ll`).

---

## 2. Idempotency Standards

- All shell configurations and installer tasks must be idempotent (safe to run repeatedly without duplicate `$PATH` entries or side effects).
- In Zsh, enforce uniqueness using `typeset -U path PATH`.
- In Bash, check before prepending: `[[ ":$PATH:" != *":$p:"* ]]`.
- In `scripts/install.sh`, use `fetch_file` or overwrite semantics rather than unbounded appends.

---

## 3. Code Formatting

- Formatter: `shfmt`
- Command: `shfmt -i 2 -ci -w <file>`
