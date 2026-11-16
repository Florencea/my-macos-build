# Agent Guidelines & Repository Workflow Rules

Repository-specific layout, verification tiers, and delivery constraints for `my-machine-build` (macOS + Windows 11 / 10 IoT LTSC). Global CLI, formatting, and communication rules come from `common-modern-tools`.

## 1. Repository Architecture

- `cli/src/` & `cli/bin/`: Vite+ TypeScript CLI commands (`commands/*.ts`), `registry.ts`, `main.ts`, hexagonal `CommandContext` ports (`lib/*.ts`), and generated shims (`cli/bin/*`, `*.cmd` via `vpr cli:sync-bins`).
- `configs/`: Shell parity (`bash/`, `zsh/`, `zsh/completions/`), global Git hooks (`git/hooks/`), and browser extension backups.
- `plugins/`: Antigravity plugin bundles (`common-modern-tools`, `macos-modern-tools`, `windows-modern-tools`, `modern-web-stack`).
- `scripts/`: Idempotent OS installers (`install.sh` Zsh for macOS; `install.ps1` + `windows/` PS 5.1 & 7+ modules for Windows) and `sync-cli-bins.ts`.
- `tests/`: Tiered PowerShell verifiers (`verify-ps-fast.ps1`, `verify-ps-lint.ps1`, `verify-ps-compat.ps1`, `VerifyCommon.psm1`), shell verifier (`verify-shell.ts`), and Vitest suites (`unit/`, `contract/`, `webread-parser.test.ts`, `plugins.test.ts`).
- `.agents/rules/`: Glob-triggered domain rules.

---

## 2. Git Delivery & Verification Protocol

- **No AI Commits**: `~/.config/git/hooks/pre-commit` rejects commits when `ANTIGRAVITY_AGENT=1`. Never run `git commit` or `git push`. After verification and formatting, run `git add <files>` and output the exact `git commit -m "type(scope): summary"` command for manual execution.
- **Verification & Tooling Shortcuts**:
  - Tier 1 (Inner loop): `vpr agent:verify:inner` (`vp check`, `ps:fast`, `lint:shell`); single PowerShell file via `vpr agent:verify:ps -- --fix --path <file>`; structured lint via `vp lint -f agent`.
  - Tier 2 (Unit): `vpr agent:verify:unit` (Tier 1 + `ps:lint:install` + Vitest `unit`).
  - Tier 3 (Full gate): `vpr agent:verify:gate` (Tier 2 + `ps:compat:install` + Vitest `contract`).
  - CLI shims: `vpr cli:sync-bins` whenever `cli/src/registry.ts` changes.
  - Vitest projects: `vp test --project unit` and `vp test --project contract`.
  - Dependencies: `vp list --json` and `vp outdated --format json`.
- **Root Settings SSOT**: Keep root `PSScriptAnalyzerSettings.psd1` identical to `plugins/common-modern-tools/PSScriptAnalyzerSettings.psd1`.

---

## 3. Domain Rules (`.agents/rules/`)

- [`.agents/rules/cli-scripts.md`](./.agents/rules/cli-scripts.md): `cli/src/**, scripts/sync-cli-bins.ts`
- [`.agents/rules/shell-configs.md`](./.agents/rules/shell-configs.md): `configs/bash/*, configs/zsh/*, configs/zsh/completions/*, configs/git/hooks/*, scripts/*.sh, scripts/*.ps1, scripts/windows/*, tests/verify-ps-*.ps1, tests/VerifyCommon.psm1, tests/verify-shell.ts`
- [`.agents/rules/skills-authoring.md`](./.agents/rules/skills-authoring.md): `plugins/**, .agents/rules/**`
