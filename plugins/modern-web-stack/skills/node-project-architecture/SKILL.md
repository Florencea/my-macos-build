---
name: node-project-architecture
description: Workspace blueprint, rules splitting, .npmrc policy, .vscode config, three-tier agent:* scripts, and CI templates for Node.js projects. Use when scaffolding projects, trimming bloated AGENTS.md, or structuring .agents/rules.
compatibility: Node.js (Active LTS), fnm, npm, Vite, Vitest, ESLint, Prettier, Antigravity
---

# Node.js Project Architecture & Rules Splitting Guidelines

Canonical workspace layout, editor integration, strict `.npmrc` policies, CI workflows, and rules splitting standards for Node.js applications.

## 0. Authoritative External SSOT Gateways

- **Vite & Vitest Config**: `npx vite --help` / `npx vitest --help` -> Stage 1 `curl -fsSL https://vite.dev/llms.txt` / `https://vitest.dev/llms.txt` -> targeted `.md`.
- **ESLint & Prettier Config**: `npx eslint --print-config <file>`, `https://eslint.org/docs/latest/rules/`, `https://typescript-eslint.io/rules/`, `curl -fsSL https://prettier.io/llms.txt`.
- **GitHub Actions Tags**: Query exact SemVer tags with `git ls-remote --tags --refs https://github.com/<owner>/<repo>.git` before pinning workflow refs.

---

## 1. Modular Workspace Layout & Bundled Templates

Replace monolithic root `AGENTS.md` files with a lean root overview plus glob-triggered `.agents/rules/` and on-demand `.agents/skills/`. Scaffold directly from the templates under `./resources/`:

- **Root & Dependencies**:
  - `AGENTS.md` (< 3 KB overview, architecture map, verification commands): [lean-agents-template.md](./resources/lean-agents-template.md)
  - `.npmrc` (strict `ignore-scripts=true`, `save-exact=true`, `install-strategy=linked`, `strict-peer-deps=true`): [npmrc-template](./resources/npmrc-template)
  - `package.json` (three-tier `agent:*` scripts & `engines.node`): [package-json-template.json](./resources/package-json-template.json)
  - `vite.config.ts` (Vite build, React + TanStack Router + Tailwind plugins, Vitest `unit` + `e2e` projects): [vite-config-template.ts](./resources/vite-config-template.ts)
- **Editor (`.vscode/`)**:
  - `settings.json` (Prettier default formatter, `source.fixAll.eslint`, `routeTree.gen.ts` excluded): [vscode-settings-template.json](./resources/vscode-settings-template.json)
  - `extensions.json` (`dbaeumer.vscode-eslint`, `esbenp.prettier-vscode`, `bradlc.vscode-tailwindcss`, `typescriptteam.native-preview`): [vscode-extensions-template.json](./resources/vscode-extensions-template.json)
- **CI & Tooling**:
  - `.github/workflows/ci.yml`: [ci-workflow-template.yml](./resources/ci-workflow-template.yml)
  - `.agents/rules/ci-workflows.md`: [ci-workflows-rule-template.md](./resources/ci-workflows-rule-template.md)
  - `scripts/lint-tailwind.ts` (Tailwind CSS language-server diagnostics & utility sorting): [lint-tailwind-template.ts](./resources/lint-tailwind-template.ts)

Division of responsibility: global plugins (`common-modern-tools`, platform plugins, `modern-web-stack`) enforce universal CLI, runtime, TypeScript, React, Tailwind, and CI invariants; project `.agents/rules/` cover repository-specific domains (`src/server/database/**`, `src/routes/**`, `src/locales/**`).

---

## 2. Continuous Integration Invariants (`.github/`)

- **Exact SemVer Pinning**: Pin every `uses:` reference to an exact SemVer tag (`@vX.Y.Z`, never `@v1` or `@v7.0`); keep tags aligned with upstream releases via `git ls-remote --tags`.
- **Concurrency, Timeouts & Caching**: Declare top-level `concurrency` (`cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}`) on `push`/`pull_request` workflows, set `timeout-minutes: 15` per job, key caches by `${{ runner.os }}-${{ runner.arch }}`, and set `retention-days: 7` on failure artifacts.
- **Explicit Browser Setup**: With `.npmrc` `ignore-scripts=true`, run `npm run test:setup` (`npx playwright install chromium`) explicitly and cache browser binaries.
- **Local `actionlint` Gate**: Run `npm run agent:lint:ci` (`actionlint`) locally with 0 errors/warnings before staging; never embed `actionlint` steps in remote GitHub Actions workflows.

---

## 3. Three-Tier Verification Gate Architecture

- **Tier 1 (`npm run agent:verify:inner`)**: `npm run typecheck && npm run lint && npm run agent:lint:tailwind` (< 2s active-edit feedback).
- **Tier 2 (`npm run agent:verify:unit`)**: `npm run agent:verify:inner && npm run agent:test:unit` (`--reporter=tap-flat --no-color`).
- **Tier 3 (`npm run agent:verify:gate` / `npm run verify`)**: Full gate adding `npm run build`, `npm run agent:test:e2e` (Playwright), and `npm run check:deadcode` (`knip`).
