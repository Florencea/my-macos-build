---
trigger: glob
globs: "**/*.ts, **/*.mts, **/*.cts, **/*.js, **/*.mjs, **/*.cjs, **/package.json, **/tsconfig*.json, **/vite.config.*, **/.npmrc"
description: Modern Node.js pure ESM, strict .npmrc, TypeScript, Oxlint/Oxfmt, and Vitest invariants.
---

# Modern Node.js, TypeScript & npm Rules

## 1. Node.js, npm & Strict `.npmrc` Invariants

- **Strict `.npmrc` Policy**: Enforce `audit=false`, `engine-strict=true`, `fund=false`, `ignore-scripts=true`, `install-strategy=linked`, `save-exact=true`, and `strict-peer-deps=true`. Because `ignore-scripts=true` disables postinstall lifecycle hooks, install browser binaries or native artifacts via explicit scripts (such as `npm run test:setup`).
- **Manifest & Runner**: Inspect and edit `package.json` through `npm pkg get/set/delete/fix` (never raw regex or `jq` rewrites). Install from lockfiles using `npm ci`; invoke scripts via `npm run <script>` and binaries via `npx`.
- **Pure ESM & Built-Ins**: Require `"type": "module"`, forbid CommonJS (`require`, `module.exports`, `__dirname`), prefix built-ins with `node:`, and use `import.meta.dirname`.
- **Built-In APIs & Process Safety**: Prefer `fetch`, `crypto.randomUUID()`, `structuredClone()`, `node:sqlite`, and `node:test`. Invoke child processes via `execFileSync` / `spawnSync` with argument arrays (`{ shell: false }`) and prefer `process.exitCode = 1` over `process.exit(1)`. Match exact on-disk casing in import specifiers.

---

## 2. Strict TypeScript & Oxlint Gateways

- **Zero Suppression & Type Safety**: Prohibit `@ts-ignore`, `@ts-expect-error`, `oxlint-disable`, double casts (`as unknown as T`), and raw unsafe casts. Narrow types via discriminated unions, `typeof`/`instanceof`/`in`, `satisfies`, or Zod `safeParse`.
- **Control Flow & Lookups**: Require explicit boolean checks (`str !== ""`, `arr.length > 0`). Perform single Map lookup (`const v = map.get(k); if (v !== undefined)`). Interpolate only primitives in template literals. Await or return every promise, prefer `??` over `||`, and enforce `import type` (`verbatimModuleSyntax`).
- **Verification & Diagnostics**: Run `npx oxlint --rules` / `--print-config` and `npx oxlint -f agent` for token-efficient diagnostics; fetch rule docs via `curl -fsSL https://oxc.rs/docs/guide/usage/linter/rules/<plugin>/<rule>.md`. Run `npx oxfmt <files>`, `npm run typecheck` (or `npx tsc -b --pretty false`), and `npx vitest run` before finalizing.

---

## 3. External SSOT Lookups

- Query two-stage `llms.txt` -> `.md` docs (`nodejs.org/llms.txt`, `oxc.rs/llms.txt`, `vite.dev/llms.txt`, `vitest.dev/llms.txt`, `zod.dev/llms.txt`, `hono.dev/llms.txt`, `orm.drizzle.team/llms.txt`) via `curl -fsSL` or inspect local `node_modules/**/*.d.ts` instead of relying on memory.
