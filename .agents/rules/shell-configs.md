---
trigger: glob
globs: "configs/fish/**, configs/bash/*, configs/zsh/*, configs/git/hooks/*, scripts/install.sh"
description: Rules for Fish primary shell, minimal Bash/Zsh profiles, and macOS installer idempotency.
---

# Shell Configuration & macOS Installer Rules

## 1. Directory Layout & Shell Roles

- **Fish Primary Shell (`configs/fish/`)**:
  - `config.fish` (interactive guard, greeting disabled, `nr`/`la`/`ll` abbreviations)
  - `conf.d/00-paths.fish` (Homebrew `shellenv`, `fish_add_path -g --prepend --move "$HOME/.local/bin"`)
  - `conf.d/fnm.fish` (`fnm env --use-on-cd --shell fish`)
  - `functions/fish_prompt.fish` and `completions/*.fish`
- **Minimal Non-Interactive Fallbacks (`configs/bash/`, `configs/zsh/`)**:
  - Keep `bash_profile`, `bashrc`, `zshenv`, `zprofile`, `zshrc` lean without third-party Zsh plugins or completion frameworks so non-interactive `/bin/zsh` and `/bin/bash` subshells locate Homebrew, `~/.local/bin`, and `fnm`.
- **macOS Installer (`scripts/install.sh`)**:
  - Written in macOS Bash 3.2 (`#!/usr/bin/env bash`, `set -euo pipefail`).
  - Bootstraps Homebrew, installs 11 Casks and 13 core CLI formulas, sets `fish` as default `UserShell`, deploys dotfiles, links `cli/*.sh` to `~/.local/bin/<cmd>`, provisions Node.js Active LTS via `fnm` with strict `.npmrc` policies, and deploys `common-modern-tools`, `macos-modern-tools`, and `modern-web-stack` plugins to `~/.gemini/config/plugins/`.

---

## 2. Idempotency & Formatting Standards

- All shell configurations and installer tasks must be idempotent (safe to run repeatedly without duplicate `PATH` entries or side effects).
- Format Bash/Zsh files with `shfmt -i 2 -ci -w <files>` and verify syntax with `bash -n`, `zsh -n`, and `shellcheck`.
- Format Fish files with `fish_indent -w <files>` and verify syntax with `fish -n`.
