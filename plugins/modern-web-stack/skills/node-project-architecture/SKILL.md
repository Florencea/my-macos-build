---
name: node-project-architecture
description: Workspace blueprint, rules splitting, .vscode config, three-tier agent:* scripts, and CI templates for Node.js/Vite+ projects. Use when scaffolding projects, trimming bloated AGENTS.md, or structuring .agents/rules.
compatibility: Node.js (Active LTS), Vite+, Antigravity
---

# Node.js Project Architecture & Rules Splitting Guidelines

Canonical workspace layout, editor integration, CI workflows, and rules splitting standards for Node.js and Vite+ applications.

## 0. Authoritative External SSOT Gateways

- **Vite+ Config & Caching**: `vp --help` -> Stage 1 `webread https://viteplus.dev/llms.txt` -> Stage 2 `webread https://viteplus.dev/guide/<topic>.md`.
- **Oxlint Rules & Config**: `vp lint --rules`, `vp lint --print-config`, `webread https://oxc.rs/llms.txt` -> `https://oxc.rs/docs/guide/usage/linter/config.md`.
- **Reusable CI Tags**: Inspect release tags in `https://github.com/Florencea/vp-actions` or run `up` / `git ls-remote --tags` before pinning workflow refs.

---

## 1. Modular Workspace Layout & Bundled Templates

Replace monolithic root `AGENTS.md` files with a lean root overview plus glob-triggered `.agents/rules/` and on-demand `.agents/skills/`. Scaffold directly from the templates under `./resources/`:

- **Root & Dependencies**:
  - `AGENTS.md` (< 3 KB overview, architecture map, verification commands): [lean-agents-template.md](./resources/lean-agents-template.md)
  - `package.json` (three-tier `agent:*` scripts & `engines.node`): [package-json-template.json](./resources/package-json-template.json)
  - `pnpm-workspace.yaml` (`saveExact: true` for deterministic installs): [pnpm-workspace-template.yaml](./resources/pnpm-workspace-template.yaml)
  - `vite.config.ts` (`run.cache`, Oxlint + `@shadcn/lint`, Oxfmt, Vitest `unit` + `e2e` projects): [vite-config-template.ts](./resources/vite-config-template.ts)
- **Editor (`.vscode/`)**:
  - `settings.json` (Oxc default formatter, `source.fixAll.oxc`, `npm.scriptRunner: "vp"`, ESLint/Prettier disabled, `routeTree.gen.ts` excluded): [vscode-settings-template.json](./resources/vscode-settings-template.json)
  - `extensions.json` (`oxc.oxc-vscode`, `VoidZero.vite-plus-extension-pack`, `bradlc.vscode-tailwindcss`, `typescriptteam.native-preview`): [vscode-extensions-template.json](./resources/vscode-extensions-template.json)
- **CI & Tooling**:
  - `.github/workflows/ci.yml`: [ci-workflow-template.yml](./resources/ci-workflow-template.yml)
  - `.agents/rules/ci-workflows.md`: [ci-workflows-rule-template.md](./resources/ci-workflows-rule-template.md)
  - `scripts/lint-tailwind.ts` (Tailwind CSS language-server diagnostics & utility sorting): [lint-tailwind-template.ts](./resources/lint-tailwind-template.ts)

Division of responsibility: global plugins (`common-modern-tools`, platform plugins, `modern-web-stack`) enforce universal CLI, runtime, TypeScript, React, Tailwind, and CI invariants; project `.agents/rules/` cover repository-specific domains (`src/server/database/**`, `src/routes/**`, `src/locales/**`).

---

## 2. Continuous Integration Invariants (`.github/`)

- **Centralized Workflows (`Florencea/vp-actions`)**: Use `vp-web-ci.yml` for web/fullstack apps (pass hooks via `inputs.pre-test-command`), `vp-electron-ci.yml` for Electron apps, or composite actions `actions/setup-vp-env` and `actions/setup-playwright` for custom pipelines.
- **Exact SemVer Pinning**: Pin every `uses:` reference to an exact SemVer tag (`@vX.Y.Z`, never `@v1` or `@v7.0`); keep tags current via `up`.
- **Concurrency, Timeouts & Caching**: Declare top-level `concurrency` (`cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}`) on `push`/`pull_request` workflows, set `timeout-minutes: 15` per job, key caches by `${{ runner.os }}-${{ runner.arch }}`, and set `retention-days: 7` on failure artifacts.
- **Local `actionlint` Gate**: Run `vpr agent:lint:ci` (`actionlint`) locally with 0 errors/warnings before staging; never embed `actionlint` steps in remote GitHub Actions workflows.

---

## 3. Three-Tier Verification Gate Architecture

- **Tier 1 (`vpr agent:verify:inner`)**: `vpr typecheck && vp lint && vpr agent:lint:tailwind` (< 2s active-edit feedback).
- **Tier 2 (`vpr agent:verify:unit`)**: `vpr agent:verify:inner && vpr agent:test:unit` (`--reporter=tap-flat --no-color`).
- **Tier 3 (`vpr agent:verify:gate` / `vpr verify`)**: Full gate adding `vp build`, `vpr agent:test:e2e` (Playwright), and `vpr check:deadcode` (`knip`).
- **Task Caching**: Vite+ caches `vpr` tasks and scripts when `run.cache: { scripts: true }` is set (`tasks: true` is enabled by default). Inspect cache hits via `vpr --last-details` or bypass via `vpr --no-cache` / `vp cache clean`.
