---
trigger: glob
globs: "**/*.ts, **/*.mts, **/*.cts, **/*.js, **/*.mjs, **/*.cjs, **/package.json, **/tsconfig*.json, **/vite.config.*"
description: Modern Node.js pure ESM, strict TypeScript, Vite+, Oxlint/Oxfmt, and Vitest invariants.
---

# Modern Node.js, TypeScript & Vite+ Rules

## 1. Node.js & Vite+ Invariants

- **Manifest & Runner**: Inspect and edit `package.json` strictly through `vp pm pkg get/set/delete` (never regex or `jq` rewrites). Enable `run.cache: { scripts: true }` in `vite.config.ts`.
- **Pure ESM & Built-Ins**: Require `"type": "module"`, forbid CommonJS (`require`, `module.exports`, `__dirname`), prefix built-ins with `node:`, and use `import.meta.dirname`.
- **Built-In APIs & Process Safety**: Prefer `fetch`, `crypto.randomUUID()`, `structuredClone()`, `node:sqlite`, and `node:test`. Invoke child processes via `execFileSync` / `spawnSync` with argument arrays (`{ shell: false }`) and prefer `process.exitCode = 1` over `process.exit(1)`. Match exact on-disk casing in import specifiers.

---

## 2. Strict TypeScript & Oxlint Gateways

- **Zero Suppression & Type Safety**: Prohibit `@ts-ignore`, `@ts-expect-error`, `oxlint-disable`, double casts (`as unknown as T`), and raw unsafe casts. Narrow types via discriminated unions, `typeof`/`instanceof`/`in`, `satisfies`, or Zod `safeParse`.
- **Control Flow & Lookups**: Require explicit boolean checks (`str !== ""`, `arr.length > 0`). Perform single Map lookup (`const v = map.get(k); if (v !== undefined)`). Interpolate only primitives in template literals. Await or return every promise, prefer `??` over `||`, and enforce `import type` (`verbatimModuleSyntax`).
- **Verification & Diagnostics**: Run `vp lint --rules` / `--print-config` and `vp lint -f agent` for token-efficient diagnostics; fetch rule docs via `webread https://oxc.rs/docs/guide/usage/linter/rules/<plugin>/<rule>.md`. Run `vp check`, `vp fmt <files>`, `vp run typecheck` (or `tsc -b --pretty false`), and `vp test run` (`vite-plus/test`) before finalizing.

---

## 3. External SSOT Lookups

- Query two-stage `llms.txt` -> `.md` docs (`nodejs.org/llms.txt`, `viteplus.dev/llms.txt`, `oxc.rs/llms.txt`, `zod.dev/llms.txt`, `hono.dev/llms.txt`, `orm.drizzle.team/llms.txt`) or local `node_modules/**/*.d.ts` instead of relying on memory.
