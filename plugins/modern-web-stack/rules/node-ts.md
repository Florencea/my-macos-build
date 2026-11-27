---
trigger: glob
globs: "**/*.ts, **/*.mts, **/*.cts, **/*.js, **/*.mjs, **/*.cjs, **/package.json, **/tsconfig*.json, **/vite.config.*, **/.npmrc"
description: Supply-chain .npmrc and cooldown governance, direct transparent JS/TS toolchain, pure ESM, and zero-suppression invariants.
---

# Node.js, TypeScript & npm Guardrails

## 1. Supply-Chain & Cooldown Governance

- **Strict `.npmrc` Policy**: Default to `audit=false`, `engine-strict=true`, `fund=false`, `ignore-scripts=true`, `install-strategy=linked`, `min-release-age=7`, `save-exact=true`, and `strict-peer-deps=true`. Install browser binaries via explicit scripts (such as `npm run test:setup`).
- **Native Module Exception (`allowScripts`)**: Only when a project requires specific native build scripts (e.g. desktop packaging), switch the project `.npmrc` to `ignore-scripts=false` and enforce a default-deny allowlist in `package.json` `"allowScripts"` permitting only audited exact package versions.
- **UX-First Dependency Cooldown**: Enforce a 7-day release floor in `.npmrc` (`min-release-age=7`) and batch toolchain dependency upgrades quarterly or semi-annually with a 7-14 day cooldown window. Patch immediately only for confirmed runtime CVEs (`npm audit --omit=dev`) or build security vulnerabilities; when a fix was published within 7 days, override selectively via `--min-release-age-exclude=<pkg>` or `--min-release-age=0` (or exempt audited first-party scopes via `min-release-age-exclude[]=@scope/*`) instead of removing `min-release-age=7`. Keep `knip` out of `devDependencies` and invoke `npx knip` on demand.
- **Node Engine Floor**: Omit root `engines.node` in `package.json` by default so `.npmrc` `engine-strict=true` enforces installed packages' declared `engines` ranges directly. Set a minimal floor (e.g. `>=22.18.0`) only when project scripts rely on unflagged native `.ts` execution.

---

## 2. Direct Transparent Toolchain (Zero Black Boxes)

- **Direct Proven Tools**: Use `npm` (`npm ci`, `npm run`, `npm pkg get/set/delete/fix`), standard TypeScript (`tsc -b --pretty false`), Vite, Vitest, ESLint (`strictTypeChecked`, `stylisticTypeChecked`, `noInlineConfig: true`, `--max-warnings 0`), and Prettier directly.
- **Forbid Experimental Wrappers & Previews**: Do not introduce meta-wrapper CLIs (`vite-plus`), experimental preview compilers (`tsgo`), or hidden AST rewrites. Prefer native `eslint.config.js` (`// @ts-check`) over TypeScript config loaders (`jiti`) when simple.
- **Shared Human-Agent Scripts**: Maintain one standard set of `npm run` scripts (`typecheck`, `lint`, `format:check`, `build`, `test`, `verify`) shared by humans and agents. Forbid duplicate `agent:*` script tracks; append `-- --reporter=tap-flat --no-color` ad hoc when compact test output is needed.

---

## 3. Pure ESM, Native APIs & Boundary Safety

- **Pure ESM & Built-Ins**: Require `"type": "module"`, forbid CommonJS (`require`, `module.exports`, `__dirname`), prefix built-ins with `node:`, and use `import.meta.dirname`. Prefer Node.js built-ins (`fetch`, `node:util`, `node:sqlite`, `node:test`, `crypto.randomUUID()`, `structuredClone()`) over utility packages.
- **Zero Suppression & Zod Boundaries**: Prohibit `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck`, `eslint-disable`, and double casts (`as unknown as T`). Validate untrusted external data (`JSON.parse`, API responses, configs, `process.env`) via Zod `safeParse` and `z.infer<typeof Schema>`. Invoke subprocesses via `execFileSync`/`spawnSync` with argument arrays (`{ shell: false }`).
- **Evidence Gate**: Verify upstream APIs via `node_modules/<pkg>/**/*.d.ts`, `npx eslint --print-config <file>`, or two-stage `llms.txt` lookups listed in `common-toolchain/references/docs-matrix.md`.
