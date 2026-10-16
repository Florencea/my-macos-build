---
trigger: glob
globs: "**/*.js, **/*.mjs, **/*.cjs, **/package.json, **/pnpm-workspace.yaml"
description: Modern Node.js pure ESM standards, pre-execution config verification, Zod runtime validation, native manifest operations, and zero-dependency built-in rules.
---

# Modern Node.js Execution Rules

## 1. Pre-Execution Config Verification & Native Manifest Operations

- **Pre-Verification Mandate**: Prior to writing or modifying any configuration files (`package.json`, `pnpm-workspace.yaml`, `.npmrc`, toolchain settings), agents MUST verify the exact schema and current runtime options:
  - Check dynamic project/runtime constraints: Run `vp toolchain` or inspect `engines.node` and dependencies in `package.json`. NEVER hardcode or assume fixed version numbers.
  - Query live documentation: Inspect `https://viteplus.dev/llms-full.txt` (via `webread --llms https://viteplus.dev`) or run `<tool> --help`.
  - NEVER guess syntax, package fields (e.g. `exports`, `imports`, `type`), or CLI flags from memory.
- **Native Manifest Operations (`vp pm pkg`)**:
  - When querying or mutating `package.json` fields programmatically, ALWAYS use native Vite+ package manifest commands:
    - Querying: `vp pm pkg get <key>` (or `vp -C <dir> pm pkg get <key>`)
    - Modifying: `vp pm pkg set <key>=<value>` (use `--json` for objects, numbers, booleans, arrays)
    - Deleting: `vp pm pkg delete <key>`
    - Standardizing: `vp pm pkg fix`
  - STRICTLY FORBIDDEN to use raw regex replacements or `jq` with intermediate file swapping (`package.json.tmp && mv`) to mutate `package.json`.

---

## 2. Environment Variables & Runtime Data Validation (Zod First)

- **Mandatory Validation for `process.env`**: Never use unvalidated environment variables or type casts:
  - ❌ `const port = Number(process.env.PORT) || 3000;`
  - ❌ `const secret = process.env.SECRET as string;`
- **Safe Zod Parsing**: Validate environment variables with Zod `safeParse` at process startup:
  ```ts
  import { z } from "zod";

  const EnvSchema = z.object({
    PORT: z.coerce.number().default(3000),
    NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
    DATABASE_URL: z.string().url(),
  });

  const parsedEnv = EnvSchema.safeParse(process.env);
  if (!parsedEnv.success) {
    console.error("Invalid environment variables:", parsedEnv.error.flatten());
    process.exitCode = 1;
    throw new Error("Environment configuration error");
  }
  export const env = parsedEnv.data;
  ```

---

## 3. Pure ESM & Module System

- **Pure ESM Only**: Always use pure ESM (`.mjs` or `"type": "module"` in `package.json`). Never write CommonJS (`require`, `module.exports`, `__dirname`, `__filename`).
- **Node Protocol Imports**: ALWAYS prefix Node built-in modules with `node:` (e.g. `import fs from 'node:fs/promises'`).
- **Native Path Resolution**: Use native built-in `import.meta.dirname` and `import.meta.filename` instead of `fileURLToPath` workarounds.
- **Top-Level Await**: Use top-level `await` freely in ESM scripts without wrapper functions.

---

## 4. Zero-Dependency Built-In Tooling (Batteries-Included)

Prioritize zero-dependency native built-ins supported by the active Node runtime over external third-party packages:

- **CLI Argument Parsing**: Use `node:util` `parseArgs({ options, allowPositionals })`. Avoid `commander`, `yargs`, or `minimist`.
- **Terminal Styling & Colors**: Use `node:util` `styleText('color', text)`. Avoid `chalk` or `colorette`.
- **File System Globbing**: Use `node:fs/promises` `glob(pattern)`. Avoid `fast-glob` or `glob`.
- **Embedded Database**: Use native `node:sqlite` (`DatabaseSync`) for local persistence instead of external native C-binding SQLite packages.
- **Environment Loading**: Use native `process.loadEnvFile()` where available instead of `dotenv`.
- **Native Web Standards**: Always use global `fetch`, `FormData`, `Request`, `Response`, `crypto.randomUUID()`, `structuredClone()`, `URL`, `AbortController`. Avoid `axios`, `uuid`, `lodash`.
- **Unit Testing**: Use native `node:test` and `node:assert/strict` for standalone Node scripts.

---

## 5. Process & Execution Safety

- **Process Execution**: In `node:child_process`, prefer `execFileSync` or `spawnSync` with an array of arguments and `shell: false` to prevent shell injection.
- **Clean Exit**: Signal failure by setting `process.exitCode = 1` rather than abruptly calling `process.exit(1)`, allowing pending asynchronous streams and stdout/stderr buffers to flush cleanly.

---

## 6. Agent-Friendly Vite+ Execution Formats & Task Caching

When running Node.js or Vite+ package manager commands as an agent, use token-efficient structured formats:

- **Production Server / Script Execution**: Prefer `vp node <script>` over raw unmanaged `node` to run within the Vite+ managed runtime environment.
- **Task Runner Caching**: In `vite.config.ts`, declare `run.cache: { scripts: true, tasks: true }` to cache script and task runs across invocations.
- **Cache Inspection**: Run `vpr --last-details` to verify whether task steps resulted in cache hits or misses.
- **Clean Execution & Cache Purging**: When troubleshooting unexpected behavior, use `vpr --no-cache` to force execution or `vp cache clean` to purge caches cleanly.
- **Installed Packages**: `vp list --json` (or `vp pm list --json`)
- **Outdated Dependencies**: `vp outdated --format json`
- **Toolchain Status**: `vp toolchain --json`
- **Test Runner**: `vp test run --reporter=tap-flat --no-color` (or `vp test run --json`)
