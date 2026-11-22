# Agent Guidelines & Repository Workflow Rules

Repository-specific layout, verification checks, and delivery constraints for `my-machine-build` (macOS Bash 3.2 + Fish + Go + fnm + npm). Global principles, CLI, formatting, and communication rules come from `common-modern-tools`.

## 1. Repository Architecture

- `cli/*.sh`: Single-file macOS Bash 3.2 CLI scripts (`clall`, `ebk`, `mkclp`, `mkgif`, `mmb`, `rea`, `ua`), symlinked to `~/.local/bin/<cmd>`.
- `configs/`: Fish primary shell configs (`fish/`), minimal `zsh/` and `bash/` fallback profiles, global Git hooks (`git/hooks/pre-commit.sh`), and browser extension backups.
- `plugins/`: Antigravity plugin bundles (`common-modern-tools`, `macos-modern-tools`, `modern-web-stack`), deployed to `~/.gemini/config/plugins/`.
- `scripts/install.sh`: Idempotent macOS Bash 3.2 installer for Homebrew casks/core formulas (including `go` and `shellcheck`), Fish default shell, fnm + Node.js Active LTS + strict `.npmrc`, dotfiles, CLI symlinks, and Antigravity plugins.
- `.agents/rules/`: Glob-triggered domain rules.

---

## 2. Git Delivery & Verification Protocol

- **No AI Commits**: `~/.config/git/hooks/pre-commit` rejects commits when `ANTIGRAVITY_AGENT=1`. Never run `git commit` or `git push`. After verification and formatting, run `git add <files>` and output the exact `git commit -m "type(scope): summary"` command for manual execution.
- **Verification & Formatting Shortcuts**:
  - Bash 3.2 syntax: `bash -n scripts/install.sh cli/*.sh configs/bash/bash_profile configs/bash/bashrc configs/git/hooks/pre-commit.sh`
  - Zsh syntax: `zsh -n configs/zsh/zshenv configs/zsh/zprofile configs/zsh/zshrc`
  - Static check: `shellcheck scripts/install.sh cli/*.sh configs/git/hooks/pre-commit.sh`
  - Shell format: `shfmt -i 2 -ci -w <files>` (verify with `shfmt -i 2 -ci -d <files>`)
  - Fish syntax & format: `fish -n configs/fish/**/*.fish` and `fish_indent -w configs/fish/**/*.fish`
  - JSON validation: `jq empty <file.json>`

---

## 3. Domain Rules (`.agents/rules/`)

- [`.agents/rules/cli-scripts.md`](./.agents/rules/cli-scripts.md): `cli/*.sh`
- [`.agents/rules/shell-configs.md`](./.agents/rules/shell-configs.md): `configs/fish/**, configs/bash/*, configs/zsh/*, configs/git/hooks/*, scripts/install.sh`
- [`.agents/rules/skills-authoring.md`](./.agents/rules/skills-authoring.md): `plugins/**, .agents/rules/**`
