# Agent Guidelines & Repository Workflow Rules

This document outlines the core architecture map, git delivery invariants, and modular domain rules for AI agents operating in this unified cross-platform (macOS + Windows 11) repository. Universal CLI toolchains, cross-platform safety, language, and formatting standards are inherited globally from the `common-modern-tools` plugin.

## 1. Quick Architecture Map

| Layer                    | Path                                                            | Responsibility                                                                                                                                                                                                                                                                              |
| :----------------------- | :-------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **CLI Tools**            | `cli/src/`, `cli/bin/`, `scripts/sync-cli-bins.ts`              | Vite+ (`vpx`) TypeScript CLI commands (`cli/src/commands/*.ts`), `registry.ts`, `main.ts`, hexagonal `CommandContext` ports & shared libraries (`cli/src/lib/*.ts`), and generated cross-platform shims (`cli/bin/*`, `*.cmd`)                                                              |
| **Dotfiles & Configs**   | `configs/bash/`, `configs/zsh/`, `configs/git/`                 | Shell configuration parity, completions, global Git hooks, and browser extension backups                                                                                                                                                                                                    |
| **Antigravity Plugins**  | `plugins/`                                                      | Cross-platform toolchain, platform & web stack bundles (`common-modern-tools`, `macos-modern-tools`, `windows-modern-tools`, `modern-web-stack`)                                                                                                                                            |
| **Installers**           | `scripts/install.sh`, `scripts/install.ps1`, `scripts/windows/` | Idempotent OS environment setup (Zsh for macOS; PowerShell 5.1 & 7+ compatible entry script, `Packages.psd1` manifest, and modular helpers under `scripts/windows/` for Windows 11 / 10 LTSC)                                                                                               |
| **Verification & Tests** | `tests/`                                                        | Tiered OS-bootstrap PowerShell verifiers (`verify-ps-fast.ps1`, `verify-ps-lint.ps1`, `verify-ps-compat.ps1`, `VerifyCommon.psm1`), Vite+ shell verifier (`verify-shell.ts`), and Vitest suites (`tests/unit/`, `tests/contract/`, `tests/webread-parser.test.ts`, `tests/plugins.test.ts`) |
| **Workspace Rules**      | `.agents/rules/`                                                | Modular project rules triggered via file globbing                                                                                                                                                                                                                                           |

---

## 2. Git Delivery Protocol & AI Rejection Invariant

- **AI Direct Commits Globally Prohibited**:
  - The repository enforces a global Git hook (`~/.config/git/hooks/pre-commit`) that rejects direct commits by AI agents (`ANTIGRAVITY_AGENT=1`).
  - Agents must NEVER execute `git commit` or `git push`.
  - Mandatory workflow:
    1. Apply code changes and verify (`vpr agent:verify:gate`, or standalone `tests/verify-ps-*.ps1` + `vpx tests/verify-shell.ts` for bootstrap/shell changes without `node_modules`).
    2. Format modified files (`shfmt` for shell, `vpx oxfmt` for TypeScript/markdown/JSON, `verify-ps-fast.ps1 --fix` for PowerShell).
    3. Stage changes using defensive explicit paths: `git add <files>`.
    4. Output the exact `git commit -m "type(scope): concise imperative description"` command for manual execution by the user.
- **Agent-Friendly Execution Formats**:
  - Prefer token-efficient structured flags and Vite+ verification tiers:
    - Inner loop (Tier 1): `vpr agent:verify:inner` (`typecheck`, `vp check`, `ps:fast`, `lint:shell`); PowerShell single-file loop via `vpr agent:verify:ps -- --fix --path <file>`; standalone linting via `vp lint -f agent`
    - Unit tier (Tier 2): `vpr agent:verify:unit` (Tier 1 + `ps:lint:install`, Vitest `unit`)
    - Full gate (Tier 3): `vpr agent:verify:gate` (Tier 2 + `ps:compat:install`, Vitest `contract`)
    - CLI shim generator: `vpr cli:sync-bins` (run whenever `cli/src/registry.ts` changes)
    - Vitest projects: `vp test --project unit` (`tests/unit/**/*.test.ts`, `tests/webread-parser.test.ts`), `vp test --project contract` (`tests/contract/**/*.test.ts`, `tests/plugins.test.ts`)
    - Dependencies: `vp pm list --json` (or `vp list --json`), `vp outdated --format json`
- **Project Root Settings SSOT**:
  - Maintain `PSScriptAnalyzerSettings.psd1` directly in the project root (synchronized with `plugins/common-modern-tools/PSScriptAnalyzerSettings.psd1`) for zero-configuration VS Code discovery.

---

## 3. Modular Domain Rules (`.agents/rules/`)

Domain-specific rules are modularized and automatically injected via file globbing:

- **CLI Scripts**: [`.agents/rules/cli-scripts.md`](./.agents/rules/cli-scripts.md) (triggers on `cli/src/**`, `scripts/sync-cli-bins.ts`)
- **Shell & Installers**: [`.agents/rules/shell-configs.md`](./.agents/rules/shell-configs.md) (triggers on `configs/bash/*`, `configs/zsh/*`, `scripts/*`)
- **Plugins, Skills & Rules**: [`.agents/rules/skills-authoring.md`](./.agents/rules/skills-authoring.md) (triggers on `plugins/**`)
