# Agent Guidelines & Workflow Rules

This document outlines the development workflow, code formatting standards, and commit rules for AI agents operating in this repository.

## 1. Code Formatting Standards

Before staging or committing any files, all modified files must be formatted using the following tools:

- **Shell Scripts** (`cli/*.sh`, `scripts/*.sh`, `configs/bash/*`, `configs/zsh/*`):
  - Formatter: `shfmt`
  - Command:
    ```bash
    shfmt -i 2 -w <modified-files>
    ```
  - Configuration: 2-space indentation.

- **Fish Shell Scripts** (`configs/fish/**/*.fish`, `*.fish`):
  - Formatter: `fish_indent`
  - Command:
    ```bash
    fish_indent -w <modified-files>
    ```
  - Configuration: Fish standard formatting (bundled with `fish`).

- **Markdown Files** (`*.md`):
  - Formatter: `prettier`
  - Command:
    ```bash
    npx prettier --write <modified-files>
    ```

## 2. Git Commit Rules

- **AI Direct Commits Prohibited**:
  - The repository enforces a pre-commit hook that rejects direct commits by AI agents (`ANTIGRAVITY_AGENT=1`).
  - Agents must **never** execute `git commit`.
  - Workflow for agents:
    1. Apply code changes.
    2. Format modified files (`shfmt` for shell scripts, `fish_indent` for fish, `prettier` for markdown).
    3. Stage changes using `git add <files>`.
    4. Provide the exact `git commit -m "..."` command for manual execution by the user.

- **Commit Message Convention**:
  - Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.
  - Common types: `feat`, `fix`, `refactor`, `style`, `docs`, `chore`.
  - Common scopes: `cli`, `configs`, `docs`, `media`.
  - Examples:
    - `refactor(cli): optimize unodev with jq and remove npm and .node-version dependencies`
    - `style: format shell scripts using shfmt (-i 2)`
    - `fix(cli): scale yt-dlp source height by width`

## 3. CLI Script Management Rules

When adding, renaming, or removing CLI tools:

- **Naming & Location**:
  - Store executable shell scripts under `cli/<command>.sh`.
  - Use the shebang `#!/usr/bin/env bash` and enable strict mode (`set -o errexit`, `set -o nounset`, `set -o pipefail`).
  - Ensure the script has executable permissions: `chmod +x cli/<command>.sh`.

- **Symlinks in `~/.local/bin`**:
  - All CLI scripts are exposed system-wide without the `.sh` extension via `$HOME/.local/bin`.
  - **Adding**: Create a symlink without extension:
    ```bash
    ln -sf "$PWD/cli/<command>.sh" "$HOME/.local/bin/<command>"
    ```
  - **Removing / Renaming**: Delete the corresponding symlink:
    ```bash
    rm -f "$HOME/.local/bin/<command>"
    ```

- **Fish Completions & Installation**:
  - Provide a completion script under `configs/fish/completions/<command>.fish`.
  - Update the completion loop in `scripts/install.sh` if adding or removing a command.
  - Format completion files with `fish_indent -w`.

## 4. Multi-Shell Configuration Rules

The repository provides unified environment parity across **Fish**, **Zsh**, and **Bash**:

- **Directory Layout**:
  - `configs/bash/`: `bash_profile`, `bashrc` (deployed to `~/.bash_profile`, `~/.bashrc`).
  - `configs/zsh/`: `zprofile`, `zshrc` (deployed to `~/.zprofile`, `~/.zshrc`).
  - `configs/fish/`: `config.fish`, `conf.d/`, `functions/`, `completions/` (deployed to `~/.config/fish/`).

- **Environment & Feature Parity**:
  When updating environment variables, PATH priorities, or aliases, keep all three shells aligned:
  - **Homebrew**: Initialize `brew shellenv`.
  - **PATH Priority**: Prepend `/opt/homebrew/opt/bash/bin`, `/opt/homebrew/opt/zsh/bin`, `/opt/homebrew/opt/curl/bin`, and `$HOME/.local/bin`.
  - **Node.js**: Activate `fnm` across all shells.
  - **Aliases**: Maintain common shortcuts (`nr`, `la`, `ll`).

- **Idempotency Standards**:
  - All shell configurations and installer tasks must be idempotent (safe to run repeatedly without side effects or duplicating `$PATH`).
  - In Zsh, enforce uniqueness using `typeset -U path PATH`.
  - In Bash, check before prepending: `[[ ":$PATH:" != *":$p:"* ]]`.
  - In `scripts/install.sh`, use `fetch_file` or overwrite semantics rather than unbounded appends.
