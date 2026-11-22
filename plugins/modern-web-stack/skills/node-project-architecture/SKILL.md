---
name: node-project-architecture
description: Lean workspace blueprint, modular .agents/rules splitting, human-agent shared npm scripts, strict .npmrc and cooldown governance, and GitHub Actions CI baseline for Node.js and Web projects. Use when scaffolding projects or trimming bloated AGENTS.md.
compatibility: Node.js (Active LTS), fnm, npm, Vite, Vitest, ESLint, Prettier, Antigravity
---

# Node.js & Web Workspace Architecture Baseline

Minimal, transparent workspace conventions that stay human-maintainable without an AI agent.

## 1. Modular Documentation & Rules Splitting

Replace monolithic root `AGENTS.md` files with a concise root overview (< 3 KB) plus glob-triggered `.agents/rules/` and on-demand `.agents/skills/`:

- **Global Plugins Own Universal Invariants**: `common-modern-tools` (selection principles, human-agent collaboration, CLI, CI), `macos-modern-tools` (Darwin/Bash 3.2), and `modern-web-stack` (`.npmrc`, cooldown governance, direct JS/TS/UI guardrails).
- **Project `.agents/rules/` Own Domain Invariants**: Keep only repository-specific rules under `.agents/rules/` (e.g. `compiler.md`, `engine.md`, `electron-main.md`, `ui-styling.md`, `testing.md`).

Minimal bundled templates under `./resources/`:

- `AGENTS.md` baseline: [lean-agents-template.md](./resources/lean-agents-template.md)
- `.npmrc` baseline: [npmrc-template](./resources/npmrc-template)
- `.github/workflows/ci.yml` baseline: [ci-workflow-template.yml](./resources/ci-workflow-template.yml)

---

## 2. Human-Agent Shared `package.json` Scripts

Humans and agents share one standard script set without duplicate `agent:*` wrappers:

- `typecheck`: `tsc -b --pretty false`
- `lint` / `lint:fix`: `eslint --max-warnings 0 .` / `eslint --fix .`
- `format` / `format:check`: `prettier --write .` / `prettier --check .`
- `build`: `vite build` (or explicit multi-step linear build)
- `test` / `test:unit` / `test:e2e`: `vitest run` (append `-- --reporter=tap-flat --no-color` when compact output is desired)
- `test:setup`: `playwright install chromium` (explicit install under `ignore-scripts=true`)
- `verify`: `npm run typecheck && npm run lint && npm run format:check && npm run build && npm test`

Avoid pinning `knip` or `wrangler` in `devDependencies`; invoke on demand via `npx`.

---

## 3. Supply-Chain, Cooldown & Zero-Black-Box Checklist

- Enforce `.npmrc` defaults (`ignore-scripts=true`, `save-exact=true`, `install-strategy=linked`, `strict-peer-deps=true`, `engine-strict=true`); use project-level `ignore-scripts=false` + `allowScripts` allowlist only when audited native builds are required.
- Omit root `engines.node` unless project scripts require unflagged native `.ts` execution (`>=22.18.0`).
- Batch toolchain updates quarterly or semi-annually with a 7-14 day cooldown; prioritize runtime CVEs via `npm audit --omit=dev`.
- Keep Vite, Vitest, ESLint, Prettier, and TypeScript configured directly without wrapper CLIs, experimental compiler previews, custom LSP scripts, or generated route trees.
- Validate `.github/workflows/*.yml` locally with `actionlint` (`0` errors/warnings) before staging.
